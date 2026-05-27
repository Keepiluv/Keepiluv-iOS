//
//  MakeGoalReducer.swift
//  FeatureHomeInterface
//
//  Created by 정지훈 on 2/1/26.
//

import SwiftUI

import ComposableArchitecture
import DomainCommonInterface
import DomainGoalInterface
import FeatureCommonInterface
import SharedDesignSystem
import SharedUtil

/// 목표 생성/수정 화면의 상태와 액션을 관리하는 Reducer입니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: MakeGoalReducer.State(mode: .add(.book))
/// ) {
///     MakeGoalReducer()
/// }
/// ```
@Reducer
public struct MakeGoalReducer {
    
    let reducer: Reduce<State, Action>
    
    @ObservableState
    /// 목표 생성/수정 화면에서 사용하는 상태입니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let state = MakeGoalReducer.State(mode: .add(.book))
    /// ```
    public struct State: Equatable {
        public let icons: [GoalIcon] = GoalIcon.allCases
        public let minimumPeriodCount = 1
        public let weeklyMaximumPeriodCount = 6
        public let monthlyMaximumPeriodCount = 25
        
        public var mode: Mode
        public var goalData: GoalForm
        public var calendarSheetDate: TXCalendarDate
        public var isCalendarSheetPresented: Bool = false
        public var calendarTarget: CalendarTarget?
        public var isPeriodSheetPresented: Bool = false
        public var isGoalTitleFocused: Bool = false
        
        public var showPeriodCount: Bool { goalData.repeatCycle != .daily }
        public var periodCountText: String { "\(goalData.repeatCycle.text) \(periodCount)번" }
        public var selectedEmojiIndex: Int { icons.firstIndex(of: goalData.icon) ?? 0 }
        public var startDateText: String { "\(goalData.startDate.month)월 \(goalData.startDate.day ?? 1)일" }
        public var endDateText: String { "\(goalData.endDate.month)월 \(goalData.endDate.day ?? 1)일" }
        public var dailyPeriodText: String { RepeatCycle.daily.text }
        public var weeklyPeriodText: String { RepeatCycle.weekly.text }
        public var monthlyPeriodText: String { RepeatCycle.monthly.text }
        public var completeButtonDisabled: Bool { !isValidTitleLength || isLoading }
        public var isInvalidTitle: Bool { isValidTitleLength }
        public var isValidTitleLength: Bool { 2 <= goalData.title.count && goalData.title.count <= 14 }
        
        public var modal: TXModalStyle?
        public var toast: TXToastType?
        public var isLoading: Bool = false
        public var submitMessage: String? = nil

        /// 화면 모드를 구분합니다.
        public enum Mode: Equatable {
            case add(GoalCategory)
            case edit(EditableGoal)
        }

        public enum CalendarTarget: Equatable {
            case startDate
            case endDate
        }

        public struct GoalForm: Equatable {
            public var goalId: Int64?
            public var category: GoalCategory?
            public var icon: GoalIcon
            public var title: String
            public var repeatCycle: RepeatCycle
            public var startDate: TXCalendarDate
            public var endDate: TXCalendarDate
            public var isEndDateOn: Bool
            public var weeklyPeriodCount: Int
            public var monthlyPeriodCount: Int

            public init(
                category: GoalCategory,
                today: TXCalendarDate,
                minimumPeriodCount: Int
            ) {
                self.goalId = nil
                self.category = category
                self.icon = GoalIcon.allCases[category.iconIndex]
                self.title = category != .custom ? category.title : ""
                self.repeatCycle = category.repeatCycle
                self.startDate = today
                self.endDate = today
                self.isEndDateOn = false
                self.weeklyPeriodCount = category.repeatCycle == .weekly
                    ? category.repeatCount
                    : minimumPeriodCount
                self.monthlyPeriodCount = category.repeatCycle == .monthly
                    ? category.repeatCount
                    : minimumPeriodCount
            }

            public init(
                editableGoal: EditableGoal,
                today: TXCalendarDate,
                minimumPeriodCount: Int
            ) {
                let startDate = TXCalendarUtil.parseAPIDateString(editableGoal.startDate) ?? today

                self.goalId = editableGoal.id
                self.category = nil
                self.icon = GoalIcon(from: editableGoal.icon)
                self.title = editableGoal.name
                self.repeatCycle = editableGoal.repeatCycle
                self.startDate = startDate
                self.endDate = editableGoal.endDate.flatMap(TXCalendarUtil.parseAPIDateString) ?? startDate
                self.isEndDateOn = editableGoal.endDate != nil
                self.weeklyPeriodCount = editableGoal.repeatCycle == .weekly
                    ? editableGoal.repeatCount ?? minimumPeriodCount
                    : minimumPeriodCount
                self.monthlyPeriodCount = editableGoal.repeatCycle == .monthly
                    ? editableGoal.repeatCount ?? minimumPeriodCount
                    : minimumPeriodCount
            }
        }
        
        /// 목표 생성/수정 화면의 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = MakeGoalReducer.State(mode: .add(.book))
        /// ```
        public init(mode: Mode) {
            let now = CalendarNow()
            let today = TXCalendarDate(
                year: now.year,
                month: now.month,
                day: now.day
            )
            let goalData: GoalForm
            
            switch mode {
            case let .add(category):
                goalData = GoalForm(
                    category: category,
                    today: today,
                    minimumPeriodCount: minimumPeriodCount
                )
                
            case let .edit(editableGoal):
                goalData = GoalForm(
                    editableGoal: editableGoal,
                    today: today,
                    minimumPeriodCount: minimumPeriodCount
                )
            }
            
            self.mode = mode
            self.goalData = goalData
            self.calendarSheetDate = goalData.startDate
        }
    }
    
    /// 목표 생성/수정 화면에서 발생 가능한 액션입니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// store.send(.view(.completeButtonTapped))
    /// ```
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case onDisappear
            case emojiButtonTapped
            case goalTitleFocusChanged(Bool)
            case dismissKeyboard
            case periodTabSelected(PeriodItem)
            case periodSelected
            case periodSheetWeeklyTapped
            case periodSheetMonthlyTapped
            case periodSheetMinusTapped
            case periodSheetPlusTapped
            case periodSheetCompleteTapped
            case startDateTapped
            case endDateTapped
            case monthCalendarConfirmTapped
            case completeButtonTapped
            case navigationBackButtonTapped
            case modalConfirmTapped(Int)
        }

        // MARK: - Response
        public enum Response: Equatable {
            case createGoalFailed
            case updateGoalFailed
        }

        // MARK: - Presentation
        public enum Presentation: Equatable {
            case showToast(TXToastType)
        }

        // MARK: - Delegate
        case delegate(Delegate)

        /// MakeGoalReducer 화면에서 외부로 전달하는 이벤트입니다.
        public enum Delegate {
            case navigateBack
        }

        case view(View)
        case response(Response)
        case presentation(Presentation)
    }
    
    /// 외부에서 주입한 Reduce로 MakeGoalReducer를 구성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = MakeGoalReducer(reducer: Reduce { _, _ in .none })
    /// ```
    public init(reducer: Reduce<State, Action>) {
        self.reducer = reducer
    }
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
        reducer
    }
}

// MARK: - Functions
public extension MakeGoalReducer.State {
    var periodCount: Int {
        switch goalData.repeatCycle {
        case .daily: return 1
        case .weekly: return goalData.weeklyPeriodCount
        case .monthly: return goalData.monthlyPeriodCount
        }
    }

    var isMinusEnable: Bool { periodCount > minimumPeriodCount }

    var isPlusEnable: Bool {
        if case .monthly = goalData.repeatCycle {
            return periodCount < monthlyMaximumPeriodCount
        } else if case .weekly = goalData.repeatCycle {
            return periodCount < weeklyMaximumPeriodCount
        } else {
            return false
        }
    }
    
    var calendarMinimumDate: TXCalendarDate? {
        switch calendarTarget {
        case .startDate:
            let now = CalendarNow()
            return TXCalendarDate(year: now.year, month: now.month, day: now.day)
            
        case .endDate:
            return goalData.startDate
            
        case .none:
            return nil
        }
    }

    var isCalendarDateEnabled: (TXCalendarDateItem) -> Bool {
        { item in
            guard let minimumDate = calendarMinimumDate else { return true }
            guard let components = item.dateComponents,
                  let year = components.year,
                  let month = components.month,
                  let day = components.day else {
                return true
            }
            let itemDate = TXCalendarDate(year: year, month: month, day: day)
            return itemDate >= minimumDate
        }
    }
}


public extension MakeGoalReducer.State.Mode {
    var title: String {
        switch self {
        case .add: return "직접 만들기"
        case .edit: return "목표 수정"
        }
    }
}
