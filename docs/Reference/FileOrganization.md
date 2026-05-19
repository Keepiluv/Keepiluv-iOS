# 파일 분리 및 구조화 규칙

> 코드베이스의 파일 구조화 원칙과 타입 분리 기준을 정의합니다.

## 📌 핵심 원칙

### 1. One Type Per File (예외 있음)

**기본 규칙**: 하나의 파일에는 하나의 주요 타입만 정의합니다.

Interface 모듈도 예외가 아닙니다. Interface 모듈은 public API를 외부에 노출하는 boundary이지만, 이것이 모든 public 타입을 반드시 하나의 `Source.swift` 파일에 모아야 한다는 뜻은 아닙니다.

**목적**:
- 파일 이름만으로 내용 파악 가능
- 코드 탐색 및 유지보수 용이
- Git 충돌 감소
- 명확한 책임 분리

### 2. 응집도 우선

**Private helper types는 owner와 함께 유지합니다.**

잘못된 예:
```swift
// ❌ AuthEndpoint.swift
enum AuthEndpoint: Endpoint {
    // ...
}

// ❌ Configuration.swift - 불필요한 분리
private enum Configuration {  // AuthEndpoint에서만 사용
    // ...
}
```

올바른 예:
```swift
// ✅ AuthEndpoint.swift
enum AuthEndpoint: Endpoint {
    // ...
}

// Private helper는 함께 유지
private enum Configuration {
    static var apiBaseURL: String? { ... }
}

private struct SignInRequest: Encodable {
    // ...
}
```

### 3. TCA Nested Types는 유지

**TCA의 State, Action은 Reducer와 함께 유지합니다.**

```swift
// ✅ AppRootReducer.swift
@Reducer
struct AppRootReducer {
    @ObservableState
    struct State {  // ← Reducer와 함께 유지
        var isLoggedIn: Bool
    }

    enum Action {   // ← Reducer와 함께 유지
        case login
        case logout
    }

    var body: some ReducerOf<Self> {
        // ...
    }
}
```

**이유**: TCA 표준 패턴이며, State/Action/Reducer는 하나의 단위로 이해되어야 함

### 4. Interface 모듈은 public boundary

**Interface 모듈은 외부 소비자가 의존하는 public boundary입니다.**

- public reducer/state/action, client, factory, dependency key 등 외부 조립에 필요한 계약을 노출합니다.
- Sources 모듈의 View, live 구현, reducer 세부 로직 등 implementation details를 숨깁니다.
- 소비자는 특별한 예외가 없는 한 implementation Sources가 아니라 Interface 모듈에 의존해야 합니다.
- 새로 만들거나 크게 수정하는 Interface 모듈은 One Type Per File을 우선 적용합니다.
- 기존 `Interface/Sources/Source.swift` 파일은 legacy/compatibility 패턴으로 유지할 수 있습니다.
- 기존 모듈을 수정할 때는 주변 패턴을 따르되, public API가 불명확해지거나 architecture boundary를 약화시키면 One Type Per File로 정리합니다.

이전 문서의 `Interface/Sources/Source.swift` 예시는 “Interface 모듈을 통해 public interface 타입을 노출한다”는 의미였으며, 모든 public 타입을 하나의 파일에 강제한다는 의미가 아닙니다.

---

## 🎯 분리 vs 유지 결정 기준

### 분리해야 하는 경우

#### 1. Internal/Public 타입이 외부에서 사용될 때

**예제: SignInResponse 분리**

Before:
```swift
// ❌ AuthEndpoint.swift (143줄, 4개 타입)
enum AuthEndpoint: Endpoint { ... }
private enum Configuration { ... }
private struct SignInRequest: Encodable { ... }
struct SignInResponse: Decodable { ... }  // ← AuthClient+Live.swift에서 사용
```

After:
```swift
// ✅ AuthEndpoint.swift (111줄, 3개 타입)
enum AuthEndpoint: Endpoint { ... }
private enum Configuration { ... }
private struct SignInRequest: Encodable { ... }

// ✅ DTO/SignInResponse.swift (32줄, 1개 타입)
struct SignInResponse: Decodable { ... }
```

**판단 기준**:
- `SignInResponse`는 `AuthClient+Live.swift`에서 사용됨 (외부 의존성)
- `Configuration`과 `SignInRequest`는 `AuthEndpoint` 내부에서만 사용 (private)
- DTO는 엔드포인트와 별개의 관심사

#### 2. 서로 다른 레이어/책임을 가질 때

**예제: NetworkProviderProtocol 분리**

Before:
```swift
// ❌ NetworkProviderProtocol.swift (70줄, 3개 타입)
public protocol NetworkProviderProtocol: Sendable {
    func request<T: Decodable>(endpoint: Endpoint) async throws -> T
}

public struct NetworkClient: Sendable {  // ← TCA 전용 래퍼
    // ...
}

extension NetworkClient: TestDependencyKey { ... }
extension DependencyValues { ... }
```

After:
```swift
// ✅ NetworkProviderProtocol.swift (26줄, 1개 타입)
public protocol NetworkProviderProtocol: Sendable {
    func request<T: Decodable>(endpoint: Endpoint) async throws -> T
}

// ✅ NetworkClient.swift (44줄, 3개 타입)
public struct NetworkClient: Sendable { ... }
private struct UnimplementedNetworkProvider: NetworkProviderProtocol { ... }
extension NetworkClient: TestDependencyKey { ... }
extension DependencyValues { ... }
```

**판단 기준**:
- `NetworkProviderProtocol`: 순수 인터페이스 정의
- `NetworkClient`: TCA 전용 의존성 클라이언트
- 서로 다른 책임 → 분리

#### 3. 레이어가 다를 때 (UIKit vs SwiftUI)

**예제: ShakeDetector 분리**

Before:
```swift
// ❌ ShakeDetector.swift (130줄, 7개 타입)
extension Notification.Name { ... }
class ShakeDetectingViewController: UIViewController { ... }
struct ShakeDetectingView: UIViewControllerRepresentable { ... }
struct ShakeDetectorModifier: ViewModifier { ... }
struct ShakeDetectingHostingView: UIViewControllerRepresentable { ... }
class ShakeDetectingHostingController: UIViewController { ... }
extension View { ... }
```

After:
```swift
// ✅ ShakeDetectingUIKit.swift (55줄, 3개 타입)
#if DEBUG
import UIKit
import Foundation

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

class ShakeDetectingHostingController: UIViewController { ... }
class ShakeDetectingViewController: UIViewController { ... }  // deprecated
#endif

// ✅ ShakeDetectorModifier.swift (75줄, 4개 타입)
#if DEBUG
import SwiftUI
import UIKit

struct ShakeDetectorModifier: ViewModifier { ... }
struct ShakeDetectingHostingView: UIViewControllerRepresentable { ... }
struct ShakeDetectingView: UIViewControllerRepresentable { ... }  // deprecated

public extension View {
    func detectShakeForPulse(label: String = "Global") -> some View { ... }
}
#endif
```

**판단 기준**:
- UIKit 관련 타입: `ShakeDetectingUIKit.swift`
- SwiftUI 관련 타입 + Public API: `ShakeDetectorModifier.swift`
- 레이어별 분리로 의존성 명확화

### 유지해야 하는 경우

#### 1. Private 타입이 owner에서만 사용될 때

```swift
// ✅ AuthEndpoint.swift
enum AuthEndpoint: Endpoint {
    // ...
}

// Private helper는 함께 유지
private enum Configuration {
    static var apiBaseURL: String? { ... }
}

private struct SignInRequest: Encodable {
    // AuthEndpoint에서만 사용되는 request DTO
}
```

**이유**: 응집도 유지, 구현 디테일 숨김

#### 2. 작은 helper 타입 (< 10줄)

```swift
// ✅ ShakeDetectorModifier.swift
struct ShakeDetectorModifier: ViewModifier {
    // ...
}

// 6줄짜리 helper는 함께 유지
struct ShakeDetectingHostingView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ShakeDetectingHostingController {
        ShakeDetectingHostingController()
    }

    func updateUIViewController(_ uiViewController: ShakeDetectingHostingController, context: Context) {}
}
```

**이유**: 과도한 파일 분리 방지 (6줄을 별도 파일로 만들 필요 없음)

#### 3. TCA TestDependencyKey stub

```swift
// ✅ NetworkClient.swift
public struct NetworkClient: Sendable {
    // ...
}

// Stub은 클라이언트와 함께 유지
private struct UnimplementedNetworkProvider: NetworkProviderProtocol {
    func request<T: Decodable>(endpoint: Endpoint) async throws -> T {
        assertionFailure("NetworkClient.request is unimplemented")
        throw NetworkError.unknownError
    }
}

extension NetworkClient: TestDependencyKey {
    public static let testValue = Self(provider: UnimplementedNetworkProvider())
}
```

**이유**: TCA 패턴에서 stub은 클라이언트 정의의 일부

#### 4. TCA Reducer의 State/Action

```swift
// ✅ AppRootReducer.swift
@Reducer
struct AppRootReducer {
    @ObservableState
    struct State {  // ← 분리하지 않음
        var isLoggedIn: Bool
    }

    enum Action {   // ← 분리하지 않음
        case login
    }

    var body: some ReducerOf<Self> {
        // ...
    }
}
```

**이유**: TCA 표준 패턴, Reducer/State/Action은 하나의 단위

---

## 📁 디렉토리 구조화 패턴

### 1. DTO 패턴

여러 DTO가 있을 경우 `DTO/` 서브디렉토리 생성:

```
Projects/Domain/Auth/Sources/
├── AuthEndpoint.swift
├── AuthClient.swift
└── DTO/
    ├── SignInResponse.swift
    ├── SignUpResponse.swift
    └── RefreshTokenResponse.swift
```

### 2. 레이어 분리 패턴

UIKit과 SwiftUI가 혼재된 경우 파일명으로 구분:

```
Projects/Core/Logging/Sources/
├── ShakeDetectingUIKit.swift       # UIKit 관련
├── ShakeDetectorModifier.swift     # SwiftUI 관련
└── PulseNetworkLogViewProvider.swift
```

### 3. Interface/Implementation 패턴

Interface 모듈은 public boundary, Sources 모듈은 implementation layer입니다. 새로 만들거나 크게 수정하는 Interface 모듈은 One Type Per File을 우선합니다.

```
Projects/Core/Network/
├── Interface/
│   └── Sources/
│       ├── NetworkProviderProtocol.swift  # public protocol/contract
│       └── NetworkClient.swift            # public TCA Client
└── Sources/
    └── NetworkProvider.swift              # 실제 구현
```

기존 `Interface/Sources/Source.swift` 파일은 compatibility 목적으로 유지할 수 있지만, 신규 public 타입을 추가할 때는 주변 패턴과 public API 명확성을 함께 고려합니다.

---

## ⚠️ 주의사항

### 1. Backward Compatibility 유지

파일 분리 시 기존 코드가 깨지지 않도록 보장:

✅ **같은 모듈 내에서만 분리**
- `import DomainAuth`로 `SignInResponse` 접근 가능 (파일 위치 무관)
- Swift 컴파일러가 자동으로 파일 순서 처리

✅ **Access level 유지**
- Internal 타입은 internal로 유지
- Public 타입은 public으로 유지

❌ **Module 경계를 넘는 분리는 신중하게**
- 다른 모듈로 이동 시 import 수정 필요
- 순환 의존성 발생 가능

### 2. Legacy Code 처리

**즉시 삭제하지 말고 deprecated 표시:**

```swift
@available(*, deprecated, message: "Use ShakeDetectorModifier directly")
class ShakeDetectingViewController: UIViewController {
    // ... legacy implementation
}
```

**이유**:
- 다른 브랜치에서 사용 중일 수 있음
- 점진적 마이그레이션 가능
- 명확한 deprecation 경로 제공

### 3. Import 최소화

파일 분리 후 불필요한 import 제거:

Before:
```swift
// ❌ NetworkProviderProtocol.swift
import Foundation
import ComposableArchitecture  // ← NetworkClient 분리 후 불필요

public protocol NetworkProviderProtocol: Sendable { ... }
```

After:
```swift
// ✅ NetworkProviderProtocol.swift
import Foundation  // ← 필요한 것만 import

public protocol NetworkProviderProtocol: Sendable { ... }
```

### 4. #if DEBUG 조건부 컴파일

분리된 파일에도 동일한 조건 유지:

```swift
// ✅ ShakeDetectingUIKit.swift
#if DEBUG
import UIKit
import Foundation

// ... 모든 코드 ...

#endif
```

---

## 📋 체크리스트

파일 분리 시 다음을 확인하세요:

### 분리 전
- [ ] 파일이 여러 타입을 포함하는가?
- [ ] 각 타입의 책임과 의존성을 분석했는가?
- [ ] Private vs Internal/Public 타입을 구분했는가?
- [ ] 외부 의존성이 있는 타입을 식별했는가?

### 분리 중
- [ ] Private 타입은 owner와 함께 유지했는가?
- [ ] TCA State/Action은 Reducer와 함께 유지했는가?
- [ ] 작은 helper 타입(<10줄)은 함께 유지했는가?
- [ ] 파일 이름이 내용을 명확히 나타내는가?
- [ ] Access level을 동일하게 유지했는가?
- [ ] 불필요한 import를 제거했는가?

### 분리 후
- [ ] 필요한 경우 `tuist generate` 성공하는가?
- [ ] 빌드 검증이 필요한 경우, 알려진 scheme/destination/configuration으로 검증했는가?
- [ ] 빌드 명령을 알 수 없는 경우 검증 제한을 보고했는가?
- [ ] 기존 코드가 정상 작동하는가?
- [ ] Public API가 변경 없이 작동하는가?
- [ ] Git status로 의도한 파일만 변경되었는지 확인했는가?

---

## 🔍 실제 사례

### Case 1: AuthEndpoint.swift 분리

**상황**: 143줄 파일에 4개 타입 혼재

**분석**:
- `AuthEndpoint` (enum): 메인 타입
- `Configuration` (private enum): AuthEndpoint에서만 사용
- `SignInRequest` (private struct): AuthEndpoint에서만 사용
- `SignInResponse` (struct): **AuthClient+Live.swift에서 사용** ← 외부 의존성

**결정**:
- ✅ `SignInResponse` → `DTO/SignInResponse.swift`로 분리
- ✅ `Configuration`, `SignInRequest` → `AuthEndpoint.swift`에 유지 (private)

**결과**:
- `AuthEndpoint.swift`: 111줄, 3개 타입
- `DTO/SignInResponse.swift`: 32줄, 1개 타입
- DTO 패턴 확립 (향후 SignUpResponse 등 추가 용이)

### Case 2: NetworkProviderProtocol.swift 분리

**상황**: 70줄 파일에 3개 타입, 서로 다른 책임

**분석**:
- `NetworkProviderProtocol` (protocol): 순수 인터페이스
- `NetworkClient` (struct): TCA 의존성 래퍼
- `UnimplementedNetworkProvider` (private struct): Test stub

**결정**:
- ✅ `NetworkClient` + stub + extensions → `NetworkClient.swift`로 분리
- ✅ `NetworkProviderProtocol` → `NetworkProviderProtocol.swift`에 유지

**결과**:
- `NetworkProviderProtocol.swift`: 26줄, 1개 타입 (protocol만)
- `NetworkClient.swift`: 44줄, 3개 타입 (TCA 관련만)
- TCA 패턴 명확화, import 최소화 (ComposableArchitecture 분리)

### Case 3: ShakeDetector.swift 분리

**상황**: 130줄 파일에 7개 타입, UIKit/SwiftUI 혼재

**분석**:
- UIKit: `Notification.Name`, `ShakeDetectingHostingController`, `ShakeDetectingViewController`
- SwiftUI: `ShakeDetectorModifier`, `ShakeDetectingHostingView`, `ShakeDetectingView`, `View` extension

**결정**:
- ✅ UIKit 관련 → `ShakeDetectingUIKit.swift`
- ✅ SwiftUI 관련 + Public API → `ShakeDetectorModifier.swift`
- ✅ 레거시 타입 → deprecated 표시로 유지

**결과**:
- `ShakeDetectingUIKit.swift`: 55줄, 3개 타입
- `ShakeDetectorModifier.swift`: 75줄, 4개 타입
- 레이어 분리로 의존성 명확화

---

## 📊 효과

### 코드 가독성
- ✅ 파일 이름만으로 내용 파악 가능
- ✅ 파일당 평균 줄 수 감소 (100줄 이하 유지)
- ✅ 타입별 책임 명확화

### 유지보수성
- ✅ 변경 시 영향 범위 명확
- ✅ Git conflict 감소
- ✅ Code review 범위 축소

### 확장성
- ✅ 패턴 확립 (DTO/, 레이어 분리)
- ✅ 일관된 코드 구조
- ✅ 새로운 타입 추가 시 명확한 위치

### 협업
- ✅ 파일 탐색 용이 (Xcode navigator)
- ✅ 병렬 작업 시 충돌 감소
- ✅ 코드 이해도 향상

---

## 🚫 안티 패턴

### 1. 과도한 분리

❌ **하지 마세요**:
```
// 6줄짜리 helper를 별도 파일로
ShakeDetectingHostingView.swift  // 6줄
```

✅ **대신**:
```swift
// ShakeDetectorModifier.swift
struct ShakeDetectorModifier: ViewModifier { ... }

// 작은 helper는 함께 유지
struct ShakeDetectingHostingView: UIViewControllerRepresentable {
    // 6줄
}
```

### 2. Private 타입 분리

❌ **하지 마세요**:
```
Configuration.swift  // private enum을 별도 파일로
```

✅ **대신**:
```swift
// AuthEndpoint.swift
enum AuthEndpoint: Endpoint { ... }

private enum Configuration {  // owner와 함께
    // ...
}
```

### 3. TCA Nested Type 분리

❌ **하지 마세요**:
```
AppRootState.swift
AppRootAction.swift
AppRootReducer.swift
```

✅ **대신**:
```swift
// AppRootReducer.swift
@Reducer
struct AppRootReducer {
    struct State { ... }
    enum Action { ... }
    var body: some ReducerOf<Self> { ... }
}
```

---

## 🎓 결론

### 기억할 핵심 원칙

1. **One Type Per File** (예외: private helpers, TCA nested types, 작은 helpers)
2. **응집도 우선** (긴밀하게 결합된 타입은 함께 유지)
3. **레이어 분리** (UIKit vs SwiftUI, Protocol vs Implementation)
4. **Backward Compatibility** (같은 모듈 내 분리, access level 유지)
5. **과도한 분리 지양** (100줄 이하는 분리 고려, 10줄 이하는 유지)

### 의사결정 플로우

```
파일에 여러 타입이 있는가?
  ↓ Yes
타입이 private인가?
  ↓ Yes → 함께 유지
  ↓ No
TCA Reducer의 State/Action인가?
  ↓ Yes → 함께 유지
  ↓ No
10줄 이하의 작은 helper인가?
  ↓ Yes → 함께 유지
  ↓ No
외부에서 사용되는가 OR 서로 다른 책임/레이어인가?
  ↓ Yes → 분리
  ↓ No → 함께 유지
```

---

**문서 버전**: 1.0
**작성일**: 2026-01-19
**기반**: AuthEndpoint, NetworkProviderProtocol, ShakeDetector 분리 사례
