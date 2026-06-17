//
//  NotificationView.swift
//  FeatureNotification
//
//  Created by Jiyong on 02/21/26.
//

import ComposableArchitecture
import FeatureNotificationInterface
import SharedDesignSystem
import SharedUtil
import SwiftUI

/// 알림 화면입니다.
public struct NotificationView: View {
    @Bindable var store: StoreOf<NotificationReducer>

    public init(store: StoreOf<NotificationReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            navigationBar

            if store.isFetchFailed {
                DataRetryView {
                    store.send(.view(.dataRetryTapped))
                }
            } else {
                ZStack {
                    if filteredNotifications.isEmpty {
                        emptyView
                    } else {
                        contentView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .onAppear {
            store.send(.view(.onAppear))
        }
        .toolbar(.hidden, for: .navigationBar)
        .txLoading(isPresented: store.isLoading && store.notifications.isEmpty)
    }
}

// MARK: - Navigation Bar

private extension NotificationView {
    var navigationBar: some View {
        TXNavigationBar(style: .subTitle(title: "알림", type: .back)) { action in
            switch action {
            case .backTapped:
                store.send(.view(.backButtonTapped))

            default:
                break
            }
        }
    }
}

// MARK: - Content View

private extension NotificationView {
    var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.spacing3) {
                sectionHeader

                notificationList
            }
            .padding(.top, Spacing.spacing6)
            .padding(.horizontal, Spacing.spacing8)
            .padding(.bottom, Spacing.spacing8)
        }
    }
}

// MARK: - Empty View

private extension NotificationView {
    var emptyView: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("알림이 없어요")
                .typography(.t1_18eb)
                .foregroundStyle(Color.Gray.gray300)

            Spacer()
        }
    }
}

// MARK: - Section Header

private extension NotificationView {
    var sectionHeader: some View {
        Text("최근 14일")
            .typography(.t1_18eb)
            .foregroundStyle(Color.Gray.gray500)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Notification List

private extension NotificationView {
    /// 14일 이내 알림만 필터링
    var filteredNotifications: [NotificationItem] {
        store.notifications.filter { $0.isWithin14Days }
    }

    var notificationList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredNotifications.enumerated()), id: \.element.id) { index, item in
                let isLast = index == filteredNotifications.count - 1
                notificationListItem(item, isLast: isLast)
                    .onAppear {
                        // 마지막 3개 아이템 중 하나가 보이면 미리 로드
                        if index >= filteredNotifications.count - 3 {
                            store.send(.view(.loadMore))
                        }
                    }
            }

            if store.isLoadingMore {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.Gray.gray500))
                    .frame(height: 44)
            }
        }
    }

    func notificationListItem(_ item: NotificationItem, isLast: Bool) -> some View {
        Button {
            store.send(.view(.notificationTapped(item)))
        } label: {
            HStack(spacing: Spacing.spacing9) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(item.message)
                        .typography(.b1_14b)
                        .foregroundStyle(Color.Gray.gray500)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(RelativeTimeFormatter().displayText(from: item.createdAt))
                        .typography(.b1_14b)
                        .foregroundStyle(Color.Gray.gray200)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.leading, Spacing.spacing3)
                }
                .frame(width: 280, alignment: .leading)

                Spacer(minLength: 0)

                if item.isNew {
                    newBadge
                }
            }
            .frame(height: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.Gray.gray100)
                    .frame(height: LineWidth.m)
            }
        }
    }

    var newBadge: some View {
        Text("NEW")
            .typography(.b4_12b)
            .foregroundStyle(Color.Common.white)
            .frame(width: 30)
            .padding(.horizontal, Spacing.spacing5)
            .padding(.vertical, Spacing.spacing3)
            .background(Color.Gray.gray500)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
    }
}
