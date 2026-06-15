//
//  SettingsReducer.swift
//  FeatureSettingsInterface
//
//  Created by Jiyong on 02/05/26.
//

import ComposableArchitecture
import DomainNotificationInterface
import Foundation
import SharedDesignSystem
import SharedUtil

/// 설정 화면의 상태와 액션을 정의하는 리듀서입니다.
///
/// ## 사용 예시
/// ```swift
/// let reducer = SettingsReducer(
///     reducer: Reduce { state, action in
///         // 실제 로직
///         return .none
///     }
/// )
/// ```
@Reducer
public struct SettingsReducer {
    private let reducer: Reduce<State, Action>

    /// 설정 화면의 상태입니다.
    @ObservableState
    public struct State: Equatable {
        // Profile
        public var nickname: String
        public var originalNickname: String
        public var isEditing: Bool
        public var isLoading: Bool
        public var isProfileFetchFailed: Bool

        // Language
        public var selectedLanguage: TXLanguage

        // Account
        public var coupleCode: String
        public var isCoupleCodeFetchFailed: Bool
        public var modal: TXModalStyle?
        public var modalPurpose: ModalPurpose?

        // Info
        public var appVersion: String
        public var storeVersion: String

        // Toast
        public var toast: TXToastType?

        // Notification Settings
        public var isPokePushEnabled: Bool
        public var isMarketingPushEnabled: Bool
        public var isNightMarketingPushEnabled: Bool
        public var isNotificationSettingsLoading: Bool
        public var isNotificationSettingsFetchFailed: Bool
        public var isSystemNotificationEnabled: Bool

        public static let minLength = 2
        public static let maxLength = 8
        // 로컬라이징 지원 이후 활성화 예정
        public static let languageOptions = TXLanguage.allCases
        // 로컬라이징 지원 이후 English, 日本語 추가 예정
        
        public enum ModalPurpose: Equatable {
            case disconnectCouple
            case withdraw
        }
        
        // TODO: - 임시 임치
        public enum TXLanguage: Equatable, CaseIterable {
            case korean
            
            public var title: String {
                switch self {
                case .korean: "한국어"
                }
            }
        }

        /// 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = SettingsReducer.State(nickname: "김민정", coupleCode: "JF2342S")
        /// ```
        public init(
            nickname: String = "",
            isEditing: Bool = false,
            selectedLanguage: TXLanguage = .korean,
            coupleCode: String = "",
            appVersion: String = "",
            storeVersion: String = "",
            isPokePushEnabled: Bool = true,
            isMarketingPushEnabled: Bool = false,
            isNightMarketingPushEnabled: Bool = false
        ) {
            self.nickname = nickname
            self.originalNickname = nickname
            self.isEditing = isEditing
            self.isLoading = false
            self.isProfileFetchFailed = false
            self.selectedLanguage = selectedLanguage
            self.coupleCode = coupleCode
            self.isCoupleCodeFetchFailed = false
            self.modalPurpose = nil
            self.appVersion = appVersion
            self.storeVersion = storeVersion
            self.isPokePushEnabled = isPokePushEnabled
            self.isMarketingPushEnabled = isMarketingPushEnabled
            self.isNightMarketingPushEnabled = isNightMarketingPushEnabled
            self.isNotificationSettingsLoading = false
            self.isNotificationSettingsFetchFailed = false
            self.isSystemNotificationEnabled = true
        }
    }

    /// 설정 화면에서 발생하는 액션입니다.
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case backButtonTapped
            case subViewBackButtonTapped
            case editButtonTapped
            case clearButtonTapped
            case nicknameEditingEnded
            case languageSettingTapped
            case languageConfirmed(Int)
            case accountTapped
            case infoTapped
            case inquiryTapped
            case notificationSettingTapped
            case privacyPolicyTapped
            case logoutTapped
            case disconnectCoupleTapped
            case withdrawTapped
            case modalConfirmTapped
            case notificationSettingsOnAppear
            case settingsDataRetryTapped
            case notificationSettingsDataRetryTapped
            case pokePushToggled(Bool)
            case marketingPushToggled(Bool)
            case nightPushToggled(Bool)
            case enableNotificationBannerTapped
        }

        // MARK: - Internal
        public enum Internal: Equatable {
            case nicknameEditingEnded
            case languageConfirmed(Int)
        }

        // MARK: - Response
        public enum Response {
            case storeVersionResponse(String?)
            case updateNicknameResponse(Result<Void, Error>)
            case fetchMyProfileResponse(Result<String, Error>)
            case fetchCoupleCodeResponse(Result<String, Error>)
            case logoutResponse(Result<Void, Error>)
            case withdrawResponse(Result<Void, Error>)
            case fetchNotificationSettingsResponse(Result<NotificationSettings, Error>)
            case updateNotificationSettingResponse(Result<NotificationSettings, Error>)
            case checkSystemNotificationResponse(Bool)
        }

        // MARK: - Presentation
        public enum Presentation: Equatable {
            case showToast(TXToastType)
        }

        // MARK: - Delegate
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case navigateBack
            case navigateBackFromSubView
            case navigateToAccount
            case navigateToInfo
            case navigateToNotificationSettings
            case navigateToWebView(url: URL, title: String)
            case logoutCompleted
            case withdrawCompleted
            case sessionExpired
        }

        case view(View)
        case `internal`(Internal)
        case response(Response)
        case presentation(Presentation)
    }

    /// 외부에서 주입된 Reduce로 리듀서를 구성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = SettingsReducer(
    ///     reducer: Reduce { state, action in
    ///         // 실제 로직
    ///         return .none
    ///     }
    /// )
    /// ```
    public init(reducer: Reduce<State, Action>) {
        self.reducer = reducer
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        reducer
    }
}

// MARK: - Computed Properties

extension SettingsReducer.State {
    public var isNicknameLengthValid: Bool {
        nickname.count >= Self.minLength && nickname.count <= Self.maxLength
    }

    public var isNicknameChanged: Bool {
        nickname != originalNickname
    }

    public var containsProfanity: Bool {
        ProfanityFilter.containsProfanity(nickname)
    }

    public var isNicknameValid: Bool {
        isNicknameLengthValid && !containsProfanity
    }

    public var isSettingsFetchFailed: Bool {
        isProfileFetchFailed || isCoupleCodeFetchFailed
    }
}
