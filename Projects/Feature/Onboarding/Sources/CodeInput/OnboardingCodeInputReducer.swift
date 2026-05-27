//
//  OnboardingCodeInputReducer.swift
//  FeatureOnboarding
//
//  Created by Jiyong on 01/28/26.
//

import ComposableArchitecture
import DomainOnboardingInterface
import Foundation
import SharedDesignSystem
import UIKit

/// 커플 연결 초대 코드 입력 화면을 관리하는 Reducer입니다.
///
/// 8자리 초대 코드를 입력받아 커플 연결을 완료합니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: OnboardingCodeInputReducer.State(myInviteCode: "KDJ34923"),
///     reducer: { OnboardingCodeInputReducer() }
/// )
/// ```
@Reducer
public struct OnboardingCodeInputReducer {
    @Dependency(\.onboardingClient)
    private var onboardingClient

    @ObservableState
    public struct State: Equatable {
        var myInviteCode: String
        var receivedCode: String = ""
        var focusedIndex: Int?
        var toast: TXToastType?
        var isLoading: Bool = false

        static let codeLength = 8

        public init(
            myInviteCode: String = "",
            receivedCode: String = ""
        ) {
            self.myInviteCode = myInviteCode
            let filtered = receivedCode.filter { $0.isNumber || $0.isLetter }
            self.receivedCode = String(filtered.prefix(Self.codeLength)).uppercased()
        }
    }

    public enum Action: BindableAction {
        // MARK: - Binding
        case binding(BindingAction<State>)

        // MARK: - View (사용자 이벤트)
        public enum View: Equatable {
            case backButtonTapped
            case codeInputChanged(String)
            case copyMyCodeButtonTapped
            case pasteCodeButtonTapped
            case completeButtonTapped
            case codeFieldTapped
        }

        // MARK: - Response (비동기 응답)
        public enum Response {
            case connectCoupleResponse(Result<Void, Error>)
        }

        // MARK: - Delegate (부모에게 알림)
        public enum Delegate: Equatable {
            case navigateBack
            case coupleConnected
        }

        case view(View)
        case response(Response)
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

            case .response(let responseAction):
                return reduceResponse(state: &state, action: responseAction)

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - View

private extension OnboardingCodeInputReducer {
    func reduceView(
        state: inout State,
        action: Action.View
    ) -> Effect<Action> {
        switch action {
        case .backButtonTapped:
            return .send(.delegate(.navigateBack))

        case let .codeInputChanged(newCode):
            let filtered = newCode.filter { $0.isNumber || $0.isLetter }
            let uppercased = String(filtered.prefix(State.codeLength)).uppercased()
            state.receivedCode = uppercased

            if uppercased.count < State.codeLength {
                state.focusedIndex = uppercased.count
            } else {
                state.focusedIndex = nil
            }
            return .none

        case .copyMyCodeButtonTapped:
            UIPasteboard.general.string = state.myInviteCode
            state.toast = .check(message: "초대 코드가 복사되었어요")
            return .none

        case .pasteCodeButtonTapped:
            guard let pastedString = UIPasteboard.general.string else { return .none }
            let filtered = pastedString.filter { $0.isNumber || $0.isLetter }
            let uppercased = String(filtered.prefix(State.codeLength)).uppercased()
            state.receivedCode = uppercased
            if uppercased.count < State.codeLength {
                state.focusedIndex = uppercased.count
            } else {
                state.focusedIndex = nil
            }
            return .none

        case .completeButtonTapped:
            guard state.isCodeComplete, !state.isLoading else { return .none }
            state.isLoading = true
            let inviteCode = state.receivedCode
            return .run { send in
                do {
                    try await onboardingClient.connectCouple(inviteCode)
                    await send(.response(.connectCoupleResponse(.success(()))))
                } catch {
                    await send(.response(.connectCoupleResponse(.failure(error))))
                }
            }

        case .codeFieldTapped:
            state.focusedIndex = min(state.receivedCode.count, State.codeLength - 1)
            return .none
        }
    }
}

// MARK: - Response

private extension OnboardingCodeInputReducer {
    func reduceResponse(
        state: inout State,
        action: Action.Response
    ) -> Effect<Action> {
        switch action {
        case .connectCoupleResponse(.success):
            state.isLoading = false
            return .send(.delegate(.coupleConnected))

        case let .connectCoupleResponse(.failure(error)):
            state.isLoading = false
            if let onboardingError = error as? OnboardingError {
                switch onboardingError {
                case .inviteCodeNotFound:
                    state.toast = .fit(message: "초대 코드를 찾을 수 없어요")

                default:
                    state.toast = .fit(message: "연결에 실패했어요. 다시 시도해주세요")
                }
            } else {
                state.toast = .fit(message: "연결에 실패했어요. 다시 시도해주세요")
            }
            return .none
        }
    }
}

// MARK: - Computed Properties

extension OnboardingCodeInputReducer.State {
    var isCodeComplete: Bool {
        receivedCode.count == Self.codeLength
    }

    var codeCharacters: [Character?] {
        let chars = Array(receivedCode)
        return (0..<Self.codeLength).map { index in
            index < chars.count ? chars[index] : nil
        }
    }
}
