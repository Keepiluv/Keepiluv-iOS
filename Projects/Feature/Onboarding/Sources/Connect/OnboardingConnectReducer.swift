//
//  OnboardingConnectReducer.swift
//  FeatureOnboarding
//
//  Created by Jiyong on 01/28/26.
//

import ComposableArchitecture
import DomainOnboardingInterface
import Foundation

/// 커플 연결 온보딩 화면을 관리하는 Reducer입니다.
///
/// 짝꿍 초대장 보내기(Share Sheet) 및 직접 연결하기 기능을 제공합니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: OnboardingConnectReducer.State(),
///     reducer: { OnboardingConnectReducer() }
/// )
/// ```
@Reducer
public struct OnboardingConnectReducer {
    @Dependency(\.onboardingClient)
    private var onboardingClient

    @ObservableState
    public struct State: Equatable {
        var isShareSheetPresented: Bool = false
        var isRestoreCoupleSheetPresented: Bool = false
        var shareContent: String
        var myInviteCode: String

        public init(shareContent: String = "", myInviteCode: String = "") {
            self.shareContent = shareContent
            self.myInviteCode = myInviteCode
        }
    }

    public enum Action: BindableAction {
        // MARK: - Binding
        case binding(BindingAction<State>)

        // MARK: - View (사용자 이벤트)
        public enum View: Equatable {
            case directConnectCardTapped
            case sendInvitationButtonTapped
            case logoutButtonTapped
            case restoreCoupleButtonTapped
            case shareSheetDismissed
            case restoreCoupleSheetDismissed
        }

        // MARK: - Delegate (부모에게 알림)
        public enum Delegate: Equatable {
            case navigateToCodeInput
            case logoutRequested
        }

        case view(View)
        case delegate(Delegate)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .view(let viewAction):
                return reduceView(state: &state, action: viewAction)

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - View

private extension OnboardingConnectReducer {
    func reduceView(
        state: inout State,
        action: Action.View
    ) -> Effect<Action> {
        switch action {
        case .directConnectCardTapped:
            return .send(.delegate(.navigateToCodeInput))

        case .sendInvitationButtonTapped:
            state.isShareSheetPresented = true
            return .none

        case .logoutButtonTapped:
            return .send(.delegate(.logoutRequested))

        case .restoreCoupleButtonTapped:
            state.isRestoreCoupleSheetPresented = true
            return .none

        case .shareSheetDismissed:
            state.isShareSheetPresented = false
            return .none

        case .restoreCoupleSheetDismissed:
            state.isRestoreCoupleSheetPresented = false
            return .none
        }
    }
}
