//
//  StatsReducer.swift
//  FeatureStatsInterface
//
//  Created by 정지훈 on 2/18/26.
//

import Foundation

import ComposableArchitecture
import DomainStatsInterface
import FeatureCommonInterface
import SharedDesignSystem

/// 통계 메인 화면의 상태와 액션을 관리하는 Reducer입니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: StatsReducer.State()
/// ) {
///     StatsReducer(reducer: Reduce { _, _ in .none })
/// }
/// ```
@Reducer
public struct StatsReducer {
    
    let reducer: Reduce<State, Action>
    
    /// 통계 메인 화면에서 사용하는 상태입니다.
    @ObservableState
    public struct State: Equatable {
        public var currentMonth: TXCalendarDate = .init()
        public var monthTitle: String { currentMonth.formattedYearMonth }
        public var isLoading: Bool = false
        public var isOngoing: Bool = true
        public var isNextMonthDisabled: Bool {
            currentMonth >= TXCalendarDate()
        }

        public var items: [StatsCardItem]? {
            return isOngoing ? ongoingItems : completedItems
        }
        
        public var ongoingItems: [StatsCardItem]?
        public var completedItems: [StatsCardItem]?
        public var ongoingItemsCache: [String: [StatsCardItem]] = [:]
        
        public var toast: TXToastType?

        public struct UIState: Equatable {
            public var isLoading: Bool
            public var isOngoing: Bool

            public init(isLoading: Bool = false, isOngoing: Bool = true) {
                self.isLoading = isLoading
                self.isOngoing = isOngoing
            }
        }

        public var ui: UIState {
            get { UIState(isLoading: isLoading, isOngoing: isOngoing) }
            set {
                isLoading = newValue.isLoading
                isOngoing = newValue.isOngoing
            }
        }
        
        /// 기본 상태를 생성합니다.
        ///
        /// ## 사용 예시
        /// ```swift
        /// let state = StatsReducer.State()
        /// ```
        public init() { }
    }
    
    /// 통계 메인 화면에서 발생 가능한 액션입니다.
    public enum Action: BindableAction {
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case topTabBarSelected(StatsTopTabItem)
            case statsCardTapped(goalId: Int64)
            case previousMonthTapped
            case nextMonthTapped
        }

        // MARK: - Internal
        public enum Internal: Equatable {
            case fetchStats
        }

        // MARK: - Response
        public enum Response: Equatable {
            case fetchedStats(stats: Stats, month: String)
            case fetchStatsFailed
        }

        // MARK: - Presentation
        public enum Presentation: Equatable {
            case showToast(TXToastType)
        }

        // MARK: - Delegate
        case delegate(Delegate)

        /// StatsReducer가 상위 Coordinator로 전달하는 이벤트입니다.
        public enum Delegate {
            case goToStatsDetail(goalId: Int64, calendarDate: TXCalendarDate)
        }

        case view(View)
        case `internal`(Internal)
        case response(Response)
        case presentation(Presentation)
    }
    
    /// 외부에서 주입된 Reduce로 StatsReducer를 구성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = StatsReducer(
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
