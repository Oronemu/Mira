import Foundation
import CoreKit

/// UserDefaults-backed persistence for smart filters. Pure CRUD; no
/// reactive stream — the list is short and changes only on user
/// action, so the consumer can re-`load()` after each mutation.
public struct SavedFilterStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "entrylist.savedfilters"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [SavedFilter] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedFilter].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ filter: SavedFilter) {
        var current = load()
        if let index = current.firstIndex(where: { $0.id == filter.id }) {
            current[index] = filter
        } else {
            current.append(filter)
        }
        write(current)
    }

    public func delete(id: UUID) {
        let next = load().filter { $0.id != id }
        write(next)
    }

    private func write(_ filters: [SavedFilter]) {
        guard let data = try? JSONEncoder().encode(filters) else { return }
        defaults.set(data, forKey: key)
    }
}
