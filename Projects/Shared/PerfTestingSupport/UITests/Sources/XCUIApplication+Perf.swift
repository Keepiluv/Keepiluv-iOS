import XCTest

public extension XCUIApplication {
    /// 앱을 어떤 perf scenario mode로 실행할지 나타냅니다.
    /// `nil`이면 PERF harness나 probe marker 없이 plain UITest mode로 실행합니다.
    enum PerfScenarioKind: String {
        /// PERF action harness, probe marker, proxy counter를 켭니다.
        /// Driver / marker sanity test 전용이며 authoritative rendering 측정에는 사용하지 않습니다.
        case probe = "-UITEST_PROBE_SCENARIO"
        /// UITest driver는 유지하되 PERF harness는 끕니다.
        /// xctrace / Instruments로 실제 rendering scenario를 기록할 때 사용합니다.
        case rendering = "-UITEST_RENDERING_SCENARIO"
    }

    /// perf UITest용 launch argument를 구성하고 앱을 실행합니다.
    /// seed, scenario, animation 비활성화 여부를 한 곳에서 맞추기 위한 helper입니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let app = XCUIApplication.launchForPerf(
    ///     seed: "stats-heavy",
    ///     scenario: .rendering
    /// )
    /// ```
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
