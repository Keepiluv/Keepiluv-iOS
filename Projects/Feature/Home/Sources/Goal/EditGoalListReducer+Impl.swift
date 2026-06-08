//
//  EditGoalListReducer+Impl.swift
//  FeatureHome
//
//  Created by 정지훈 on 2/4/26.
//

import Foundation
import SwiftUI

import ComposableArchitecture
import DomainCommonInterface
import DomainGoalInterface
import FeatureCommonInterface
import FeatureHomeInterface
import SharedDesignSystem

extension EditGoalListReducer {
    /// 실제 로직을 포함한 EditGoalListReducer를 생성합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let reducer = EditGoalListReducer()
    /// ```
    // swiftlint:disable:next function_body_length
    public init() {
        @Dependency(\.goalClient) var goalClient
        
        // swiftlint:disable:next closure_body_length
        let reducer = Reduce<State, Action> { state, action in
            switch action {
                // MARK: - LifeCycle
            case .view(.onAppear):
                return .send(.internal(.fetchGoals))
                
            case .view(.onDisappear):
                state.selectedCardMenu = nil
                return .none
                
                // MARK: - User Action
            case let .view(.calendarDateSelected(item)):
                guard let components = item.dateComponents,
                      let year = components.year,
                      let month = components.month,
                      let day = components.day else {
                    return .none
                }
                return .send(.internal(.setCalendarDate(.init(year: year, month: month, day: day))))
                
            case let .view(.weekCalendarSwipe(swipe)):
                switch swipe {
                case .next:
                    guard let nextWeekDate = TXCalendarUtil.dateByAddingWeek(
                        from: state.calendarDate,
                        by: 1
                    ) else {
                        return .none
                    }
                    return .send(.internal(.setCalendarDate(nextWeekDate)))

                case .previous:
                    guard let previousWeekDate = TXCalendarUtil.dateByAddingWeek(
                        from: state.calendarDate,
                        by: -1
                    ) else {
                        return .none
                    }
                    return .send(.internal(.setCalendarDate(previousWeekDate)))
                }
                
            case .view(.navigationBackButtonTapped):
                return .send(.delegate(.navigateBack))
                
            case let .view(.cardMenuButtonTapped(card)):
                state.selectedCardMenu = state.selectedCardMenu == card ? nil : card
                return .none
                
            case let .view(.cardMenuItemSelected(item)):
                guard let card = state.selectedCardMenu else { return .none }
                
                switch item {
                case .edit:
                    state.selectedCardMenu = nil
                    
                    // FIXME: - 통계 나오기 전까지 토스트 띄움
                    let isPast = state.calendarDate < TXCalendarDate()
                    if isPast {
                        state.toast = .warning(message: "이미 완료한 목표입니다!")
                    } else {
                        guard let editableGoal = state.editableGoals?.first(where: { $0.id == card.id }) else {
                            return .send(.response(.apiError("목표 수정에 실패했어요")))
                        }
                        return .send(.delegate(.goToGoalEdit(editableGoal)))
                    }
                    
                case .finish:
                    state.pendingGoalId = card.id
                    state.pendingAction = .complete
                    state.modal = .info(
                        image: card.iconImage,
                        title: "\(card.goalName)\n목표를 이루셨나요?",
                        subtitle: "이룬 목표에서 확인할 수 있어요",
                        leftButtonText: "취소",
                        rightButtonText: "이뤘어요"
                    )
                    
                case .delete:
                    state.pendingGoalId = card.id
                    state.pendingAction = .delete
                    state.modal = .info(
                        image: card.iconImage,
                        title: "\(card.goalName)\n목표를 삭제할까요?",
                        subtitle: "저장된 인증샷은 모두 삭제됩니다.",
                        leftButtonText: "취소",
                        rightButtonText: "삭제"
                    )
                }
                
                state.selectedCardMenu = nil
                return .none
                
            case .view(.backgroundTapped):
                state.selectedCardMenu = nil
                return .none
                
            case .view(.modalConfirmTapped):
                guard !state.isLoading,
                      let goalId = state.pendingGoalId,
                      let pendingAction = state.pendingAction else {
                    return .none
                }

                state.isLoading = true
                state.modal = nil
                
                switch pendingAction {
                case .complete:
                    return .run { send in
                        do {
                            _ = try await goalClient.completeGoal(goalId)
                            await send(.response(.completeGoalCompleted(goalId: goalId)))
                        } catch {
                            await send(.response(.apiError("이미 끝났습니다.")))
                        }
                    }
                    
                case .delete:
                    return .run { send in
                        do {
                            try await goalClient.deleteGoal(goalId)
                            await send(.response(.deleteGoalCompleted(goalId: goalId)))
                        } catch {
                            await send(.response(.apiError("목표 삭제에 실패했어요")))
                        }
                    }
                }
                
            case .view(.toastButtonTapped):
                return .send(.delegate(.goToCompletedStats))

            case .view(.dataRetryTapped):
                return .send(.internal(.fetchGoals))
                
                // MARK: - Update State
            case let .internal(.setCalendarDate(date)):
                if date == state.calendarDate {
                    return .none
                }
                state.calendarDate = date
                state.calendarWeeks = TXCalendarDataGenerator.generateWeekData(for: date)
                state.isLoading = true
                return .send(.internal(.fetchGoals))
                
            case .internal(.fetchGoals):
                state.isLoading = true
                state.isFetchFailed = false
                let date = state.calendarDate
                return .run { send in
                    do {
                        let goals = try await goalClient.fetchGoalEditList(TXCalendarUtil.apiDateString(for: date))
                            .compactMap { goal -> EditableGoal? in
                                guard let repeatCycle = goal.repeatCycle,
                                      let startDate = goal.startDate else {
                                    return nil
                                }
                                
                                return EditableGoal(
                                    id: goal.id,
                                    name: goal.title,
                                    icon: goal.goalIcon,
                                    repeatCycle: repeatCycle,
                                    repeatCount: goal.repeatCount,
                                    startDate: startDate,
                                    endDate: goal.endDate
                                )
                            }
                        await send(.response(.fetchGoalsCompleted(goals, date: date)))
                    } catch {
                        await send(.response(.apiError("목표 조회에 실패했어요")))
                    }
                }

            case let .response(.fetchGoalsCompleted(goals, date)):
                if date != state.calendarDate {
                    return .none
                }
                state.isLoading = false
                state.isFetchFailed = false
                state.editableGoals = goals
                let items = goals.map {
                    GoalEditCardItem(
                        id: $0.id,
                        goalName: $0.name,
                        goalIcon: GoalIcon(from: $0.icon),
                        iconImage: GoalIcon(from: $0.icon).thinImage,
                        repeatCycle: $0.repeatCycle.text,
                        startDate: $0.startDate.dateDisplayString,
                        endDate: $0.endDate?.dateDisplayString ?? "미설정"
                    )
                }
                if state.cards != items {
                    state.cards = items
                }
                return .none

            case let .response(.deleteGoalCompleted(goalId)):
                state.isLoading = false
                state.pendingGoalId = nil
                state.pendingAction = nil
                state.editableGoals?.removeAll { $0.id == goalId }
                state.cards?.removeAll { $0.id == goalId }
                return .send(.presentation(.showToast(.delete(message: "목표가 삭제되었어요"))))

            case let .response(.completeGoalCompleted(goalId)):
                state.isLoading = false
                state.pendingGoalId = nil
                state.pendingAction = nil
                state.editableGoals?.removeAll { $0.id == goalId }
                state.cards?.removeAll { $0.id == goalId }
                return .send(.presentation(.showToast(.success(message: "목표를 이뤘어요", buttonText: "보러가기"))))

            case let .response(.apiError(message)):
                state.isLoading = false
                state.pendingGoalId = nil
                state.pendingAction = nil
                
                if state.cards == nil {
                    state.isFetchFailed = true
                    return .none
                }
                return .send(.presentation(.showToast(.warning(message: message))))

            case let .presentation(.showToast(toast)):
                state.toast = toast
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
