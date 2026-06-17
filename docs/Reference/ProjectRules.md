# 프로젝트 규칙

> 팀 아키텍처 결정과 공통 구현 규칙을 정리한 canonical reference입니다.

상세 구현 체크리스트는 [Checklists.md](./Checklists.md)를, 파일 분리 기준은 [FileOrganization.md](./FileOrganization.md)를, 네이밍 규칙은 [NamingConventions.md](./NamingConventions.md)를 함께 확인하세요.

---

## DocC 문서화 기준

대상: Core / Domain / Feature / Shared 모듈의 public API

### 문서화 대상

- Interface 계층의 public 타입(struct, enum, class 등): 간단 설명 필수
- Shared 모듈은 Interface가 없으므로 public 타입에 한해 문서화 필수
- public 함수: 사용 예시 코드 작성 필수

### 문서화 제외

- enum case, 변수/프로퍼티: 문서화 주석 작성 안 함
- App 계층: internal 타입이므로 문서화 불필요
- Implementation 계층: public이 아닌 한 문서화 불필요

### 적용 원칙

- 문서화 제외 항목은 불필요한 주석을 추가하지 않습니다.
- public API 타입/함수의 문서화 누락은 규칙 위반입니다.

---

## Feature 조립 규칙

상세 구조는 [Architecture/Overview.md](../Architecture/Overview.md)를 따릅니다.

- 일반 Feature는 Interface / Sources 분리 구조를 유지합니다.
- 외부 모듈은 일반적으로 Interface 모듈에만 의존합니다.
- Sources 모듈은 View, live 구현, reducer 세부 로직 등 implementation details를 숨깁니다.
- Feature Root 또는 App 조립 계층은 필요한 구현체를 조립하고 dependency를 명시적으로 주입합니다.
- Feature Root에서 타입 재노출이 필요할 경우 public boundary를 해치지 않도록 Interface 타입 재노출을 우선합니다.

### 예외 Feature

다음 Feature는 App 직접 조립 예외로 문서화되어 있습니다.

- Auth
- Onboarding
- MainTab

이 예외 Feature들은 App에서 `makeView(_:)` 없이 직접 조립할 수 있고, 내부 하위 Feature 조립 시 implementation 모듈을 직접 import 할 수 있습니다.

---

## Reducer 생성 규칙

- Interface에는 Reducer의 public signature를 둡니다.
- Implementation에서는 실제 `Reduce`를 구성하는 기본 initializer를 제공합니다.
- 다른 Feature에서 Reducer를 사용할 때는 Interface 타입 의존을 우선합니다.

```swift
@Reducer
public struct CounterReducer {
    public let reducer: Reduce<State, Action>

    public init(reducer: Reduce<State, Action>) {
        self.reducer = reducer
    }

    public var body: some ReducerOf<Self> {
        reducer
    }
}
```

```swift
extension CounterReducer {
    public init() {
        self.init(reducer: Reduce { state, action in
            // 실제 로직
            return .none
        })
    }
}
```

---

## ViewFactory 도입 기준

ViewFactory는 모든 Feature에 강제하지 않습니다.

- Flow 단위 Feature가 내부에서만 사용되고 외부 재사용 가능성이 낮으면 Root에서 직접 조립할 수 있습니다.
- 다른 화면/Feature에서 재사용될 하위 기능 단위 Feature는 ViewFactory 또는 동등한 factory를 Interface에 정의하고 Sources에서 live 구현을 제공합니다.
- 예외 Feature(Auth / Onboarding / MainTab)는 별도 조립 규칙을 따릅니다.

---

## 의존성 주입 규칙

- Struct + closure + TCA Dependency 스타일을 기본으로 사용합니다.
- 모든 모듈은 TCA Dependency Container를 사용합니다.
- Feature 간 또는 Feature/Domain/Core 간 연결은 가능한 한 Interface 모듈만 import합니다.
- `liveValue`는 Implementation 모듈에서 제공합니다.
- 조립은 App 또는 Feature Root에서 `.withDependency`로 명시합니다.
- Implementation 모듈 내부에서 다른 모듈의 의존성을 임의로 조립하지 않습니다.
- Core/Network, Core/Storage는 singleton 직접 접근 대신 TCA Dependency로 주입 가능한 인스턴스형 구조를 사용합니다.

---

## 외부 의존성 참조 규칙

서로 다른 계층(Feature / Domain / Core) 간 참조는 Interface만으로 해결 가능한지 먼저 검증합니다.

- Interface만으로 해결 가능하면 Interface 의존만 사용합니다.
- Interface만으로 불가능한 경우에만 implementation 의존을 검토하고, 불가능한 이유를 문서화합니다.
- 전체 모듈 참조(예: `.domain`, `.core`)로 대체하는 결정은 지양하며, 구조적 필요성이 명확할 때만 허용합니다.

---

## Token 접근 규칙

토큰 접근은 현재 `TokenManager` 패턴을 통해 중재합니다.

현재 코드베이스 기준 위치:

- `TokenManager`: `Projects/Domain/Auth/Interface/Sources/TokenManager.swift`
- Token storage interface: `Projects/Core/Storage/Interface/Sources/TokenStorageProtocol.swift`
- Keychain implementation: `Projects/Core/Storage/Sources/KeychainTokenStorage.swift`
- 현재 Authorization header 처리 패턴: `Projects/Domain/Auth/Sources/AuthInterceptor.swift`가 `TokenManager`를 사용
- 현재 App/root wiring: `Projects/App/Sources/View/TwixApp.swift`에서 live token storage dependency 설정

금지:

- Feature / Reducer / View / 일반 Client에서 `@Dependency(\.tokenStorage)` 직접 사용
- Feature / Reducer / View / 일반 Client / request-building code에서 `TokenStorageClient`, `TokenStorageProtocol`, `KeychainTokenStorage`, Keychain, UserDefaults 등 token persistence 직접 접근
- Authorization header 구성을 위해 storage를 직접 읽기
- Feature client에서 token refresh logic 중복 구현
- owner 승인 없이 새로운 token/header path 도입

허용:

- `TokenManager` 내부
- Core Storage interface/implementation
- App/root dependency wiring
- tests/mocks
- `AuthInterceptor`처럼 `TokenManager`에 의존하는 승인된 auth infrastructure

위 경로는 현재 코드베이스 기준입니다. `TokenManager`의 장기적 모듈 위치를 고정하는 의미는 아닙니다.

---

## SwiftLint 규칙

SwiftLint 경고를 가능한 한 최소화합니다.

- 새로운 코드에서는 SwiftLint 경고가 발생하지 않도록 작성합니다.
- 변경으로 인해 경고가 증가하지 않도록 합니다.
- 불가피한 경우에만 제한적으로 `swiftlint:disable`을 사용하고, 범위를 최소화합니다.
- SwiftLint 실행은 Tuist에 설정된 script를 따릅니다: `Tuist/ProjectDescriptionHelpers/Scripts/SwiftLintScript.swift`
- 별도 standalone SwiftLint 명령을 임의로 만들지 않습니다.

---

## 코드 스타일 규칙

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

## 검증 정책

Tuist는 setup/generation 용도로 사용합니다.

```bash
tuist install
tuist generate
tuist clean
```

- `tuist clean`은 regeneration cleanup이 필요할 때만 사용합니다.
- `tuist build`는 표준 검증 명령이 아닙니다.
- CI/PR 수준 검증은 `bundle exec fastlane ios ci_pr`를 우선 사용합니다.
- Bundler를 사용할 수 없는 경우에만 `fastlane ios ci_pr`를 사용합니다.
- direct `xcodebuild`는 scheme / destination / configuration이 명시적으로 문서화되었거나 제공된 direct-xcodebuild-specific task에서만 사용합니다.
- direct `xcodebuild` 값을 추측하지 않습니다.
- 검증을 실행할 수 없는 경우 결과 보고에 검증 한계를 명시합니다.

---

## Unresolved

### TestDependencyKey와 Testing 모듈 분리

Interface에 `TestDependencyKey`를 두는 현재 패턴은 MFA의 Testing 모듈 분리 원칙과 충돌할 가능성이 있습니다.

현재 문서와 예제는 `TestDependencyKey`를 Interface에 두는 패턴을 포함하지만, 장기적으로 팀 합의에 따라 Testing 모듈로 대체할 수 있습니다. 새 패턴을 도입하거나 기존 패턴을 변경하기 전에는 owner 확인이 필요합니다.
