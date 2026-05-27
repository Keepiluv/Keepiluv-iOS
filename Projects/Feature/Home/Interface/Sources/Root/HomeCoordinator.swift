//
//  HomeCoordinatorReducer.swift
//  FeatureHomeInterface
//
//  Created by 정지훈 on 1/27/26.
//

import ComposableArchitecture
import DomainGoalInterface
import FeatureGoalDetailInterface
import FeatureNotificationInterface
import FeatureMakeGoalInterface
import FeatureProofPhotoInterface
import FeatureSettingsInterface
import FeatureStatsInterface

/// Home Feature의 NavigationStack을 관리하는 Root Reducer입니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: HomeCoordinatorReducer.State()
/// ) {
///     HomeCoordinatorReducer()
/// }
/// ```
@Reducer
public struct HomeCoordinator {
    private let reducer: Reduce<State, Action>
    private let homeReducer: HomeReducer
    private let goalDetailReducer: GoalDetailReducer
    private let statsDetailReducer: StatsDetailReducer
    private let makeGoalReducer: MakeGoalReducer
    private let editGoalListReducer: EditGoalListReducer
    private let settingsReducer: SettingsReducer
    private let notificationReducer: NotificationReducer
    
    /// HomeCoordinator 화면에서 사용하는 상태입니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let state = HomeCoordinatorReducer.State()
    /// ```
    @ObservableState
    public struct State: Equatable {
        public var routes: [HomeRoute] = []

        public var home = HomeReducer.State()
        public var goalDetail: GoalDetailReducer.State?
        public var statsDetail: StatsDetailReducer.State?
        public var makeGoal: MakeGoalReducer.State?
        public var editGoalList: EditGoalListReducer.State?
        public var settings: SettingsReducer.State?
        public var notification: NotificationReducer.State?

        /// 기본 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = HomeCoordinatorReducer.State()
        /// ```
        public init() { }
    }
    
    /// HomeCoordinator 화면에서 발생 가능한 액션입니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// store.send(.home(.view(.onAppear)))
    /// ```
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - Child Action
        case home(HomeReducer.Action)
        case goalDetail(GoalDetailReducer.Action)
        case statsDetail(StatsDetailReducer.Action)
        case makeGoal(MakeGoalReducer.Action)
        case editGoalList(EditGoalListReducer.Action)
        case settings(SettingsReducer.Action)
        case notification(NotificationReducer.Action)


        // MARK: - Navigation
        case navigateToGoalDetail(id: Int64, owner: GoalDetail.Owner, date: String)

        // MARK: - Delegate
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case logoutCompleted
            case withdrawCompleted
            case sessionExpired
            case notificationItemTapped(NotificationItem)
            case goToCompletedStats
        }
    }

    /// 외부에서 주입된 Reduce로 HomeCoordinatorReducer를 구성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = HomeCoordinatorReducer(
    ///     reducer: Reduce { _, _ in .none },
    ///     homeReducer: HomeReducer(reducer: Reduce { _, _ in .none })
    /// )
    /// ```
    public init(
        reducer: Reduce<State, Action>,
        homeReducer: HomeReducer,
        goalDetailReducer: GoalDetailReducer,
        statsDetailReducer: StatsDetailReducer,
        makeGoalReducer: MakeGoalReducer,
        editGoalListReducer: EditGoalListReducer,
        settingsReducer: SettingsReducer,
        notificationReducer: NotificationReducer
    ) {
        self.reducer = reducer
        self.homeReducer = homeReducer
        self.goalDetailReducer = goalDetailReducer
        self.statsDetailReducer = statsDetailReducer
        self.makeGoalReducer = makeGoalReducer
        self.editGoalListReducer = editGoalListReducer
        self.settingsReducer = settingsReducer
        self.notificationReducer = notificationReducer
    }
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.home, action: \.home) {
            homeReducer
        }
        
        reducer
            .ifLet(\.goalDetail, action: \.goalDetail) {
                goalDetailReducer
            }
            .ifLet(\.statsDetail, action: \.statsDetail) {
                statsDetailReducer
            }
            .ifLet(\.makeGoal, action: \.makeGoal) {
                makeGoalReducer
            }
            .ifLet(\.editGoalList, action: \.editGoalList) {
                editGoalListReducer
            }
            .ifLet(\.settings, action: \.settings) {
                settingsReducer
            }
            .ifLet(\.notification, action: \.notification) {
                notificationReducer
            }
    }
}
