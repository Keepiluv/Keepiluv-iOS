//
//  SettingsView.swift
//  FeatureSettings
//
//  Created by Jiyong on 02/05/26.
//

import ComposableArchitecture
import FeatureSettingsInterface
import SharedDesignSystem
import SwiftUI

/// 설정 화면입니다.
public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>
    @FocusState private var isTextFieldFocused: Bool

    public init(store: StoreOf<SettingsReducer>) {
        self.store = store
    }

    public var body: some View {
        settingsContent
    }

    private var settingsContent: some View {
        VStack(spacing: 0) {
            navigationBar

            ScrollView {
                VStack(spacing: Spacing.spacing9) {
                    profileSection
                        .padding(.horizontal, Spacing.spacing8)

                    settingsListSection
                        .padding(.horizontal, Spacing.spacing8)
                }
                .padding(.top, Spacing.spacing8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .onTapGesture {
            dismissKeyboard()
        }
        .onChange(of: isTextFieldFocused) { _, newValue in
            if !newValue && store.isEditing {
                store.send(.view(.nicknameEditingEnded))
            }
        }
        .txModal(item: $store.modal) { action in
            switch action {
            case let .confirmWithIndex(index):
                store.send(.view(.languageConfirmed(index)))
            case .confirm:
                store.send(.view(.modalConfirmTapped))
            default:
                break
            }
        }
        .onAppear {
            store.send(.view(.onAppear))
        }
        .toolbar(.hidden, for: .navigationBar)
        .txDataRetry(
            isPresented: store.isSettingsFetchFailed,
            onRetry: { store.send(.view(.settingsDataRetryTapped)) }
        )
    }

    private func dismissKeyboard() {
        isTextFieldFocused = false
    }
}

// MARK: - Navigation Bar

private extension SettingsView {
    var navigationBar: some View {
        TXNavigationBar(style: .subTitle(title: "설정", type: .back)) { action in
            switch action {
            case .backTapped:
                store.send(.view(.backButtonTapped))

            default:
                break
            }
        }
    }
}

// MARK: - Profile Section

private extension SettingsView {
    @ViewBuilder
    var profileSection: some View {
        if store.isEditing {
            editingProfileContent
        } else {
            HStack(spacing: Spacing.spacing7) {
                profileIcon
                displayProfileContent
                Spacer()
            }
        }
    }

    var profileIcon: some View {
        Image.Icon.Illustration.profile
            .resizable()
            .frame(width: 52, height: 52)
    }

    var displayProfileContent: some View {
        HStack(spacing: 0) {
            Text(store.nickname)
                .typography(.t1_18eb)
                .foregroundStyle(Color.Gray.gray500)

            Button {
                store.send(.view(.editButtonTapped))
            } label: {
                Image.Icon.Symbol.edit
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.Gray.gray500)
            }
            .frame(width: 44, height: 44)
        }
    }

    var editingProfileContent: some View {
        HStack(alignment: .top, spacing: Spacing.spacing5) {
            profileIcon

            nicknameTextField
                .frame(maxWidth: .infinity)
        }
    }

    var nicknameTextField: some View {
        TXTextField(
            text: $store.nickname,
            placeholderText: "닉네임을 입력해 주세요.",
            submitLabel: .done,
            tintColor: Color.Gray.gray500,
            subText: .init(text: "닉네임 2-8자", state: validationState)
        )
        .focused($isTextFieldFocused)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    var validationState: TXTextField.SubTextConfiguration.State {
        if store.nickname.isEmpty {
            return .empty
        }
        return store.isNicknameValid ? .valid : .invalid
    }
}

// MARK: - Settings List Section

private extension SettingsView {
    var settingsListSection: some View {
        VStack(spacing: 0) {
            languageSettingItem
            settingsDivider
            accountItem
            settingsDivider
            infoItem
            settingsDivider
            inquiryItem
            settingsDivider
            notificationItem
        }
        .background(Color.Common.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(Color.Gray.gray500, lineWidth: LineWidth.m)
        )
    }
    
    var languageSettingItem: some View {
        settingsListItem(
            icon: Image.Icon.Symbol.lang,
            title: "언어 설정",
            trailing: { languageTrailing }
        ) {
            dismissKeyboard()
            store.send(.view(.languageSettingTapped))
        }
    }

    var accountItem: some View {
        settingsListItem(
            icon: Image.Icon.Symbol.profile,
            title: "계정"
        ) {
            store.send(.view(.accountTapped))
        }
    }

    var infoItem: some View {
        settingsListItem(
            icon: Image.Icon.Symbol.info,
            title: "정보"
        ) {
            store.send(.view(.infoTapped))
        }
    }

    var inquiryItem: some View {
        settingsListItem(
            icon: Image.Icon.Symbol.qa,
            title: "문의하기",
            trailing: { inquiryTrailing }
        ) {
            store.send(.view(.inquiryTapped))
        }
    }
    
    var notificationItem: some View {
        settingsListItem(
            icon: Image.Icon.Symbol.alert,
            title: "알림 설정"
        ) {
            store.send(.view(.notificationSettingTapped))
        }
    }

    func settingsListItem<Trailing: View>(
        icon: Image,
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                HStack(spacing: Spacing.spacing5) {
                    icon
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color.Gray.gray500)

                    Text(title)
                        .typography(.b1_14b)
                        .foregroundStyle(Color.Gray.gray500)
                }

                Spacer()

                trailing()
            }
            .padding(Spacing.spacing7)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var settingsDivider: some View {
        Rectangle()
            .fill(Color.Gray.gray500)
            .frame(height: LineWidth.m)
    }

    @ViewBuilder
    var languageTrailing: some View {
        HStack(spacing: Spacing.spacing5) {
            Text(store.selectedLanguage.title)
                .typography(.b2_14r)
                .foregroundStyle(Color.Gray.gray500)

            arrowDownIcon
        }
    }

    @ViewBuilder
    var inquiryTrailing: some View {
        Text("평일 오전 9시 - 오후 6시 운영")
            .typography(.b2_14r)
            .foregroundStyle(Color.Gray.gray500)
    }

    var arrowDownIcon: some View {
        ZStack {
            Circle()
                .fill(Color.Gray.gray500)
                .frame(width: 18, height: 18)

            Image.Icon.Symbol.arrow1MDown
                .resizable()
                .renderingMode(.template)
                .frame(width: 14.14, height: 14.14)
                .foregroundStyle(Color.Common.white)
        }
    }
}
