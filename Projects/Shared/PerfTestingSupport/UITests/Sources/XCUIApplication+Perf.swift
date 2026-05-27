import XCTest

public extension XCUIApplication {
    /// Selects which Pass 3 measurement mode the app launches in.
    /// `nil` keeps the app in plain UITest mode without any PERF harness or
    /// probe markers — appropriate for smoke / navigation / scroll tests
    /// that should not see harness-induced layout shifts.
    enum PerfScenarioKind: String {
        /// Activates the PERF action harness, probe markers, and proxy
        /// counters. For driver/marker sanity tests only — NOT for
        /// authoritative rendering measurements.
        case probe = "-UITEST_PROBE_SCENARIO"
        /// Keeps the PERF harness disabled while still being a UITest
        /// driver. Intended for xctrace / Instruments recording of real
        /// rendering scenarios (e.g. home-heavy feed scroll).
        case rendering = "-UITEST_RENDERING_SCENARIO"
    }

    static func launchForPerf(
        seed: String,
        scenario: PerfScenarioKind? = nil,
        disableAnimations: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-UITEST")
        app.launchArguments.append(contentsOf: ["-UITEST_SEED", seed])
        app.launchArguments.append("-UITEST_WAIT_READY")

        if disableAnimations {
            app.launchArguments.append("-UITEST_DISABLE_ANIMATIONS")
        }

        if let scenario {
            app.launchArguments.append(scenario.rawValue)
        }

        app.launch()
        return app
    }
}
