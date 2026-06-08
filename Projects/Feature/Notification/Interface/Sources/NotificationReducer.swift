//
//  NotificationReducer.swift
//  FeatureNotificationInterface
//
//  Created by Jiyong on 02/21/26.
//

import ComposableArchitecture
import DomainNotificationInterface
import Foundation

/// 알림 화면의 상태와 액션을 정의하는 리듀서입니다.
@Reducer
public struct NotificationReducer {
    private let reducer: Reduce<State, Action>

    /// 알림 화면의 상태입니다.
    @ObservableState
    public struct State: Equatable {
        public var notifications: IdentifiedArrayOf<NotificationItem>
        public var isLoading: Bool
        public var isFetchFailed: Bool
        public var isLoadingMore: Bool
        public var hasNext: Bool
        public var lastId: Int64?

        public init(
            notifications: IdentifiedArrayOf<NotificationItem> = [],
            isLoading: Bool = false,
            isFetchFailed: Bool = false,
            isLoadingMore: Bool = false,
            hasNext: Bool = false,
            lastId: Int64? = nil
        ) {
            self.notifications = notifications
            self.isLoading = isLoading
            self.isFetchFailed = isFetchFailed
            self.isLoadingMore = isLoadingMore
            self.hasNext = hasNext
            self.lastId = lastId
        }
    }

    /// 알림 화면에서 발생하는 액션입니다.
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case backButtonTapped
            case notificationTapped(NotificationItem)
            case loadMore
            case dataRetryTapped
        }

        // MARK: - Response
        public enum Response {
            case fetchListResponse(Result<NotificationListResult, Error>)
            case fetchMoreResponse(Result<NotificationListResult, Error>)
            case markAsReadResponse(NotificationItem, Result<Void, Error>)
        }

        // MARK: - Delegate
        public enum Delegate: Equatable {
            case navigateBack
            case notificationSelected(NotificationItem)
        }

        case view(View)
        case response(Response)
        case delegate(Delegate)
    }

    public init(reducer: Reduce<State, Action>) {
        self.reducer = reducer
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        reducer
    }
}
