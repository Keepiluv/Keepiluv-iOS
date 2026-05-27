//
//  HomeReducer.swift
//  FeatureHomeInterface
//
//  Created by 정지훈 on 1/26/26.
//

import Foundation

import ComposableArchitecture
import DomainGoalInterface
import FeatureMakeGoalInterface
import FeatureProofPhotoInterface
import SharedDesignSystem
import SharedUtil

/// 홈 화면의 상태와 액션을 관리하는 Reducer입니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: HomeReducer.State()
/// ) {
///     HomeReducer()
/// }
/// ```
@Reducer
public struct HomeReducer {
    let reducer: Reduce<State, Action>
    private let proofPhotoReducer: ProofPhotoReducer
    
    @ObservableState
    /// 홈 화면에서 사용되는 상태 모델입니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let state = HomeReducer.State()
    /// ```
    public struct State: Equatable {
        public struct Data: Equatable {
            public var items: [HomeGoalItem] = []
            public var calendarWeeks: [[TXCalendarDateItem]] = []
            public var calendarDate: TXCalendarDate = .init()
            public var calendarSheetDate: TXCalendarDate = .init()
            public var goalsCache: [String: [HomeGoalItem]] = [:]
            public var pendingDeleteGoalID: Int64?
            public var pendingDeletePhotologID: Int64?
            public var hadFirstGoal: Bool?

            public init() { }
        }

        public struct UIState: Equatable {
            public var isLoading: Bool = true
            public var mainTitle: String = "KEEPILUV"
            public var calendarMonthTitle: String = ""
            public var isRefreshHidden: Bool = true
            public var hasUnreadNotification: Bool = false

            public init() { }
        }

        public struct Presentation: Equatable {
            public var toast: TXToastType?
            public var modal: TXModalStyle?
            public var isCalendarSheetPresented: Bool = false
            public var isProofPhotoPresented: Bool = false
            public var isAddGoalPresented: Bool = false
            public var isCameraPermissionAlertPresented: Bool = false

            public init() { }
        }

        public var data = Data()
        public var ui = UIState()
        public var presentation = Presentation()
        public var proofPhoto: ProofPhotoReducer.State?

        public var items: [HomeGoalItem] {
            get { data.items }
            set { data.items = newValue }
        }
        public var isLoading: Bool {
            get { ui.isLoading }
            set { ui.isLoading = newValue }
        }
        public var mainTitle: String {
            get { ui.mainTitle }
            set { ui.mainTitle = newValue }
        }
        public var calendarMonthTitle: String {
            get { ui.calendarMonthTitle }
            set { ui.calendarMonthTitle = newValue }
        }
        public var calendarWeeks: [[TXCalendarDateItem]] {
            get { data.calendarWeeks }
            set { data.calendarWeeks = newValue }
        }
        public var calendarDate: TXCalendarDate {
            get { data.calendarDate }
            set { data.calendarDate = newValue }
        }
        public var calendarSheetDate: TXCalendarDate {
            get { data.calendarSheetDate }
            set { data.calendarSheetDate = newValue }
        }
        public var goalsCache: [String: [HomeGoalItem]] {
            get { data.goalsCache }
            set { data.goalsCache = newValue }
        }
        public var isRefreshHidden: Bool {
            get { ui.isRefreshHidden }
            set { ui.isRefreshHidden = newValue }
        }
        public var isCalendarSheetPresented: Bool {
            get { presentation.isCalendarSheetPresented }
            set { presentation.isCalendarSheetPresented = newValue }
        }
        public var pendingDeleteGoalID: Int64? {
            get { data.pendingDeleteGoalID }
            set { data.pendingDeleteGoalID = newValue }
        }
        public var pendingDeletePhotologID: Int64? {
            get { data.pendingDeletePhotologID }
            set { data.pendingDeletePhotologID = newValue }
        }
        public var toast: TXToastType? {
            get { presentation.toast }
            set { presentation.toast = newValue }
        }
        public var modal: TXModalStyle? {
            get { presentation.modal }
            set { presentation.modal = newValue }
        }
        public var isProofPhotoPresented: Bool {
            get { presentation.isProofPhotoPresented }
            set { presentation.isProofPhotoPresented = newValue }
        }
        public var isAddGoalPresented: Bool {
            get { presentation.isAddGoalPresented }
            set { presentation.isAddGoalPresented = newValue }
        }
        public var isCameraPermissionAlertPresented: Bool {
            get { presentation.isCameraPermissionAlertPresented }
            set { presentation.isCameraPermissionAlertPresented = newValue }
        }
        public var hasUnreadNotification: Bool {
            get { ui.hasUnreadNotification }
            set { ui.hasUnreadNotification = newValue }
        }
        public var hadFirstGoal: Bool? {
            get { data.hadFirstGoal }
            set { data.hadFirstGoal = newValue }
        }
        public var hasCards: Bool { !items.isEmpty }
        public var isEmptyVisible: Bool { !isLoading && items.isEmpty }
        public var nowDate: CalendarNow { CalendarNow() }
        public var goalSectionTitle: String {
            let now = CalendarNow()
            let today = TXCalendarDate(year: now.year, month: now.month, day: now.day)
            if calendarDate < today {
                return "지난 우리 목표"
            }
            if today < calendarDate {
                return "다음 우리 목표"
            }
            return "오늘 우리 목표"
        }

        /// 기본 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = HomeReducer.State()
        /// ```
        public init() { }
    }
    
    /// 홈 화면에서 발생 가능한 모든 이벤트를 정의합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// store.send(.view(.onAppear))
    /// ```
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - Child Action
        case proofPhoto(ProofPhotoReducer.Action)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case refreshPulled
            case calendarDateSelected(TXCalendarDateItem)
            case weekCalendarSwipe(TXCalendar.SwipeGesture)
            case navigationBarAction(TXNavigationBar.Action)
            case monthCalendarConfirmTapped
            case goalCheckButtonTapped(id: Int64, isChecked: Bool)
            case modalConfirmTapped
            case yourCardTapped(GoalCardItem)
            case myCardTapped(GoalCardItem)
            case headerTapped(GoalCardItem)
            case floatingButtonTapped
            case editButtonTapped
            case proofPhotoDismissed
            case addGoalButtonTapped(GoalCategory)
            case cameraPermissionAlertDismissed
            case perfToastShowTapped
            case perfToastDismissTapped
            case perfCalendarNextTapped
            case perfCalendarPreviousTapped
        }

        // MARK: - Internal
        public enum Internal: Equatable {
            case fetchGoals
            case setCalendarDate(TXCalendarDate)
            case setCalendarSheetPresented(Bool)
            case setPokeButtonDisabled(goalId: Int64, Bool, date: TXCalendarDate)
        }

        // MARK: - Response
        public enum Response {
            case fetchGoalsCompleted(GoalList, date: TXCalendarDate)
            case fetchGoalsFailed
            case authorizationCompleted(id: Int64, isAuthorized: Bool)
            case deletePhotoLogCompleted(goalId: Int64)
            case deletePhotoLogFailed
            case fetchUnreadResponse(Bool)
        }

        // MARK: - Presentation
        public enum Presentation: Equatable {
            case showToast(TXToastType)
        }

        // MARK: - Delegate
        case delegate(Delegate)

        /// 홈 화면에서 외부로 전달하는 이벤트입니다.
        public enum Delegate {
            case goToGoalDetail(id: Int64, owner: GoalDetail.Owner, verificationDate: String)
            case goToStatsDetail(id: Int64)
            case goToMakeGoal(GoalCategory)
            case goToEditGoalList(date: TXCalendarDate)
            case goToSettings
            case goToNotification
        }

        case view(View)
        case `internal`(Internal)
        case response(Response)
        case presentation(Presentation)
    }
    
    /// 외부에서 주입한 Reduce로 HomeReducer를 구성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = HomeReducer(reducer: Reduce { _, _ in .none })
    /// ```
    public init(
        reducer: Reduce<State, Action>,
        proofPhotoReducer: ProofPhotoReducer = ProofPhotoReducer(
            reducer: Reduce { _, _ in .none }
        )
    ) {
        self.reducer = reducer
        self.proofPhotoReducer = proofPhotoReducer
    }
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        reducer
            .ifLet(\.proofPhoto, action: \.proofPhoto) {
                proofPhotoReducer
            }
    }
}
