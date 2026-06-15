//
//  AccountView.swift
//  FeatureSettings
//
//  Created by Jiyong on 02/05/26.
//

import ComposableArchitecture
import FeatureSettingsInterface
import SharedDesignSystem
import SwiftUI

/// 계정 화면입니다.
struct AccountView: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            if store.isSettingsFetchFailed {
                DataRetryView {
                    store.send(.view(.settingsDataRetryTapped))
                }
            } else {
                ScrollView {
                    accountList
                        .padding(.top, Spacing.spacing8)
                        .padding(.horizontal, Spacing.spacing8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .navigationBarBackButtonHidden(true)
        .txModal(item: $store.modal) { action in
            if action == .confirm {
                store.send(.view(.modalConfirmTapped))
            }
        }
        .txLoading(isPresented: store.isLoading)
    }
}

// MARK: - Navigation Bar

private extension AccountView {
    var navigationBar: some View {
        TXNavigationBar(style: .subTitle(title: "계정", type: .back)) { action in
            if action == .backTapped {
                store.send(.view(.subViewBackButtonTapped))
            }
        }
    }
}

// MARK: - Account List

private extension AccountView {
    var accountList: some View {
        VStack(spacing: 0) {
            logoutItem
            listDivider
            coupleCodeItem
            listDivider
            disconnectCoupleItem
            listDivider
            withdrawItem
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(Color.Gray.gray500, lineWidth: LineWidth.m)
        )
    }

    var logoutItem: some View {
        listItem(title: "로그아웃") {
            store.send(.view(.logoutTapped))
        }
    }

    var coupleCodeItem: some View {
        listItem(
            title: "커플코드",
            trailingText: store.coupleCode
        ) {
            // 탭해도 동작 없음 (표시만)
        }
    }

    var disconnectCoupleItem: some View {
        listItem(title: "커플 끊기") {
            store.send(.view(.disconnectCoupleTapped))
        }
    }

    var withdrawItem: some View {
        listItem(title: "탈퇴하기") {
            store.send(.view(.withdrawTapped))
        }
    }

    func listItem(
        title: String,
        trailingText: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .typography(.b1_14b)
                    .foregroundStyle(Color.Gray.gray500)

                Spacer()

                if let trailingText {
                    Text(trailingText)
                        .typography(.b2_14r)
                        .foregroundStyle(Color.Gray.gray500)
                }
            }
            .padding(Spacing.spacing7)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var listDivider: some View {
        Rectangle()
            .fill(Color.Gray.gray500)
            .frame(height: LineWidth.m)
    }
}
