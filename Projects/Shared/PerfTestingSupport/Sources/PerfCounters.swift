import Foundation
import SwiftUI

/// Process-wide **probe-only** counters for Pass 3 direct instrumentation.
/// Counters are only mutated when `UITestMode.isEnabled` is true, so
/// production builds pay only for a single boolean check on each call.
/// Counter values are surfaced to UITests via accessibility markers (see
/// `perfCounterMarkers(slug:keys:)`).
///
/// These counters are sanity signals for the UITest driver / harness, not
/// authoritative SwiftUI rendering metrics. The authoritative metric is an
/// Xcode Instruments / xctrace trace.
public enum PerfCounters {
#if PERF_TESTING
    private static let lock = NSLock()
    private static var values: [String: Int] = [:]
#endif

    /// Increments the named counter. No-op in production.
    public static func increment(_ key: String) {
#if PERF_TESTING
        guard UITestMode.isEnabled else { return }
        lock.lock()
        values[key, default: 0] += 1
        lock.unlock()
#else
        _ = key
#endif
    }

    /// Reads the current value of a counter. Always returns 0 in production.
    public static func value(for key: String) -> Int {
#if PERF_TESTING
        guard UITestMode.isEnabled else { return 0 }
        lock.lock()
        defer { lock.unlock() }
        return values[key, default: 0]
#else
        _ = key
        return 0
#endif
    }
}

/// **Proxy** counter for SwiftUI view rebuild frequency. Increments on every
/// `init` because SwiftUI re-instantiates the View struct whenever its parent
/// rebuilds the child node. This is a **proxy signal, not an exact SwiftUI
/// body-evaluation counter** — SwiftUI may skip body closure evaluation for
/// structurally identical views even when they are re-initialized, and
/// counter timing is affected by marker refresh and accessibility update
/// scheduling.
///
/// Treat the value as a coarse invalidation-frequency signal. Do not cite it
/// as "body evaluation count" in any rendering performance report. Use
/// Xcode Instruments / xctrace traces for authoritative analysis.
public struct PerfRebuildProxyPing: View {
    public init(_ key: String) {
#if PERF_TESTING
        PerfCounters.increment(key)
#else
        _ = key
#endif
    }

    public var body: some View {
        Color.clear.frame(width: 0, height: 0)
    }
}
