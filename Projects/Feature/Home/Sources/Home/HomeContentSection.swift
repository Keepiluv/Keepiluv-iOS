//
//  HomeContentSection.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem
import SharedPerfTestingSupport

/// `items`, `goalSectionTitle`을 읽는 홈 콘텐츠 영역입니다.
/// 50/200개 셀 `LazyVStack`을 소유하며, presentation flag 변경은 `HomePresentationLayer`에서 처리해
/// 카드 리스트 read-set을 오염시키지 않습니다.
struct HomeContentSection: View {
    let store: StoreOf<HomeReducer>

    #if PERF_TESTING
    /// Pass 4-S2: 초기 layout settling 중 body가 여러 번 invalidation되어도 self-run scroll Task가
    /// scene appearance당 한 번만 실행되도록 보호합니다.
    @State private var selfRunScrollStarted: Bool = false
    /// Pass 4-S2: scrollTo sequence가 끝나면 `"true"`로 바뀌며, trace 분석에서 post-scroll window를
    /// 분리할 수 있도록 `perfStateMarker`로 노출합니다.
    @State private var selfRunScrollDone: String = "false"
    #endif

    var body: some View {
        #if PERF_TESTING
        if UITestMode.isEnabled, UITestMode.isSwiftUISelfRunFeedScroll {
            selfRunScrollContent
        } else {
            scrollContent
        }
        #else
        scrollContent
        #endif
    }

    private var scrollContent: some View {
        ScrollView {
            Group {
                HomeHeaderRow(store: store)
                cardList
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 103)
        }
        .refreshable {
            store.send(.fetchGoals)
        }
    }

    #if PERF_TESTING
    /// Pass 4-S2: Example/perf 전용 branch입니다.
    /// 동일한 `scrollContent`를 `ScrollViewReader`로 감싸 launch-mode SwiftUI Template에서
    /// interactive scroll attribution을 캡처할 수 있게 합니다.
    private var selfRunScrollContent: some View {
        ScrollViewReader { proxy in
            scrollContent
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
    #endif

    var cardList: some View {
        LazyVStack(spacing: 16) {
            ForEach(store.items) { item in
                goalCard(for: item)
                    .perfCell(slug: "home", stableId: item.id)
            }
        }
        .padding(.top, 12)
        .perfFeed("home")
    }

    func goalCard(for item: HomeGoalItem) -> some View {
        GoalCardView(
            item: item.card,
            onHeaderTapped: { store.send(.headerTapped(item.card)) },
            onCheckButtonTapped: {
                store.send(.goalCheckButtonTapped(
                    id: item.id,
                    isChecked: item.card.myCard.isSelected
                ))
            },
            actionLeft: { store.send(.myCardTapped(item.card)) },
            actionRight: { store.send(.yourCardTapped(item.card)) }
        )
    }
}
