//
//  NotificationReducer+Impl.swift
//  FeatureNotification
//
//  Created by Jiyong on 02/21/26.
//

import ComposableArchitecture
import DomainNotificationInterface
import FeatureNotificationInterface
import Foundation

extension NotificationReducer {
    /// 기본 구현을 제공하는 리듀서를 생성합니다.
    public init() {
        @Dependency(\.notificationClient) var notificationClient

        let reducer = Reduce<NotificationReducer.State, NotificationReducer.Action> { state, action in
            reduceCore(state: &state, action: action, notificationClient: notificationClient)
        }
        self.init(reducer: reducer)
    }
}

// MARK: - Core Reduce Logic

private func reduceCore(
    state: inout NotificationReducer.State,
    action: NotificationReducer.Action,
    notificationClient: NotificationClient
) -> Effect<NotificationReducer.Action> {
    switch action {
    case .binding:
        return .none

    case .view(let viewAction):
        return reduceView(state: &state, action: viewAction, notificationClient: notificationClient)

    case .response(let responseAction):
        return reduceResponse(state: &state, action: responseAction)

    case .delegate:
        return .none
    }
}

// MARK: - View

private func reduceView(
    state: inout NotificationReducer.State,
    action: NotificationReducer.Action.View,
    notificationClient: NotificationClient
) -> Effect<NotificationReducer.Action> {
    switch action {
    case .onAppear:
        return handleOnAppear(state: &state, notificationClient: notificationClient)

    case .backButtonTapped:
        return .send(.delegate(.navigateBack))

    case .notificationTapped(let item):
        return handleNotificationTapped(item: item, notificationClient: notificationClient)

    case .loadMore:
        return handleLoadMore(state: &state, notificationClient: notificationClient)
    }
}

// MARK: - Response

private func reduceResponse(
    state: inout NotificationReducer.State,
    action: NotificationReducer.Action.Response
) -> Effect<NotificationReducer.Action> {
    switch action {
    case .fetchListResponse(.success(let result)):
        state.isLoading = false
        state.notifications = IdentifiedArray(
            uniqueElements: result.notifications.map { NotificationItem(from: $0) }
        )
        state.hasNext = result.hasNext
        state.lastId = result.lastId
        return .none

    case .fetchListResponse(.failure):
        state.isLoading = false
        return .none

    case .fetchMoreResponse(.success(let result)):
        state.isLoadingMore = false
        let newItems = result.notifications.map { NotificationItem(from: $0) }
        for item in newItems {
            state.notifications.append(item)
        }
        state.hasNext = result.hasNext
        state.lastId = result.lastId
        return .none

    case .fetchMoreResponse(.failure):
        state.isLoadingMore = false
        return .none

    case .markAsReadResponse(let item, .success):
        state.notifications.remove(id: item.id)
        return .send(.delegate(.notificationSelected(item)))

    case .markAsReadResponse(let item, .failure):
        return .send(.delegate(.notificationSelected(item)))
    }
}

// MARK: - Action Handlers

private func handleOnAppear(
    state: inout NotificationReducer.State,
    notificationClient: NotificationClient
) -> Effect<NotificationReducer.Action> {
    guard !state.isLoading else { return .none }
    state.isLoading = true
    return .run { send in
        do {
            let result = try await notificationClient.fetchList(nil, 10)
            await send(.response(.fetchListResponse(.success(result))))

            try? await notificationClient.markAllAsRead()
        } catch {
            await send(.response(.fetchListResponse(.failure(error))))
        }
    }
}

private func handleLoadMore(
    state: inout NotificationReducer.State,
    notificationClient: NotificationClient
) -> Effect<NotificationReducer.Action> {
    guard !state.isLoadingMore,
          state.hasNext,
          let lastId = state.lastId else {
        return .none
    }

    state.isLoadingMore = true
    return .run { send in
        do {
            let result = try await notificationClient.fetchList(lastId, 20)
            await send(.response(.fetchMoreResponse(.success(result))))
        } catch {
            await send(.response(.fetchMoreResponse(.failure(error))))
        }
    }
}

private func handleNotificationTapped(
    item: NotificationItem,
    notificationClient: NotificationClient
) -> Effect<NotificationReducer.Action> {
    guard !item.isRead else {
        return .send(.delegate(.notificationSelected(item)))
    }

    return .run { send in
        do {
            try await notificationClient.markAsRead(item.id)
            await send(.response(.markAsReadResponse(item, .success(()))))
        } catch {
            await send(.response(.markAsReadResponse(item, .failure(error))))
        }
    }
}
