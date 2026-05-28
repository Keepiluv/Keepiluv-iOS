//
//  HomeCalendarSection.swift
//  FeatureHome
//

import SwiftUI

import ComposableArchitecture
import FeatureHomeInterface
import SharedDesignSystem
import SharedPerfTestingSupport

/// `$calendarDate` binding과 `calendarWeeks`를 읽습니다.
/// 캘린더 월 marker도 이 하위 뷰에 두어 parent body read-set으로 새지 않게 합니다.
struct HomeCalendarSection: View {
    @Bindable var store: StoreOf<HomeReducer>

    var body: some View {
        let calendarView = TXCalendar(
            mode: .weekly,
            currentDate: $store.calendarDate,
            weeks: store.calendarWeeks,
            config: .init(
                dateStyle: .init(lastDateTextColor: Color.Gray.gray500)
            ),
            onSelect: { item in
                store.send(.view(.calendarDateSelected(item)))
            },
            onSwipe: { swipe in
                store.send(.view(.weekCalendarSwipe(swipe)))
            }
        )
        .frame(maxWidth: .infinity, maxHeight: 76)
        .perfControl(slug: "home", element: "calendar")
        .transaction { transaction in
            transaction.animation = nil
        }

        if UITestMode.isProbeScenario {
            calendarView.perfStateMarker(
                slug: "home",
                key: "calendar-month",
                value: "\(store.calendarDate.year)-\(store.calendarDate.month)"
            )
        } else {
            calendarView
        }
    }
}
