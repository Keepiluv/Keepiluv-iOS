//
//  HomePerfSupport.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem
import SharedPerfTestingSupport

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
