//
//  InfoView.swift
//  FeatureSettings
//
//  Created by Jiyong on 02/05/26.
//

import ComposableArchitecture
import FeatureSettingsInterface
import SharedDesignSystem
import SwiftUI

/// 정보 화면입니다.
struct InfoView: View {
    @Bindable var store: StoreOf<SettingsReducer>

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            ScrollView {
                infoList
                    .padding(.top, Spacing.spacing8)
                    .padding(.horizontal, Spacing.spacing8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            store.send(.view(.onAppear))
        }
    }
}

// MARK: - Navigation Bar

private extension InfoView {
    var navigationBar: some View {
        TXNavigationBar(style: .subTitle(title: "정보", type: .back)) { action in
            if action == .backTapped {
                store.send(.view(.subViewBackButtonTapped))
            }
        }
    }
}

// MARK: - Info List

private extension InfoView {
    var infoList: some View {
        VStack(spacing: 0) {
            privacyPolicyItem
            listDivider
            myVersionItem
            listDivider
            storeVersionItem
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(Color.Gray.gray500, lineWidth: LineWidth.m)
        )
    }

    var privacyPolicyItem: some View {
        listItem(title: "개인정보 처리방침") {
            store.send(.view(.privacyPolicyTapped))
        }
    }

    var myVersionItem: some View {
        listItem(
            title: "나의 버전",
            trailingText: store.appVersion
        ) {
            // 탭해도 동작 없음 (표시만)
        }
    }

    var storeVersionItem: some View {
        listItem(
            title: "스토어 최신 버전",
            trailingText: store.storeVersion
        ) {
            // 탭해도 동작 없음 (표시만)
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
