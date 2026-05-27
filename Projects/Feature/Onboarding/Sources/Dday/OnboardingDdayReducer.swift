//
//  OnboardingDdayReducer.swift
//  FeatureOnboarding
//
//  Created by Jiyong on 01/29/26.
//

import ComposableArchitecture
import DomainOnboardingInterface
import Foundation
import SharedDesignSystem

/// 기념일 등록 화면을 관리하는 Reducer입니다.
///
/// 커플의 기념일(D-day)을 선택하여 등록합니다.
///
/// ## 사용 예시
/// ```swift
/// let store = Store(
///     initialState: OnboardingDdayReducer.State(),
///     reducer: { OnboardingDdayReducer() }
/// )
/// ```
@Reducer
public struct OnboardingDdayReducer {
    @Dependency(\.onboardingClient)
    private var onboardingClient
    @Dependency(\.continuousClock)
    private var clock

    public enum CancelID: Hashable {
        case polling
    }

    @ObservableState
    public struct State: Equatable {
        var selectedDate: TXCalendarDate
        var showCalendarSheet: Bool = false
        var isLoading: Bool = false
        var toast: TXToastType?
        var modal: TXModalStyle?

        public init() {
            self.selectedDate = TXCalendarDate()
        }
    }

    public enum Action: BindableAction {
        // MARK: - Binding
        case binding(BindingAction<State>)

        // MARK: - View
        public enum View: Equatable {
            case onAppear
            case backButtonTapped
            case dateSelectorTapped
            case completeButtonTapped
            case modalConfirmTapped
            case calendarCompleted
        }

        // MARK: - Internal
        public enum Internal: Equatable {
            case calendarCompleted
            case pollingTick
        }

        // MARK: - Response
        public enum Response {
            case setAnniversaryResponse(Result<Void, Error>)
            case pollingResult(Result<OnboardingStatus, Error>)
        }

        // MARK: - Delegate
        public enum Delegate: Equatable {
            case navigateBack
            case ddayCompleted
        }

        case view(View)
        case `internal`(Internal)
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

            case .internal(let internalAction):
                return reduceInternal(state: &state, action: internalAction)

            case .response(let responseAction):
                return reduceResponse(state: &state, action: responseAction)

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - View

private extension OnboardingDdayReducer {
    func reduceView(
        state: inout State,
        action: Action.View
    ) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .run { [clock] send in
                for await _ in clock.timer(interval: .seconds(3)) {
                    await send(.internal(.pollingTick))
                }
            }
            .cancellable(id: CancelID.polling, cancelInFlight: true)

        case .backButtonTapped:
            return .send(.delegate(.navigateBack))

        case .dateSelectorTapped:
            state.showCalendarSheet = true
            return .none

        case .completeButtonTapped:
            guard let date = state.selectedDate.date, !state.isLoading else { return .none }
            state.isLoading = true
            return .merge(
                .cancel(id: CancelID.polling),
                .run { send in
                    do {
                        try await onboardingClient.setAnniversary(date)
                        await send(.response(.setAnniversaryResponse(.success(()))))
                    } catch {
                        await send(.response(.setAnniversaryResponse(.failure(error))))
                    }
                }
            )

        case .modalConfirmTapped:
            state.modal = nil
            return .send(.delegate(.ddayCompleted))

        case .calendarCompleted:
            return .send(.internal(.calendarCompleted))
        }
    }
}

// MARK: - Internal

private extension OnboardingDdayReducer {
    func reduceInternal(
        state: inout State,
        action: Action.Internal
    ) -> Effect<Action> {
        switch action {
        case .calendarCompleted:
            state.showCalendarSheet = false
            return .none

        case .pollingTick:
            return .run { [onboardingClient] send in
                do {
                    let status = try await onboardingClient.fetchStatus()
                    await send(.response(.pollingResult(.success(status))))
                } catch {
                    await send(.response(.pollingResult(.failure(error))))
                }
            }
        }
    }
}

// MARK: - Response

private extension OnboardingDdayReducer {
    func reduceResponse(
        state: inout State,
        action: Action.Response
    ) -> Effect<Action> {
        switch action {
        case .setAnniversaryResponse(.success):
            state.isLoading = false
            return .send(.delegate(.ddayCompleted))

        case let .setAnniversaryResponse(.failure(error)):
            state.isLoading = false
            if let onboardingError = error as? OnboardingError,
               onboardingError == .alreadyOnboarded {
                state.modal = .info(
                    image: .Icon.Illustration.heart,
                    title: "메이트가 기념일을 등록했어요!",
                    subtitle: "이미 우리의 기념일이 저장됐어요.\n이제 함께 시작해봐요 :)",
                    leftButtonText: "확인",
                    rightButtonText: "시작하기"
                )
                return .cancel(id: CancelID.polling)
            }
            state.toast = .fit(message: "기념일 등록에 실패했어요. 다시 시도해주세요")
            return .none

        case let .pollingResult(.success(status)):
            guard status == .completed else { return .none }
            state.modal = .info(
                image: .Icon.Illustration.heart,
                title: "메이트가 기념일을 등록했어요!",
                subtitle: "이미 우리의 기념일이 저장됐어요.\n이제 함께 시작해봐요 :)",
                leftButtonText: "확인",
                rightButtonText: "시작하기"
            )
            return .cancel(id: CancelID.polling)

        case .pollingResult(.failure):
            return .none
        }
    }
}

// MARK: - Computed Properties

extension OnboardingDdayReducer.State {
    /// 날짜가 선택되었는지 여부
    var isDateSelected: Bool {
        selectedDate.day != nil
    }

    /// 포맷된 날짜 문자열 (YYYY-MM-DD)
    var formattedDate: String? {
        guard let day = selectedDate.day else { return nil }
        return String(format: "%d-%02d-%02d", selectedDate.year, selectedDate.month, day)
    }
}
