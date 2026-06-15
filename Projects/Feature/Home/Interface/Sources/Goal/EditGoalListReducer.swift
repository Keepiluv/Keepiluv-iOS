//
//  EditGoalListReducer.swift
//  FeatureHome
//
//  Created by 정지훈 on 2/4/26.
//

import Foundation

import ComposableArchitecture
import DomainGoalInterface
import FeatureCommonInterface
import SharedDesignSystem
import SharedUtil
import SwiftUI

@Reducer
/// 목표 편집 화면의 상태와 액션을 관리하는 Reducer입니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(initialState: EditGoalListReducer.State()) {
///     EditGoalListReducer()
/// }
/// ```
public struct EditGoalListReducer {
    
    let reducer: Reduce<State, Action>
    
    @ObservableState
    /// 목표 편집 화면에서 사용하는 상태 모델입니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let state = EditGoalListReducer.State()
    /// ```
    public struct State: Equatable {
        public struct Data: Equatable {
            public var calendarDate: TXCalendarDate
            public var calendarWeeks: [[TXCalendarDateItem]]
            public var editableGoals: [EditableGoal]?
            public var cards: [GoalEditCardItem]?
            public var selectedCardMenu: GoalEditCardItem?
            public var pendingGoalId: Int64?
            public var pendingAction: PendingAction?

            public init(calendarDate: TXCalendarDate) {
                self.calendarDate = calendarDate
                self.calendarWeeks = TXCalendarDataGenerator.generateWeekData(for: calendarDate)
            }
        }

        public struct UIState: Equatable {
            public var isLoading: Bool = true
            public var isFetchFailed: Bool = false
            public init() { }
        }

        public struct Presentation: Equatable {
            public var modal: TXModalStyle?
            public var toast: TXToastType?
            public init() { }
        }

        public var data: Data
        public var ui = UIState()
        public var presentation = Presentation()

        public var calendarDate: TXCalendarDate { get { data.calendarDate } set { data.calendarDate = newValue } }
        public var calendarWeeks: [[TXCalendarDateItem]] { get { data.calendarWeeks } set { data.calendarWeeks = newValue } }
        public var editableGoals: [EditableGoal]? { get { data.editableGoals } set { data.editableGoals = newValue } }
        public var cards: [GoalEditCardItem]? { get { data.cards } set { data.cards = newValue } }
        public var selectedCardMenu: GoalEditCardItem? { get { data.selectedCardMenu } set { data.selectedCardMenu = newValue } }
        public var modal: TXModalStyle? { get { presentation.modal } set { presentation.modal = newValue } }
        public var toast: TXToastType? { get { presentation.toast } set { presentation.toast = newValue } }
        public var isLoading: Bool { get { ui.isLoading } set { ui.isLoading = newValue } }
        public var isFetchFailed: Bool { get { ui.isFetchFailed } set { ui.isFetchFailed = newValue } }
        public var pendingGoalId: Int64? { get { data.pendingGoalId } set { data.pendingGoalId = newValue } }
        public var pendingAction: PendingAction? { get { data.pendingAction } set { data.pendingAction = newValue } }
        public var hasCards: Bool { !(cards?.isEmpty ?? true) }

        public enum PendingAction: Equatable {
            case delete
            case complete
        }

        /// 기본 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = EditGoalListReducer.State()
        /// ```
        public init(calendarDate: TXCalendarDate) {
            self.data = Data(calendarDate: calendarDate)
        }
    }
    
    /// 목표 편집 화면에서 발생 가능한 이벤트입니다.
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case onDisappear
            case calendarDateSelected(TXCalendarDateItem)
            case weekCalendarSwipe(TXCalendar.SwipeGesture)
            case navigationBackButtonTapped
            case cardMenuButtonTapped(GoalEditCardItem)
            case cardMenuItemSelected(GoalDropList)
            case backgroundTapped
            case modalConfirmTapped
            case toastButtonTapped
            case dataRetryTapped
        }

        // MARK: - Internal
        public enum Internal: Equatable {
            case setCalendarDate(TXCalendarDate)
            case fetchGoals
        }

        // MARK: - Response
        public enum Response: Equatable {
            case fetchGoalsCompleted([EditableGoal], date: TXCalendarDate)
            case deleteGoalCompleted(goalId: Int64)
            case completeGoalCompleted(goalId: Int64)
            case apiError(String)
        }

        // MARK: - Presentation
        public enum Presentation: Equatable {
            case showToast(TXToastType)
        }

        // MARK: - Delegate
        case delegate(Delegate)

        public enum Delegate {
            case navigateBack
            case goToGoalEdit(EditableGoal)
            case goToCompletedStats
        }

        case view(View)
        case `internal`(Internal)
        case response(Response)
        case presentation(Presentation)
    }
    
    /// 외부에서 주입한 Reduce로 EditGoalListReducer를 구성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = EditGoalListReducer(
    ///     reducer: Reduce { _, _ in .none }
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
