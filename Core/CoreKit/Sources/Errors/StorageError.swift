import Foundation

public enum StorageError: LocalizedError, Sendable {
    case notFound
    case corruptedData
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            String(localized: "Data not found.")
        case .corruptedData:
            String(localized: "Data is corrupted.")
        case .underlying(let message):
            message
        }
    }
}
