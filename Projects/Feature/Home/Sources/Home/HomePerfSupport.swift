//
//  HomePerfSupport.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem
import SharedPerfTestingSupport

#if PERF_TESTING
/// Pass 4-S2 Home feed self-run scroll 전용 harness입니다.
/// Production content section에서 ScrollViewReader / Task 상태를 분리합니다.
struct HomeSelfRunFeedScrollHarness<Content: View>: View {
    let store: StoreOf<HomeReducer>
    private let content: Content

    /// Pass 4-S2: 초기 layout settling 중 body가 여러 번 invalidation되어도 self-run scroll Task가
    /// scene appearance당 한 번만 실행되도록 보호합니다.
    @State private var selfRunScrollStarted: Bool = false
    /// Pass 4-S2: scrollTo sequence가 끝나면 `"true"`로 바뀌며, trace 분석에서 post-scroll window를
    /// 분리할 수 있도록 `perfStateMarker`로 노출합니다.
    @State private var selfRunScrollDone: String = "false"

    init(
        store: StoreOf<HomeReducer>,
        @ViewBuilder content: () -> Content
    ) {
        self.store = store
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .perfStateMarker(
                    slug: "home",
                    key: "swiftui-selfrun-scroll",
                    value: selfRunScrollDone
                )
                .onAppear { startSelfRunScrollIfNeeded(proxy: proxy) }
        }
    }

    private func startSelfRunScrollIfNeeded(proxy: ScrollViewProxy) {
        guard !selfRunScrollStarted else { return }
        selfRunScrollStarted = true
        let allIds = store.items.map(\.id)
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
            selfRunScrollDone = "true"
        }
    }
}
#endif

/// Pass 3 probe scenario(toast / calendar month toggle)에서만 쓰는 PERF 전용 control입니다.
/// `store.calendarDate` 읽기를 별도 sub-view에 가둬 probe scenario에서도 parent `HomeView.body`
/// read-set을 오염시키지 않게 합니다.
///
/// Production layout에서는 `UITestMode.isProbeScenario`가 false라 이 branch가 진입되지 않습니다.
/// 이 harness는 `-UITEST_PROBE_SCENARIO` launch argument가 있을 때만 노출되며, authoritative rendering
/// scenario(`-UITEST_RENDERING_SCENARIO`)와 섞으면 안 됩니다.
struct HomePerfActionHarness: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        HStack(spacing: 0) {
            Button {
                store.send(.showToast(.warning(message: "perf-toast")))
            } label: {
                Text(verbatim: "T")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("feature.home.perf.toast-show")

            Button {
                store.toast = nil
            } label: {
                Text(verbatim: "X")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("feature.home.perf.toast-dismiss")

            Button {
                var next = store.calendarDate
                next.goToNextMonth()
                store.send(.setCalendarDate(next))
            } label: {
                Text(verbatim: "▶")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("feature.home.perf.calendar-next")

            Button {
                var prev = store.calendarDate
                prev.goToPreviousMonth()
                store.send(.setCalendarDate(prev))
            } label: {
                Text(verbatim: "◀")
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("feature.home.perf.calendar-prev")
        }
        .opacity(0.05)
    }
}

/// Pass 3 probe scenario에서 `toast` state-change marker를 노출하는 PERF 전용 modifier입니다.
/// Production에서는 `content`를 그대로 반환해 `HomeView` read-set에 `toast`가
/// 포함되지 않게 합니다.
struct PerfToastPresentationHarness: ViewModifier {
    @Binding var toast: TXToastType?

    func body(content: Content) -> some View {
        if UITestMode.isProbeScenario {
            content
                .overlay(alignment: .bottom) {
                    if toast != nil {
                        Color.clear.frame(width: 1, height: 1)
                    }
                }
                .perfStateMarker(
                    slug: "home",
                    key: "toast",
                    value: toast == nil ? "hidden" : "visible"
                )
        } else {
            content
        }
    }
}

/// Probe scenario에서만 `perfCounterMarkers` accessibility overlay를 붙입니다.
/// Rendering / smoke launch에서는 marker overlay가 붙지 않습니다.
struct PerfHomeCounterMarkersHarness: ViewModifier {
    func body(content: Content) -> some View {
        if UITestMode.isProbeScenario {
            content.perfCounterMarkers(
                slug: "home",
                keys: ["home.view.rebuild.proxy"]
            )
        } else {
            content
        }
    }
}
