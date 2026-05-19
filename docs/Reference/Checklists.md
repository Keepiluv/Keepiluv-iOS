# Feature 구현 체크리스트

> Feature를 구현할 때 빠뜨리지 말아야 할 항목들

이 문서는 Feature 구현 시 사용하는 **canonical checklist**입니다. 중복된 축약 체크리스트 대신 이 문서를 기준으로 확인합니다.

---

## 구현 품질 Gate

비단순 구현을 시작하기 전에 구조가 팀 아키텍처를 기계적으로 따르는 수준을 넘어, 유지보수 가능한 형태인지 확인합니다.

- [ ] 변경 코드가 올바른 module / layer / feature에 위치하는가?
- [ ] Interface 모듈은 public boundary로 유지되는가?
- [ ] Sources 모듈의 구현 세부사항이 외부로 새지 않는가?
- [ ] 소비자가 implementation Sources가 아니라 Interface 모듈에 의존하는가?
- [ ] 의존성 방향이 역전되거나 순환 의존성을 만들지 않는가?
- [ ] TCA State / Action / Reducer 소유권이 해당 Feature에 명확히 있는가?
- [ ] Side effect는 Dependency와 Effect를 통해 처리되는가?
- [ ] 토큰 접근이 필요한 경우 `TokenManager`를 사용하고, Feature/Reducer/View/일반 Client에서 `TokenStorage`/Keychain에 직접 접근하지 않았는가?
- [ ] Authorization header 또는 token refresh logic을 중복 구현하지 않았는가?
- [ ] public API는 필요한 최소 범위인가?
- [ ] Feature 간 불필요한 coupling을 만들지 않는가?
- [ ] 동일 책임의 Client / Factory / Route / Model을 중복 생성하지 않았는가?
- [ ] 새로운 architecture pattern 또는 예외가 필요하다면 구현 전에 승인을 받았는가?
- [ ] 동작 또는 아키텍처가 바뀌면 관련 문서 업데이트가 필요한지 확인했는가?

---

## Interface 구현 체크리스트
Auth / MainTab / Onboarding은 예외 Feature로 취급되어 이 체크리스트를 강제하지 않습니다.

Interface 모듈은 외부 소비자가 의존하는 public boundary입니다. 새로 만들거나 크게 수정하는 Interface 모듈은 One Type Per File을 우선합니다. 기존 `Interface/Sources/Source.swift` 파일은 legacy/compatibility 패턴으로 유지할 수 있습니다.

### Reducer

- [ ] `@Reducer` 매크로 추가
- [ ] `public struct {Feature}Reducer` 정의
- [ ] `public let reducer: Reduce<State, Action>` 프로퍼티
- [ ] `public init(reducer: Reduce<State, Action>)` 생성자
- [ ] `public var body: some ReducerOf<Self> { reducer }` 구현

### State

- [ ] `@ObservableState` 매크로 추가
- [ ] `public struct State: Equatable` 정의
- [ ] 모든 프로퍼티 `public` 선언
- [ ] `public init()` 생성자 정의 ⚠️ **필수!**

### Action

- [ ] `public enum Action` 정의
- [ ] 사용자 액션 정의 (`Tapped/Changed` 접미사)
- [ ] 시스템 응답 정의 (`Response` 접미사)
- [ ] Delegate 액션 정의 (필요 시)

### Delegate (필요 시)

- [ ] `@CasePathable` 매크로 추가
- [ ] `public enum Delegate` 정의
- [ ] Delegate 케이스 정의

### Client (필요 시)

- [ ] `public struct {Domain}Client` 정의
- [ ] Feature dependency는 struct-based TCA Client를 기본으로 사용
- [ ] 메서드 프로퍼티 정의 (`@Sendable` 클로저)
- [ ] `public init` 생성자 정의
- [ ] `TestDependencyKey` extension 추가
- [ ] `DependencyValues` extension 추가

### ViewFactory (필요 시)

- [ ] `public struct {Feature}ViewFactory: Sendable` 정의
- [ ] `public var makeView: @MainActor (_ store:) -> AnyView` 정의
- [ ] `public init` 생성자 정의
- [ ] `TestDependencyKey` extension 추가
- [ ] `DependencyValues` extension 추가

---

## Sources 구현 체크리스트

### Reducer 로직

- [ ] `extension {Feature}Reducer` 작성
- [ ] `public init()` 구현 (기본 생성자)
- [ ] `@Dependency` 주입
- [ ] `self.init(reducer: Reduce { ... })` 호출
- [ ] 모든 Action에 대한 case 처리
- [ ] State 변경 후 Effect 반환
- [ ] 비동기/외부 side effect는 Dependency와 Effect를 통해 처리

### View

- [ ] `struct {Feature}View: View` 정의 ⚠️ **internal**
- [ ] `let store: StoreOf<{Feature}Reducer>` 프로퍼티
- [ ] `var body: some View` 구현
- [ ] `store.send(action)` 호출
- [ ] `store.state` 직접 접근

### Client 구현 (필요 시)

- [ ] `extension {Domain}Client: DependencyKey` 작성
- [ ] `public static let liveValue` 구현
- [ ] 실제 로직 구현 (네트워크, DB 등)

### ViewFactory 구현 (필요 시)

- [ ] `extension {Feature}ViewFactory: DependencyKey` 작성
- [ ] `public static let liveValue` 구현
- [ ] `AnyView({Feature}View(store: store))` 반환

### Linker (Static Library인 경우)

- [ ] `public enum Feature{Name}Linker` 정의
- [ ] `public static func link()` 구현
- [ ] 모든 `liveValue` 강제 참조

---

## 문서화 체크리스트

상세 DocC 기준은 [ProjectRules.md](./ProjectRules.md)를 따릅니다.

### DocC 주석

- [ ] Interface 계층의 public 타입에 `///` 주석 추가
- [ ] Shared 모듈은 public 타입에 `///` 주석 추가
- [ ] public 함수는 `## 사용 예시`와 코드 블록 (```swift```) 추가
- [ ] enum case, 변수/프로퍼티에는 불필요한 문서화 주석을 추가하지 않음
- [ ] 복잡한 로직은 `## 동작 원리` 섹션 추가

### 예시

```swift
/// 소셜 로그인을 처리하는 클라이언트입니다.
///
/// Apple, Kakao 등의 소셜 로그인 제공자를 통해 사용자 인증을 수행합니다.
///
/// ## 사용 예시
/// ```swift
/// @Dependency(\.authLoginClient) var authLoginClient
/// let result = try await authLoginClient.login(.apple)
/// ```
public struct AuthLoginClient { }
```

---

## Preview 체크리스트

- [ ] `#Preview("Live")` - 실제 동작
- [ ] `#Preview("Mock - 성공")` - Mock 데이터
- [ ] `#Preview("Mock - 에러")` - 에러 상태
- [ ] `#Preview("Loading")` - 로딩 상태
- [ ] `#Preview("Empty")` - 빈 상태 (필요 시)

### 예시

```swift
#Preview("Live") {
    AuthView(
        store: Store(initialState: AuthReducer.State()) {
            AuthReducer()
        }
    )
}

#Preview("Mock - 성공") {
    AuthView(
        store: Store(initialState: AuthReducer.State()) {
            AuthReducer()
        } withDependencies: {
            $0.authLoginClient = .mockSuccess
        }
    )
}
```

---

## 테스트 정책

현재 테스트는 일반 요구사항으로 정착되어 있지 않습니다. 테스트 아키텍처를 임의로 만들지 않습니다.

- [ ] 명시적으로 요청받지 않았다면 새 테스트를 만들지 않음
- [ ] 테스트 타겟 또는 실행 명령이 없으면 테스트를 실행했다고 주장하지 않음
- [ ] 위험한 로직 변경은 테스트 계획을 제안
- [ ] 테스트 부재로 검증이 제한되는 경우 결과 보고에 명시

### 향후 테스트 추가 시 참고 항목

- [ ] Reducer 유닛 테스트 (`TestStore`)
- [ ] Client Mock (`mockSuccess`, `mockFailure` 등)
- [ ] Integration 테스트
- [ ] Preview 시나리오 (Live, Mock, Error, Loading, Empty)

---

## Tuist 설정 / 생성 체크리스트

Tuist는 setup/generation의 canonical tool입니다. `tuist build`는 사용하지 않습니다. CI/PR 수준 검증은 Fastlane을 사용합니다.

- [ ] 필요한 경우 `tuist install` 실행
- [ ] 프로젝트 파일 재생성이 필요한 경우 `tuist generate` 실행
- [ ] regeneration 문제가 있을 때만 `tuist clean` 고려
- [ ] CI/PR 수준 검증이 필요한 경우 `bundle exec fastlane ios ci_pr` 실행
- [ ] Bundler를 사용할 수 없는 경우에만 `fastlane ios ci_pr` 사용
- [ ] direct `xcodebuild` scheme / destination / configuration을 추측하지 않음
- [ ] `xcodebuild`는 올바른 scheme / destination / configuration이 문서화되었거나 제공된 경우에만 사용
- [ ] Fastlane 또는 빌드 명령 실행이 불가능한 경우 검증 제한을 결과 보고에 명시

현재 단계에서는 테스트/Testing 타겟 추가를 필수로 보지 않습니다.

> Unresolved: `TestDependencyKey`를 Interface에 두는 현재 패턴은 Testing 모듈 분리 원칙과 충돌할 가능성이 있습니다. 새 패턴을 도입하거나 기존 패턴을 변경하기 전에는 owner 확인이 필요합니다.

### Project.swift

- [ ] `.feature(interface:)` 타겟 정의
- [ ] `.feature(implements:)` 타겟 정의
- [ ] `.feature(example:)` 타겟 정의 (필요 시)
- [ ] `.feature(testing:)` 타겟 정의 (필요 시)
- [ ] 의존성 정확히 설정

### 의존성 규칙

```swift
// Interface는 최소 의존성만
.feature(interface: .auth, config: .init(
    dependencies: [
        .external(dependency: .ComposableArchitecture)
    ]
))

// Sources는 Interface + 필요한 모듈
.feature(implements: .auth, config: .init(
    dependencies: [
        .feature(interface: .auth),
        .core(implements: .logging),
        .external(dependency: .ComposableArchitecture)
    ]
))
```

---

## 코드 리뷰 체크리스트

### 아키텍처

- [ ] Interface/Sources 분리 올바른가? (예외 Feature: Auth / MainTab / Onboarding 제외)
- [ ] Interface가 public boundary로 유지되는가?
- [ ] Sources의 implementation detail이 외부로 노출되지 않는가?
- [ ] 의존성 방향이 올바른가?
- [ ] 올바른 Feature / module / layer에 배치되었는가?
- [ ] public/internal 접근 제어자 올바른가?
- [ ] public API가 최소인가?
- [ ] 기존 Client / Factory / Route / Model과 책임이 중복되지 않는가?
- [ ] Dependency 올바르게 주입했는가?
- [ ] 토큰 조회/저장/삭제/refresh-state 전환은 `TokenManager`를 통해 수행되는가?
- [ ] `@Dependency(\.tokenStorage)`, `TokenStorageClient`, `TokenStorageProtocol`, `KeychainTokenStorage`, Keychain, UserDefaults를 Feature/Reducer/View/일반 Client에서 직접 사용하지 않았는가?
- [ ] Reducer는 순수 함수인가? (Side Effect 없는가?)

### 네이밍

- [ ] Action은 "What happened" 형태인가?
- [ ] 사용자 액션은 `Tapped/Changed` 접미사 사용했는가?
- [ ] Bool 프로퍼티는 `is/has/should` 접두사 사용했는가?
- [ ] 약어 사용하지 않았는가?

### State 관리

- [ ] State는 최소한인가? (계산 가능한 것은 computed property)
- [ ] State는 `Equatable`인가?
- [ ] Optional은 적절히 사용했는가?

### Effect

- [ ] 비동기 작업은 `.run`으로 래핑했는가?
- [ ] Effect는 적절한 시점에 반환되는가?
- [ ] Effect 취소가 필요한 경우 `.cancellable(id:)` 사용했는가?

### 에러 처리

- [ ] 모든 네트워크 에러 처리했는가?
- [ ] 사용자에게 에러 메시지 표시하는가?
- [ ] Retry 로직이 필요한가?

---

## 완료 전 최종 체크리스트

- [ ] CI/PR 수준 검증이 필요한 경우 `bundle exec fastlane ios ci_pr`를 실제로 실행했는가?
- [ ] Bundler를 사용할 수 없는 경우 `fastlane ios ci_pr`로 검증했는가?
- [ ] Fastlane/빌드/테스트 명령을 실행할 수 없는 경우 검증 제한을 보고했는가?
- [ ] 테스트를 만들거나 실행하지 않은 경우 그렇게 명시했는가?
- [ ] 불필요한 로그 제거
- [ ] 주석 처리된 코드 제거
- [ ] TODO 주석 확인
- [ ] 필요한 DocC 문서 완성
- [ ] SwiftLint 경고가 증가하지 않았는지 확인 (Tuist-configured script: `Tuist/ProjectDescriptionHelpers/Scripts/SwiftLintScript.swift`)
- [ ] Example 앱/Preview 확인이 필요한 변경인지 판단했는가?
- [ ] 동작 또는 아키텍처 변경 시 관련 문서 업데이트 필요성을 확인했는가?

---

**작성일**: 2026-01-12
