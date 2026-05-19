# TCA 네트워크 통신 완벽 가이드

> URLSession을 TCA Client로 래핑하여 테스트 가능하고 재사용 가능한 네트워크 계층 구축하기

## 목차

1. [기본 개념](#기본-개념)
2. [현재 프로젝트 구조](#현재-프로젝트-구조)
3. [TCA Client 패턴 (3가지 구현)](#tca-client-패턴-3가지-구현)
4. [Endpoint 정의](#endpoint-정의)
5. [Reducer에서 Client 사용](#reducer에서-client-사용)
6. [Preview에서 Mock 주입](#preview에서-mock-주입)
7. [실전 네트워크 패턴](#실전-네트워크-패턴)
8. [고급: NetworkProvider를 Dependency로 주입](#고급-networkprovider를-dependency로-주입)
9. [체크리스트](#체크리스트)

---

## 기본 개념

### URLSession → TCA Client 변환 과정

```
1. Interface에 struct-based TCA Client 계약 정의
2. Sources에 URLSession/NetworkProvider 기반 live 구현
3. Reducer에서 @Dependency로 주입
4. Effect로 비동기 호출
```

Feature dependency는 **struct-based TCA Client**를 기본으로 사용합니다. 새 Feature Client마다 protocol을 만들지 않습니다.

Protocol-based client/abstraction은 다음 경우에만 사용합니다.
- 기존 Core protocol이 이미 존재하는 경우
- 플랫폼 abstraction에 protocol이 필요한 경우
- legacy integration이 protocol을 요구하는 경우
- 명시적인 문서/요구사항이 protocol을 요구하는 경우

### 왜 Client로 래핑하나?

| 항목 | 직접 URLSession 사용 | TCA Client 패턴 |
|------|---------------------|----------------|
| **테스트** | Mock 어려움 | Mock 쉬움 |
| **재사용** | 코드 중복 | 재사용 가능 |
| **Preview** | 실제 API 호출 필요 | Mock 데이터 사용 |
| **에러 처리** | 분산됨 | 중앙 집중 |

---

## 현재 프로젝트 구조

아래 `NetworkProviderProtocol`, `Endpoint`는 Core Network의 infrastructure-level protocol입니다. 이는 Feature별 dependency도 protocol로 만들어야 한다는 뜻이 아닙니다. Feature Reducer가 주입받는 dependency는 일반적으로 struct-based TCA Client입니다.

```
Projects/Core/Network/
├── Interface/Sources/
│   ├── NetworkProviderProtocol.swift  # Protocol 정의
│   ├── Endpoint.swift                 # Endpoint Protocol
│   ├── NetworkError.swift             # Error 정의
│   └── HTTPMethod.swift
│
└── Sources/
    └── NetworkProvider.swift          # URLSession 구현
```

**이미 Interface/Sources 분리가 완벽하게 되어 있습니다!**

### NetworkProviderProtocol

```swift
public protocol NetworkProviderProtocol {
    func request<T: Decodable>(endpoint: Endpoint) async throws -> T
}
```

### Endpoint Protocol

```swift
public protocol Endpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var query: [URLQueryItem]? { get }
    var body: Encodable? { get }
}
```

### NetworkError

```swift
public enum NetworkError: Error {
    case invalidURLError
    case invalidResponseError
    case authorizationError
    case badRequestError
    case serverError
    case decodingError
    case encodingError
    case unknownError
}

extension NetworkError {
    var errorMessage: String {
        switch self {
        case .invalidURLError:
            return "유효하지 않은 URL입니다."
        case .serverError:
            return "서버 에러입니다."
        // ... 다른 케이스들
        }
    }
}
```

---

## TCA Client 패턴 (3가지 구현)

### 왜 3가지 구현이 필요한가?

1. **liveValue** (실제 API 호출) - 프로덕션 앱에서 사용
2. **testValue** (assertionFailure) - 유닛 테스트에서 미구현 감지
3. **mockSuccess/Failure** (테스트 데이터) - Preview 및 Integration 테스트

### 전체 구현 예시

Feature dependency는 아래처럼 `struct`로 정의합니다. 같은 책임의 protocol을 추가로 만들지 않습니다.

```swift
// 1️⃣ Interface에 struct-based TCA Client 정의
public struct PostsClient {
    public var fetchPosts: @Sendable () async throws -> [Post]
    public var fetchPost: @Sendable (_ id: Int) async throws -> Post

    public init(
        fetchPosts: @escaping @Sendable () async throws -> [Post],
        fetchPost: @escaping @Sendable (Int) async throws -> Post
    ) {
        self.fetchPosts = fetchPosts
        self.fetchPost = fetchPost
    }
}

// 2️⃣ Test Dependency (테스트 시 미구현 감지)
extension PostsClient: TestDependencyKey {
    public static let testValue = Self(
        fetchPosts: {
            assertionFailure("PostsClient.fetchPosts is unimplemented")
            return []
        },
        fetchPost: { _ in
            assertionFailure("PostsClient.fetchPost is unimplemented")
            throw NetworkError.unknownError
        }
    )
}

// 3️⃣ DependencyValues 확장 (주입 포인트)
public extension DependencyValues {
    var postsClient: PostsClient {
        get { self[PostsClient.self] }
        set { self[PostsClient.self] = newValue }
    }
}

// 4️⃣ Live Implementation (실제 API 호출)
extension PostsClient: DependencyKey {
    public static let liveValue: PostsClient = {
        let networkProvider = NetworkProvider()

        return Self(
            fetchPosts: {
                // ✨ NetworkProvider를 사용하여 실제 API 호출
                return try await networkProvider.request(endpoint: APIEndpoint.posts)
            },
            fetchPost: { id in
                return try await networkProvider.request(endpoint: APIEndpoint.post(id: id))
            }
        )
    }()
}

// 5️⃣ Mock Implementation (Preview 및 Integration 테스트)
extension PostsClient {
    public static let mockSuccess = Self(
        fetchPosts: {
            return [
                Post(id: 1, userId: 1, title: "Mock Post 1", body: "Mock body 1"),
                Post(id: 2, userId: 1, title: "Mock Post 2", body: "Mock body 2")
            ]
        },
        fetchPost: { id in
            return Post(id: id, userId: 1, title: "Mock Post \(id)", body: "Mock body")
        }
    )

    public static let mockFailure = Self(
        fetchPosts: {
            throw NetworkError.serverError
        },
        fetchPost: { _ in
            throw NetworkError.badRequestError
        }
    )
}
```

---

## Endpoint 정의

### 실제 API Endpoint 예시

```swift
enum APIEndpoint: Endpoint {
    case posts
    case post(id: Int)
    case users
    case user(id: Int)

    var baseURL: URL {
        URL(string: "https://jsonplaceholder.typicode.com")!
    }

    var path: String {
        switch self {
        case .posts:
            return "/posts"
        case .post(let id):
            return "/posts/\(id)"
        case .users:
            return "/users"
        case .user(let id):
            return "/users/\(id)"
        }
    }

    var method: HTTPMethod {
        .get
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }

    var query: [URLQueryItem]? {
        nil
    }

    var body: Encodable? {
        nil
    }
}
```

### POST 요청 예시

```swift
enum APIEndpoint: Endpoint {
    case createPost(title: String, body: String, userId: Int)

    var path: String {
        switch self {
        case .createPost:
            return "/posts"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .createPost:
            return .post
        }
    }

    var body: Encodable? {
        switch self {
        case .createPost(let title, let body, let userId):
            return CreatePostRequest(title: title, body: body, userId: userId)
        }
    }
}

struct CreatePostRequest: Encodable {
    let title: String
    let body: String
    let userId: Int
}
```

### Query Parameters 예시

```swift
enum APIEndpoint: Endpoint {
    case searchPosts(query: String, limit: Int)

    var path: String {
        switch self {
        case .searchPosts:
            return "/posts"
        }
    }

    var query: [URLQueryItem]? {
        switch self {
        case .searchPosts(let query, let limit):
            return [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        }
    }
}
```

---

## Reducer에서 Client 사용

### 기본 패턴

```swift
@Reducer
struct PostsListReducer {
    @ObservableState
    struct State: Equatable {
        var posts: [Post] = []
        var isLoading = false
        var errorMessage: String?
    }

    enum Action {
        case fetchPostsButtonTapped
        case postsResponse(Result<[Post], Error>)
        case dismissError
    }

    @Dependency(\.postsClient) var postsClient  // ✨ Dependency 주입

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchPostsButtonTapped:
                state.isLoading = true
                state.errorMessage = nil

                // ✨ Effect로 비동기 호출
                return .run { send in
                    do {
                        let posts = try await postsClient.fetchPosts()
                        await send(.postsResponse(.success(posts)))
                    } catch {
                        await send(.postsResponse(.failure(error)))
                    }
                }

            case .postsResponse(.success(let posts)):
                state.isLoading = false
                state.posts = posts
                return .none

            case .postsResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = errorMessage(for: error)
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}

// Helper function
private func errorMessage(for error: Error) -> String {
    if let networkError = error as? NetworkError {
        return networkError.errorMessage
    }
    return error.localizedDescription
}
```

### View 구현

```swift
struct PostsListView: View {
    let store: StoreOf<PostsListReducer>

    var body: some View {
        NavigationStack {
            VStack {
                if store.isLoading {
                    ProgressView("Loading posts...")
                } else if store.posts.isEmpty {
                    Text("No posts yet. Tap the button to fetch!")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(store.posts) { post in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.title)
                                    .font(.headline)
                                Text(post.body)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Posts")
            .toolbar {
                Button {
                    store.send(.fetchPostsButtonTapped)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { _ in store.send(.dismissError) }
                )
            ) {
                Button("OK") {
                    store.send(.dismissError)
                }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}
```

---

## Preview에서 Mock 주입

### 여러 상태의 Preview 만들기

```swift
#Preview("Live - 실제 API") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State()
        ) {
            PostsListReducer()
        }
    )
}

#Preview("Mock - 성공") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State()
        ) {
            PostsListReducer()
        } withDependencies: {
            // ✨ Mock Client 주입
            $0.postsClient = .mockSuccess
        }
    )
}

#Preview("Mock - 에러") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State()
        ) {
            PostsListReducer()
        } withDependencies: {
            $0.postsClient = .mockFailure
        }
    )
}

#Preview("Loading") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State(isLoading: true)
        ) {
            PostsListReducer()
        }
    )
}

#Preview("Empty State") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State(posts: [])
        ) {
            PostsListReducer()
        }
    )
}
```

---

## 실전 네트워크 패턴

### 패턴 1: 여러 API 동시 호출 (Parallel)

```swift
case .onAppear:
    return .merge(
        .run { send in
            let posts = try await postsClient.fetchPosts()
            await send(.postsResponse(.success(posts)))
        },
        .run { send in
            let user = try await postsClient.fetchUser(1)
            await send(.userResponse(.success(user)))
        }
    )
```

**사용 시나리오**: 화면 로드 시 여러 데이터를 동시에 가져올 때

---

### 패턴 2: API 순차 호출 (Sequential)

```swift
case .fetchPostAndAuthor(let postId):
    return .run { send in
        // 1. Post 가져오기
        let post = try await postsClient.fetchPost(postId)
        await send(.postResponse(.success(post)))

        // 2. Post의 작성자 가져오기
        let user = try await postsClient.fetchUser(post.userId)
        await send(.userResponse(.success(user)))
    }
```

**사용 시나리오**: 첫 번째 API 결과가 두 번째 API의 파라미터로 필요할 때

---

### 패턴 3: API 취소 (Debounce)

```swift
@ObservableState
struct State: Equatable {
    var searchQuery: String = ""
    var searchResults: [Post] = []
    var isSearching = false
}

enum Action {
    case searchQueryChanged(String)
    case searchResponse(Result<[Post], Error>)
    case cancelSearch
}

enum CancelID { case search }

var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .searchQueryChanged(let query):
            state.searchQuery = query
            state.isSearching = true

            guard !query.isEmpty else {
                state.searchResults = []
                state.isSearching = false
                return .cancel(id: CancelID.search)
            }

            return .run { send in
                try await Task.sleep(for: .milliseconds(300))  // Debounce
                let posts = try await postsClient.searchPosts(query)
                await send(.searchResponse(.success(posts)))
            }
            .cancellable(id: CancelID.search)  // ✨ 이전 요청 자동 취소

        case .searchResponse(.success(let posts)):
            state.isSearching = false
            state.searchResults = posts
            return .none

        case .cancelSearch:
            state.isSearching = false
            return .cancel(id: CancelID.search)
        }
    }
}
```

**사용 시나리오**: 검색창에서 입력할 때마다 API 호출 (타이핑 멈추면 300ms 후 요청)

---

### 패턴 4: Pagination (무한 스크롤)

```swift
@ObservableState
struct State: Equatable {
    var posts: [Post] = []
    var currentPage = 1
    var isLoading = false
    var isLoadingMore = false
    var hasMorePages = true
}

enum Action {
    case fetchInitialPosts
    case loadMore
    case postsResponse(Result<[Post], Error>)
    case morePostsLoaded(Result<[Post], Error>)
    case noMorePages
}

var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .fetchInitialPosts:
            state.isLoading = true
            state.currentPage = 1

            return .run { send in
                let posts = try await postsClient.fetchPosts(page: 1)
                await send(.postsResponse(.success(posts)))
            }

        case .postsResponse(.success(let posts)):
            state.isLoading = false
            state.posts = posts
            state.hasMorePages = posts.count >= 20  // 페이지 크기
            return .none

        case .loadMore:
            guard !state.isLoadingMore && state.hasMorePages else {
                return .none
            }

            state.isLoadingMore = true

            return .run { [page = state.currentPage] send in
                let newPosts = try await postsClient.fetchPosts(page: page + 1)

                if newPosts.isEmpty {
                    await send(.noMorePages)
                } else {
                    await send(.morePostsLoaded(.success(newPosts)))
                }
            }

        case .morePostsLoaded(.success(let newPosts)):
            state.isLoadingMore = false
            state.currentPage += 1
            state.posts.append(contentsOf: newPosts)
            state.hasMorePages = newPosts.count >= 20
            return .none

        case .noMorePages:
            state.isLoadingMore = false
            state.hasMorePages = false
            return .none

        case .postsResponse(.failure), .morePostsLoaded(.failure):
            state.isLoading = false
            state.isLoadingMore = false
            return .none
        }
    }
}
```

**View에서 무한 스크롤 트리거**:

```swift
List {
    ForEach(store.posts) { post in
        PostRow(post: post)
            .onAppear {
                // 마지막 항목에 도달하면 더 로드
                if post.id == store.posts.last?.id {
                    store.send(.loadMore)
                }
            }
    }

    if store.isLoadingMore {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
}
```

---

### 패턴 5: 에러 처리 (Retry)

```swift
@ObservableState
struct State: Equatable {
    var posts: [Post] = []
    var isLoading = false
    var errorMessage: String?
    var canRetry = false
}

enum Action {
    case fetchPosts
    case postsResponse(Result<[Post], Error>)
    case retryButtonTapped
    case dismissError
}

var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .fetchPosts:
            state.isLoading = true
            state.errorMessage = nil
            state.canRetry = false

            return .run { send in
                do {
                    let posts = try await postsClient.fetchPosts()
                    await send(.postsResponse(.success(posts)))
                } catch {
                    await send(.postsResponse(.failure(error)))
                }
            }

        case .postsResponse(.success(let posts)):
            state.isLoading = false
            state.posts = posts
            return .none

        case .postsResponse(.failure(let error)):
            state.isLoading = false

            // ✨ 네트워크 에러 종류에 따라 재시도 가능 여부 결정
            if case NetworkError.serverError = error {
                state.errorMessage = "서버 에러가 발생했습니다. 재시도하시겠습니까?"
                state.canRetry = true
            } else if case NetworkError.invalidResponseError = error {
                state.errorMessage = "네트워크 연결을 확인해주세요."
                state.canRetry = true
            } else {
                state.errorMessage = error.localizedDescription
                state.canRetry = false
            }
            return .none

        case .retryButtonTapped:
            return .send(.fetchPosts)

        case .dismissError:
            state.errorMessage = nil
            state.canRetry = false
            return .none
        }
    }
}
```

**View에서 Retry UI**:

```swift
.alert(
    "Error",
    isPresented: Binding(
        get: { store.errorMessage != nil },
        set: { _ in store.send(.dismissError) }
    )
) {
    if store.canRetry {
        Button("Retry") {
            store.send(.retryButtonTapped)
        }
    }
    Button("Cancel") {
        store.send(.dismissError)
    }
} message: {
    Text(store.errorMessage ?? "")
}
```

---

### 패턴 6: 자동 재시도 (Exponential Backoff)

```swift
case .fetchPostsButtonTapped:
    state.isLoading = true
    state.retryCount = 0

    return .run { send in
        await send(.attemptFetch)
    }

case .attemptFetch:
    return .run { [retryCount = state.retryCount] send in
        do {
            let posts = try await postsClient.fetchPosts()
            await send(.postsResponse(.success(posts)))
        } catch {
            // 최대 3번 재시도
            if retryCount < 3 {
                // 지수 백오프: 1초, 2초, 4초
                let delay = pow(2.0, Double(retryCount))
                try await Task.sleep(for: .seconds(delay))
                await send(.incrementRetryCount)
            } else {
                await send(.postsResponse(.failure(error)))
            }
        }
    }

case .incrementRetryCount:
    state.retryCount += 1
    return .send(.attemptFetch)
```

---

## 고급: NetworkProvider를 Dependency로 주입

이 섹션은 Core Network infrastructure를 TCA Dependency로 감싸는 고급 패턴입니다. 기존 `NetworkProviderProtocol` 같은 infrastructure-level protocol을 보존하는 경우에 사용합니다.

일반적인 Feature dependency는 여전히 struct-based TCA Client를 우선합니다. 새 Feature Client마다 protocol을 만들기 위한 패턴으로 사용하지 않습니다.

NetworkProvider 자체도 Dependency로 주입하여 테스트 시 Mock으로 교체 가능합니다.

### 1. NetworkProvider를 Dependency로 등록

```swift
// Core/Network/Sources/NetworkProvider+Dependency.swift
extension NetworkProvider: DependencyKey {
    public static let liveValue: NetworkProvider = NetworkProvider()
}

public extension DependencyValues {
    var networkProvider: any NetworkProviderProtocol {
        get { self[NetworkProviderKey.self] }
        set { self[NetworkProviderKey.self] = newValue }
    }
}

private enum NetworkProviderKey: DependencyKey {
    static let liveValue: any NetworkProviderProtocol = NetworkProvider()
    static let testValue: any NetworkProviderProtocol = MockNetworkProvider()
}
```

### 2. Mock NetworkProvider 구현

```swift
// Core/Network/Testing/Sources/MockNetworkProvider.swift
public struct MockNetworkProvider: NetworkProviderProtocol {
    private let mockResponses: [String: Any]

    public init(mockResponses: [String: Any] = [:]) {
        self.mockResponses = mockResponses
    }

    public func request<T: Decodable>(endpoint: Endpoint) async throws -> T {
        // endpoint.path를 키로 사용하여 Mock 응답 반환
        guard let response = mockResponses[endpoint.path] as? T else {
            throw NetworkError.decodingError
        }
        return response
    }
}
```

### 3. PostsClient에서 NetworkProvider Dependency 사용

```swift
extension PostsClient {
    public static var liveWithDependency: PostsClient {
        @Dependency(\.networkProvider) var networkProvider

        return Self(
            fetchPosts: {
                // ✨ Dependency로 주입받은 NetworkProvider 사용
                return try await networkProvider.request(endpoint: APIEndpoint.posts)
            },
            fetchPost: { id in
                return try await networkProvider.request(endpoint: APIEndpoint.post(id: id))
            }
        )
    }
}
```

### 4. 테스트에서 Mock NetworkProvider 주입

```swift
@Test
func testFetchPosts() async throws {
    let mockPosts = [
        Post(id: 1, userId: 1, title: "Test Post", body: "Test Body")
    ]

    let store = TestStore(
        initialState: PostsListReducer.State()
    ) {
        PostsListReducer()
    } withDependencies: {
        // ✨ Mock NetworkProvider 주입
        $0.networkProvider = MockNetworkProvider(
            mockResponses: [
                "/posts": mockPosts
            ]
        )
    }

    await store.send(.fetchPostsButtonTapped) {
        $0.isLoading = true
    }

    await store.receive(.postsResponse(.success(mockPosts))) {
        $0.isLoading = false
        $0.posts = mockPosts
    }
}
```

---

## 체크리스트

### Client 구현 체크리스트

- [ ] Endpoint 정의 (baseURL, path, method, headers 등)
- [ ] Client struct 정의 (Interface)
- [ ] 새 protocol을 만들지 않았는지 확인 (기존 Core/platform/legacy boundary가 필요한 경우 제외)
- [ ] TestDependencyKey 구현 (assertionFailure)
- [ ] Live Implementation (NetworkProvider 사용)
- [ ] Mock Implementation (Preview/테스트용)
- [ ] DependencyValues 확장 (주입 포인트)

### Reducer 구현 체크리스트

- [ ] @Dependency로 Client 주입
- [ ] Effect(.run)로 비동기 호출
- [ ] 성공 Response Action 처리
- [ ] 실패 Response Action 처리
- [ ] 에러 메시지를 State에 저장
- [ ] Loading 상태 관리

### View 구현 체크리스트

- [ ] Loading 상태 UI
- [ ] Empty 상태 UI
- [ ] 에러 Alert/Toast
- [ ] Retry 버튼 (필요 시)
- [ ] Pull-to-Refresh (필요 시)
- [ ] 무한 스크롤 (필요 시)

### Preview 구현 체크리스트

- [ ] Live Preview (실제 API)
- [ ] Mock Success Preview
- [ ] Mock Failure Preview
- [ ] Loading Preview
- [ ] Empty State Preview

---

## 전체 예제 코드

### Domain Models

```swift
public struct Post: Equatable, Codable, Identifiable {
    public let id: Int
    public let userId: Int
    public let title: String
    public let body: String

    public init(id: Int, userId: Int, title: String, body: String) {
        self.id = id
        self.userId = userId
        self.title = title
        self.body = body
    }
}
```

### Client 전체 구현

```swift
// Interface
public struct PostsClient {
    public var fetchPosts: @Sendable () async throws -> [Post]
    public var fetchPost: @Sendable (_ id: Int) async throws -> Post

    public init(
        fetchPosts: @escaping @Sendable () async throws -> [Post],
        fetchPost: @escaping @Sendable (Int) async throws -> Post
    ) {
        self.fetchPosts = fetchPosts
        self.fetchPost = fetchPost
    }
}

// TestDependency
extension PostsClient: TestDependencyKey {
    public static let testValue = Self(
        fetchPosts: {
            assertionFailure("PostsClient.fetchPosts is unimplemented")
            return []
        },
        fetchPost: { _ in
            assertionFailure("PostsClient.fetchPost is unimplemented")
            throw NetworkError.unknownError
        }
    )
}

// DependencyValues
public extension DependencyValues {
    var postsClient: PostsClient {
        get { self[PostsClient.self] }
        set { self[PostsClient.self] = newValue }
    }
}

// Live Implementation
extension PostsClient: DependencyKey {
    public static let liveValue: PostsClient = {
        let networkProvider = NetworkProvider()

        return Self(
            fetchPosts: {
                return try await networkProvider.request(endpoint: APIEndpoint.posts)
            },
            fetchPost: { id in
                return try await networkProvider.request(endpoint: APIEndpoint.post(id: id))
            }
        )
    }()
}

// Mock Implementation
extension PostsClient {
    public static let mockSuccess = Self(
        fetchPosts: {
            return [
                Post(id: 1, userId: 1, title: "Mock Post 1", body: "Mock body 1"),
                Post(id: 2, userId: 1, title: "Mock Post 2", body: "Mock body 2")
            ]
        },
        fetchPost: { id in
            return Post(id: id, userId: 1, title: "Mock Post \(id)", body: "Mock body")
        }
    )

    public static let mockFailure = Self(
        fetchPosts: {
            throw NetworkError.serverError
        },
        fetchPost: { _ in
            throw NetworkError.badRequestError
        }
    )
}
```

### Endpoint 구현

```swift
enum APIEndpoint: Endpoint {
    case posts
    case post(id: Int)

    var baseURL: URL {
        URL(string: "https://jsonplaceholder.typicode.com")!
    }

    var path: String {
        switch self {
        case .posts:
            return "/posts"
        case .post(let id):
            return "/posts/\(id)"
        }
    }

    var method: HTTPMethod {
        .get
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }

    var query: [URLQueryItem]? {
        nil
    }

    var body: Encodable? {
        nil
    }
}
```

### Reducer 구현

```swift
@Reducer
struct PostsListReducer {
    @ObservableState
    struct State: Equatable {
        var posts: [Post] = []
        var isLoading = false
        var errorMessage: String?
    }

    enum Action {
        case onAppear
        case fetchPostsButtonTapped
        case postsResponse(Result<[Post], Error>)
        case dismissError
    }

    @Dependency(\.postsClient) var postsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear, .fetchPostsButtonTapped:
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    do {
                        let posts = try await postsClient.fetchPosts()
                        await send(.postsResponse(.success(posts)))
                    } catch {
                        await send(.postsResponse(.failure(error)))
                    }
                }

            case .postsResponse(.success(let posts)):
                state.isLoading = false
                state.posts = posts
                return .none

            case .postsResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = errorMessage(for: error)
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}

private func errorMessage(for error: Error) -> String {
    if let networkError = error as? NetworkError {
        return networkError.errorMessage
    }
    return error.localizedDescription
}
```

### View 구현

```swift
struct PostsListView: View {
    let store: StoreOf<PostsListReducer>

    var body: some View {
        NavigationStack {
            VStack {
                if store.isLoading {
                    ProgressView("Loading posts...")
                } else if store.posts.isEmpty {
                    Text("No posts yet. Tap the button to fetch!")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(store.posts) { post in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.title)
                                    .font(.headline)
                                Text(post.body)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Posts")
            .toolbar {
                Button {
                    store.send(.fetchPostsButtonTapped)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { _ in store.send(.dismissError) }
                )
            ) {
                Button("OK") {
                    store.send(.dismissError)
                }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }
}
```

### Preview 구현

```swift
#Preview("Live - 실제 API") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State()
        ) {
            PostsListReducer()
        }
    )
}

#Preview("Mock - 성공") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State()
        ) {
            PostsListReducer()
        } withDependencies: {
            $0.postsClient = .mockSuccess
        }
    )
}

#Preview("Mock - 에러") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State()
        ) {
            PostsListReducer()
        } withDependencies: {
            $0.postsClient = .mockFailure
        }
    )
}

#Preview("Loading") {
    PostsListView(
        store: Store(
            initialState: PostsListReducer.State(isLoading: true)
        ) {
            PostsListReducer()
        }
    )
}
```

---

## 정리

### 핵심 포인트

1. **Struct-based TCA Client** - Feature dependency의 기본 형태
2. **Client 패턴** - 3가지 구현 (live, test, mock)으로 유연성 확보
3. **Infrastructure protocol 보존** - 기존 Core/platform/legacy boundary가 있을 때만 protocol 사용
4. **Effect 사용** - `.run { send in ... }` 패턴으로 비동기 처리
5. **에러 처리** - Result 타입으로 성공/실패 분기
6. **Mock 주입** - `withDependencies`로 Preview 및 테스트에서 Mock 사용
7. **취소 가능** - `.cancellable(id:)`로 중복 요청 방지

## 인증 토큰 처리

Authorization header가 필요한 요청은 token storage나 Keychain을 직접 읽지 않습니다.

현재 승인된 패턴:

- `TokenManager`: `Projects/Domain/Auth/Interface/Sources/TokenManager.swift`
- `AuthInterceptor`: `Projects/Domain/Auth/Sources/AuthInterceptor.swift`
- `AuthInterceptor`는 `TokenManager`에서 access token을 읽고, refresh flow는 `AuthClient.refreshToken` 경로로 위임합니다.
- App/root wiring은 `Projects/App/Sources/View/TwixApp.swift`에서 live token storage dependency를 설정합니다.

금지:

- Feature Client나 Network request code에서 `@Dependency(\.tokenStorage)` 직접 사용
- `TokenStorageClient`, `TokenStorageProtocol`, `KeychainTokenStorage`, Keychain, UserDefaults를 Authorization header 생성을 위해 직접 읽기
- Feature Client마다 token refresh logic을 중복 구현
- owner 승인 없이 새로운 token/header path 도입

직접 TokenStorage 사용은 `TokenManager` 내부, Core Storage interface/implementation, App/root dependency wiring, tests/mocks로 제한합니다. 인증 인프라를 추가해야 한다면 `TokenStorage`가 아니라 `TokenManager`에 의존하도록 설계합니다.

---

### 다음 단계

- [ ] 실제 프로젝트에 API Client 구현
- [ ] 여러 Endpoint 추가
- [ ] 인증 토큰 처리는 `TokenManager` + `AuthInterceptor` 패턴 확인
- [ ] 캐싱 전략 구현
- [ ] 오프라인 대응

---

**작성일**: 2026-01-12
**작성자**: Claude Code Assistant
