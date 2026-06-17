# UI Rendering Perf Infrastructure

이 문서는 Feature Example 앱에 seed 기반 UITest와 `xctrace` 측정을 추가하기 위한 공통 인프라 사용법입니다. 현재 범위는 smoke UITest와 Time Profiler launch 검증까지이며, 실제 `measure(metrics:)` 성능 시나리오는 다음 작업에서 추가합니다.

## Targets

측정 대상 Example 앱:

| Feature | Example scheme | Bundle ID | UITest target |
| --- | --- | --- | --- |
| Auth | `FeatureAuthExample` | `org.yapp.twix.example.auth` | `FeatureAuthExampleUITests` |
| GoalDetail | `FeatureGoalDetailExample` | `org.yapp.twix.example.goal-detail` | `FeatureGoalDetailExampleUITests` |
| Home | `FeatureHomeExample` | `org.yapp.twix.example.home` | `FeatureHomeExampleUITests` |
| MainTab | `FeatureMainTabExample` | `org.yapp.twix.example.main-tab` | `FeatureMainTabExampleUITests` |
| MakeGoal | `FeatureMakeGoalExample` | `org.yapp.twix.example.make-goal` | `FeatureMakeGoalExampleUITests` |
| Notification | `FeatureNotificationExample` | `org.yapp.twix.example.notification` | `FeatureNotificationExampleUITests` |
| Onboarding | `FeatureOnboardingExample` | `org.yapp.twix.example.onboarding` | `FeatureOnboardingExampleUITests` |
| ProofPhoto | `FeatureProofPhotoExample` | `org.yapp.twix.example.proof-photo` | `FeatureProofPhotoExampleUITests` |
| Settings | `FeatureSettingsExample` | `org.yapp.twix.example.settings` | `FeatureSettingsExampleUITests` |
| Stats | `FeatureStatsExample` | `org.yapp.twix.example.stats` | `FeatureStatsExampleUITests` |

`Common`은 Example target이 없는 의도된 예외입니다.

## Launch Contract

Example 앱은 `SharedPerfTestingSupport.UITestMode`를 통해 다음 launch arguments를 읽습니다.

```text
-UITEST
-UITEST_SEED <name>
-UITEST_DISABLE_ANIMATIONS
-UITEST_WAIT_READY
```

공통 helper:

```swift
let app = XCUIApplication.launchForPerf(seed: "default")
waitForFeatureReady("home")
```

Seed별 fixture가 필요한 경우:

- Example 앱 내부에서 `UITestMode.seedName`을 switch합니다.
- 기존 `Testing` 모듈이 있는 Feature는 `Feature...Testing`에 seed 이름 또는 mock helper를 추가합니다.
- Testing 모듈이 없는 Auth, MainTab, Notification, Settings는 새 Testing 모듈을 만들지 말고 Example target 내부 fixture를 사용합니다.

## Accessibility Contract

식별자 형식:

```text
feature.<slug>.root
feature.<slug>.feed
feature.<slug>.cell.<stableId>
feature.<slug>.<element>
feature.<slug>.ready
```

현재 smoke UITest는 Feature당 정확히 하나이며 `feature.<slug>.ready`만 기다립니다. 성능 시나리오를 추가할 때 화면별 feed, cell, control identifier를 확장합니다.

## Build Configuration

Tuist 모듈 프로젝트는 `Debug`, `Release`, `Profile`, `PerfProfile` configuration을 생성합니다. `Profile`과 `PerfProfile`은 Release 계열이며 Time Profiler 분석을 위해 다음 값을 유지합니다.

```text
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
COPY_PHASE_STRIP = NO
STRIP_INSTALLED_PRODUCT = NO
```

`PerfProfile`은 Pass 3/Pass 4 perf UITest와 xctrace 측정 전용입니다. `Profile`과 동일한 Release-like 설정에 `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) PERF_TESTING`만 추가합니다. `SharedPerfTestingSupport`의 accessibility marker / counter modifier는 `PERF_TESTING`이 켜진 빌드에서만 실제 marker를 붙이고, 일반 `Profile`/`Release`에서는 no-op입니다.

Production 앱 signing은 기존 manual/match 설정을 유지합니다. Example 앱과 Example UITest target만 automatic signing을 사용합니다.

## Verification Commands

먼저 프로젝트를 생성합니다.

```bash
tuist generate
```

이 작업은 direct `xcodebuild`를 사용하는 perf infra 검증이므로 scheme/configuration/destination 형식을 명시합니다. 실기기 destination 값은 로컬 기기에 맞게 지정해야 합니다.

```bash
xcodebuild test \
  -scheme FeatureHomeExample \
  -configuration PerfProfile \
  -destination 'platform=iOS,name=<DEVICE_NAME>' \
  -only-testing:FeatureHomeExampleUITests
```

전체 Example의 Time Profiler launch smoke는 실기기에서만 실행합니다.

```bash
DEVICE_NAME='<DEVICE_NAME>' Scripts/verify-perf-targets.sh
```

SwiftUI template 기반 profiling은 simulator에서 신뢰할 수 없으므로 실기기 검증만 지원합니다.

## Known Issues

- `FeatureOnboardingExample`은 entitlements를 사용합니다. Automatic signing에서 associated domains 등 provisioning 누락이 발생하면 target, 누락 entitlement, Xcode signing error를 이 문서에 추가하고 owner가 Apple Developer portal capability를 확인해야 합니다.
- 이 인프라는 launch/readiness smoke만 제공합니다. 실제 render scenario, baseline/after 비교, 리포트 생성, 성능 개선은 별도 작업입니다.
