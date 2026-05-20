//
//  StatsView.swift
//  FeatureStats
//
//  Created by 정지훈 on 2/18/26.
//

import SwiftUI

import ComposableArchitecture
import FeatureStatsInterface
import SharedDesignSystem
import SharedPerfTestingSupport

struct StatsView: View {
    @Bindable public var store: StoreOf<StatsReducer>

    #if PERF_TESTING
    /// Pass 4-S3 — guards the self-run scroll Task so it only fires once
    /// per scene appearance, even if SwiftUI invalidates the view during
    /// initial layout settling.
    @State private var selfRunStatsScrollStarted: Bool = false
    /// Pass 4-S3 — flips to `"true"` once the self-run scrollTo sequence
    /// completes. Surfaced via `perfStateMarker` so trace analysis can
    /// isolate the post-scroll window.
    @State private var selfRunStatsScrollDone: String = "false"
    #endif

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            topTabBar
            if store.isOngoing {
                monthNavigation
                    .padding(.top, 16)
                    .background(Color.Gray.gray50)
            }
            
            if let items = store.items, !items.isEmpty {
                cardList
            }
            
            Spacer()
        }
        .background(Color.Gray.gray50)
        .overlay {
            if let items = store.items, items.isEmpty {
               statsEmptyView
            }
        }
        .onAppear { store.send(.onAppear) }
        .txToast(item: $store.toast)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - SubViews
private extension StatsView {
    var navigationBar: some View {
        TXNavigationBar(style: .mainTitle(title: "스탬프 통계"))
    }
    
    var topTabBar: some View {
        TXTab(
            style: .line(StatsTopTabItem.allCases),
            selectedItem: store.isOngoing ? .ongoing : .completed,
            onSelect: { item in
                store.send(.topTabBarSelected(item))
            }
        )
        .background(Color.Common.white)
    }
    
    @ViewBuilder
    var monthNavigation: some View {
        TXCalendarMonthNavigation(
            title: store.monthTitle,
            onTitleTap: { },
            isNextDisabled: store.isNextMonthDisabled,
            onPrevious: { store.send(.previousMonthTapped) },
            onNext: { store.send(.nextMonthTapped) }
        )
    }
    
    @ViewBuilder
    var cardList: some View {
        #if PERF_TESTING
        if UITestMode.isEnabled, UITestMode.isSwiftUISelfRunStatsScroll {
            selfRunCardList
        } else {
            scrollCardList
        }
        #else
        scrollCardList
        #endif
    }

    private var scrollCardList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(store.items ?? [], id: \.self.goalId) { item in
                    StatsCardView(
                        item: item,
                        isOngoing: store.isOngoing,
                        onTap: { goalId in
                            store.send(.statsCardTapped(goalId: goalId))
                        }
                    )
                    .perfCell(slug: "stats", stableId: item.goalId)
                }
            }
            .padding(.top, store.isOngoing ? 12 : 20)
            .padding([.horizontal, .bottom], 20)
            .perfFeed("stats")
        }
        .background(Color.Gray.gray50)
    }

    #if PERF_TESTING
    /// Pass 4-S3 — Example/perf-only branch. Wraps the same
    /// `scrollCardList` in a `ScrollViewReader` (public SwiftUI API) so a
    /// self-running Task can call `proxy.scrollTo(id:anchor:)` across a
    /// stride of `stats-heavy` item `goalId`s. State-driven self-run:
    /// not equivalent to real finger drag; lower bound on real scroll cost.
    private var selfRunCardList: some View {
        ScrollViewReader { proxy in
            scrollCardList
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
        let allIds = (store.items ?? []).map(\.goalId)
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
    #endif
    
    var statsEmptyView: some View {
        Group {
            if store.isOngoing {
                VStack(spacing: 8) {
                    Image.Illustration.scare
                    Text("아직 목표가 없어요!")
                        .typography(.t2_16b)
                        .foregroundStyle(Color.Gray.gray400)
                }
            } else {
                VStack(spacing: 8) {
                    Image.Illustration.trash
                    Text("아직 끝낸 목표가 없어요!")
                        .typography(.t2_16b)
                        .foregroundStyle(Color.Gray.gray400)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
