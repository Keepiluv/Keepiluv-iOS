//
//  HomeView.swift
//  FeatureHome
//
//  Created by 정지훈 on 1/26/26.
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem
import SharedPerfTestingSupport

/// 홈 화면을 렌더링하는 View입니다.
///
/// ## 사용 예시
/// ```swift
/// HomeView(
///     store: Store(
///         initialState: HomeReducer.State()
///     ) {
///         HomeReducer()
///     }
/// )
/// ```
///
/// ## Read-set split (Pass 3 Commit 3)
///
/// The view is decomposed into sibling sub-view structs so SwiftUI's
/// `@ObservableState` observation tracking can isolate which fields cause
/// which sub-view to re-render. Each sub-view's body only reads the fields
/// it actually uses, so a change to one field only invalidates the views
/// that observe it. Presentation modifiers (sheets / modal / fullScreenCover
/// / alert) move into `HomePresentationLayer`, a ViewModifier whose body
/// reads the presentation bindings — keeping that read-set off the parent
/// `HomeView.body`.
public struct HomeView: View {

    @Bindable public var store: StoreOf<HomeReducer>

    /// HomeView를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let view = HomeView(store: Store(initialState: HomeReducer.State()) { HomeReducer() })
    /// ```
    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // PERF probe harness — activated only for probe scenarios
            // (`-UITEST_PROBE_SCENARIO`). Reading store.toast / store.calendarDate
            // inside the harness adds an artificial read to the parent body;
            // this is acceptable because probe scenarios are not the
            // authoritative rendering metric.
            if UITestMode.isProbeScenario {
                HomePerfActionHarness(store: store)
                PerfRebuildProxyPing("home.view.rebuild.proxy")
            }
            HomeNavigationBarSection(store: store)
            HomeCalendarSection(store: store)
            // The branch reads presentation booleans so it stays in the parent
            // body. Each section owns the rest of its read-set.
            if store.isFetchFailed {
                DataRetryView {
                    store.send(.view(.dataRetryTapped))
                }
            } else if store.hasCards {
                HomeContentSection(store: store)
            } else if store.isEmptyVisible {
                HomeEmptyContentSection(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(PerfToastPresentationHarness(toast: $store.presentation.toast))
        .modifier(PerfHomeCounterMarkersHarness())
        .modifier(HomePresentationLayer(store: store))
        .onAppear {
            store.send(.view(.onAppear))
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
