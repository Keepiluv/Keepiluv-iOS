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

    var body: some View {
        #if PERF_TESTING
        if UITestMode.isEnabled, UITestMode.isSwiftUISelfRunFeedScroll {
            HomeSelfRunFeedScrollHarness(store: store) {
                scrollContent
            }
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
