//
//  OnboardingConnectView.swift
//  FeatureOnboarding
//
//  Created by Jiyong on 01/28/26.
//

import ComposableArchitecture
import SharedDesignSystem
import SwiftUI

/// 커플 연결 온보딩 화면입니다.
public struct OnboardingConnectView: View {
    @Bindable var store: StoreOf<OnboardingConnectReducer>

    public init(store: StoreOf<OnboardingConnectReducer>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            backgroundIllustration
            foregroundContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Common.white)
        .sheet(isPresented: $store.isShareSheetPresented) {
            store.send(.view(.shareSheetDismissed))
        } content: {
            ShareSheet(activityItems: [store.shareContent])
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .txBottomSheet(isPresented: $store.isRestoreCoupleSheetPresented) {
            restoreCoupleSheetContent
        }
    }
}

// MARK: - Background

private extension OnboardingConnectView {
    var backgroundIllustration: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: geometry.size.height * 0.22)

                illustrationSection
                    .frame(maxWidth: .infinity)

                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Foreground

private extension OnboardingConnectView {
    var foregroundContent: some View {
        VStack(spacing: 0) {
            topAppBar

            titleSection
                .padding(.top, Spacing.spacing8)

            Spacer()

            buttonSection
                .padding(.horizontal, Spacing.spacing12)

            restoreCoupleButton
                .padding(.top, Spacing.spacing8)
                .padding(.bottom, 32)
        }
    }
}

// MARK: - Subviews

private extension OnboardingConnectView {
    var topAppBar: some View {
        HStack {
            Button {
                store.send(.view(.logoutButtonTapped))
            } label: {
                Image.Icon.Symbol.logout
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.Gray.gray500)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)

            Spacer()
        }
        .padding(.leading, 10)
        .padding(.top, 14)
    }

    var titleSection: some View {
        HStack {
            Text("""
                짝꿍과 연결하고
                함께 키피럽 시작하세요
                """)
                .typography(.h3_22eb)
                .foregroundStyle(Color.Gray.gray500)
            Spacer()
        }
        .padding(.horizontal, Spacing.spacing9)
    }

    var illustrationSection: some View {
        Image.Illustration.invite
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 300, height: 300)
    }

    var buttonSection: some View {
        VStack(spacing: 20) {
            sendInvitationButton

            directConnectCard
        }
    }

    var sendInvitationButton: some View {
        Button {
            store.send(.view(.sendInvitationButtonTapped))
        } label: {
            Text("초대장 보내기")
                .typography(.t2_16b)
                .foregroundStyle(Color.Common.white)
                .frame(maxWidth: .infinity)
                .frame(height: 86)
                .background(Color.Gray.gray500)
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        }
        .buttonStyle(.plain)
    }

    var directConnectCard: some View {
        Button {
            store.send(.view(.directConnectCardTapped))
        } label: {
            HStack(spacing: 3) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("짝꿍에게 코드를 받았다면?")
                        .typography(.c1_12r)
                        .foregroundStyle(Color.Gray.gray400)
                    
                    Text("직접 연결하기").typography(.t2_16b)
//                    HStack(spacing: 0) {
//                        Text("직접 ").typography(.t2_16eb)
//                        Text("연결하기").typography(.t2_16b)
//                    }.foregroundStyle(Color.Gray.gray500)
                }

                Spacer()

                arrowButton
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 18)
            .frame(height: 86)
            .background(Color.Common.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s)
                    .strokeBorder(Color.Gray.gray500, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    var arrowButton: some View {
        Image.Icon.Symbol.arrow3Right
            .resizable()
            .renderingMode(.template)
            .frame(width: 34, height: 34)
            .foregroundStyle(Color.Gray.gray500)
            .frame(width: 44, height: 44)
            .background(Color.Gray.gray50)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.Gray.gray500, lineWidth: LineWidth.m)
            )
    }

    var restoreCoupleButton: some View {
        Button {
            store.send(.view(.restoreCoupleButtonTapped))
        } label: {
            HStack(spacing: 0) {
                Text("해지한 커플 복구하려면?")
                    .typography(.b1_14b)
                    .foregroundStyle(Color.Gray.gray400)

                Image.Icon.Symbol.arrow1MRight
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.Gray.gray400)
            }
        }
        .buttonStyle(.plain)
    }

    var restoreCoupleSheetContent: some View {
        VStack(spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("해지한 커플 복구하려면?")
                    .typography(.t1_18eb)
                    .foregroundStyle(Color.Gray.gray500)

                Text("아래 내용을 포함하여 문의해 주시기 바랍니다.\n고객센터 메일 - ttwixteamm@gmail.com")
                    .typography(.b2_14r)
                    .foregroundStyle(Color.Gray.gray400)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)

            // Info Box
            VStack(alignment: .leading, spacing: 0) {
                bulletItem("본인 로그인 계정 메일")
                bulletItem("짝꿍의 로그인 계정 메일")
                bulletItem("해지 일시")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.spacing7)
            .padding(.vertical, Spacing.spacing6)
            .frame(height: 78)
            .background(Color.Gray.gray50)
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            .padding(.horizontal, 30)
        }
        .padding(.bottom, Spacing.spacing7)
    }

    func bulletItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.spacing2) {
            Text("•")
                .typography(.b4_12b)
                .foregroundStyle(Color.Gray.gray300)

            Text(text)
                .typography(.b4_12b)
                .foregroundStyle(Color.Gray.gray300)
        }
    }
}
