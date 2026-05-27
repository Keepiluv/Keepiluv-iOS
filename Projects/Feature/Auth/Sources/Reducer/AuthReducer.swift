//
//  AuthReducer.swift
//  FeatureAuth
//
//  Created by Jiyong
//

import ComposableArchitecture
import CoreAnalyticsInterface
import CoreCrashlyticsInterface
import CoreLogging
import DomainAuthInterface
import Foundation

/// 사용자 인증 화면을 관리하는 Reducer입니다.
///
/// Apple, Kakao 등의 소셜 로그인 기능을 제공하며,
/// 로그인 상태와 에러 처리를 관리합니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: AuthReducer.State(),
///     reducer: { AuthReducer() }
/// )
/// ```
@Reducer
public struct AuthReducer {
    @Dependency(\.analyticsClient) var analyticsClient

    @ObservableState
    public struct State: Equatable {
        public var isLoading = false
        public var errorMessage: String?
        public var lastAuthResult: AuthResult?

        public init() {}
    }

    public enum Action {
        // MARK: - View
        public enum View {
            case onAppear
            case appleLoginButtonTapped
            case kakaoLoginButtonTapped
            case googleLoginButtonTapped
            case dismissError
        }

        // MARK: - Response
        public enum Response {
            case loginResponse(Result<AuthResult, Error>)
        }

        // MARK: - Delegate
        @CasePathable
        public enum Delegate {
            case loginSucceeded(AuthResult)
        }

        case view(View)
        case response(Response)
        case delegate(Delegate)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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

private extension AuthReducer {
    func reduceView(
        state: inout State,
        action: Action.View
    ) -> Effect<Action> {
        switch action {
        case .onAppear:
            analyticsClient.logEvent(AuthAnalyticsEvent.loginViewed)
            return .none

        case .appleLoginButtonTapped:
            return Self.handleLogin(provider: .apple, state: &state)

        case .kakaoLoginButtonTapped:
            return Self.handleLogin(provider: .kakao, state: &state)

        case .googleLoginButtonTapped:
            return Self.handleLogin(provider: .google, state: &state)

        case .dismissError:
            state.errorMessage = nil
            return .none
        }
    }
}

// MARK: - Response

private extension AuthReducer {
    func reduceResponse(
        state: inout State,
        action: Action.Response
    ) -> Effect<Action> {
        switch action {
        case .loginResponse(.success(let result)):
            return Self.handleLoginSuccess(state: &state, result: result)

        case .loginResponse(.failure(let error)):
            return Self.handleLoginFailure(state: &state, error: error)
        }
    }
}

// MARK: - Private Handlers

private extension AuthReducer {
    @Dependency(\.authClient)
    static var authClient

    @Dependency(\.crashlyticsClient)
    static var crashlytics

    @Dependency(\.authLogger)
    static var logger

    static func handleLogin(
        provider: AuthProvider,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.errorMessage = nil

        return .run { send in
            do {
                let authResult = try await authClient.signIn(provider)
                await send(.response(.loginResponse(.success(authResult))))
            } catch {
                await send(.response(.loginResponse(.failure(error))))
            }
        }
    }

    static func handleLoginSuccess(
        state: inout State,
        result: AuthResult
    ) -> Effect<Action> {
        state.isLoading = false
        state.lastAuthResult = result
        #if DEBUG
        logger.info("\(debugPayload(for: result))")
        #endif
        return .send(.delegate(.loginSucceeded(result)))
    }

    static func handleLoginFailure(
        state: inout State,
        error: Error
    ) -> Effect<Action> {
        state.isLoading = false

        // 사용자가 직접 취소한 경우 알림 표시하지 않음
        if case .userCanceled = error as? AuthLoginError {
            return .none
        }

        state.errorMessage = errorMessage(for: error)
        #if DEBUG
        logger.error("로그인 실패 - \(error.localizedDescription)")
        #else
        crashlytics.record(
            error,
            AuthCrashlyticsRecordEvent.loginFailed(error as? AuthLoginError)
        )
        #endif
        return .none
    }
}

// MARK: - Helper Functions

private func errorMessage(for error: Error) -> String {
    if let authError = error as? AuthLoginError {
        return authError.localizedDescription
    }
    return error.localizedDescription
}

private func debugPayload(for result: AuthResult) -> String {
    let userId = result.userId
    let isNewUser = result.isNewUser
    let accessToken = escapeForJSON(String(result.token.accessToken.prefix(20)))
    return "{\"userId\":\(userId),\"isNewUser\":\(isNewUser),\"accessToken\":\"\(accessToken)...\"}"
}

private func escapeForJSON(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
}

// MARK: - Dependencies

extension DependencyValues {
    var authLogger: TXLogger {
        get { self[AuthLoggerKey.self] }
        set { self[AuthLoggerKey.self] = newValue }
    }
}

private enum AuthLoggerKey: DependencyKey {
    static let liveValue: TXLogger = {
        return TXLogger(label: "Auth")
    }()
}
