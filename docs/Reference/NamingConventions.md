# 네이밍 규칙

> 일관된 코드 작성을 위한 네이밍 규칙

## Action 네이밍

### 사용자 액션: `<동사><대상>Tapped/Changed/Selected`

```swift
// 버튼 탭
case loginButtonTapped
case incrementButtonTapped
case submitButtonTapped

// 입력 변경
case usernameChanged(String)
case emailChanged(String)
case searchQueryChanged(String)

// 선택 변경
case itemSelected(Item)
case tabSelected(Int)
case optionSelected(Option)
```

### 시스템 응답: `<이름>Response`

```swift
// 네트워크 응답
case loginResponse(Result<User, Error>)
case postsResponse(Result<[Post], Error>)
case dataResponse(Result<Data, Error>)

// 성공만 필요한 경우
case loginSucceeded(User)
case dataLoaded([Item])
```

### Lifecycle: `on<이벤트>`

```swift
case onAppear
case onDisappear
case onForeground
case onBackground
```

---

## Action 주석 구분

Action이 많아지면 가독성을 위해 MARK 주석으로 구분합니다.

```swift
public enum Action: BindableAction {
    // MARK: - Binding
    case binding(BindingAction<State>)

    // MARK: - LifeCycle
    case onAppear

    // MARK: - User Action
    case backButtonTapped
    case submitButtonTapped
    case itemSelected(Item)

    // MARK: - Update State
    case fetchCompleted([Item])
    case toastDismissed

    // MARK: - Delegate
    case delegate(Delegate)

    // MARK: - Navigation (Coordinator에서 사용)
    case routeChanged([FeatureRoute])
}
```

### 주석 카테고리
- **Binding**: `BindingAction` 관련
- **LifeCycle**: `onAppear`, `onDisappear` 등
- **User Action**: 사용자 인터랙션 (`~Tapped`, `~Changed`, `~Selected`)
- **Update State**: 상태 업데이트 응답 (`~Completed`, `~Dismissed`)
- **Delegate**: 부모에게 전달하는 이벤트
- **Navigation**: Coordinator의 route/path 변경 액션 (필요시). 이 프로젝트는 `[Route]` 배열 기반 NavigationStack 패턴을 사용합니다.
- **Child Action**: 자식 Reducer 액션 (필요시)

### Delegate: `delegate(<결과>)`

```swift
case delegate(Delegate)

@CasePathable
enum Delegate {
    case loginSucceeded(User)
    case onboardingCompleted
    case itemSelected(Item)
}
```

### 타이머/스트림: `<이름>Tick/Updated`

```swift
case timerTick
case locationUpdated(Location)
case notificationReceived(Notification)
```

---

## File 네이밍

### Interface 모듈

Interface 모듈은 외부 소비자가 의존하는 public boundary입니다. 이전 `Source.swift` 예시는 public interface 타입을 Interface 모듈을 통해 노출한다는 의미였으며, 모든 public 타입을 하나의 파일에 강제한다는 의미가 아닙니다.

새로 만들거나 크게 수정하는 Interface 모듈은 One Type Per File을 우선합니다. 기존 `Interface/Sources/Source.swift` 파일은 legacy/compatibility 패턴으로 유지할 수 있습니다.

```
Interface/Sources/{Feature}Reducer.swift     # public Reducer / State / Action
Interface/Sources/{Feature}Factory.swift     # public ViewFactory 또는 factory
Interface/Sources/{Domain}Client.swift       # public TCA Client
Interface/Sources/{Feature}Route.swift       # public Route enum (필요 시)
Interface/Sources/Source.swift               # 기존 compatibility/re-export 파일 (필요 시)
```

### Sources 모듈

```
Sources/{Feature}Reducer.swift           # Reducer 구현 (extension)
Sources/{Feature}View.swift              # View 구현 (internal)
Sources/{Feature}Client.swift            # Client 구현
Sources/{Feature}ViewFactory+Live.swift  # ViewFactory 구현
Sources/{Feature}Proxy.swift             # 플랫폼별 래퍼 (예: AppleLoginProxy)
Sources/FeatureXXXLinker.swift           # Static library 링킹
```

### Example 모듈

```
Example/Sources/{Feature}App.swift       # 독립 실행 앱
```

### Testing 모듈

```
Testing/Sources/Mock{Feature}Client.swift  # Mock Client
Testing/Sources/{Feature}Fixtures.swift    # Test Fixtures
```

---

## 코드 스타일

메서드의 매개변수가 2개 이상일 때는 개행하여 가독성을 높입니다.

```swift
public func example(
    a: Int,
    b: Int
) -> ReturnType {
    // ...
}
```

---

## 변수/프로퍼티 네이밍

### State 프로퍼티

```swift
@ObservableState
struct State: Equatable {
    // Bool: is/has/should
    var isLoading = false
    var hasError = false
    var shouldShowAlert = false

    // 데이터
    var posts: [Post] = []
    var selectedItem: Item?
    var errorMessage: String?

    // 페이지네이션
    var currentPage = 1
    var hasMorePages = true
}
```

### Dependency

```swift
// Client
@Dependency(\.postsClient) var postsClient
@Dependency(\.authLoginClient) var authLoginClient

// Factory
@Dependency(\.authViewFactory) var authViewFactory
@Dependency(\.mainTabViewFactory) var mainTabViewFactory

// Logger
@Dependency(\.logger) var logger
@Dependency(\.authLogger) var authLogger
```

---

## Reducer 네이밍

### Reducer 이름: `{Feature}Reducer`

```swift
@Reducer
struct AuthReducer { }

@Reducer
struct MainTabReducer { }

@Reducer
struct PostsListReducer { }
```

### State 네이밍: `State` (중첩)

```swift
@Reducer
struct AuthReducer {
    @ObservableState
    struct State: Equatable {
        // ...
    }
}
```

### Action 네이밍: `Action` (중첩)

```swift
@Reducer
struct AuthReducer {
    enum Action {
        // ...
    }
}
```

---

## Client 네이밍

### Client 이름: `{Domain}Client`

```swift
public struct AuthLoginClient { }
public struct PostsClient { }
public struct UserClient { }
public struct NotificationClient { }
```

### Client 메서드

```swift
public struct PostsClient {
    // fetch - 데이터 가져오기
    public var fetchPosts: @Sendable () async throws -> [Post]
    public var fetchPost: @Sendable (Int) async throws -> Post

    // create - 데이터 생성
    public var createPost: @Sendable (CreatePostRequest) async throws -> Post

    // update - 데이터 수정
    public var updatePost: @Sendable (Int, UpdatePostRequest) async throws -> Post

    // delete - 데이터 삭제
    public var deletePost: @Sendable (Int) async throws -> Void
}
```

---

## ViewFactory 네이밍

```swift
public struct AuthViewFactory { }
public struct MainTabViewFactory { }
public struct PostDetailViewFactory { }
```

---

## Enum Case 네이밍

### CamelCase, lowercase 시작

```swift
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum NetworkError: Error {
    case invalidURL
    case decodingError
    case serverError
}

@CasePathable
enum PathState {
    case auth(AuthReducer.State)
    case mainTab(MainTabReducer.State)
}
```

---

## 나쁜 예시 (피해야 할 것)

### ❌ 명령형 Action

```swift
// ❌ 나쁜 예
case setLoading(Bool)
case updateUsername(String)
case showError(String)

// ✅ 좋은 예
case loginButtonTapped
case usernameChanged(String)
case loginResponse(.failure(error))
```

### ❌ 불명확한 네이밍

```swift
// ❌ 나쁜 예
case tap
case changed
case response

// ✅ 좋은 예
case loginButtonTapped
case usernameChanged(String)
case loginResponse(Result<User, Error>)
```

### ❌ 약어 사용

```swift
// ❌ 나쁜 예
case btnTapped
case usrChanged
case authResp

// ✅ 좋은 예
case buttonTapped
case userChanged
case authResponse
```

---

## 체크리스트

작성한 코드가 다음 규칙을 따르는지 확인하세요:

- [ ] Action은 "What happened" 형태로 작성 (사건 중심)
- [ ] 사용자 액션은 `Tapped/Changed/Selected` 접미사 사용
- [ ] 시스템 응답은 `Response` 접미사 사용
- [ ] Bool 프로퍼티는 `is/has/should` 접두사 사용
- [ ] File 이름은 일관된 패턴 사용
- [ ] Client 메서드는 `fetch/create/update/delete` 동사 사용
- [ ] 약어 사용 안 함 (명확한 이름 사용)

---

**작성일**: 2026-01-12
