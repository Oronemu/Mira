import Foundation
import os

/// Reports total device RAM and the per-process memory budget. Used to
/// gate large-model downloads/loads with a clear error instead of letting
/// the OS jetsam the app.
public enum DeviceMemoryProbe {
    private static let log = MiraLog.logger(.models)

    /// Total physical RAM on the device, in bytes.
    public static var physicalMemoryBytes: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    /// Remaining memory the process is allowed to allocate before iOS
    /// starts issuing jetsam warnings. Wraps `os_proc_available_memory()`.
    /// Returns 0 if the query is unsupported (e.g. some simulator builds).
    public static var availableBytes: Int {
        let value = os_proc_available_memory()
        return max(value, 0)
    }

    /// Minimum free allocation headroom (in bytes) to attempt loading a
    /// model whose weights are `weightsBytes` large. We reserve 1.2×
    /// weights for KV cache / inference buffers on top.
    public static func requiredBytesForModel(weightsBytes: Int64) -> Int64 {
        Int64(Double(weightsBytes) * 1.2)
    }

    public enum Feasibility: Sendable, Equatable {
        case ok
        case insufficientRAM(deviceGB: Double, requiredGB: Int)
        case insufficientBudget(availableGB: Double, requiredGB: Double)
    }

    /// Evaluates whether the current device has enough physical memory and
    /// per-process budget to run a model with the given requirements.
    public static func feasibility(
        requiredRAMGB: Int,
        weightsBytes: Int64
    ) -> Feasibility {
        let deviceGB = Double(physicalMemoryBytes) / 1_073_741_824.0
        // iOS carves out a non-trivial chunk from the marketed RAM
        // tier: `physicalMemory` on an 8 GB iPhone 15 Pro reports ~7.5
        // GB, and 12 GB iPhone 17 reports ~11.8 GB. Tolerate up to
        // ~0.75 GB below the requirement so devices that are nominally
        // at the tier still pass. 6 GB phones trying to run an 8 GB
        // model still fail (5.8 + 0.75 = 6.55 < 8).
        if Double(requiredRAMGB) > deviceGB + 0.75 {
            log.warning("Device RAM \(deviceGB, format: .fixed(precision: 1), privacy: .public) GB < required \(requiredRAMGB, privacy: .public) GB")
            return .insufficientRAM(deviceGB: deviceGB, requiredGB: requiredRAMGB)
        }
        let available = availableBytes
        let required = requiredBytesForModel(weightsBytes: weightsBytes)
        if available > 0 && Int64(available) < required {
            let availGB = Double(available) / 1_073_741_824.0
            let requiredGB = Double(required) / 1_073_741_824.0
            log.warning("Process budget \(availGB, format: .fixed(precision: 2), privacy: .public) GB < required \(requiredGB, format: .fixed(precision: 2), privacy: .public) GB")
            return .insufficientBudget(availableGB: availGB, requiredGB: requiredGB)
        }
        return .ok
    }

    public static func logSnapshot(label: String) {
        let deviceGB = Double(physicalMemoryBytes) / 1_073_741_824.0
        let availGB = Double(availableBytes) / 1_073_741_824.0
        log.info("mem[\(label, privacy: .public)] device=\(deviceGB, format: .fixed(precision: 1), privacy: .public)GB available=\(availGB, format: .fixed(precision: 2), privacy: .public)GB")
    }
}
