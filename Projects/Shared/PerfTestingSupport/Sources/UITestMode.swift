import ComposableArchitecture
import SwiftUI

/// Example 앱과 perf UITest가 공유하는 launch argument 계약입니다.
public enum UITestMode {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// `-UITEST` launch argument가 있는지 나타냅니다.
    /// `PerfCounters`의 fast-path에서 매번 `ProcessInfo.arguments`를 스캔하지 않도록 캐시합니다.
    public static let isEnabled: Bool = arguments.contains("-UITEST")

    /// probe scenario(driver / marker / counter sanity test)로 실행됐는지 나타냅니다.
    /// `HomeView`의 PERF action harness와 probe marker/counter를 켭니다.
    /// 실제 렌더링 측정에는 사용하지 않습니다.
    public static let isProbeScenario: Bool = arguments.contains("-UITEST_PROBE_SCENARIO")

    /// Xcode Instruments / xctrace로 기록하는 authoritative rendering scenario인지 나타냅니다.
    /// PERF probe harness를 끄고 production layout / scroll geometry를 유지합니다.
    public static let isRenderingScenario: Bool = arguments.contains("-UITEST_RENDERING_SCENARIO")

    /// `-UITEST_SEED` 뒤에 전달된 fixture seed 이름입니다.
    /// 값이 없으면 `"default"`를 반환합니다.
    public static var seedName: String {
        value(after: "-UITEST_SEED") ?? "default"
    }

    /// `-UITEST_DISABLE_ANIMATIONS` launch argument가 있는지 나타냅니다.
    /// UITest나 perf harness에서 애니메이션 noise를 줄이는 데 사용합니다.
    public static var disablesAnimations: Bool {
        arguments.contains("-UITEST_DISABLE_ANIMATIONS")
    }

    /// `-UITEST_WAIT_READY` launch argument가 있는지 나타냅니다.
    /// Example host가 ready marker를 노출해야 하는 scenario를 구분합니다.
    public static var waitsForReady: Bool {
        arguments.contains("-UITEST_WAIT_READY")
    }

    /// SwiftUI Template launch-mode에서 typing interaction을 self-run으로 재현할지 나타냅니다.
    /// attach-mode가 이 환경에서 0 rows를 내는 경우 interactive SwiftUI row attribution을 얻기 위한
    /// Example/perf 전용 flag입니다.
    public static var isSwiftUISelfRunTyping: Bool {
        arguments.contains("-UITEST_SWIFTUI_SELF_RUN_TYPING")
    }

    /// Home feed self-running scroll을 켤지 나타냅니다.
    /// Home Example host에서 `ScrollViewReader`와 `proxy.scrollTo(...)`를 사용해
    /// SwiftUI Template launch-mode가 scroll attribution을 캡처하도록 돕는 Example/perf 전용 flag입니다.
    public static var isSwiftUISelfRunFeedScroll: Bool {
        arguments.contains("-UITEST_SWIFTUI_SELF_RUN_FEED_SCROLL")
    }

    /// Stats feed self-running scroll을 켤지 나타냅니다.
    /// `stats-heavy` seed의 `StatsCardView` 리스트에서 scroll attribution을 캡처하기 위한
    /// Example/perf 전용 flag입니다.
    public static var isSwiftUISelfRunStatsScroll: Bool {
        arguments.contains("-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL")
    }

    /// MainTab Calendar bottomsheet self-running presentation을 켤지 나타냅니다.
    /// xctrace launch-mode가 Calendar bottomsheet presentation window를 직접 캡처하도록 돕는
    /// Example/perf 전용 flag입니다.
    public static var isSwiftUISelfRunCalendarBottomSheet: Bool {
        arguments.contains("-UITEST_SWIFTUI_SELF_RUN_CALENDAR_BOTTOM_SHEET")
    }

    /// 현재 launch argument에 따라 앱 전역 UITest 설정을 적용합니다.
    /// 지금은 `-UITEST_DISABLE_ANIMATIONS`가 있을 때 UIKit animation을 비활성화합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// UITestMode.configureApplication()
    /// ```
    public static func configureApplication() {
        guard isEnabled, disablesAnimations else { return }
        UIView.setAnimationsEnabled(false)
    }

    /// UITest일 때만 TCA dependency override를 적용하는 wrapper를 반환합니다.
    /// Production launch에서는 전달된 update closure를 실행하지 않습니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let update = UITestMode.dependencyValues { _ in
    ///     // UITest launch에서만 dependency override 적용
    /// }
    /// withDependencies(update) {
    ///     // UITest launch에서만 override 적용
    /// }
    /// ```
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
