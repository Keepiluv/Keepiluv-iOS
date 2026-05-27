import SwiftUI

public extension View {
    /// Exposes a root-level accessibility marker for the feature.
    ///
    /// IMPORTANT: applied as an overlay (Color.clear 1x1) rather than a
    /// direct `.accessibilityIdentifier` on the receiver. `accessibilityIdentifier`
    /// on a parent SwiftUI view propagates to descendant accessibility
    /// elements that don't have their own — so a direct identifier here
    /// would override child `perfControl(slug:element:)` / accessibility
    /// identifiers everywhere in the feature tree. The overlay pattern
    /// keeps the marker scoped to the inserted Color.clear element only.
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

    func perfFeed(_ slug: String) -> some View {
#if PERF_TESTING
        accessibilityIdentifier("feature.\(slug).feed")
#else
        self
#endif
    }

    func perfCell(slug: String, stableId: CustomStringConvertible) -> some View {
#if PERF_TESTING
        accessibilityIdentifier("feature.\(slug).cell.\(stableId)")
#else
        self
#endif
    }

    func perfControl(slug: String, element: String) -> some View {
#if PERF_TESTING
        accessibilityIdentifier("feature.\(slug).\(element)")
#else
        self
#endif
    }

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

    /// Exposes a deterministic accessibility marker whose identifier changes when
    /// `value` changes. UITests can `waitForExistence` on a specific value to
    /// detect that SwiftUI has reflected a state mutation.
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

    /// Exposes one accessibility marker per `PerfCounters` key. Each marker's
    /// identifier embeds the current counter value, e.g.
    /// `feature.home.counter.home.view.rebuild.proxy.42`. UITests can enumerate
    /// `feature.<slug>.counter.*` after a scenario completes to capture
    /// deltas. The markers are evaluated when the surrounding view body
    /// re-renders; trigger a body re-render via a state-change marker before
    /// reading.
    ///
    /// **Probe-only**. The counter values are sanity signals for the UITest
    /// driver, not authoritative SwiftUI rendering metrics.
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
