import Foundation
import CoreKit

/// UserDefaults-backed persistence for Ask Mira personas. JSON-encoded
/// list + a separate active-id pointer. The store always reports at
/// least the built-in `.default` persona so callers never see an empty
/// list, even on a fresh install.
public struct AskMiraPersonaStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let listKey: String
    private let activeKey: String

    public init(
        defaults: UserDefaults = .standard,
        listKey: String = "askmira.personas.list",
        activeKey: String = "askmira.personas.active"
    ) {
        self.defaults = defaults
        self.listKey = listKey
        self.activeKey = activeKey
    }

    public func load() -> [AskMiraPersona] {
        let user: [AskMiraPersona] = {
            guard let data = defaults.data(forKey: listKey),
                  let decoded = try? JSONDecoder().decode([AskMiraPersona].self, from: data) else {
                return []
            }
            return decoded
        }()
        return [.default] + user.filter { !$0.isBuiltIn }
    }

    public func saveUserPersonas(_ personas: [AskMiraPersona]) {
        let userOnly = personas.filter { !$0.isBuiltIn }
        guard let data = try? JSONEncoder().encode(userOnly) else { return }
        defaults.set(data, forKey: listKey)
    }

    public func activeID() -> UUID? {
        guard let raw = defaults.string(forKey: activeKey),
              let id = UUID(uuidString: raw) else {
            return nil
        }
        return id
    }

    public func setActiveID(_ id: UUID?) {
        if let id {
            defaults.set(id.uuidString, forKey: activeKey)
        } else {
            defaults.removeObject(forKey: activeKey)
        }
    }

    /// Resolves the currently active persona, falling back to the
    /// built-in default when no active id is set or it doesn't match
    /// any persisted persona (e.g. one was deleted while active).
    public func active() -> AskMiraPersona {
        let all = load()
        if let id = activeID(), let match = all.first(where: { $0.id == id }) {
            return match
        }
        return .default
    }
}
