//
//  MainTabStore.swift
//  Feature
//
//  Created by 정지훈 on 1/4/26.
//

import Foundation

import ComposableArchitecture
import CoreAnalyticsInterface
import CoreLogging
import CorePushInterface
import DomainNotificationInterface
import FeatureGoalDetail
import FeatureGoalDetailInterface
import FeatureHome
import FeatureHomeInterface
import FeatureNotification
import FeatureNotificationInterface
import FeatureMakeGoal
import FeatureMakeGoalInterface
import FeatureProofPhoto
import FeatureProofPhotoInterface
import FeatureSettings
import FeatureSettingsInterface
import FeatureStats
import FeatureStatsInterface
import SharedDesignSystem

/// 앱의 메인 탭 화면을 관리하는 Reducer입니다.
///
/// 홈, 통계, 커플, 마이페이지 탭으로 구성된 메인 화면의 상태와 액션을 처리합니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: MainTabReducer.State(),
///     reducer: { MainTabReducer() }
/// )
/// ```
@Reducer
public struct MainTabReducer {
    
    @ObservableState
    /// 메인 탭의 화면 상태를 정의합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let state = MainTabReducer.State()
    /// ```
    public struct State: Equatable {
        public var home: HomeCoordinator.State = .init()
        public var stats: StatsCoordinator.State = .init()
        public var selectedTab: TXTabItem = .home
        public var isTabBarHidden: Bool = false
        public var shouldShowHomeFloatingButton: Bool {
            selectedTab == .home && !isTabBarHidden
        }

        /// 기본 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = MainTabReducer.State()
        /// ```
        public init() { }
    }

    /// 메인 탭에서 발생 가능한 액션을 정의합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// store.send(.view(.selectedTabChanged(.home)))
    /// ```
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case selectedTabChanged(TXTabItem)
            case notificationDeepLinkReceived(NotificationDeepLink)
        }

        // MARK: - Delegate
        public enum Delegate: Equatable {
            case logoutCompleted
            case withdrawCompleted
            case sessionExpired
        }

        // MARK: - Child Action
        case home(HomeCoordinator.Action)
        case stats(StatsCoordinator.Action)

        case view(View)
        case delegate(Delegate)
    }

    /// 기본 구성의 MainTabReducer를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = MainTabReducer()
    /// ```
    public init() { }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.analyticsClient) var analyticsClient

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.home, action: \.home) {
            let proofPhotoReducer = ProofPhotoReducer()
            HomeCoordinator(
                goalDetailReducer: GoalDetailReducer(proofPhotoReducer: proofPhotoReducer),
                statsDetailReducer: StatsDetailReducer(),
                proofPhotoReducer: proofPhotoReducer,
                makeGoalReducer: MakeGoalReducer(),
                editGoalListReducer: EditGoalListReducer(),
                settingsReducer: SettingsReducer(),
                notificationReducer: NotificationReducer()
            )
        }
        
        Scope(state: \.stats, action: \.stats) {
            StatsCoordinator(
                statsReducer: StatsReducer(),
                statsDetailReducer: StatsDetailReducer(),
                goalDetailReducer: GoalDetailReducer(
                    proofPhotoReducer: ProofPhotoReducer()
                ),
                makeGoalReducer: MakeGoalReducer()
            )
        }

        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return reduceView(state: &state, action: viewAction)

                // MARK: - Child Action (Home)
            case .home(.delegate(.logoutCompleted)):
                return .send(.delegate(.logoutCompleted))

            case .home(.delegate(.withdrawCompleted)):
                return .send(.delegate(.withdrawCompleted))

            case .home(.delegate(.sessionExpired)):
                return .send(.delegate(.sessionExpired))

            case let .home(.delegate(.notificationItemTapped(item))):
                guard let deepLinkString = item.deepLink,
                      let url = URL(string: deepLinkString),
                      let deepLink = NotificationDeepLink.parse(from: url) else {
                    return .none
                }

                switch deepLink {
                case let .poke(_, goalId, date):
                    guard let id = Int64(goalId) else { return .none }
                    return .send(.home(.navigateToGoalDetail(id: id, owner: .mySelf, date: date)))

                case let .goalCompleted(_, goalId, date):
                    guard let id = Int64(goalId) else { return .none }
                    return .send(.home(.navigateToGoalDetail(id: id, owner: .you, date: date)))

                case let .reaction(_, goalId, date):
                    guard let id = Int64(goalId) else { return .none }
                    return .send(.home(.navigateToGoalDetail(id: id, owner: .mySelf, date: date)))

                case .partnerConnected, .dailyGoalAchieved, .marketing:
                    return .none

                case .goalEnded:
                    // TODO: 통계 탭 → 종료된 목표로 이동
                    return .none
                }

            case .home(.delegate(.goToCompletedStats)):
                state.selectedTab = .statistics
                state.stats.stats.ui.isOngoing = false
                state.stats.routes = []
                return .none

            case .home:
                state.isTabBarHidden = !state.home.routes.isEmpty
                return .none

            case .stats:
                state.isTabBarHidden = !state.stats.routes.isEmpty
                return .none

            case .delegate:
                return .none

            case .binding:
                return .none
            }
        }
    }
}

// MARK: - View

private extension MainTabReducer {
    func reduceView(
        state: inout State,
        action: Action.View
    ) -> Effect<Action> {
        switch action {
        case .selectedTabChanged:
            switch state.selectedTab {
            case .home:
                state.isTabBarHidden = !state.home.routes.isEmpty
                    || state.home.home.presentation.isCalendarSheetPresented

            case .statistics, .couple:
                state.isTabBarHidden = false
            }
            return .none

        case let .notificationDeepLinkReceived(deepLink):
            state.selectedTab = .home
            state.home.routes = []
            analyticsClient.logEvent(MainTabAnalyticsEvent.openedByPush(deepLink: deepLink))

            let notificationIdString = deepLink.notificationId
            let markAsReadEffect: Effect<Action> = .run { [notificationClient] _ in
                guard let notificationId = Int64(notificationIdString) else { return }
                try? await notificationClient.markAsRead(notificationId)
            }

            switch deepLink {
            case let .poke(_, goalId, date):
                guard let id = Int64(goalId) else { return markAsReadEffect }
                return .merge(
                    markAsReadEffect,
                    .send(.home(.navigateToGoalDetail(id: id, owner: .mySelf, date: date)))
                )

            case let .goalCompleted(_, goalId, date):
                guard let id = Int64(goalId) else { return markAsReadEffect }
                return .merge(
                    markAsReadEffect,
                    .send(.home(.navigateToGoalDetail(id: id, owner: .you, date: date)))
                )

            case let .reaction(_, goalId, date):
                guard let id = Int64(goalId) else { return markAsReadEffect }
                return .merge(
                    markAsReadEffect,
                    .send(.home(.navigateToGoalDetail(id: id, owner: .mySelf, date: date)))
                )

            case .partnerConnected, .dailyGoalAchieved, .marketing:
                return markAsReadEffect

            case .goalEnded:
                // TODO: 통계 탭 → 종료된 목표로 이동
                return markAsReadEffect
            }
        }
    }
}
