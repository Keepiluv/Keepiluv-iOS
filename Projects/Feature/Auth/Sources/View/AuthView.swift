//
//  AuthView.swift
//  FeatureAuth
//
//  Created by Jiyong
//

// swiftlint:disable no_magic_numbers

import ComposableArchitecture
import FeatureAuthInterface
import SharedDesignSystem
import SwiftUI

public struct AuthView: View {
    let store: StoreOf<AuthReducer>

    public init(store: StoreOf<AuthReducer>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            backgroundIllustration
            foregroundContent
        }
        .background(Color.Common.white)
        .txLoading(isPresented: store.isLoading)
        .alert(
            "로그인 실패",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { _ in store.send(.view(.dismissError)) }
            )
        ) {
            Button("확인") {
                store.send(.view(.dismissError))
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

// MARK: - Background

private extension AuthView {
    var backgroundIllustration: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: geometry.size.height * 0.25)

                Image.Illustration.singing
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width)

                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Foreground

private extension AuthView {
    var foregroundContent: some View {
        VStack(spacing: 0) {
            headerSection
            Spacer()
            loginButtonsSection
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            logoView
            Spacer()
                .frame(height: Spacing.spacing9)
            titleView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.spacing9)
        .padding(.top, 36)
    }

    var logoView: some View {
        Image.Illustration.logo
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 20)
    }

    var titleView: some View {
        Text("""
            함께니까 멈추지 않아요.
            지금 바로 키피럽 시작하기!
            """)
            .typography(.h3_22eb)
            .foregroundStyle(Color.Gray.gray500)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var loginButtonsSection: some View {
        VStack(spacing: Spacing.spacing6) {
            kakaoLoginButton
            googleLoginButton
            appleLoginButton
        }
        .padding(.horizontal, Spacing.spacing8)
        .padding(.bottom, Spacing.spacing9)
    }
}

// MARK: - Login Buttons

private extension AuthView {
    var kakaoLoginButton: some View {
        Button {
            store.send(.view(.kakaoLoginButtonTapped))
        } label: {
            HStack(spacing: Spacing.spacing6) {
                Image.Icon.Symbol.kakao
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)

                Text("카카오로 시작하기")
                    .typography(.t3_14eb)
            }
            .foregroundStyle(Color.Gray.gray500)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(red: 254/255, green: 229/255, blue: 0/255))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading)
    }

    var googleLoginButton: some View {
        Button {
            store.send(.view(.googleLoginButtonTapped))
        } label: {
            HStack(spacing: Spacing.spacing6) {
                Image.Icon.Symbol.google
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)

                Text("Google로 시작하기")
                    .typography(.t3_14eb)
            }
            .foregroundStyle(Color.Gray.gray500)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.Common.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.Gray.gray200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading)
    }

    var appleLoginButton: some View {
        Button {
            store.send(.view(.appleLoginButtonTapped))
        } label: {
            HStack(spacing: Spacing.spacing6) {
                Image.Icon.Symbol.apple
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)

                Text("Apple로 시작하기")
                    .typography(.t3_14eb)
            }
            .foregroundStyle(Color.Common.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.Gray.gray500)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading)
    }

}

// swiftlint:enable no_magic_numbers

#Preview {
    AuthView(
        store: Store(
            initialState: AuthReducer.State(),
            reducer: { AuthReducer() }
        )
    )
}
