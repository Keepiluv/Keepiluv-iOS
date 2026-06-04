//
//  MainTabView.swift
//  Feature
//
//  Created by 정지훈 on 1/4/26.
//

import SwiftUI

import ComposableArchitecture
import FeatureHome
import FeatureHomeInterface
import FeatureGoalDetail
import FeatureStats
import FeatureStatsInterface
import FeatureProofPhoto
import SharedDesignSystem

/// 메인 탭 화면을 표시하는 View입니다.
///
/// ## 사용 예시
/// ```swift
/// MainTabView(
///     store: Store(
///         initialState: MainTabReducer.State(),
///         reducer: { MainTabReducer() }
///     )
/// )
/// ```
public struct MainTabView: View {
    @Bindable public var store: StoreOf<MainTabReducer>

    /// MainTabView를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let view = MainTabView(
    ///     store: Store(initialState: MainTabReducer.State()) { MainTabReducer() }
    /// )
    /// ```
    public init(store: StoreOf<MainTabReducer>) {
        self.store = store
    }

    public var body: some View {
        TXTabBarContainer(
            selectedItem: $store.selectedTab,
            isTabBarHidden: store.isTabBarHidden
        ) {
            HomeCoordinatorView(store: store.scope(state: \.home, action: \.home))
                .tag(TXTabItem.home)
            
            StatsCoordinatorView(store: store.scope(state: \.stats, action: \.stats))
                .tag(TXTabItem.statistics)
            
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tag(TXTabItem.couple)
        }
        .overlay(alignment: .bottomTrailing) {
            if store.shouldShowHomeFloatingButton {
                homeFloatingButton
            }
        }
        .txToast(
            item: $store.home.home.presentation.toast,
            customPadding: TXTabBarLayout.height
        )
        .txLoading(isPresented: isTabLoading)
    }
}

private extension MainTabView {
    var isTabLoading: Bool {
        (store.selectedTab == .home && store.home.routes.isEmpty && store.home.home.ui.isLoading) ||
        (store.selectedTab == .statistics && store.stats.routes.isEmpty && store.stats.stats.ui.isLoading)
    }
}

private extension MainTabView {
    var homeFloatingButton: some View {
        TXButton(
            shape: .circle(
                style: .basic(icon: Image.Icon.Symbol.plusL),
                size: .m,
                state: .standard
            ),
            onTap: { store.send(.home(.home(.view(.floatingButtonTapped)))) }
        )
        .outsideBorder(
            Color.Gray.gray300,
            shape: .circle,
            lineWidth: LineWidth.m
        )
        .shadow(color: .black.opacity(0.16), radius: 20, x: 2, y: 1)
        .padding(.trailing, 16)
        .padding(.bottom, 12 + TXTabBarLayout.height)
    }
}

#Preview {
    MainTabView(store: Store(initialState: MainTabReducer.State(), reducer: {
        MainTabReducer()
    }))
}
