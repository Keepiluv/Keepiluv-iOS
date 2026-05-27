//
//  OnboardingProfileView.swift
//  FeatureOnboarding
//
//  Created by Jiyong on 01/28/26.
//

import ComposableArchitecture
import SharedDesignSystem
import SwiftUI

/// 프로필 설정(닉네임 입력) 화면입니다.
public struct OnboardingProfileView: View {
    @Bindable var store: StoreOf<OnboardingProfileReducer>
    @FocusState private var isTextFieldFocused: Bool

    public init(store: StoreOf<OnboardingProfileReducer>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    titleSection
                        .padding(.top, 72)
                        .padding(.horizontal, Spacing.spacing9)
                        .padding(.bottom, 32)

                    textFieldSection
                        .padding(.horizontal, Spacing.spacing8)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            Spacer()

            bottomButton
                .padding(.horizontal, Spacing.spacing8)
                .padding(.bottom, isTextFieldFocused ? Spacing.spacing6 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .onTapGesture {
            isTextFieldFocused = false
        }
        .txToast(item: $store.toast, customPadding: 76)
        .txLoading(isPresented: store.isLoading)
    }
}

// MARK: - Subviews

private extension OnboardingProfileView {
    var titleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("""
                    짝꿍에게 보일
                    내 이름을 입력해 주세요
                    """)
                    .typography(.h3_22eb)
                    .foregroundStyle(Color.Gray.gray500)
            }
            Spacer()
        }
    }

    var textFieldSection: some View {
        TXTextField(
            text: $store.nickname,
            placeholderText: "닉네임을 입력해 주세요.",
            isFocused: $isTextFieldFocused,
            subText: .init(text: "닉네임 2-8자", state: validationState)
        )
    }

    var validationState: TXTextField.SubTextConfiguration.State {
        if store.nickname.isEmpty {
            return .empty
        }
        return store.isNicknameValid ? .valid : .invalid
    }

    var bottomButton: some View {
        TXButton(
            shape: .rect(
                style: .basic(text: "완료"),
                size: .l,
                state: store.isNicknameValid ? .standard : .disabled
            ),
            onTap: { store.send(.view(.completeButtonTapped)) }
        )
    }
}
