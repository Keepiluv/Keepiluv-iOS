//
//  HomeReducer+Impl.swift
//  FeatureHome
//
//  Created by 정지훈 on 1/26/26.
//

import Foundation
import SwiftUI

import ComposableArchitecture
import CoreAnalyticsInterface
import CoreCaptureSessionInterface
import DomainGoalInterface
import DomainNotificationInterface
import DomainPhotoLogInterface
import FeatureHomeInterface
import FeatureProofPhotoInterface
import SharedDesignSystem
import SharedUtil

// MARK: - Cancel IDs

private enum PokeCancelID: Hashable {
    case poke(Int64)
}

// MARK: - Poke Cooldown Manager

private enum PokeCooldownManager {
    private static let userDefaultsKey = "pokeCooldownTimestamps"
    private static let cooldownInterval: TimeInterval = 3 * 60 * 60 // 3시간

    /// 찌르기 쿨다운 남은 시간을 반환합니다.
    /// - Parameter goalId: 목표 ID
    /// - Returns: 남은 시간(초). 쿨다운이 끝났으면 nil
    static func remainingCooldown(goalId: Int64) -> TimeInterval? {
        guard let timestamps = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: TimeInterval],
              let lastPokeTime = timestamps[String(goalId)] else {
            return nil
        }
        let elapsed = Date().timeIntervalSince1970 - lastPokeTime
        let remaining = cooldownInterval - elapsed
        return remaining > 0 ? remaining : nil
    }

    /// 남은 시간을 포맷팅합니다.
    /// - Parameter seconds: 남은 시간(초)
    /// - Returns: "2시간 20분", "1시간", "28분" 형태의 문자열
    static func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(ceil(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)시간 \(minutes)분"
        } else if hours > 0 {
            return "\(hours)시간"
        } else {
            return "\(max(1, minutes))분"
        }
    }

    /// 찌르기 시간을 기록합니다.
    /// - Parameter goalId: 목표 ID
    static func recordPoke(goalId: Int64) {
        var timestamps = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: TimeInterval] ?? [:]
        timestamps[String(goalId)] = Date().timeIntervalSince1970
        UserDefaults.standard.set(timestamps, forKey: userDefaultsKey)
    }

    /// 찌르기 기록을 제거합니다. API 실패 시 쿨다운을 롤백합니다.
    /// - Parameter goalId: 목표 ID
    static func removePoke(goalId: Int64) {
        var timestamps = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: TimeInterval] ?? [:]
        timestamps.removeValue(forKey: String(goalId))
        UserDefaults.standard.set(timestamps, forKey: userDefaultsKey)
    }
}

extension HomeReducer {
    /// 실제 로직을 포함한 HomeReducer를 생성합니다.
    /// 
    /// ## 사용 예시
    /// ```swift
    /// let reducer = HomeReducer()
    /// ```
    
    // swiftlint:disable:next function_body_length
    public init(
        proofPhotoReducer: ProofPhotoReducer
    ) {
        @Dependency(\.goalClient) var goalClient
        @Dependency(\.captureSessionClient) var captureSessionClient
        @Dependency(\.photoLogClient) var photoLogClient
        @Dependency(\.notificationClient) var notificationClient
        @Dependency(\.analyticsClient) var analyticsClient
        
        // swiftlint:disable:next closure_body_length
        let reducer = Reduce<State, Action> { state, action in
            
            switch action {
                // MARK: - Life Cycle
            case .onAppear:
                if state.calendarDate.day == nil {
                    let now = state.nowDate
                    let date = TXCalendarDate(
                        year: now.year,
                        month: now.month,
                        day: now.day
                    )
                    return .send(.setCalendarDate(date))
                }
                state.isLoading = true
                return .send(.fetchGoals)
                
                // MARK: - User Action
            case let .calendarDateSelected(item):
                guard let components = item.dateComponents,
                      let year = components.year,
                      let month = components.month,
                      let day = components.day else {
                    return .none
                }
                return .send(.setCalendarDate(TXCalendarDate(year: year, month: month, day: day)))
                
            case let .setCalendarSheetPresented(isPresented):
                state.isCalendarSheetPresented = isPresented
                if isPresented {
                    state.calendarSheetDate = state.calendarDate
                }
                return .none
                
            case let .navigationBarAction(action):
                switch action {
                case .refreshTapped:
                    let now = state.nowDate
                    let date = TXCalendarDate(
                        year: now.year,
                        month: now.month,
                        day: now.day
                    )
                    if date == state.calendarDate {
                        state.isLoading = true
                        return .send(.fetchGoals)
                    }
                    return .send(.setCalendarDate(date))
                    
                case .subTitleTapped:
                    return .send(.setCalendarSheetPresented(true))
                    
                case .alertTapped:
                    return .send(.delegate(.goToNotification))
                    
                case .settingTapped:
                    return .send(.delegate(.goToSettings))
                    
                case .backTapped,
                        .rightTapped,
                        .closeTapped:
                    return .none
                }
                
            case .monthCalendarConfirmTapped:
                state.isCalendarSheetPresented = false
                return .send(.setCalendarDate(state.calendarSheetDate))
                
            case let .goalCheckButtonTapped(id, isChecked):
                guard let item = state.items.first(where: { $0.id == id }) else {
                    return .none
                }
                
                if isChecked {
                    guard let photologId = item.card.myCard.photologId
                    else { return .none }
                    
                    state.pendingDeleteGoalID = id
                    state.pendingDeletePhotologID = photologId
                    state.modal = .info(
                        image: .Icon.Illustration.modalWarning,
                        title: "체크를 해제할까요?",
                        subtitle: "해제하면 등록한 사진은 사라집니다.",
                        leftButtonText: "취소",
                        rightButtonText: "해제"
                    )
                } else {
                    let now = state.nowDate
                    let today = TXCalendarDate(
                        year: now.year,
                        month: now.month,
                        day: now.day
                    )
                    if state.calendarDate > today {
                        state.toast = .warning(message: "미래의 인증샷은 지금 올릴 수 없어요!")
                        return .none
                    } else if case .completed = item.goal.status {
                        state.toast = .warning(message: "끝난 목표는 인증이 불가능해요!")
                    } else {
                        return .run { send in
                            let isAuthorized = await captureSessionClient.fetchIsAuthorized()
                            await send(.authorizationCompleted(id: id, isAuthorized: isAuthorized))
                        }
                    }
                }
                
                return .none
                
            case .modalConfirmTapped:
                guard let pendingGoalID = state.pendingDeleteGoalID,
                      let pendingPhotologID = state.pendingDeletePhotologID else {
                    return .none
                }
                state.pendingDeleteGoalID = nil
                state.pendingDeletePhotologID = nil
                return .run { send in
                    do {
                        try await photoLogClient.deletePhotoLog(pendingPhotologID)
                        await send(.deletePhotoLogCompleted(goalId: pendingGoalID))
                    } catch {
                        await send(.deletePhotoLogFailed)
                    }
                }
                
            case let .yourCardTapped(card):
                if !card.yourCard.isSelected {
                    if let item = state.items.first(where: { $0.id == card.id }),
                       case .completed = item.goal.status {
                        return .send(.showToast(.warning(message: "끝난 목표는 인증이 불가능해요!")))
                    }
                    // 쿨다운 확인 (3시간 이내 재요청 방지)
                    if let remaining = PokeCooldownManager.remainingCooldown(goalId: card.id) {
                        let timeText = PokeCooldownManager.formatRemainingTime(remaining)
                        return .send(.showToast(.warning(message: "\(timeText) 뒤에 다시 찌를 수 있어요")))
                    }
                    // 상대방 미인증 시 찌르기 API 호출
                    let goalId = card.id
                    let pokeDate = state.calendarDate
                    return .run { send in
                        PokeCooldownManager.recordPoke(goalId: goalId)
                        do {
                            try await goalClient.pokePartner(goalId)
                            await send(.setPokeButtonDisabled(goalId: goalId, true, date: pokeDate))
                            await send(.showToast(.poke(message: "상대방을 찔렀어요!")))
                        } catch {
                            PokeCooldownManager.removePoke(goalId: goalId)
                            await send(.setPokeButtonDisabled(goalId: goalId, false, date: pokeDate))
                            await send(.showToast(.warning(message: "찌르기에 실패했어요")))
                        }
                    }
                    .debounce(id: PokeCancelID.poke(goalId), for: .milliseconds(300), scheduler: DispatchQueue.main)
                } else {
                    let verificationDate = TXCalendarUtil.apiDateString(for: state.calendarDate)
                    return .send(
                        .delegate(
                            .goToGoalDetail(
                                id: card.id,
                                owner: .you,
                                verificationDate: verificationDate
                            )
                        )
                    )
                }
                
            case let .myCardTapped(card):
                let verificationDate = TXCalendarUtil.apiDateString(for: state.calendarDate)
                return .send(.delegate(.goToGoalDetail(id: card.id, owner: .mySelf, verificationDate: verificationDate)))
                
            case let .headerTapped(card):
                return .send(.delegate(.goToStatsDetail(id: card.id)))
                
            case .floatingButtonTapped:
                state.isAddGoalPresented = true
                return .none
                
            case let .addGoalButtonTapped(category):
                state.isAddGoalPresented = false
                analyticsClient.logEvent(HomeAnalyticsEvent.selectGoalClicked(kind: category.rawValue))
                return .send(.delegate(.goToMakeGoal(category)))
                
            case .editButtonTapped:
                return .send(.delegate(.goToEditGoalList(date: state.calendarDate)))
                
            case let .weekCalendarSwipe(swipe):
                switch swipe {
                case .next:
                    guard let nextWeekDate = TXCalendarUtil.dateByAddingWeek(
                        from: state.calendarDate,
                        by: 1
                    ) else {
                        return .none
                    }
                    return .send(.setCalendarDate(nextWeekDate))
                    
                case .previous:
                    guard let previousWeekDate = TXCalendarUtil.dateByAddingWeek(
                        from: state.calendarDate,
                        by: -1
                    ) else {
                        return .none
                    }
                    return .send(.setCalendarDate(previousWeekDate))
                }
                
                // MARK: - Update State
            case let .fetchGoalsCompleted(goalList, date):
                let cacheKey = TXCalendarUtil.apiDateString(for: date)
                let items = goalList.goals
                    .map(HomeGoalItem.init(goal:))
                    .map { $0.applyingPokeCooldownState() }
                state.goalsCache[cacheKey] = items
                state.hadFirstGoal = goalList.hasEverRegisteredGoal
                
                if date != state.calendarDate {
                    return .none
                }
                
                state.isLoading = false
                
                if state.items != items {
                    state.items = items
                }
                return .none
                
            case .fetchGoalsFailed:
                state.isLoading = false
                return .send(.showToast(.warning(message: "목표 조회에 실패했어요")))
                
            case let .setCalendarDate(date):
                guard date != state.calendarDate else { return .none }

                let now = state.nowDate
                let today = TXCalendarDate(
                    year: now.year,
                    month: now.month,
                    day: now.day
                )
                let calendar = Calendar(identifier: .gregorian)
                
                state.calendarDate = date
                state.calendarMonthTitle = "\(date.month)월 \(date.year)"
                state.calendarWeeks = TXCalendarDataGenerator.generateWeekData(for: date)
                
                if let selectedDate = date.date,
                   let todayDate = today.date {
                    let isThisWeek = calendar.isDate(
                        selectedDate,
                        equalTo: todayDate,
                        toGranularity: .weekOfYear
                    )
                    state.isRefreshHidden = isThisWeek
                }
                
                state.isLoading = true
                return .send(.fetchGoals)
                
            case .fetchGoals:
                let date = state.calendarDate
                let cacheKey = TXCalendarUtil.apiDateString(for: date)
                if let cachedItems = state.goalsCache[cacheKey] {
                    let items = cachedItems.map { $0.applyingPokeCooldownState() }
                    state.items = items
                    state.goalsCache[cacheKey] = items
                    state.isLoading = false
                } else {
                    state.isLoading = true
                }
                return .run { send in
                    // 읽지 않은 알림 여부 체크
                    if let hasUnread = try? await notificationClient.fetchUnread() {
                        await send(.fetchUnreadResponse(hasUnread))
                    }
                    
                    do {
                        let goalList = try await goalClient.fetchGoals(cacheKey)
                        await send(.fetchGoalsCompleted(goalList, date: date))
                    } catch {
                        await send(.fetchGoalsFailed)
                    }
                }
                
            case let .showToast(toast):
                state.toast = toast
                return .none
                
            case let .setPokeButtonDisabled(goalId, isDisabled, date):
                if date == state.calendarDate {
                    updatePokeButtonDisabled(in: &state.items, goalId: goalId, isDisabled: isDisabled)
                }
                
                let cacheKey = TXCalendarUtil.apiDateString(for: date)
                guard var cachedItems = state.goalsCache[cacheKey] else { return .none }
                
                updatePokeButtonDisabled(in: &cachedItems, goalId: goalId, isDisabled: isDisabled)
                state.goalsCache[cacheKey] = cachedItems
                return .none
                
            case let .authorizationCompleted(id, isAuthorized):
                if !isAuthorized {
                    state.isCameraPermissionAlertPresented = true
                    return .none
                }
                state.proofPhoto = .init(
                    goalId: id,
                    verificationDate: TXCalendarUtil.apiDateString(for: state.calendarDate)
                )
                state.isProofPhotoPresented = true
                return .none
                
            case .cameraPermissionAlertDismissed:
                state.isCameraPermissionAlertPresented = false
                return .none
                
            case .proofPhoto(.delegate(.closeProofPhoto)):
                state.isProofPhotoPresented = false
                return .none
                
            case let .proofPhoto(.delegate(.completedUploadPhoto(myPhotoLog, _))):
                state.isProofPhotoPresented = false
                guard let goalId = state.proofPhoto?.goalId else { return .none }
                guard let index = state.items.firstIndex(where: { $0.id == goalId }) else { return .none }
                let goal = state.items[index].goal
                let updatedGoal = Goal(
                    id: goal.id,
                    goalIcon: goal.goalIcon,
                    title: goal.title,
                    myVerification: .init(
                        photologId: myPhotoLog.photologId,
                        isCompleted: true,
                        imageURL: myPhotoLog.imageUrl,
                        emoji: goal.myVerification?.emoji
                    ),
                    yourVerification: goal.yourVerification,
                    repeatCycle: goal.repeatCycle,
                    repeatCount: goal.repeatCount,
                    startDate: goal.startDate,
                    endDate: goal.endDate,
                    status: goal.status
                )
                state.items[index].updateGoal(updatedGoal)
                refreshPokeCooldownStates(state: &state)
                return .none
                
            case .proofPhotoDismissed:
                state.proofPhoto = nil
                return .none
                
            case .proofPhoto:
                return .none
                
            case let .deletePhotoLogCompleted(goalId):
                guard let index = state.items.firstIndex(where: { $0.id == goalId }) else {
                    return .none
                }
                let goal = state.items[index].goal
                let updatedGoal = Goal(
                    id: goal.id,
                    goalIcon: goal.goalIcon,
                    title: goal.title,
                    myVerification: .init(
                        photologId: nil,
                        isCompleted: false,
                        imageURL: nil,
                        emoji: goal.myVerification?.emoji
                    ),
                    yourVerification: goal.yourVerification,
                    repeatCycle: goal.repeatCycle,
                    repeatCount: goal.repeatCount,
                    startDate: goal.startDate,
                    endDate: goal.endDate,
                    status: goal.status
                )
                state.items[index].updateGoal(updatedGoal)
                refreshPokeCooldownStates(state: &state)
                return .send(.showToast(.delete(message: "인증이 해제되었어요")))
                
            case .deletePhotoLogFailed:
                return .send(.showToast(.warning(message: "해제에 실패했어요")))

            case let .fetchUnreadResponse(hasUnread):
                state.hasUnreadNotification = hasUnread
                return .none
                
            case .binding:
                return .none
                
            case .delegate:
                return .none
            }
        }
        
        self.init(
            reducer: reducer,
            proofPhotoReducer: proofPhotoReducer
        )
    }
}

private extension HomeGoalItem {
    func applyingPokeCooldownState() -> Self {
        var item = self
        item.card.yourCard.isButtonDisabled = !item.card.yourCard.isSelected
            && PokeCooldownManager.remainingCooldown(goalId: item.id) != nil
        return item
    }
}

private func refreshPokeCooldownStates(state: inout HomeReducer.State) {
    state.items = state.items.map { $0.applyingPokeCooldownState() }
    state.goalsCache[TXCalendarUtil.apiDateString(for: state.calendarDate)] = state.items
}

private func updatePokeButtonDisabled(
    in items: inout [HomeGoalItem],
    goalId: Int64,
    isDisabled: Bool
) {
    guard let index = items.firstIndex(where: { $0.id == goalId }) else { return }
    items[index].card.yourCard.isButtonDisabled = isDisabled
}
