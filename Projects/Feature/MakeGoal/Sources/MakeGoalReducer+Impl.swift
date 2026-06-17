//
//  MakeGoalReducer+Impl.swift
//  FeatureMakeGoalInterface
//
//  Created by 정지훈 on 2/1/26.
//

import Foundation

import ComposableArchitecture
import CoreAnalyticsInterface
import DomainGoalInterface
import FeatureMakeGoalInterface
import SharedDesignSystem

extension MakeGoalReducer {
    // swiftlint:disable:next function_body_length
    public init() {
        @Dependency(\.goalClient) var goalClient
        @Dependency(\.analyticsClient) var analyticsClient
        // swiftlint:disable:next closure_body_length
        let reducer = Reduce<State, Action> { state, action in
            switch action {
                // MARK: - LifeCycle
            case .view(.onAppear):
                return .none

            case .view(.onDisappear):
                return .none

            case .response(.createGoalFailed):
                state.isLoading = false
                state.submitMessage = nil
                return .send(.presentation(.showToast(.warning(message: "목표 생성에 실패했어요"))))

            case .response(.updateGoalFailed):
                state.isLoading = false
                state.submitMessage = nil
                return .send(.presentation(.showToast(.warning(message: "이미 완료한 목표입니다!"))))

                // MARK: - User Action
            case .view(.emojiButtonTapped):
                state.isGoalTitleFocused = false
                state.modal = .selection(
                    title: "아이콘 변경",
                    icons: state.icons.map { $0.image },
                    selectedIndex: state.selectedEmojiIndex,
                    buttonTitle: "완료"
                )
                return .none
                
            case let .view(.modalConfirmTapped(index)):
                state.goalData.icon = state.icons[index]
                return .none

            case let .view(.goalTitleFocusChanged(isFocused)):
                state.isGoalTitleFocused = isFocused
                return .none

            case .view(.dismissKeyboard):
                state.isGoalTitleFocused = false
                return .none

            case let .view(.periodTabSelected(item)):
                state.goalData.repeatCycle = item.repeatCycle
                return .none
                
            case .view(.periodSelected):
                state.isGoalTitleFocused = false
                state.isPeriodSheetPresented = true
                return .none
                
            case .view(.periodSheetWeeklyTapped):
                state.goalData.repeatCycle = .weekly
                return .none
                
            case .view(.periodSheetMonthlyTapped):
                state.goalData.repeatCycle = .monthly
                return .none
                
            case .view(.periodSheetMinusTapped):
                switch state.goalData.repeatCycle {
                case .daily:
                    return .none
                    
                case .weekly:
                    state.goalData.weeklyPeriodCount -= 1
                    state.goalData.repeatCycle = .weekly
                    
                case .monthly:
                    state.goalData.monthlyPeriodCount -= 1
                    state.goalData.repeatCycle = .monthly
                }
                
                return .none
                
            case .view(.periodSheetPlusTapped):
                switch state.goalData.repeatCycle {
                case .daily:
                    return .none
                    
                case .weekly:
                    state.goalData.weeklyPeriodCount += 1
                    state.goalData.repeatCycle = .weekly
                    
                case .monthly:
                    state.goalData.monthlyPeriodCount += 1
                    state.goalData.repeatCycle = .monthly
                }
                
                return .none
                
            case .view(.periodSheetCompleteTapped):
                state.isPeriodSheetPresented = false
                return .none
                
            case .view(.startDateTapped):
                state.isGoalTitleFocused = false
                state.calendarTarget = .startDate
                state.calendarSheetDate = state.goalData.startDate
                state.isCalendarSheetPresented = true
                return .none
                
            case .view(.endDateTapped):
                state.isGoalTitleFocused = false
                state.calendarTarget = .endDate
                if state.goalData.endDate < state.goalData.startDate {
                    state.goalData.endDate = state.goalData.startDate
                }
                state.calendarSheetDate = state.goalData.endDate
                state.isCalendarSheetPresented = true
                return .none
                
            case .view(.monthCalendarConfirmTapped):
                guard let target = state.calendarTarget else {
                    state.isCalendarSheetPresented = false
                    return .none
                }
                
                switch target {
                case .startDate:
                    state.goalData.startDate = state.calendarSheetDate
                    if state.goalData.endDate < state.goalData.startDate {
                        state.goalData.endDate = state.goalData.startDate
                    }
                    
                case .endDate:
                    state.goalData.endDate = state.calendarSheetDate
                }
                
                state.isCalendarSheetPresented = false
                return .none
                
            case .view(.completeButtonTapped):
                guard !state.isLoading else { return .none }
                guard !state.completeButtonDisabled  else {
                    return .send(.presentation(.showToast(.warning(message: "목표 이름은 14글자 이내로 입력해 주세요!"))))
                }

                state.isLoading = true
                let endDateString: String? = state.goalData.isEndDateOn
                ? TXCalendarUtil.apiDateString(for: state.goalData.endDate)
                : nil
                switch state.mode {
                case let .add(category):
                    let category = category.rawValue
                    state.submitMessage = "등록 중..."
                    let request = GoalCreateRequestDTO(
                        name: state.goalData.title,
                        icon: state.goalData.icon.rawValue,
                        repeatCycle: state.goalData.repeatCycle.rawValue,
                        repeatCount: state.periodCount,
                        startDate: TXCalendarUtil.apiDateString(for: state.goalData.startDate),
                        endDate: endDateString
                    )
                    return .run { send in
                        do {
                            let goal = try await goalClient.createGoal(request)
                            analyticsClient
                                .logEvent(
                                    MakeGoalAnalyticsEvent.created(goalId: goal.id, kind: category)
                                )
                            await send(.delegate(.navigateBack))
                        } catch {
                            await send(.response(.createGoalFailed))
                        }
                    }

                case .edit:
                    state.submitMessage = "수정 중..."
                    guard let goalId = state.goalData.goalId else {
                        state.isLoading = false
                        state.submitMessage = nil
                        return .send(.presentation(.showToast(.warning(message: "목표 수정에 실패했어요"))))
                    }
                    let request = GoalUpdateRequestDTO(
                        goalName: state.goalData.title,
                        icon: state.goalData.icon.rawValue,
                        repeatCycle: state.goalData.repeatCycle.rawValue,
                        repeatCount: state.periodCount,
                        endDate: endDateString
                    )
                    return .run { [goalId] send in
                        do {
                            _ = try await goalClient.updateGoal(goalId, request)
                            await send(.delegate(.navigateBack))
                        } catch {
                            await send(.response(.updateGoalFailed))
                        }
                    }
                }
                
            case .view(.navigationBackButtonTapped):
                return .send(.delegate(.navigateBack))

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
