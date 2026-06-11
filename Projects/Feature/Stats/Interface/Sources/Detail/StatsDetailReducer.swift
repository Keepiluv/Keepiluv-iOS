//
//  StatsDetailReducer.swift
//  FeatureStatsInterface
//
//  Created by 정지훈 on 2/19/26.
//

import Foundation

import ComposableArchitecture
import DomainGoalInterface
import DomainStatsInterface
import FeatureCommonInterface
import SharedDesignSystem

/// 통계 상세 화면의 상태와 액션을 관리하는 Reducer입니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: StatsDetailReducer.State(
///         goalId: 1,
///         initialMonth: TXCalendarDate()
///     )
/// ) {
///     StatsDetailReducer(reducer: Reduce { _, _ in .none })
/// }
/// ```
@Reducer
public struct StatsDetailReducer {
    let reducer: Reduce<State, Action>

    /// 통계 상세 화면에서 사용하는 상태입니다.
    @ObservableState
    public struct State: Equatable {
        public let goalId: Int64
        
        public var isLoading: Bool = false
        public var isDropdownPresented: Bool = false
        public var selectedDropDownItem: GoalDropList?
        public var currentMonth: TXCalendarDate
        public var monthlyData: [[TXCalendarDateItem]]
        public var statsDetail: StatsDetail?
        public var statsSummary: StatsDetail.Summary?
        public var completedDateByKey: [String: StatsDetail.CompletedDate] = [:]
        public var completedDateCache: [String: [StatsDetail.CompletedDate]] = [:]
        public var statsSummaryInfo: [StatsSummaryInfo] = []
        public var modal: TXModalStyle?
        public var toast: TXToastType?
        
        public var currentMonthTitle: String { currentMonth.formattedYearMonth }
        public var nextMonthDisabled: Bool { currentMonth >= TXCalendarDate() }
        public var previousMonthDisabled: Bool {
            guard let startDateString = statsSummary?.startDate,
                let startDate = TXCalendarUtil.parseAPIDateString(startDateString) else {
                return false
            }
            
            return currentMonth <= startDate
        }
        public var naviBarTitle: String { statsDetail?.goalName ?? "" }
        public var isCompleted: Bool { statsDetail?.isCompleted == true }
        
        /// 통계 요약 영역의 단일 행 정보를 표현합니다.
        public struct StatsSummaryInfo: Equatable {
            public let title: String
            public let content: [String]
            
            public var isCompletedCount: Bool { content.count > 1 }
            
            public init(
                title: String,
                content: [String]
            ) {
                self.title = title
                self.content = content
            }
        }

        /// 기본 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = StatsDetailReducer.State(
        ///     goalId: 1,
        ///     initialMonth: TXCalendarDate()
        /// )
        /// ```
        public init(goalId: Int64, initialMonth: TXCalendarDate) {
            self.goalId = goalId

            self.currentMonth = initialMonth
            self.monthlyData = TXCalendarDataGenerator.generateMonthData(
                for: initialMonth,
                hideAdjacentDates: true
            )
        }
    }

    /// 통계 상세 화면에서 발생 가능한 액션입니다.
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case onDisappear
            case navigationBarTapped(TXNavigationBar.Action)
            case previousMonthTapped
            case nextMonthTapped
            case calendarSwiped(TXCalendar.SwipeGesture)
            case calendarCellTapped(TXCalendarDateItem)
            case dropDownSelected(GoalDropList)
            case backgroundTapped
            case modalConfirmTapped
        }

        // MARK: - Internal
        public enum Internal: Equatable {
            case fetchStatsDetailCalendar
            case fetchStatsDetailSummary
            case patchCompleteGoal
            case deleteGoal
            case updateStatsDetail(StatsDetail)
            case updateStatsSummary(StatsDetail.Summary)
            case updateMonthlyDate(([StatsDetail.CompletedDate]))
        }

        // MARK: - Response
        public enum Response: Equatable {
            case fetchStatsDetailCalendarSuccess(StatsDetail, month: String)
            case fetchStatsDetailCalendarFailed
            case fetchStatsDetailSummarySuccess(StatsDetail.Summary)
            case fetchStatsDetailSummaryFailed
            case completeGoalSuccees
            case deleteGoalSuccees
        }

        // MARK: - Presentation
        public enum Presentation: Equatable {
            case showToast(String)
        }

        // MARK: - Delegate
        case delegate(Delegate)

        public enum Delegate {
            case navigateBack
            case goToGoalDetail(goalId: Int64, isCompletedPartner: Bool, date: String)
            case goToGoalEdit(EditableGoal)
        }

        case view(View)
        case `internal`(Internal)
        case response(Response)
        case presentation(Presentation)
    }

    /// 외부에서 주입된 Reduce로 StatsDetailReducer를 구성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = StatsDetailReducer(
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
