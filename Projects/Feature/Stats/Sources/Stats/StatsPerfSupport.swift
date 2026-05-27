//
//  StatsPerfSupport.swift
//  FeatureStats
//

import SwiftUI

import SharedDesignSystem
import SharedPerfTestingSupport

#if PERF_TESTING
/// Pass 4-S3 Stats feed self-run scroll 전용 harness입니다.
/// `StatsView`에서 ScrollViewReader / Task 상태를 분리합니다.
struct StatsSelfRunScrollHarness<Content: View>: View {
    let items: [StatsCardItem]
    private let content: Content

    /// Pass 4-S3 — guards the self-run scroll Task so it only fires once
    /// per scene appearance, even if SwiftUI invalidates the view during
    /// initial layout settling.
    @State private var selfRunStatsScrollStarted: Bool = false
    /// Pass 4-S3 — flips to `"true"` once the self-run scrollTo sequence
    /// completes. Surfaced via `perfStateMarker` so trace analysis can
    /// isolate the post-scroll window.
    @State private var selfRunStatsScrollDone: String = "false"

    init(
        items: [StatsCardItem],
        @ViewBuilder content: () -> Content
    ) {
        self.items = items
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .perfStateMarker(
                    slug: "stats",
                    key: "swiftui-selfrun-scroll",
                    value: selfRunStatsScrollDone
                )
                .onAppear { startSelfRunStatsScrollIfNeeded(proxy: proxy) }
        }
    }

    private func startSelfRunStatsScrollIfNeeded(proxy: ScrollViewProxy) {
        guard !selfRunStatsScrollStarted else { return }
        selfRunStatsScrollStarted = true
        let allIds = items.map(\.goalId)
        let stridedTargets = stride(from: 5, to: allIds.count, by: 5)
            .compactMap { allIds.indices.contains($0) ? allIds[$0] : nil }
        let preRollNanos: UInt64 = 1_000_000_000
        let stepIntervalNanos: UInt64 = 300_000_000
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: preRollNanos)
            for id in stridedTargets {
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .top)
                }
                try? await Task.sleep(nanoseconds: stepIntervalNanos)
            }
            selfRunStatsScrollDone = "true"
        }
    }
}
#endif
