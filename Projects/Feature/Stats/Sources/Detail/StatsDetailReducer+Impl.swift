//
//  StatsDetailReducer+Impl.swift
//  FeatureStats
//
//  Created by 정지훈 on 2/19/26.
//

import Foundation

import ComposableArchitecture
import DomainGoalInterface
import DomainStatsInterface
import FeatureCommonInterface
import FeatureStatsInterface
import SharedDesignSystem

// TODO: API 연동
extension StatsDetailReducer {
    /// 기본 구성의 StatsDetailReducer를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = StatsDetailReducer()
    /// ```
    // swiftlint:disable:next function_body_length
    public init() {
        @Dependency(\.goalClient) var goalClient
        @Dependency(\.statsClient) var statsClient
        
        // swiftlint:disable:next closure_body_length
        let reducer = Reduce<State, Action> { state, action in
            switch action {
                // MARK: - LifeCycle
            case .view(.onAppear):
                return .merge(
                    .send(.internal(.fetchStatsDetailCalendar)),
                    .send(.internal(.fetchStatsDetailSummary))
                )
                
            case .view(.onDisappear):
                return .none

            case .view(.dataRetryTapped):
                return .merge(
                    .send(.internal(.fetchStatsDetailCalendar)),
                    .send(.internal(.fetchStatsDetailSummary))
                )
                
                // MARK: - User Action
            case let .view(.navigationBarTapped(action)):
                if case .backTapped = action {
                    return .send(.delegate(.navigateBack))
                } else if case .rightTapped = action {
                    if state.isCompleted {
                        return .send(.view(.dropDownSelected(.delete)))
                    } else {
                        state.isDropdownPresented = true
                        return .none
                    }
                }
                return .none
                
            case .view(.previousMonthTapped):
                state.currentMonth.goToPreviousMonth()
                state.monthlyData = TXCalendarDataGenerator.generateMonthData(
                    for: state.currentMonth,
                    hideAdjacentDates: true
                )
                return .send(.internal(.fetchStatsDetailCalendar))
                
            case .view(.nextMonthTapped):
                guard !state.nextMonthDisabled else { return .none }
                state.currentMonth.goToNextMonth()
                state.monthlyData = TXCalendarDataGenerator.generateMonthData(
                    for: state.currentMonth,
                    hideAdjacentDates: true
                )
                return .send(.internal(.fetchStatsDetailCalendar))

            case let .view(.calendarSwiped(swipe)):
                switch swipe {
                case .previous:
                    return .send(.view(.previousMonthTapped))
                case .next:
                    return .send(.view(.nextMonthTapped))
                }
                
            case let .view(.calendarCellTapped(item)):
                guard let dateComponents = item.dateComponents,
                      let txDate = TXCalendarDate(components: dateComponents)
                else { return .none }
                let dateString = txDate.formattedAPIDateString()
                let completedItem = state.completedDateByKey[dateString]
                let owner: GoalDetail.Owner = completedItem?.partnerImageUrl != nil ? .you : .mySelf
                
                return .send(
                    .delegate(
                        .goToGoalDetail(
                            goalId: state.goalId,
                            owner: owner,
                            date: dateString
                        )
                    )
                )
                
            case let .view(.dropDownSelected(item)):
                guard let detail = state.statsDetail,
                      let summary = state.statsSummary else { return .none }
                let goalItem = GoalEditCardItem(
                    id: detail.goalId,
                    goalName: detail.goalName,
                    iconImage: GoalIcon(from: detail.goalIcon).thinImage,
                    repeatCycle: summary.repeatCycle.text,
                    startDate: summary.startDate,
                    endDate: summary.endDate ?? ""
                )
                state.isDropdownPresented = false
                state.selectedDropDownItem = item
                
                switch item {
                case .edit:
                    let editableGoal = EditableGoal(
                        id: state.goalId,
                        name: detail.goalName,
                        icon: detail.goalIcon,
                        repeatCycle: summary.repeatCycle,
                        repeatCount: nil,
                        startDate: summary.startDate,
                        endDate: summary.endDate
                    )
                    return .send(.delegate(.goToGoalEdit(editableGoal)))
                    
                case .finish:
                    state.modal = .info(
                        image: goalItem.iconImage,
                        title: "\(goalItem.goalName)\n목표를 이루셨나요?",
                        subtitle: "이룬 목표에서 확인할 수 있어요",
                        leftButtonText: "취소",
                        rightButtonText: "이뤘어요"
                    )
                    
                case .delete:
                    state.modal = .info(
                        image: goalItem.iconImage,
                        title: "\(goalItem.goalName)\n목표를 삭제할까요?",
                        subtitle: "저장된 인증샷은 모두 삭제됩니다.",
                        leftButtonText: "취소",
                        rightButtonText: "삭제"
                    )
                }
                return .none
                
            case .view(.backgroundTapped):
                state.isDropdownPresented = false
                return .none
                
            case .view(.modalConfirmTapped):
                guard let selectedDropDownItem = state.selectedDropDownItem else { return .none }
                switch selectedDropDownItem {
                case .edit: return .none
                case .finish: return .send(.internal(.patchCompleteGoal))
                case .delete: return .send(.internal(.deleteGoal))
                }
                
                // MARK: - Network
            case .internal(.fetchStatsDetailCalendar):
                let month = state.currentMonth.formattedYearDashMonth
                let goalId = state.goalId
                var applyCached: Effect<Action> = .none
                if let cached = state.completedDateCache[month] {
                    state.isLoading = false
                    state.isCalendarFetchFailed = false
                    applyCached = .send(.internal(.updateMonthlyDate(cached)))
                } else {
                    state.isLoading = true
                    state.isCalendarFetchFailed = false
                }
                
                let fetchRemote: Effect<Action> = .run { send in
                    do {
                        let statsDetail = try await statsClient.fetchStatsDetailCalendar(goalId, month)
                        await send(.response(.fetchStatsDetailCalendarSuccess(statsDetail, month: month)))
                    } catch {
                        await send(.response(.fetchStatsDetailCalendarFailed(month: month)))
                    }
                }
                
                return .merge(applyCached, fetchRemote)
            
            case .internal(.fetchStatsDetailSummary):
                let goalId = state.goalId
                state.isSummaryFetchFailed = false
                return .run { send in
                    do {
                        let summary = try await statsClient.fetchStatsDetailSummary(goalId)
                        await send(.response(.fetchStatsDetailSummarySuccess(summary)))
                    } catch {
                        await send(.response(.fetchStatsDetailSummaryFailed))
                    }
                }

            case let .response(.fetchStatsDetailCalendarSuccess(statsDetail, month)):
                state.isLoading = false
                state.isCalendarFetchFailed = false
                state.statsDetail = statsDetail
                state.completedDateCache[month] = statsDetail.completedDate.filter { $0.date.hasPrefix(month) }
                
                let currentMonth = state.currentMonth.formattedYearDashMonth
                guard currentMonth == month else {
                    return .none
                }
                
                return .send(.internal(.updateMonthlyDate(state.completedDateCache[month] ?? [])))
                
            case let .response(.fetchStatsDetailCalendarFailed(month)):
                guard month == state.currentMonth.formattedYearDashMonth else { return .none }
                state.isLoading = false
                state.isCalendarFetchFailed = true
                return .none

            case let .response(.fetchStatsDetailSummarySuccess(summary)):
                state.isSummaryFetchFailed = false
                return .send(.internal(.updateStatsSummary(summary)))

            case .response(.fetchStatsDetailSummaryFailed):
                state.isSummaryFetchFailed = true
                return .none
                
            case .internal(.patchCompleteGoal):
                let goalId = state.goalId
                return .run { send in
                    do {
                        _ = try await goalClient.completeGoal(goalId)
                        await send(.response(.completeGoalSuccees))
                    } catch {
                        await send(.presentation(.showToast("이미 끝났습니다.")))
                    }
                }
                
            case .response(.completeGoalSuccees):
                state.statsDetail?.isCompleted = true
                return .none
                
            case .internal(.deleteGoal):
                let goalId = state.goalId
                return .run { send in
                    do {
                        try await goalClient.deleteGoal(goalId)
                        await send(.response(.deleteGoalSuccees))
                    } catch {
                        await send(.presentation(.showToast("목표 삭제에 실패했어요")))
                    }
                }
                
            case .response(.deleteGoalSuccees):
                return .send(.delegate(.navigateBack))
                
                // MARK: - Update State
            case let .internal(.updateStatsDetail(statsDetail)):
                state.statsDetail = statsDetail
                return .none
                
            case let .internal(.updateStatsSummary(summary)):
                state.statsSummary = summary
                let myCountString = "\(summary.myNickname) - \(summary.myCompletedCount)/\(summary.totalCount)"
                let partnerCountString = "\(summary.partnerNickname) - \(summary.partnerCompltedCount)/\(summary.totalCount)"
                 
                let summaryInfo: [State.StatsSummaryInfo] = [
                    .init(title: "달성 횟수", content: [myCountString, partnerCountString]),
                    .init(title: "반복 주기", content: [summary.repeatCycle.text]),
                    .init(title: "시작일", content: [summary.startDate]),
                    .init(title: "종료일", content: [summary.endDate ?? "미설정"]),
                ]
                
                state.statsSummaryInfo = summaryInfo
                return .none
                
            case let .internal(.updateMonthlyDate(completedDate)):
                state.completedDateByKey = completedDate.reduce(into: [:]) { result, item in
                    guard item.myImageUrl != nil || item.partnerImageUrl != nil else { return }
                    result[item.date] = item
                }

                let completedDateSet = Set(completedDate.map(\.date))
                state.monthlyData = state.monthlyData.map { week in
                    week.map { item in
                        guard let components = item.dateComponents,
                              let date = TXCalendarDate(components: components) else {
                            return item
                        }
                        let isCompletedDate = completedDateSet.contains(date.formattedAPIDateString())

                        guard isCompletedDate else { return item }
                        return TXCalendarDateItem(
                            id: item.id,
                            text: item.text,
                            status: .completed,
                            dateComponents: item.dateComponents
                        )
                    }
                }
                return .none
                
            case let .presentation(.showToast(text)):
                state.toast = .warning(message: text)
                return .none
             
            case .delegate:
                return .none
                
            case .binding:
                return .none
            }
        }

        self.init(reducer: reducer)
    }
}
