import Foundation
import SwiftUI

/// Pass 3 direct instrumentation에서 사용하는 process-wide probe 전용 counter입니다.
/// `UITestMode.isEnabled`일 때만 값이 바뀌므로 production build에서는 boolean check 비용만 냅니다.
///
/// 이 값은 UITest driver / harness sanity signal이며, authoritative SwiftUI rendering metric이 아닙니다.
/// 최종 렌더링 판단은 Xcode Instruments / xctrace trace를 기준으로 합니다.
public enum PerfCounters {
#if PERF_TESTING
    private static let lock = NSLock()
    private static var values: [String: Int] = [:]
#endif

    /// 이름이 같은 counter를 1 증가시킵니다.
    /// Production build 또는 UITest가 아닌 실행에서는 no-op입니다.
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

    /// counter의 현재 값을 읽습니다.
    /// Production build 또는 UITest가 아닌 실행에서는 항상 0을 반환합니다.
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

/// SwiftUI view rebuild 빈도를 거칠게 보기 위한 proxy counter view입니다.
/// parent가 child node를 다시 만들 때 View struct가 재생성될 수 있으므로
/// `init`에서 counter를 증가시킵니다.
///
/// 이 값은 정확한 SwiftUI body evaluation count가 아닙니다. 보고서에서는
/// coarse invalidation-frequency signal로만 다루고, authoritative 분석에는
/// Xcode Instruments / xctrace trace를 사용합니다.
public struct PerfRebuildProxyPing: View {
    /// 추적할 counter key로 proxy ping view를 생성합니다.
    public init(_ key: String) {
#if PERF_TESTING
        PerfCounters.increment(key)
#else
        _ = key
#endif
    }

    /// 화면에는 보이지 않는 0 크기 view입니다.
    public var body: some View {
        Color.clear.frame(width: 0, height: 0)
    }
}
