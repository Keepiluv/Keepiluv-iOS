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
    
    var cardList: some View {
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
