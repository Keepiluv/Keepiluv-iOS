//
//  HomeNavigationBarSection.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem

/// `mainTitle`, `calendarMonthTitle`, `isRefreshHidden`, `hasUnreadNotification`을 읽습니다.
/// 콘텐츠나 presentation 상태 변경이 내비게이션 바를 다시 그리지 않도록
/// read-set을 분리합니다.
struct HomeNavigationBarSection: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        TXNavigationBar(
            style: .home(
                .init(
                    subTitle: store.calendarMonthTitle,
                    mainTitle: store.mainTitle,
                    isHiddenRefresh: store.isRefreshHidden,
                    isRemainedAlarm: store.hasUnreadNotification
                )
            ), onAction: { action in
                store.send(.navigationBarAction(action))
            }
        )
    }
}
