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

    /// Pass 4-S retry — SwiftUI Template self-run feasibility flag.
    /// When set, Example apps may dispatch reducer/binding actions from inside
    /// `launch-mode` to mimic interaction (e.g. comment typing) so that
    /// `xcrun xctrace --template SwiftUI --launch` can capture interactive
    /// SwiftUI rows without needing an XCUITest driver (attach-mode produces
    /// 0 rows on this device/OS). Example-only; production code must not branch
    /// on this.
    public static var isSwiftUISelfRunTyping: Bool {
        arguments.contains("-UITEST_SWIFTUI_SELF_RUN_TYPING")
    }

    /// Pass 4-S2 — Home feed self-running scroll. When set, the Home Example
    /// host's `LazyVStack` ScrollView is wrapped in a `ScrollViewReader` and
    /// a Task drives `proxy.scrollTo(...)` across a stride of `home-heavy`
    /// item ids so SwiftUI Template launch-mode can capture interactive
    /// scroll attribution. Example/perf-only; production code must not
    /// branch on this.
    public static var isSwiftUISelfRunFeedScroll: Bool {
        arguments.contains("-UITEST_SWIFTUI_SELF_RUN_FEED_SCROLL")
    }

    /// Pass 4-S3 — Stats feed self-running scroll. Analogous to
    /// `isSwiftUISelfRunFeedScroll` (Pass 4-S2) but for the Stats
    /// `StatsCardView` LazyVStack under the `stats-heavy` seed. When set,
    /// `StatsView.cardList` wraps its `ScrollView` in a `ScrollViewReader`
    /// and a Task drives `proxy.scrollTo(...)` across a stride of stats
    /// item `goalId`s so SwiftUI Template launch-mode can capture
    /// interactive scroll attribution for the Stats list. Example/perf-only;
    /// production code must not branch on this.
    public static var isSwiftUISelfRunStatsScroll: Bool {
        arguments.contains("-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL")
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
