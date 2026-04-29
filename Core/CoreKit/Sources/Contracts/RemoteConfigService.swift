import Foundation

/// Sendable wrapper for remote-config default values. Mirrors the value
/// types Firebase Remote Config understands and lets us define an in-code
/// defaults table that satisfies Swift 6 concurrency.
public enum RemoteConfigDefaultValue: Sendable, Hashable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
}

/// Server-driven feature flags and textual parameters.
public protocol RemoteConfigService: Sendable {
    /// Seed the in-memory defaults table. Values set here are returned
    /// until a successful fetch replaces them.
    func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) async

    /// Fetch the latest config and activate it atomically. Returns `true`
    /// if any values changed versus the previously active set.
    @discardableResult
    func fetchAndActivate() async throws -> Bool

    /// Read the currently active string for a key, or `nil` if unset.
    func string(forKey key: String) async -> String?

    /// Read the currently active boolean for a key. Falls back to the
    /// default (or `false` if no default) when the key is absent.
    func bool(forKey key: String) async -> Bool

    /// Read the currently active integer for a key. Returns `0` when the
    /// key is absent and no default was seeded.
    func int(forKey key: String) async -> Int

    /// Read the currently active double for a key. Returns `0` when the
    /// key is absent and no default was seeded.
    func double(forKey key: String) async -> Double
}
