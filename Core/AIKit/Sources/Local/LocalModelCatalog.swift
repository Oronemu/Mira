import Foundation

/// One downloadable on-device model. `huggingFaceRepo` is resolved by the
/// `LocalModelManager` against HuggingFace Hub; `sizeBytes` is indicative
/// (shown in the UI before download starts) and may drift from the real
/// payload over time.
public struct LocalModel: Sendable, Hashable, Identifiable, Codable {
    public let id: String
    public let displayName: String
    public let huggingFaceRepo: String
    public let sizeBytes: Int64
    public let minimumRAMGB: Int
    public let description: String
    /// Short bullet-style selling points — 3-4 items work best. Rendered in
    /// the model picker as a list with mood-colored dots.
    public let highlights: [String]

    public init(
        id: String,
        displayName: String,
        huggingFaceRepo: String,
        sizeBytes: Int64,
        minimumRAMGB: Int,
        description: String,
        highlights: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.huggingFaceRepo = huggingFaceRepo
        self.sizeBytes = sizeBytes
        self.minimumRAMGB = minimumRAMGB
        self.description = description
        self.highlights = highlights
    }
}

/// Curated list of models the app knows how to run. Adding a model here
/// is enough to surface it in the picker; no code changes elsewhere.
public enum LocalModelCatalog {
    public static let defaultModelID = "qwen-3-4b-instruct-4bit"

    public static let all: [LocalModel] = [
        LocalModel(
            id: "qwen-3-4b-instruct-4bit",
            displayName: "Qwen 3 4B",
            huggingFaceRepo: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
            sizeBytes: 2_260_000_000,
            minimumRAMGB: 8,
            description: "A compact 4-billion-parameter model from the Qwen 3 family with stronger reasoning than 3B. Recommended default for devices with 8 GB of RAM.",
            highlights: [
                "Needs 8 GB RAM: iPhone 15 Pro / 16 / 17, or M-series iPad/Mac",
                "Supports English and Russian out of the box",
                "≈2.3 GB download, ≈4 GB RAM during generation",
            ]
        ),
        LocalModel(
            id: "qwen-3-8b-instruct-4bit",
            displayName: "Qwen 3 8B",
            huggingFaceRepo: "lmstudio-community/Qwen3-8B-MLX-4bit",
            sizeBytes: 4_610_000_000,
            minimumRAMGB: 12,
            description: "A larger 8-billion-parameter model from Qwen 3 for noticeably deeper reflections and more nuanced writing. Needs a device with at least 12 GB of RAM.",
            highlights: [
                "Best on-device quality Mira can offer",
                "Richer, longer-form reflections",
                "Needs 12 GB RAM: iPhone 17, iPad Pro (1 TB+), or 16 GB+ Mac",
                "≈4.6 GB download — use Wi-Fi",
            ]
        ),
    ]

    public static func model(id: String) -> LocalModel? {
        all.first { $0.id == id }
    }

    public static var `default`: LocalModel {
        model(id: defaultModelID) ?? all[0]
    }
}
