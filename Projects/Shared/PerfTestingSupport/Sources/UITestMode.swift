import ComposableArchitecture
import SwiftUI

/// Launch argument contract shared by Example apps and perf UITests.
public enum UITestMode {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// Cached so production code on the increment fast-path of `PerfCounters`
    /// pays a single `let` read instead of scanning `ProcessInfo.arguments`
    /// every call.
    public static let isEnabled: Bool = arguments.contains("-UITEST")

    /// True when launched for a **probe scenario** (driver/marker/counter
    /// sanity test, e.g. `HomeExampleRenderingProbeTests`). Activates the
    /// PERF action harness and probe markers / counters in `HomeView`. Do
    /// not enable for authoritative rendering scenarios — the harness shifts
    /// HomeView layout by ~44pt and that may affect SwiftUI layout pass,
    /// scroll geometry, and LazyVStack materialization.
    public static let isProbeScenario: Bool = arguments.contains("-UITEST_PROBE_SCENARIO")

    /// True when launched for an **authoritative rendering scenario** driven
    /// by Xcode Instruments / xctrace (e.g. home-heavy feed scroll). Keeps
    /// the PERF probe harness disabled so the production layout / scroll
    /// geometry is preserved during trace recording.
    public static let isRenderingScenario: Bool = arguments.contains("-UITEST_RENDERING_SCENARIO")

    public static var seedName: String {
        value(after: "-UITEST_SEED") ?? "default"
    }

    public static var disablesAnimations: Bool {
        arguments.contains("-UITEST_DISABLE_ANIMATIONS")
    }

    public static var waitsForReady: Bool {
        arguments.contains("-UITEST_WAIT_READY")
    }

    public static func configureApplication() {
        guard isEnabled, disablesAnimations else { return }
        UIView.setAnimationsEnabled(false)
    }

    public static func dependencyValues(
        _ update: @escaping (inout DependencyValues) -> Void
    ) -> (inout DependencyValues) -> Void {
        { values in
            guard isEnabled else { return }
            update(&values)
        }
    }

    private static func value(after key: String) -> String? {
        guard let index = arguments.firstIndex(of: key) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}
