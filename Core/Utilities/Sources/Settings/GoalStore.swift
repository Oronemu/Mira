import Foundation
import CoreKit

/// UserDefaults-backed CRUD for goals. Same shape as `HabitStore`.
public struct GoalStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "goals.list"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [Goal] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Goal].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.createdAt < $1.createdAt }
    }

    public func save(_ goal: Goal) {
        var current = load()
        if let index = current.firstIndex(where: { $0.id == goal.id }) {
            current[index] = goal
        } else {
            current.append(goal)
        }
        write(current)
    }

    public func delete(id: UUID) {
        write(load().filter { $0.id != id })
    }

    private func write(_ goals: [Goal]) {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        defaults.set(data, forKey: key)
    }
}
