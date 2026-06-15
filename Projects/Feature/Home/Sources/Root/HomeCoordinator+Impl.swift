//
//  HomeCoordinatorReducer+Impl.swift
//  FeatureHome
//
//  Created by 정지훈 on 1/27/26.
//

import ComposableArchitecture
import FeatureGoalDetailInterface
import FeatureHomeInterface
import FeatureNotificationInterface
import FeatureMakeGoalInterface
import FeatureProofPhotoInterface
import FeatureSettingsInterface
import FeatureStatsInterface

extension HomeCoordinator {
    // 기본 구성의 HomeCoordinator를 생성합니다.
    // swiftlint:disable:next function_body_length
    public init(
        goalDetailReducer: GoalDetailReducer,
        statsDetailReducer: StatsDetailReducer,
        proofPhotoReducer: ProofPhotoReducer,
        makeGoalReducer: MakeGoalReducer,
        editGoalListReducer: EditGoalListReducer,
        settingsReducer: SettingsReducer,
        notificationReducer: NotificationReducer
    ) {
        // swiftlint:disable:next closure_body_length
        let reducer = Reduce<State, Action> { state, action in
            switch action {
            case let .home(.delegate(.goToGoalDetail(id, owner, date))):
                return .send(
                    .navigateToGoalDetail(
                        id: id,
                        owner: owner,
                        date: date
                    )
                )
                
            case let .home(.delegate(.goToMakeGoal(category))):
                state.routes.append(.makeGoal)
                state.makeGoal = .init(mode: .add(category))
                return .none
                
            case let .home(.delegate(.goToEditGoalList(date))):
                state.routes.append(.editGoalList)
                state.editGoalList = .init(calendarDate: date)
                return .none
                
            case .home(.delegate(.goToSettings)):
                state.routes.append(.settings)
                state.settings = .init()
                return .none
                
            case .home(.delegate(.goToNotification)):
                state.routes.append(.notification)
                state.notification = .init()
                return .none
                
            case let .home(.delegate(.goToStatsDetail(id, date))):
                state.routes.append(.statsDetail)
                state.statsDetail = .init(goalId: id, initialMonth: date)
                return .none
                
            case .statsDetail(.delegate(.navigateBack)):
                popLastRoute(&state.routes)
                return .none
                
            case let .statsDetail(.delegate(.goToGoalEdit(goalData))):
                state.routes.append(.makeGoal)
                state.makeGoal = .init(mode: .edit(goalData))
                return .none
                
            case .statsDetail(.view(.onDisappear)):
                if !state.routes.contains(.statsDetail) {
                    state.statsDetail = nil
                }
                return .none
                
            case .statsDetail:
                return .none

            case .goalDetail(.delegate(.navigateBack)):
                popLastRoute(&state.routes)
                return .none
                
            case .goalDetail(.view(.onDisappear)):
                state.goalDetail = nil
                return .none
                
            case .makeGoal(.delegate(.navigateBack)):
                popLastRoute(&state.routes)
                return .none
                
            case .editGoalList(.view(.onDisappear)):
                if !state.routes.contains(.editGoalList) {
                    state.editGoalList = nil
                }
                return .none
                
            case .makeGoal(.view(.onDisappear)):
                state.makeGoal = nil
                return .none
                
            case .editGoalList(.delegate(.navigateBack)):
                popLastRoute(&state.routes)
                return .none

            case let .editGoalList(.delegate(.goToGoalEdit(goalData))):
                state.routes.append(.makeGoal)
                state.makeGoal = .init(mode: .edit(goalData))
                return .none

            case .editGoalList(.delegate(.goToCompletedStats)):
                popLastRoute(&state.routes)
                return .send(.delegate(.goToCompletedStats))
                
            case .home:
                return .none
                
            case .goalDetail:
                return .none
                
            case .makeGoal:
                return .none
                
            case .editGoalList:
                return .none
                
            case .settings(.delegate(.navigateBack)):
                popLastRoute(&state.routes)
                state.settings = nil
                return .none
                
            case .settings(.delegate(.navigateBackFromSubView)):
                popLastRoute(&state.routes)
                return .none
                
            case .settings(.delegate(.navigateToAccount)):
                state.routes.append(.settingsAccount)
                return .none
                
            case .settings(.delegate(.navigateToInfo)):
                state.routes.append(.settingsInfo)
                return .none
                
            case .settings(.delegate(.navigateToNotificationSettings)):
                state.routes.append(.settingsNotificationSettings)
                return .none
                
            case let .settings(.delegate(.navigateToWebView(url, title))):
                state.routes.append(.settingsWebView(url: url, title: title))
                return .none
                
            case .settings(.delegate(.logoutCompleted)):
                state.routes.removeAll()
                state.settings = nil
                return .send(.delegate(.logoutCompleted))
                
            case .settings(.delegate(.withdrawCompleted)):
                state.routes.removeAll()
                state.settings = nil
                return .send(.delegate(.withdrawCompleted))
                
            case .settings(.delegate(.sessionExpired)):
                state.routes.removeAll()
                state.settings = nil
                return .send(.delegate(.sessionExpired))
                
            case .settings:
                return .none
                
            case .notification(.delegate(.navigateBack)):
                popLastRoute(&state.routes)
                state.notification = nil
                return .none
                
            case let .notification(.delegate(.notificationSelected(item))):
                popLastRoute(&state.routes)
                state.notification = nil
                return .send(.delegate(.notificationItemTapped(item)))
                
            case .notification:
                return .none
                
            case let .navigateToGoalDetail(id, owner, date):
                let isAlreadyOnDetail = state.routes.last == .detail

                if !isAlreadyOnDetail {
                    state.routes.append(.detail)
                }

                state.goalDetail = .init(
                    currentUser: owner,
                    id: id,
                    verificationDate: date
                )
                return isAlreadyOnDetail
                    ? .send(.goalDetail(.view(.onAppear)))
                    : .none

            case .delegate:
                return .none

            case .binding:
                return .none
            }
        }
        
        self.init(
            reducer: reducer,
            homeReducer: HomeReducer(proofPhotoReducer: proofPhotoReducer),
            goalDetailReducer: goalDetailReducer,
            statsDetailReducer: statsDetailReducer,
            makeGoalReducer: makeGoalReducer,
            editGoalListReducer: editGoalListReducer,
            settingsReducer: settingsReducer,
            notificationReducer: notificationReducer
        )
    }
}

private func popLastRoute(_ routes: inout [HomeRoute]) {
    guard !routes.isEmpty else { return }
    routes.removeLast()
}
