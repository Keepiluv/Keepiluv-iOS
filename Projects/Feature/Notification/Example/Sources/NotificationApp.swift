//
//  NotificationApp.swift
//  FeatureNotificationExample
//
//  Created by Jiyong on 02/21/26.
//

import ComposableArchitecture
import FeatureNotification
import FeatureNotificationInterface
import SharedDesignSystem
import SharedPerfTestingSupport
import SwiftUI

@main
struct NotificationApp: App {
    init() {
        UITestMode.configureApplication()
    }

    var body: some Scene {
        WindowGroup {
            NotificationView(
                store: Store(
                    initialState: NotificationReducer.State(
                        notifications: NotificationApp.mockNotifications
                    ),
                    reducer: {
                        NotificationReducer()
                    }
                )
            )
            .perfRoot("notification")
            .perfReadyMarker("notification")
        }
    }
}

// MARK: - Mock Data

extension NotificationApp {
    static let referenceDate = Date(timeIntervalSince1970: 1_772_496_000)

    static let mockNotifications: IdentifiedArrayOf<NotificationItem> = [
        NotificationItem(
            id: 1,
            type: "PARTNER_CONNECTED",
            title: "파트너 연결",
            message: "닉네임길어도될까님과 연결됐어요!",
            deepLink: nil,
            isRead: false,
            createdAt: referenceDate
        ),
        NotificationItem(
            id: 2,
            type: "GOAL_COMPLETED",
            title: "목표 완료",
            message: "닉네임길어도될까님의 오늘 하루가 등록됐어요. 확인해 볼까요?",
            deepLink: nil,
            isRead: false,
            createdAt: referenceDate
        ),
        NotificationItem(
            id: 3,
            type: "POKE",
            title: "찌르기",
            message: "닉네임길어도될까님이 찔렀어요! 오늘 하루도 파이팅~",
            deepLink: nil,
            isRead: false,
            createdAt: referenceDate
        ),
        NotificationItem(
            id: 4,
            type: "GOAL_COMPLETED",
            title: "목표 완료",
            message: "닉네임길어도될까님이 끝냄 인증샷을 올렸네요! 보러 가봐요!",
            deepLink: nil,
            isRead: false,
            createdAt: referenceDate
        ),
        NotificationItem(
            id: 5,
            type: "REACTION",
            title: "리액션",
            message: "닉네임길어도될까님이 내게 반응을 남겼어요. 보러 가봐요!",
            deepLink: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        ),
        NotificationItem(
            id: 6,
            type: "DAILY_GOAL_ACHIEVED",
            title: "데일리 목표 달성",
            message: "축하해요! 오늘도 열심히 산 우리에게 박수~",
            deepLink: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: referenceDate) ?? referenceDate
        ),
        NotificationItem(
            id: 7,
            type: "DAILY_GOAL_ACHIEVED",
            title: "데일리 목표 달성",
            message: "축하해요! 오늘도 열심히 산 우리에게 박수~",
            deepLink: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: referenceDate) ?? referenceDate
        ),
        NotificationItem(
            id: 8,
            type: "DAILY_GOAL_ACHIEVED",
            title: "데일리 목표 달성",
            message: "축하해요! 오늘도 열심히 산 우리에게 박수~",
            deepLink: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: referenceDate) ?? referenceDate
        ),
        NotificationItem(
            id: 9,
            type: "DAILY_GOAL_ACHIEVED",
            title: "데일리 목표 달성",
            message: "축하해요! 오늘도 열심히 산 우리에게 박수~",
            deepLink: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        ),
        NotificationItem(
            id: 10,
            type: "DAILY_GOAL_ACHIEVED",
            title: "데일리 목표 달성",
            message: "축하해요! 오늘도 열심히 산 우리에게 박수~",
            deepLink: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -10, to: referenceDate) ?? referenceDate
        ),
        // 14일 초과 - 필터링되어 표시되지 않음
        NotificationItem(
            id: 11,
            type: "MARKETING",
            title: "마케팅",
            message: "이 알림은 15일 전이라 표시되지 않아요",
            deepLink: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -15, to: referenceDate) ?? referenceDate
        ),
        NotificationItem(
            id: 12,
            type: "MARKETING",
            title: "마케팅",
            message: "이 알림은 20일 전이라 표시되지 않아요",
            deepLink: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -20, to: referenceDate) ?? referenceDate
        )
    ]
}
