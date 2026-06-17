# Reducer 패턴

> Interface/Implementation 분리 + 중첩 State/Action 구조에 대한 가이드

---

## 개요

Feature Reducer가 커져서 State/Action의 의미가 흐려질 때는 다음 원칙을 우선합니다.
작은 단일 목적 Reducer는 기존 플랫 구조를 유지할 수 있습니다.

1. **Interface/Implementation 분리** — `*Interface` 모듈에 State/Action 셸, `Sources` 모듈에 실제 Reduce 로직
2. **중첩 Action enum** — 규모가 큰 Action은 `View` / `Internal` / `Response` / `Presentation` / `Delegate` 로 분리
3. **중첩 State struct** — 상태 규모에 따라 `Data` / `UIState` / `Presentation` 분리를 검토
4. **Reducer 분기 분리** — Reduce 클로저 내 큰 분기를 `reduceView`, `reduceInternal` 등 helper 함수/메서드로 위임

---

## Action 구조

```swift
public enum Action: BindableAction {
    case binding(BindingAction<State>)

    /// 사용자 이벤트. ~Tapped, ~Changed, ~Selected 네이밍.
    /// SwiftUI에서 직접 전송하는 onAppear/onDisappear 같은 lifecycle도 여기에 둡니다.
    public enum View: Equatable {
        case backButtonTapped
        case submitButtonTapped
        case onAppear          // lifecycle — SwiftUI가 직접 트리거
    }

    /// Reducer 내부에서 발행하는 Effect 트리거.
    /// API 호출 시작, 상태 계산, View 이벤트 이후의 후속 작업 등.
    public enum Internal: Equatable {
        case fetchItems
        case updateCache([Item])
    }

    /// 비동기 응답. Result<T, Error> 포함 시 Equatable 불필요.
    public enum Response {
        case fetchItemsResponse(Result<[Item], Error>)
        case deleteItemResponse(Result<Void, Error>)
    }

    /// 토스트·모달 표시.
    public enum Presentation: Equatable {
        case showToast(TXToastType)
    }

    /// 부모 Reducer에게 알림. 항상 Equatable.
    public enum Delegate: Equatable {
        case navigateBack
        case itemSelected(Item)
    }

    case view(View)
    case `internal`(Internal)
    case response(Response)
    case presentation(Presentation)
    case delegate(Delegate)
}
```

### 규칙 요약

| enum | Equatable | 내용 |
|------|-----------|------|
| `View` | ✅ | 사용자 탭·입력·lifecycle |
| `Internal` | ✅ | Reducer 내부 Effect 트리거 |
| `Response` | ❌ (Error 포함 시) | 비동기 결과 |
| `Presentation` | ✅ | 토스트, 모달 |
| `Delegate` | ✅ | 부모에게 전달하는 이벤트 |

---

## State 구조

### 분리 기준

**플랫 State 유지** (인스턴스 프로퍼티 5개 이하):
- 단일 목적의 작은 화면 (OnboardingProfile, Auth 등)
- Presentation 레이어 없음 (modal/toast 없음)

**Data/UIState/Presentation 분리 권장** (인스턴스 프로퍼티 6개 이상):
- 여러 섹션을 가진 복잡한 화면
- modal·toast 같은 Presentation 상태가 도메인 데이터와 섞이는 경우

> `static let` 상수는 인스턴스 프로퍼티가 아니므로 개수 계산에서 제외합니다.

---

### Constants 위치

**`static let` 상수는 `State` 최상위에 선언하는 것을 권장합니다.** `Data` / `UIState` / `Presentation` 서브구조체 안에 두지 않습니다.
인스턴스 `let`(상수처럼 보이지만 사실 모든 State 인스턴스에 복사되는 프로퍼티)은 피합니다.

```swift
public struct State: Equatable {
    // ✅ 타입 상수 — State 최상위
    public static let maxLength = 8
    public static let icons: [GoalIcon] = GoalIcon.allCases

    // ❌ 인스턴스 상수 — 금지 (모든 State 인스턴스마다 복사됨)
    // public let maxLength = 8

    public struct Data: Equatable { ... }
    public struct UIState: Equatable { ... }
    public struct Presentation: Equatable { ... }
    ...
}
```

---

### 서브구조체 선택적 적용

세 구조체 중 해당하는 카테고리가 없으면 만들지 않습니다.

```swift
// Presentation(modal/toast)이 없는 경우 — Presentation 생략
public struct State: Equatable {
    public struct Data: Equatable { ... }
    public struct UIState: Equatable { ... }
    public var data: Data
    public var ui: UIState
}
```

---

규모가 충분하면 아래 패턴으로 분리합니다.

```swift
@ObservableState
public struct State: Equatable {

    /// 도메인 데이터
    public struct Data: Equatable {
        public var items: [Item] = []
        public var selectedItemId: Int64?
    }

    /// UI 플래그 및 로딩 상태
    public struct UIState: Equatable {
        public var isLoading: Bool = false
        public var isEditing: Bool = false
    }

    /// 토스트, 모달, 시트 표시 여부
    public struct Presentation: Equatable {
        public var toast: TXToastType?
        public var modal: TXModalStyle?
    }

    public var data: Data
    public var ui: UIState
    public var presentation: Presentation

    // 서브구조체를 넘나드는 computed property는 최상위에 둡니다
    public var isReady: Bool { !ui.isLoading && !data.items.isEmpty }

    public init() {
        self.data = Data()
        self.ui = UIState()
        self.presentation = Presentation()
    }
}
```

### `Swift.Data` 충돌 주의

`State` 안에 `Data` struct를 정의하면 Swift 표준 `Data` 타입과 이름이 충돌합니다.
`Data` 타입을 사용하는 프로퍼티는 `Swift.Data`로 명시합니다.

```swift
public var imageData: Swift.Data?
```

---

## Interface 셸

`*Interface` 모듈에는 State/Action 정의와 셸 init만 둡니다.
실제 Reduce 로직은 포함하지 않습니다.

```swift
// FeatureXxxInterface/Sources/XxxReducer.swift
@Reducer
public struct XxxReducer {
    private let reducer: Reduce<State, Action>

    @ObservableState
    public struct State: Equatable { ... }

    public enum Action: BindableAction { ... }

    public init(reducer: Reduce<State, Action>) {
        self.reducer = reducer
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        reducer
        // ifLet 등 child reducer 연결은 여기에
    }
}
```

---

## Implementation

`Sources` 모듈의 `extension` 파일에서 실제 Reduce를 구성합니다.

```swift
// FeatureXxx/Sources/XxxReducer+Impl.swift
extension XxxReducer {
    public init() {
        let reducer = Reduce<XxxReducer.State, XxxReducer.Action> { state, action in
            switch action {
            case .view(let viewAction):
                return reduceView(state: &state, action: viewAction)

            case .internal(let internalAction):
                return reduceInternal(state: &state, action: internalAction)

            case .response(let responseAction):
                return reduceResponse(state: &state, action: responseAction)

            case .presentation(let presentationAction):
                return reducePresentation(state: &state, action: presentationAction)

            case .binding:
                return .none

            case .delegate:
                return .none
            }
        }
        self.init(reducer: reducer)
    }
}

// MARK: - View

private func reduceView(
    state: inout XxxReducer.State,
    action: XxxReducer.Action.View
) -> Effect<XxxReducer.Action> {
    switch action {
    case .backButtonTapped:
        return .send(.delegate(.navigateBack))
    case .onAppear:
        return .send(.internal(.fetchItems))
    }
}

// MARK: - Internal

private func reduceInternal(
    state: inout XxxReducer.State,
    action: XxxReducer.Action.Internal
) -> Effect<XxxReducer.Action> {
    switch action {
    case .fetchItems:
        @Dependency(\.xxxClient) var client
        return .run { send in
            do {
                let items = try await client.fetchItems()
                await send(.response(.fetchItemsResponse(.success(items))))
            } catch {
                await send(.response(.fetchItemsResponse(.failure(error))))
            }
        }
    }
}

// MARK: - Response

private func reduceResponse(
    state: inout XxxReducer.State,
    action: XxxReducer.Action.Response
) -> Effect<XxxReducer.Action> {
    switch action {
    case .fetchItemsResponse(.success(let items)):
        state.data.items = items
        state.ui.isLoading = false
        return .none

    case .fetchItemsResponse(.failure):
        state.ui.isLoading = false
        return .send(.presentation(.showToast(.warning(message: "불러오기 실패"))))
    }
}

// MARK: - Presentation

private func reducePresentation(
    state: inout XxxReducer.State,
    action: XxxReducer.Action.Presentation
) -> Effect<XxxReducer.Action> {
    switch action {
    case .showToast(let toast):
        state.presentation.toast = toast
        return .none
    }
}
```

### `@Dependency` 위치

- **지연 해석 방식**: 자유 함수 reducer에서는 `@Dependency`를 필요한 `case` 핸들러 내부에 선언할 수 있습니다.
  `init` 시점이 아니라 실행 시점에 DI Container에서 꺼내므로, 테스트에서 재정의가 가능합니다.
- 구조체 reducer가 이미 `@Dependency` 프로퍼티를 보유한 경우에는 최신 구현을 우선 보존하고, 네임스페이스 이동만을 위해 의존성 주입 방식을 바꾸지 않습니다.

```swift
case .logoutTapped:
    @Dependency(\.authClient) var authClient  // ← 핸들러 내부 선언
    return .run { send in
        try await authClient.signOut()
        ...
    }
```

---

## 예외 1: Coordinator Reducer

`HomeCoordinator`, `StatsCoordinator` 등 네비게이션을 담당하는 Coordinator는 State 분리 패턴을 적용하지 않습니다.

**이유:**
- State가 자식 Reducer의 State(`home: HomeReducer.State`, `stats: StatsReducer.State`)와 라우트 배열로 구성됨
- 도메인 데이터·UI 플래그가 아니라 화면 조합이 목적이므로 Data/UIState/Presentation 구분이 부자연스러움
- `scope` 키패스가 바뀌면 자식 연결 코드 전체가 영향을 받음

**Action 중첩 패턴은 동일하게 적용합니다.** (View/Delegate 등)

---

## 예외 2: 자체 구현 Reducer (Auth / MainTab / Onboarding)

Auth / MainTab / Onboarding은 Interface 분리 없이 `Sources`에 구현이 모두 있습니다.
동일한 Action 중첩 패턴을 적용하되, `init(reducer:)` 셸 없이 `body` 내 `Reduce { }` 직접 작성도 허용합니다.
State 분리는 일반 기준(인스턴스 프로퍼티 6개 이상)을 따릅니다.

---

## View에서의 액션 디스패치

```swift
// View 이벤트
store.send(.view(.backButtonTapped))
store.send(.view(.onAppear))

// Reducer 내부 후속 작업
return .send(.internal(.fetchItems))
```

SwiftUI가 직접 보내는 lifecycle 이벤트(`onAppear`, `onDisappear`)는 `Action.View`에 둡니다.
Reducer가 View 이벤트를 받은 뒤 스스로 발행하는 API 호출 시작, 캐시 갱신, 계산 트리거는 `Action.Internal`에 둡니다.

---

**작성일**: 2026-04-14
