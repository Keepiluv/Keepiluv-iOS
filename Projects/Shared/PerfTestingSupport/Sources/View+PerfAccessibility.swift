import SwiftUI

public extension View {
    /// feature root-level accessibility marker를 노출합니다.
    ///
    /// Parent SwiftUI view에 직접 `accessibilityIdentifier`를 붙이면
    /// child identifier를 덮을 수 있으므로,
    /// 1x1 `Color.clear` overlay에만 marker를 붙입니다.
    func perfRoot(_ slug: String) -> some View {
#if PERF_TESTING
        overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("feature.\(slug).root")
        }
#else
        self
#endif
    }

    /// feature feed container에 deterministic accessibility identifier를 부여합니다.
    /// PERF_TESTING build가 아니면 원본 view를 그대로 반환합니다.
    func perfFeed(_ slug: String) -> some View {
#if PERF_TESTING
        accessibilityIdentifier("feature.\(slug).feed")
#else
        self
#endif
    }

    /// feature feed cell에 stable id 기반 accessibility identifier를 부여합니다.
    /// UITest driver가 특정 cell을 찾거나 scroll target을 잡을 때 사용합니다.
    func perfCell(slug: String, stableId: CustomStringConvertible) -> some View {
#if PERF_TESTING
        accessibilityIdentifier("feature.\(slug).cell.\(stableId)")
#else
        self
#endif
    }

    /// feature control에 accessibility identifier를 부여합니다.
    /// Button, calendar 등 interaction target을 UITest에서 안정적으로 찾기 위한 helper입니다.
    func perfControl(slug: String, element: String) -> some View {
#if PERF_TESTING
        accessibilityIdentifier("feature.\(slug).\(element)")
#else
        self
#endif
    }

    /// feature가 perf scenario 준비를 마쳤음을 나타내는 ready marker를 노출합니다.
    /// UITest는 이 marker가 나타날 때까지 기다린 뒤 action을 시작합니다.
    func perfReadyMarker(_ slug: String) -> some View {
#if PERF_TESTING
        overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("feature.\(slug).ready")
        }
#else
        self
#endif
    }

    /// `value` 변경에 따라 identifier가 바뀌는 deterministic accessibility marker를 노출합니다.
    /// UITest는 특정 값의 marker를 기다려 SwiftUI가 state mutation을 반영했는지
    /// 확인할 수 있습니다.
    func perfStateMarker(slug: String, key: String, value: String) -> some View {
#if PERF_TESTING
        overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("feature.\(slug).marker.\(key).\(value)")
        }
#else
        self
#endif
    }

    /// `PerfCounters` key마다 accessibility marker를 하나씩 노출합니다.
    /// 각 marker identifier에는 현재 counter 값이 포함됩니다.
    ///
    /// Probe 전용 sanity signal이며, authoritative SwiftUI rendering metric으로 인용하지 않습니다.
    func perfCounterMarkers(slug: String, keys: [String]) -> some View {
#if PERF_TESTING
        overlay(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(keys, id: \.self) { key in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier(
                            "feature.\(slug).counter.\(key).\(PerfCounters.value(for: key))"
                        )
                }
            }
        }
#else
        self
#endif
    }
}
