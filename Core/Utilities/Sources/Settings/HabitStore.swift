import Foundation
import CoreKit

/// UserDefaults-backed CRUD for habits. Mirror of `GoalStore` /
/// `SavedFilterStore` — the lists are short, so callers reload rather
/// than subscribing.
public struct HabitStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "habits.list"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [Habit] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Habit].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ habit: Habit) {
        var current = load()
        if let index = current.firstIndex(where: { $0.id == habit.id }) {
            current[index] = habit
        } else {
            current.append(habit)
        }
        write(current)
    }

    public func delete(id: UUID) {
        write(load().filter { $0.id != id })
    }

    private func write(_ habits: [Habit]) {
        guard let data = try? JSONEncoder().encode(habits) else { return }
        defaults.set(data, forKey: key)
    }
}
