# 아키텍처 개요

> 프로젝트의 전체 구조와 설계 철학

## 목차

1. [전체 구조](#전체-구조)
2. [계층별 역할](#계층별-역할)
3. [핵심 원칙](#핵심-원칙)
4. [데이터 흐름](#데이터-흐름)

---

## 전체 구조

```
Projects/
├── App/                        # 앱 진입점
│   ├── Sources/
│   │   ├── TwixApp.swift      # @main
│   │   ├── AppRootReducer.swift
│   │   └── AppRootView.swift
│   └── Resources/
│
├── Feature/                    # 기능 모듈 (UI + 비즈니스 로직)
│   ├── Auth/                  # 현재 App 직접 조립 예외 Feature
│   ├── Onboarding/            # 현재 App 직접 조립 예외 Feature
│   ├── MainTab/               # 현재 App 직접 조립 예외 Feature
│   └── Sources/               # 현재 Feature Root / re-export layer
│
├── Domain/                     # 도메인 로직
│   └── Auth/
│
├── Core/                       # 핵심 인프라
│   ├── Network/
│   └── Logging/
│
└── Shared/                     # 공통 유틸
    ├── DesignSystem/
    └── ThirdPartyLib/
```

---

## 계층별 역할

### App 계층
- 앱의 진입점 (`@main`)
- Feature들을 조립하여 최종 앱 구성
- AppRootReducer에서 화면 전환 관리

### Feature 계층
- UI + 비즈니스 로직
- Interface/Sources 분리
- Interface 모듈은 외부에 노출되는 public boundary입니다.
- Sources 모듈은 구현 세부사항을 숨기는 implementation layer입니다.
- 다른 Feature/App/상위 조립 계층은 일반적으로 implementation Sources가 아니라 Interface 모듈에 의존합니다.
- 독립적으로 실행 가능 (Example 타겟)

### Domain 계층
- 도메인 모델 (Entity, VO)
- 비즈니스 규칙
- Feature와 독립적

### Core 계층
- 네트워크, 로깅 등 인프라
- Feature에서 사용하는 공통 기능
- Core/Network, Core/Storage는 singleton을 사용하지 않고 DI 가능한 구조로 제공합니다.

### Shared 계층
- 디자인 시스템
- 써드파티 라이브러리 래핑

---

## 핵심 원칙

### 1. Interface/Implementation 분리

```
Feature/{Feature}/
├── Interface/Sources/          # 외부 공개 계약(public boundary)
└── Sources/                    # 실제 구현(implementation details)
```

Interface 모듈은 public reducer/state/action, client, factory, dependency key 등 외부 조립에 필요한 공개 계약을 제공합니다. Sources 모듈은 View, live 구현, reducer 세부 로직 등 구현 세부사항을 숨깁니다.

소비자는 특별한 예외가 없는 한 implementation Sources가 아니라 Interface 모듈에 의존해야 합니다. 구현 모듈을 직접 import하는 것은 모듈 경계를 약화시키므로, 문서화된 예외 또는 명시적 승인 없이 새로 도입하지 않습니다.

**장점**:
- 빌드 시간 최적화
- 의존성 최소화
- 테스트 용이

**예외 (App 직접 조립 Feature)**:
- Auth / Onboarding / MainTab은 App에서 직접 Path를 관리하는 중간 관리자 Feature로 취급합니다.
- 현재 경로는 각각 `Projects/Feature/Auth/`, `Projects/Feature/Onboarding/`, `Projects/Feature/MainTab/`입니다.
- 현재 `Projects/Feature/Sources/Source.swift`는 Feature Root / re-export layer로 사용됩니다.
- 위 경로는 현재 코드베이스 관찰값이며, 그 자체가 모든 신규 구조의 이상적인 형태임을 의미하지는 않습니다.
- 위 Feature는 Interface/Implementation 분리 및 ViewFactory 강제 규칙에서 예외입니다.
- App은 위 Feature를 `makeView(_:)` 없이 직접 조립할 수 있습니다.
- 위 Feature는 내부 하위 Feature 조립 시 Implementation 모듈을 직접 import 할 수 있습니다.
- 위 Feature는 자식 Feature를 Interface-only `makeView(_:)` 대신 직접 생성할 수 있습니다.

**그 외 Feature**:
- Interface 모듈만 import합니다.
- 외부 조립은 Interface layer의 `makeView(_:)` 또는 동등한 factory를 통해서만 이뤄집니다.

### 2. Dependency Injection

모든 의존성은 TCA Dependency Container로 주입합니다.
- 모든 모듈에서 TCA Dependency Container를 사용합니다.
- 계층 간 연결은 Interface 모듈만 노출하며, liveValue는 Implementation 모듈에서 제공합니다.
- 서로 다른 계층(Feature / Domain / Core) 간 참조는 Interface만으로 해결 가능한지 먼저 검증합니다.
- Interface만으로 불가능한 implementation 의존은 명확한 구조적 이유가 있을 때만 허용합니다.
- 의존성 조립은 App/Feature Root에서 `.withDependency`로 명시적으로 수행합니다.
- Feature Root에서 타입 재노출이 필요할 경우 public boundary를 해치지 않도록 Interface 타입 재노출을 우선합니다.
```swift
@Dependency(\.authLoginClient) var authLoginClient
```

### 3. ViewFactory 패턴

View를 직접 노출하지 않고 Factory로 생성:
```swift
@Dependency(\.authViewFactory) var authViewFactory
authViewFactory.makeView(store)
```

### 4. Token 접근 경계

토큰 접근은 현재 `TokenManager` 패턴을 통해 중재합니다.

- `TokenManager`: `Projects/Domain/Auth/Interface/Sources/TokenManager.swift`
- Token storage interface: `Projects/Core/Storage/Interface/Sources/TokenStorageProtocol.swift`
- Keychain implementation: `Projects/Core/Storage/Sources/KeychainTokenStorage.swift`
- 현재 Authorization header 처리 패턴: `Projects/Domain/Auth/Sources/AuthInterceptor.swift`가 `TokenManager`를 사용합니다.
- 현재 App/root wiring: `Projects/App/Sources/View/TwixApp.swift`에서 live token storage dependency를 설정합니다.

Feature, Reducer, View, 일반 Client, request-building code는 `TokenStorageClient`, `TokenStorageProtocol`, `KeychainTokenStorage`, Keychain, UserDefaults 등 token persistence에 직접 접근하지 않습니다. 토큰 조회/저장/삭제/refresh-state 전환 및 access token 조회는 `TokenManager`를 통해 수행합니다.

직접 TokenStorage 사용은 `TokenManager` 내부, Core Storage interface/implementation, App/root dependency wiring, tests/mocks, 그리고 `TokenManager`에 의존하는 승인된 auth infrastructure로 제한합니다.

---

## 데이터 흐름

```
사용자 → View → Action → Reducer → State 변경 → View 업데이트
                   ↓
              Effect (비동기 작업)
                   ↓
              새로운 Action
```

**예시: 로그인 플로우**

```
1. 사용자가 "Apple로 로그인" 버튼 탭
   ↓
2. AuthView: store.send(.appleLoginButtonTapped)
   ↓
3. AuthReducer: state.isLoading = true
   ↓
4. Effect: authLoginClient.login(.apple)
   ↓
5. 성공 시: send(.loginResponse(.success(result)))
   ↓
6. AuthReducer: return .send(.delegate(.loginSucceeded))
   ↓
7. AppRootReducer: state.path = .mainTab(...)
   ↓
8. MainTabView 렌더링
```

---

## 다음 단계

- [구현 체크리스트](../Reference/Checklists.md) - Feature 구현 확인 항목
- [파일 구조화 규칙](../Reference/FileOrganization.md) - 파일 분리 및 Interface 파일 정책
- [네이밍 규칙](../Reference/NamingConventions.md) - Action, File, 타입 네이밍
- [프로젝트 규칙](../Reference/ProjectRules.md) - 팀 합의사항

---

**작성일**: 2026-01-12
