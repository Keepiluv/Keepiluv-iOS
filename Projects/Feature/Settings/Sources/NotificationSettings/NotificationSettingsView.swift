//
//  NotificationSettingsView.swift
//  FeatureSettings
//
//  Created by Jiyong on 02/05/26.
//

import ComposableArchitecture
import FeatureSettingsInterface
import SharedDesignSystem
import SwiftUI

/// 알림 설정 화면입니다.
struct NotificationSettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            if store.isNotificationSettingsFetchFailed {
                DataRetryView {
                    store.send(.view(.notificationSettingsDataRetryTapped))
                }
            } else {
                ZStack {
                    if !store.isSystemNotificationEnabled {
                        disabledView
                    } else {
                        ScrollView {
                            notificationList
                                .padding(.top, Spacing.spacing8)
                                .padding(.horizontal, Spacing.spacing8)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            store.send(.view(.notificationSettingsOnAppear))
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.send(.view(.notificationSettingsOnAppear))
            }
        }
        .txLoading(isPresented: store.isNotificationSettingsLoading)
    }
}

// MARK: - Navigation Bar

private extension NotificationSettingsView {
    var navigationBar: some View {
        TXNavigationBar(style: .subTitle(title: "알림 설정", type: .back)) { action in
            if action == .backTapped {
                store.send(.view(.subViewBackButtonTapped))
            }
        }
    }
}

// MARK: - Disabled View (System Notification Off)

private extension NotificationSettingsView {
    var disabledView: some View {
        VStack(spacing: 0) {
            enableNotificationBanner
                .padding(.top, Spacing.spacing6)
                .padding(.horizontal, Spacing.spacing8)

            Spacer()
        }
    }

    var enableNotificationBanner: some View {
        Button {
            store.send(.view(.enableNotificationBannerTapped))
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("(권장) 알림을 켜 주세요.")
                        .typography(.b1_14b)
                        .foregroundStyle(Color.Gray.gray500)

                    Text("메이트의 소식을 받아볼 수 있어요.")
                        .typography(.c1_12r)
                        .foregroundStyle(Color.Gray.gray300)
                }

                Spacer()

                Image.Icon.Symbol.arrow1MRight
                    .foregroundStyle(Color.Gray.gray300)
            }
            .padding(Spacing.spacing7)
            .background(Color.Common.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s)
                    .stroke(Color.Gray.gray500, lineWidth: LineWidth.m)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification List

private extension NotificationSettingsView {
    var notificationList: some View {
        VStack(spacing: 0) {
            pokePushItem
            listDivider
            marketingPushItem
            listDivider
            nightMarketingPushItem
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(Color.Gray.gray500, lineWidth: LineWidth.m)
        )
    }

    var pokePushItem: some View {
        toggleItem(
            title: "찌르기 푸쉬알림",
            isOn: store.isPokePushEnabled,
            onToggle: { store.send(.view(.pokePushToggled($0))) }
        )
    }

    var marketingPushItem: some View {
        toggleItem(
            title: "마케팅 정보 푸쉬알림",
            isOn: store.isMarketingPushEnabled,
            onToggle: { store.send(.view(.marketingPushToggled($0))) }
        )
    }

    var nightMarketingPushItem: some View {
        toggleItem(
            title: "야간 마케팅 정보 푸쉬알림",
            isOn: store.isNightMarketingPushEnabled,
            onToggle: { store.send(.view(.nightPushToggled($0))) }
        )
    }

    func toggleItem(
        title: String,
        isOn: Bool,
        onToggle: @escaping (Bool) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .typography(.b1_14b)
                .foregroundStyle(Color.Gray.gray500)

            Spacer()

            TXToggleSwitch(isOn: Binding(
                get: { isOn },
                set: { onToggle($0) }
            ))
        }
        .padding(Spacing.spacing7)
        .frame(height: 64)
    }

    var listDivider: some View {
        Rectangle()
            .fill(Color.Gray.gray500)
            .frame(height: LineWidth.m)
    }
}
