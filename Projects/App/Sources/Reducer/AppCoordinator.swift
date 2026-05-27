//
//  AppCoordinator.swift
//  Twix
//
//  Created by 정지훈 on 1/4/26.
//

import ComposableArchitecture
import CoreAnalytics
import CoreAnalyticsInterface
import CoreCrashlyticsInterface
import CoreLogging
import CoreNetworkInterface
import CorePushInterface
import DomainAuthInterface
import DomainNotificationInterface
import DomainOnboardingInterface
import Feature
import Foundation
import UIKit

@Reducer
struct AppCoordinator {
    @Dependency(\.tokenManager)
    var tokenManager

    @Dependency(\.onboardingClient)
    var onboardingClient

    @Dependency(\.authClient)
    var authClient

    @Dependency(\.pushClient)
    var pushClient

    @Dependency(\.notificationClient)
    var notificationClient

    @Dependency(\.analyticsClient)
    var analyticsClient

    @Dependency(\.crashlyticsClient)
    var crashlytics

    private let authReducer: AuthReducer
    private let onboardingCoordinator: OnboardingCoordinator
    private let mainTabReducer: MainTabReducer

    @ObservableState
    struct State: Equatable {
        var route: Route = .auth(AuthReducer.State())
        var isCheckingAuth: Bool = true
        var pendingInviteCode: String?
        var pendingNotificationDeepLink: NotificationDeepLink?
        var userProfile: UserProfile?

        public init() { }
    }

    @ObservableState
    @CasePathable
    enum Route: Equatable {
        case auth(AuthReducer.State)
        case onboarding(OnboardingCoordinator.State)
        case mainTab(MainTabReducer.State)

        var auth: AuthReducer.State? {
            get {
                if case .auth(let state) = self { return state }
                return nil
            }
            set {
                if let newValue { self = .auth(newValue) }
            }
        }

        var onboarding: OnboardingCoordinator.State? {
            get {
                if case .onboarding(let state) = self { return state }
                return nil
            }
            set {
                if let newValue { self = .onboarding(newValue) }
            }
        }

        var mainTab: MainTabReducer.State? {
            get {
                if case .mainTab(let state) = self { return state }
                return nil
            }
            set {
                if let newValue { self = .mainTab(newValue) }
            }
        }
    }

    enum Action {
        case onAppear
        case checkAuthResult(Result<Token?, Error>)
        case checkOnboardingStatusResult(Result<OnboardingStatus, Error>)
        case deepLinkReceived(code: String)
        case notificationDeepLinkReceived(NotificationDeepLink)
        case route(RouteAction)

        // MARK: - FCM Token
        case registerFCMTokenCompleted
        case fcmTokenRefreshed(String)

        // MARK: - User Profile
        case fetchMyProfileCompleted(UserProfile)
    }

    @CasePathable
    enum RouteAction {
        case auth(AuthReducer.Action)
        case onboarding(OnboardingCoordinator.Action)
        case mainTab(MainTabReducer.Action)
    }

    init() {
        self.authReducer = AuthReducer()
        self.onboardingCoordinator = OnboardingCoordinator()
        self.mainTabReducer = MainTabReducer()
    }

    var body: some ReducerOf<Self> {
        // swiftlint:disable:next closure_body_length
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    do {
                        let token = try await tokenManager.loadTokenFromStorage()
                        await send(.checkAuthResult(.success(token)))
                    } catch {
                        await send(.checkAuthResult(.failure(error)))
                    }
                }

            case .checkAuthResult(.success(let token)):
                if token != nil {
                    return .run { send in
                        do {
                            let status = try await onboardingClient.fetchStatus()
                            await send(.checkOnboardingStatusResult(.success(status)))
                        } catch {
                            await send(.checkOnboardingStatusResult(.failure(error)))
                        }
                    }
                } else {
                    state.isCheckingAuth = false
                    state.route = .auth(AuthReducer.State())
                }
                return .none

            case .checkAuthResult(.failure(let error)):
                state.isCheckingAuth = false
                state.route = .auth(AuthReducer.State())
                crashlytics.record(error, AppCrashlyticsRecordEvent.appStartupFailed)
                return .none
                
            case let .checkOnboardingStatusResult(.success(status)):
                state.isCheckingAuth = false
                switch status {
                case .completed:
                    state.route = .mainTab(MainTabReducer.State())
                    // FCM 토큰 등록 및 tokenRefreshStream 구독 (기존 유저 로그인)
                    var effects: [Effect<Action>] = [
                        registerFCMTokenEffect(
                            pushClient: pushClient,
                            notificationClient: notificationClient
                        ),
                        subscribeTokenRefreshEffect(
                            pushClient: pushClient,
                            notificationClient: notificationClient
                        )
                    ]
                    
                    if state.userProfile == nil {
                        effects.append(fetchUserProfile(client: authClient))
                    }
                    
                    // pending 딥링크가 있으면 처리
                    if let pendingDeepLink = state.pendingNotificationDeepLink {
                        state.pendingNotificationDeepLink = nil
                        effects.append(.send(.route(.mainTab(.view(.notificationDeepLinkReceived(pendingDeepLink))))))
                    }
                    
                    return .merge(effects)
                    
                case .coupleConnection,
                        .profileSetup,
                        .anniversarySetup:
                    state.route = .onboarding(OnboardingCoordinator.State(
                        initialStatus: status,
                        pendingReceivedCode: state.pendingInviteCode
                    ))
                    state.pendingInviteCode = nil
                }
                return .none
                
            case let .checkOnboardingStatusResult(.failure(error)):
                state.isCheckingAuth = false
                if let networkError = error as? NetworkError,
                   case .authorizationError = networkError {
                    crashlytics.log(AppCrashlyticsLogEvent.sessionExpiredAtOnboardingStatusCheck)
                    state.route = .auth(AuthReducer.State())
                    return .none
                }
                crashlytics.record(error, AppCrashlyticsRecordEvent.onboardingStatusCheckFailed)
                state.route = .onboarding(OnboardingCoordinator.State(
                    pendingReceivedCode: state.pendingInviteCode
                ))
                state.pendingInviteCode = nil
                return .none
                
            case let .deepLinkReceived(code):
                state.pendingInviteCode = code
                
                if case .onboarding = state.route {
                    return .send(.route(.onboarding(.deepLinkReceived(code: code))))
                }
                return .none
                
            case let .notificationDeepLinkReceived(deepLink):
                // 메인탭 상태가 아니면 pending으로 저장
                guard case .mainTab = state.route else {
                    state.pendingNotificationDeepLink = deepLink
                    return .none
                }
                
                state.pendingNotificationDeepLink = nil
                return .send(.route(.mainTab(.view(.notificationDeepLinkReceived(deepLink)))))

            case let .route(.auth(.delegate(.loginSucceeded(authResult)))):
                crashlytics.setUserIdentifier("\(authResult.userId)")
                return .merge(
                    // 1. 온보딩 상태 체크
                    .run { [onboardingClient] send in
                        do {
                            let status = try await onboardingClient.fetchStatus()
                            await send(.checkOnboardingStatusResult(.success(status)))
                        } catch {
                            await send(.checkOnboardingStatusResult(.failure(error)))
                        }
                    },
                    // 2. FCM 토큰 조기 등록 (온보딩 중 푸시 수신을 위해)
                    registerFCMTokenEffect(
                        pushClient: pushClient,
                        notificationClient: notificationClient
                    )
                )
                
            case let .route(.onboarding(.delegate(.onboardingCompleted(isPushEnabled, isMarketingEnabled, isNightEnabled)))):
                state.route = .mainTab(MainTabReducer.State())
                // 온보딩 완료 시: initSettings + FCM 토큰 등록
                // (시스템 권한 요청은 OnboardingCoordinator에서 이미 완료됨)
                var effects: [Effect<Action>] = [
                    .run { [pushClient, notificationClient] _ in
                        // 1. 권한 결과 + 사용자 선택값으로 initSettings 호출
                        _ = try? await notificationClient.initSettings(isPushEnabled, isMarketingEnabled, isNightEnabled)
                        
                        // 2. 권한 허용 시 FCM 토큰 등록
                        if isPushEnabled {
                            await pushClient.registerForRemoteNotifications()
                            guard let token = try? await pushClient.getFCMToken(),
                                  let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
                                return
                            }
                            try? await notificationClient.registerFCMToken(token, deviceId)
                        }
                    },
                    subscribeTokenRefreshEffect(
                        pushClient: pushClient,
                        notificationClient: notificationClient
                    ),
                    fetchUserProfile(client: authClient)
                ]
                
                if let pendingDeepLink = state.pendingNotificationDeepLink {
                    state.pendingNotificationDeepLink = nil
                    effects.append(.send(.route(.mainTab(.view(.notificationDeepLinkReceived(pendingDeepLink))))))
                }
                
                return .merge(effects)
                
            case .route(.onboarding(.delegate(.logoutRequested))):
                return .run { [authClient] send in
                    try? await authClient.signOut()
                    await send(.checkAuthResult(.failure(NSError(domain: "Logout", code: 0))))
                }
                
            case .route(.mainTab(.delegate(.logoutCompleted))),
                    .route(.mainTab(.delegate(.withdrawCompleted))),
                    .route(.mainTab(.delegate(.sessionExpired))):
                state.route = .auth(AuthReducer.State())
                state.userProfile = nil
                analyticsClient.setUserProfile(nil)
                return .none

            case .route:
                return .none

            case .registerFCMTokenCompleted:
                return .none

            case .fcmTokenRefreshed(let token):
                // 토큰 갱신 시 서버에 재등록
                return .run { [notificationClient] _ in
                    guard let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
                        return
                    }
                    try? await notificationClient.registerFCMToken(token, deviceId)
                }

            case let .fetchMyProfileCompleted(profile):
                state.userProfile = profile
                analyticsClient.setUserProfile(
                    AnalyticsUserProfile(
                        id: Int64(profile.id),
                        name: profile.name
                    )
                )

                return .none
            }
        }
        .ifLet(\.route.auth, action: \.route.auth) {
            authReducer
        }
        .ifLet(\.route.onboarding, action: \.route.onboarding) {
            onboardingCoordinator
        }
        .ifLet(\.route.mainTab, action: \.route.mainTab) {
            mainTabReducer
        }
    }
}

// MARK: - FCM Token Effects

private func registerFCMTokenEffect(
    pushClient: PushClient,
    notificationClient: NotificationClient
) -> Effect<AppCoordinator.Action> {
    .run { send in
        // 1. 현재 권한 상태 확인
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        // 이미 권한이 허용된 경우에만 등록 (notDetermined/denied는 온보딩 완료 시점에서 처리)
        guard settings.authorizationStatus == .authorized else { return }

        // 3. APNS 등록 및 FCM 토큰 획득
        await pushClient.registerForRemoteNotifications()

        guard let token = try? await pushClient.getFCMToken(),
              let deviceId = await UIDevice.current.identifierForVendor?.uuidString else {
            return
        }

        try? await notificationClient.registerFCMToken(token, deviceId)
        await send(.registerFCMTokenCompleted)
    }
}

private func subscribeTokenRefreshEffect(
    pushClient: PushClient,
    notificationClient: NotificationClient
) -> Effect<AppCoordinator.Action> {
    .run { send in
        for await token in pushClient.tokenRefreshStream() {
            await send(.fcmTokenRefreshed(token))
        }
    }
}

private func fetchUserProfile(client: AuthClient) -> Effect<AppCoordinator.Action> {
    .run { send in
        do {
            let profile = try await client.fetchMyProfile()
            await send(.fetchMyProfileCompleted(profile))
        } catch {
            TXLogger(label: "Analytics").error("Failed to fetch user profile for analytics: \(error)")
        }
    }
}
