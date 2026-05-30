import Foundation
import CoreKit
import Utilities
@preconcurrency import MLXLMCommon
@preconcurrency import MLXLLM

/// On-device `AIProvider` backed by MLX. Models live on disk under the
/// path owned by `LocalModelManager`; the first request loads the
/// `ModelContainer` into memory and reuses it until the app is evicted.
public actor MLXLocalProvider: AIProvider {
    private let manager: LocalModelManager
    private var loadedContainer: ModelContainer?
    private var loadedModelID: String?

    public init(manager: LocalModelManager = .shared) {
        self.manager = manager
    }

    public var isAvailable: Bool {
        get async {
            let modelID = manager.currentModelID
            guard let model = await manager.resolveModel(id: modelID) else { return false }
            return await manager.isDownloaded(model)
        }
    }

    public var requiresStrictPrompts: Bool {
        get async { true }
    }

    public func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        let modelID = manager.currentModelID
        guard let model = await manager.resolveModel(id: modelID) else {
            throw AIError.noProviderConfigured
        }
        guard await manager.isDownloaded(model) else {
            throw AIError.providerUnavailable
        }

        try preflightMemory(for: model)

        let container = try await ensureLoaded(model: model)
        let chat = Self.toChatMessages(request.messages)
        let temperature = Float(request.temperature)
        let maxTokens = request.maxTokens
        let chatBox = SendableBox(value: chat)

        return AsyncThrowingStream { continuation in
            let work = Task {
                do {
                    try await container.perform { context in
                        let userInput = UserInput(chat: chatBox.value)
                        let lmInput = try await context.processor.prepare(input: userInput)
                        let stream = try MLXLMCommon.generate(
                            input: lmInput,
                            parameters: GenerateParameters(temperature: temperature),
                            context: context
                        )
                        var emitted = 0
                        for await event in stream {
                            try Task.checkCancellation()
                            if case .chunk(let text) = event {
                                continuation.yield(AIResponseChunk(textDelta: text))
                                emitted += 1
                                if let maxTokens, emitted >= maxTokens { break }
                            }
                        }
                    }
                    continuation.yield(AIResponseChunk(textDelta: "", isFinal: true))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIError.cancelled)
                } catch {
                    continuation.finish(throwing: AIError.requestFailed(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    private struct SendableBox<T>: @unchecked Sendable {
        let value: T
    }

    private func ensureLoaded(model: LocalModel) async throws -> ModelContainer {
        if let loadedContainer, loadedModelID == model.id {
            return loadedContainer
        }
        // Drop any previously-loaded container before allocating the next
        // one — otherwise switching between 3B and 7B briefly holds both
        // in memory and blows the process budget.
        loadedContainer = nil
        loadedModelID = nil
        DeviceMemoryProbe.logSnapshot(label: "before-load:\(model.id)")
        let configuration = ModelConfiguration(id: model.huggingFaceRepo)
        let hub = await manager.hub
        let container = try await LLMModelFactory.shared.loadContainer(
            hub: hub,
            configuration: configuration
        )
        loadedContainer = container
        loadedModelID = model.id
        DeviceMemoryProbe.logSnapshot(label: "after-load:\(model.id)")
        return container
    }

    public func unload() {
        loadedContainer = nil
        loadedModelID = nil
    }

    /// Throws `AIError.insufficientMemory` with a user-facing message if
    /// the device physically can't host the model or the per-process
    /// budget is already too small. Called before we touch MLX/Metal so
    /// users see a readable error instead of a jetsam-induced crash.
    ///
    /// When the model is already resident, we only check headroom for this
    /// turn's KV cache instead of the full weights — otherwise the resident
    /// weights get double-counted and valid follow-up turns are rejected.
    private func preflightMemory(for model: LocalModel) throws {
        let alreadyLoaded = loadedContainer != nil && loadedModelID == model.id
        let feasibility = alreadyLoaded
            ? DeviceMemoryProbe.feasibilityForLoadedModel()
            : DeviceMemoryProbe.feasibility(
                requiredRAMGB: model.minimumRAMGB,
                weightsBytes: model.sizeBytes
            )
        switch feasibility {
        case .ok:
            return
        case .insufficientRAM(let deviceGB, let requiredGB):
            throw AIError.insufficientMemory(
                String(
                    format: String(localized: "This model needs ~%d GB of RAM, but this device has %.1f GB. Pick a smaller model in Settings."),
                    requiredGB,
                    deviceGB
                )
            )
        case .insufficientBudget(let availableGB, let requiredGB):
            throw AIError.insufficientMemory(
                String(
                    format: String(localized: "Not enough free memory right now (~%.1f GB available, ~%.1f GB needed). Close other apps and try again."),
                    availableGB,
                    requiredGB
                )
            )
        }
    }

    private static func toChatMessages(_ messages: [AIMessage]) -> [Chat.Message] {
        messages.map { message in
            switch message.role {
            case .system: .system(message.content)
            case .user: .user(message.content)
            case .assistant: .assistant(message.content)
            }
        }
    }
}
