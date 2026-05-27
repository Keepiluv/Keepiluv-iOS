//
//  SettingsReducer+Impl.swift
//  FeatureSettings
//
//  Created by Jiyong on 02/05/26.
//

import ComposableArchitecture
import CoreNetworkInterface
import CorePushInterface
import DomainAuthInterface
import DomainNotificationInterface
import DomainOnboardingInterface
import FeatureSettingsInterface
import Foundation
import SharedDesignSystem
import SharedUtil
import UIKit
import UserNotifications

extension SettingsReducer {
    /// 기본 구현을 제공하는 리듀서를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let store = Store(
    ///     initialState: SettingsReducer.State(nickname: "김민정"),
    ///     reducer: { SettingsReducer() }
    /// )
    /// ```
    // swiftlint:disable function_body_length
    public init() {
        let reducer = Reduce<SettingsReducer.State, SettingsReducer.Action> { state, action in
            reduceCore(state: &state, action: action)
        }
        self.init(reducer: reducer)
    }
    // swiftlint:enable function_body_length
}

// MARK: - Core Reduce Logic

// swiftlint:disable function_body_length
private func reduceCore(
    state: inout SettingsReducer.State,
    action: SettingsReducer.Action
) -> Effect<SettingsReducer.Action> {
    switch action {
    case .binding(\.nickname):
        if state.nickname.count > SettingsReducer.State.maxLength {
            state.nickname = String(state.nickname.prefix(SettingsReducer.State.maxLength))
        }
        return .none

    case .binding:
        return .none

    case .view(.onAppear):
        @Dependency(\.authClient) var authClient
        @Dependency(\.onboardingClient) var onboardingClient

        state.appVersion = AppVersionProvider.currentVersion
        return .merge(
            .run { send in
                let storeVersion = await AppVersionProvider.fetchStoreVersion()
                await send(.response(.storeVersionResponse(storeVersion)))
            },
            .run { send in
                do {
                    let profile = try await authClient.fetchMyProfile()
                    await send(.response(.fetchMyProfileResponse(.success(profile.name))))
                } catch {
                    await send(.response(.fetchMyProfileResponse(.failure(error))))
                }
            },
            .run { send in
                do {
                    let coupleCode = try await onboardingClient.fetchInviteCode()
                    await send(.response(.fetchCoupleCodeResponse(.success(coupleCode))))
                } catch {
                    await send(.response(.fetchCoupleCodeResponse(.failure(error))))
                }
            }
        )

    case .response(.storeVersionResponse(let version)):
        state.storeVersion = version ?? "-"
        return .none

    case .view(.backButtonTapped):
        return .send(.delegate(.navigateBack))

    case .view(.subViewBackButtonTapped):
        return .send(.delegate(.navigateBackFromSubView))

    case .view(.editButtonTapped):
        state.isEditing = true
        return .none

    case .view(.clearButtonTapped):
        state.nickname = ""
        return .none

    case .view(.nicknameEditingEnded):
        return .send(.internal(.nicknameEditingEnded))

    case .internal(.nicknameEditingEnded):
        return handleNicknameEditingEnded(state: &state)

    case .response(.updateNicknameResponse(.success)):
        state.isLoading = false
        state.originalNickname = state.nickname
        state.isEditing = false
        return .none

    case .response(.updateNicknameResponse(.failure(let error))):
        state.isLoading = false
        state.nickname = state.originalNickname
        state.isEditing = false
        if let networkError = error as? NetworkError,
           networkError == .authorizationError {
            return .send(.delegate(.sessionExpired))
        }
        return .none

    case .view(.languageSettingTapped):
        state.modal = .selectList(
            title: "언어 설정",
            subtitle: "이미 앱 내에 저장된 언어는 변경되지 않아요",
            options: SettingsReducer.State.languageOptions.map { $0.title },
            selectedIndex: SettingsReducer.State.languageOptions.firstIndex(of: state.selectedLanguage) ?? 0,
            leftButtonText: "취소",
            rightButtonText: "완료"
        )
        return .none

    case let .view(.languageConfirmed(index)):
        return .send(.internal(.languageConfirmed(index)))

    case let .internal(.languageConfirmed(index)):
        guard SettingsReducer.State.languageOptions.indices.contains(index) else {
            return .none
        }
        state.selectedLanguage = SettingsReducer.State.languageOptions[index]
        // TODO: 언어 설정 저장 로직 구현
        return .none

    case .view(.accountTapped):
        return .send(.delegate(.navigateToAccount))

    case .view(.infoTapped):
        return .send(.delegate(.navigateToInfo))

    case .view(.logoutTapped):
        guard !state.isLoading else { return .none }
        @Dependency(\.authClient) var authClient
        @Dependency(\.pushClient) var pushClient
        @Dependency(\.notificationClient) var notificationClient

        state.isLoading = true
        return .run { send in
            // FCM 토큰 삭제 (실패해도 로그아웃 진행)
            if let token = try? await pushClient.getFCMToken() {
                try? await notificationClient.deleteFCMToken(token)
            }

            do {
                try await authClient.signOut()
                await send(.response(.logoutResponse(.success(()))))
            } catch {
                await send(.response(.logoutResponse(.failure(error))))
            }
        }

    case .view(.disconnectCoupleTapped):
        state.modalPurpose = .disconnectCouple
        state.modal = .info(
            image: .Icon.Illustration.modalWarning,
            title: "정말 커플을 끊으시겠어요?",
            subtitle: """
            오늘부로 30일 후, 모든 데이터가 삭제됩니다.
            복구 가능 기간은 30일 이내입니다.
            복구 희망시 ttwixteamm@gmail.com로
            문의해 주시기 바랍니다.
            """,
            leftButtonText: "취소",
            rightButtonText: "해제"
        )
        return .none

    case .view(.withdrawTapped):
        state.modalPurpose = .withdraw
        state.modal = .info(
            image: .Icon.Illustration.modalWarning,
            title: "정말 탈퇴하시겠어요?",
            subtitle: """
            커플 연결이 끊어집니다.
            데이터는 전부 삭제되며 복구가 불가능합니다.
            """,
            leftButtonText: "취소",
            rightButtonText: "탈퇴"
        )
        return .none

    case .view(.modalConfirmTapped):
        guard !state.isLoading else { return .none }
        @Dependency(\.authClient) var authClient

        switch state.modalPurpose {
        case .disconnectCouple:
            state.isLoading = true
            return .run { send in
                do {
                    try await authClient.withdraw()
                    await send(.response(.withdrawResponse(.success(()))))
                } catch {
                    await send(.response(.withdrawResponse(.failure(error))))
                }
            }
        case .withdraw:
            state.isLoading = true
            return .run { send in
                do {
                    try await authClient.withdraw()
                    await send(.response(.withdrawResponse(.success(()))))
                } catch {
                    await send(.response(.withdrawResponse(.failure(error))))
                }
            }
        default:
            break
        }
        return .none

    case .view(.privacyPolicyTapped):
        if let url = URL(string: "https://incongruous-sweatshirt-b32.notion.site/Keepliuv-3024eb2e10638051824ef9ac7f9a522f") {
            return .send(.delegate(.navigateToWebView(url: url, title: "개인정보 처리방침")))
        }
        return .none

    case .view(.notificationSettingTapped):
        return .send(.delegate(.navigateToNotificationSettings))

    case .response(.fetchMyProfileResponse(.success(let name))):
        state.nickname = name
        state.originalNickname = name
        return .none

    case .response(.fetchMyProfileResponse(.failure(let error))):
        if let networkError = error as? NetworkError,
           networkError == .authorizationError {
            return .send(.delegate(.sessionExpired))
        }
        return .none

    case .response(.fetchCoupleCodeResponse(.success(let coupleCode))):
        state.coupleCode = coupleCode
        return .none

    case .response(.fetchCoupleCodeResponse(.failure(let error))):
        if let networkError = error as? NetworkError,
           networkError == .authorizationError {
            return .send(.delegate(.sessionExpired))
        }
        return .none

    case .response(.logoutResponse(.success)):
        state.isLoading = false
        return .send(.delegate(.logoutCompleted))

    case .response(.logoutResponse(.failure(let error))):
        state.isLoading = false
        if let networkError = error as? NetworkError,
           networkError == .authorizationError {
            return .send(.delegate(.sessionExpired))
        }
        return .send(.presentation(.showToast(.warning(message: "로그아웃에 실패했어요"))))

    case .response(.withdrawResponse(.success)):
        state.isLoading = false
        return .send(.delegate(.withdrawCompleted))

    case .response(.withdrawResponse(.failure(let error))):
        state.isLoading = false
        if let networkError = error as? NetworkError,
           networkError == .authorizationError {
            return .send(.delegate(.sessionExpired))
        }
        return .send(.presentation(.showToast(.warning(message: "회원 탈퇴에 실패했어요"))))

    case let .presentation(.showToast(toast)):
        state.toast = toast
        return .none

    case .view(.inquiryTapped):
        @Dependency(\.openURL) var openURL
        guard let url = URL(string: "http://pf.kakao.com/_znAzX/chat") else {
            return .none
        }
        return .run { _ in
            await openURL(url)
        }

    case .delegate:
        return .none

    // MARK: - Notification Settings

    case .view(.notificationSettingsOnAppear):
        @Dependency(\.notificationClient) var notificationClient

        let checkPermissionEffect: Effect<SettingsReducer.Action> = .run { send in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let isEnabled = settings.authorizationStatus == .authorized
            await send(.response(.checkSystemNotificationResponse(isEnabled)))
        }

        guard !state.isNotificationSettingsLoading else {
            return checkPermissionEffect
        }

        state.isNotificationSettingsLoading = true
        return .merge(
            checkPermissionEffect,
            .run { send in
                do {
                    let notificationSettings = try await notificationClient.fetchSettings()
                    await send(.response(.fetchNotificationSettingsResponse(.success(notificationSettings))))
                } catch {
                    await send(.response(.fetchNotificationSettingsResponse(.failure(error))))
                }
            }
        )

    case .response(.fetchNotificationSettingsResponse(.success(let settings))):
        state.isNotificationSettingsLoading = false
        state.isPokePushEnabled = settings.isPushEnabled
        state.isMarketingPushEnabled = settings.isMarketingEnabled
        state.isNightMarketingPushEnabled = settings.isNightEnabled
        return .none

    case .response(.fetchNotificationSettingsResponse(.failure(let error))):
        state.isNotificationSettingsLoading = false
        if let networkError = error as? NetworkError,
           networkError == .authorizationError {
            return .send(.delegate(.sessionExpired))
        }
        return .none

    case .view(.pokePushToggled(let enabled)):
        @Dependency(\.notificationClient) var notificationClient
        // 낙관적 업데이트
        state.isPokePushEnabled = enabled
        return .run { send in
            do {
                let settings = try await notificationClient.updatePokeSetting(enabled)
                await send(.response(.updateNotificationSettingResponse(.success(settings))))
            } catch {
                await send(.response(.updateNotificationSettingResponse(.failure(error))))
            }
        }.cancellable(id: "pokePushToggle", cancelInFlight: true)

    case .view(.marketingPushToggled(let enabled)):
        @Dependency(\.notificationClient) var notificationClient
        // 낙관적 업데이트
        state.isMarketingPushEnabled = enabled
        return .run { send in
            do {
                let settings = try await notificationClient.updateMarketingSetting(enabled)
                await send(.response(.updateNotificationSettingResponse(.success(settings))))
            } catch {
                await send(.response(.updateNotificationSettingResponse(.failure(error))))
            }
        }.cancellable(id: "marketingPushToggle", cancelInFlight: true)

    case .view(.nightPushToggled(let enabled)):
        @Dependency(\.notificationClient) var notificationClient
        // 낙관적 업데이트
        state.isNightMarketingPushEnabled = enabled
        return .run { send in
            do {
                let settings = try await notificationClient.updateNightSetting(enabled)
                await send(.response(.updateNotificationSettingResponse(.success(settings))))
            } catch {
                await send(.response(.updateNotificationSettingResponse(.failure(error))))
            }
        }.cancellable(id: "nightPushToggle", cancelInFlight: true)

    case .response(.updateNotificationSettingResponse(.success(let settings))):
        // 서버 응답으로 상태 동기화
        state.isPokePushEnabled = settings.isPushEnabled
        state.isMarketingPushEnabled = settings.isMarketingEnabled
        state.isNightMarketingPushEnabled = settings.isNightEnabled
        return .none

    case .response(.updateNotificationSettingResponse(.failure(let error))):
        // 실패 시 서버에서 다시 가져오기
        if let networkError = error as? NetworkError,
           networkError == .authorizationError {
            return .send(.delegate(.sessionExpired))
        }
        return .send(.view(.notificationSettingsOnAppear))

    case let .response(.checkSystemNotificationResponse(isEnabled)):
        state.isSystemNotificationEnabled = isEnabled
        return .none

    case .view(.enableNotificationBannerTapped):
        return .run { _ in
            await MainActor.run {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
// swiftlint:enable function_body_length

private func handleNicknameEditingEnded(
    state: inout SettingsReducer.State
) -> Effect<SettingsReducer.Action> {
    guard state.isEditing else { return .none }

    if ProfanityFilter.containsProfanity(state.nickname) {
        state.nickname = state.originalNickname
        state.isEditing = false
        return .none
    }

    guard state.isNicknameLengthValid else {
        state.nickname = state.originalNickname
        state.isEditing = false
        return .none
    }

    guard state.isNicknameChanged else {
        state.isEditing = false
        return .none
    }

    let nickname = state.nickname
    state.isLoading = true
    return .run { send in
        @Dependency(\.onboardingClient) var onboardingClient

        do {
            try await onboardingClient.updateProfile(nickname)
            await send(.response(.updateNicknameResponse(.success(()))))
        } catch {
            await send(.response(.updateNicknameResponse(.failure(error))))
        }
    }
}
