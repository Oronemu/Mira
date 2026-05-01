import Foundation
import Observation
import CoreKit
import Utilities
import AIKit

@MainActor
@Observable
public final class InsightsListState {
    public private(set) var insights: [InsightSnapshot] = []
    public private(set) var isGenerating: Bool = false
    public private(set) var errorMessage: String?

    private let repository: any InsightRepository
    private let entryRepository: any EntryRepository
    private let aiProvider: any AIProvider
    private let analyticsService: any AnalyticsService
    private let crashReporter: any CrashReporter

    public init(
        repository: any InsightRepository,
        entryRepository: any EntryRepository,
        aiProvider: any AIProvider,
        analyticsService: any AnalyticsService = UnimplementedAnalyticsService(),
        crashReporter: any CrashReporter = UnimplementedCrashReporter()
    ) {
        self.repository = repository
        self.entryRepository = entryRepository
        self.aiProvider = aiProvider
        self.analyticsService = analyticsService
        self.crashReporter = crashReporter
    }

    public func observe() async {
        for await snapshot in repository.observeAll() {
            insights = snapshot.sorted { $0.createdAt > $1.createdAt }
        }
    }

    public func generateNow(locale: Locale = .autoupdatingCurrent) async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            if try await ReflectionService().generate(
                locale: locale,
                aiProvider: aiProvider,
                entryRepository: entryRepository,
                insightRepository: repository
            ) != nil {
                HapticsService().play(.success)
                analyticsService.log(
                    event: "insight_generated",
                    parameters: ["source": .string("manual")]
                )
            }
        } catch let error as AIError {
            errorMessage = error.errorDescription
            HapticsService().play(.error)
            crashReporter.recordError(error, reason: "insights.generate.ai_error")
        } catch {
            errorMessage = error.localizedDescription
            HapticsService().play(.error)
            crashReporter.recordError(error, reason: "insights.generate")
        }
    }

    public func delete(id: UUID) async {
        do {
            try await repository.delete(id: id)
            HapticsService().play(.warning)
            analyticsService.log(event: "insight_deleted")
        } catch {
            errorMessage = error.localizedDescription
            crashReporter.recordError(error, reason: "insights.delete")
        }
    }
}
