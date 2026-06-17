# Pass 3 — Measurement target coverage

베이스라인 재수집 **전** 에 작성한 target 인벤토리. 목표는 Home 한 화면이 아니라
사용자가 실제로 체감하는 UI Rendering / Interaction delay / Hitch 를 앱 전반에서
수치화하는 것. Authoritative metric = real device Time Profiler + Animation Hitches.

## Coverage table

| Priority | Area | Feature/Example Scheme | Target View | User/VoC Reason | Scenario Candidate | Data/Seed Needed | Current Coverage | Gap | Phase |
|---|---|---|---|---|---|---|---|---|---|
| P0 | Home | `FeatureHomeExample` | `HomeView` (LazyVStack feed) | hub 화면 + LazyVStack heavy scroll baseline | feed scroll 50 drag (window-normalized) | `home-heavy` (200 cells) ✓ | 드라이버 + identifier 모두 있음 (`pass3-rendering-before` tag) | 없음 — 좌표 fix 후 baseline 재수집만 | **Phase 1** |
| P0 | Home | `FeatureHomeExample` | `HomeView` 전체 | same-screen state-change 시 list 무효화 비용 | calendar week sweep (`weekCalendarSwipe` → `setCalendarDate` cascade) | `home-heavy` | `feature.home.calendar` identifier + 드라이버 ✓ | 없음 — 새 baseline 으로 재수집만 | **Phase 1** |
| P0 | GoalDetail | `FeatureGoalDetailExample` | `ReactionBarView` + `FlyingReactionOverlay` | "GoalDetailView 가 굉장히 무겁게 느껴짐" (직접 체감) | reaction button tap 반복 → flying particle 30개 × 1.05–1.55s × TimelineView 60Hz | reactions seed 불필요 (탭마다 30 particle 즉시 emit) | Example app ✓ + perfRoot ✓ + perfReadyMarker ✓. ReactionButton identifier ✗, rendering test ✗ | 6 emoji 버튼에 `perfControl` 추가 (또는 coordinate-tap), 새 `GoalDetailExampleRenderingTests` | **Phase 1** |
| P0 | GoalDetail | `FeatureGoalDetailExample` | `GoalDetailView` initial render | 진입 직후 무거움 체감 | cold initial render trace (xctrace launch + driver wait-ready) | seed 불필요 | ColdLaunchTests ✓ (이미 Pass 2 측정됨) | 없음 — 재측정만 새 baseline 으로 | **Phase 1** |
| P0 | GoalDetail | `FeatureGoalDetailExample` | `FlyingReactionOverlay.TimelineView` | idle CPU 0.12% 상시 점유 (Pass 2 확인) | idle scenario (탭 없이 N초 대기) | seed 불필요 | 없음 | 새 `testRendering_goalDetailIdle` (launch → ready → 8s 대기 → 종료) | **Phase 1** (cheap) |
| P0 | ProofPhoto | `FeatureProofPhotoExample` | `ProofPhotoView` preview + comment | VoC/체감 — 사진 업로드 전 UI 느림 | preview rendering with prefilled `imageData` (서버 / OS picker 우회) | initial State 에 `imageData: Data` 사전 주입 OR `proof-photo-prefilled` seed | Example app ✓ + perfRoot ✓ + perfReadyMarker ✓. PERF seed 분기 ✗, rendering test ✗ | ProofPhotoApp 에 fixture image inject (예: 1024x1024 jpg) + 새 RenderingTests | **Phase 1** |
| P0 | ProofPhoto | `FeatureProofPhotoExample` | `TXCommentCircle` (5글자) | comment 작성 + keyboard inset + TimelineView 커서 animation | comment focus on → 5글자 typing → focus off | imageData 사전 주입 (위와 동일) | 키보드 진입 driver + Text typing | 위 fixture 의 후속 step | **Phase 1** |
| P0 | Stats | `FeatureStatsExample` | `StatsView` (LazyVStack) | Home 과 동일 패턴, 이미 인프라 있음 | heavy scroll (현 `scroll-50` 시나리오 재사용 또는 `scroll-heavy` 200 cells) | `scroll-50` ✓, `stats-heavy` (200) 추가 권고 | ScrollTests ✓ + ColdLaunchTests ✓ + SmokeTests ✓ + NavigationTests ✓ | `stats-heavy` 200-cell seed (선택), Time Profiler/Hitches baseline 으로 첫 측정 | **Phase 1** |
| P0 | Stats | `FeatureStatsExample` | `StatsView` cold render | 진입 시 rendering 비용 | cold launch trace | seed 불필요 | ColdLaunchTests ✓ | 없음 — 새 baseline 으로 측정만 | **Phase 1** |
| P1 | GoalDetail | `FeatureGoalDetailExample` | `GoalDetailView` detail content scroll | 향후 photo-log scrollable 추가 시 | scroll driver (Home 패턴) | scrollable content 구조 필요 | View 가 VStack 만 — ScrollView 미보유 | view 구조 변경 필요 → **Phase 2 follow-up** | **Phase 2** |
| P1 | Stats | `FeatureStatsExample` | `StatsDetailView` calendar swipe | dateCellBackground (inline AnyView + `completedDate(for:)`) 가 Pass 1 smell inventory hot 후보 | calendar month swipe (production action) | 기존 client | `feature.stats.calendar` identifier ✗, rendering test ✗ | identifier 추가 + 새 test | **Phase 1.5** |
| P2 | Settings | `FeatureSettingsExample` | `SettingsView.displayProfileContent` `Text(store.nickname)` | "닉네임이 늦게 뜬다" 체감 | onAppear → `fetchMyProfile` → state.nickname 갱신 transition | `authClient.fetchMyProfile` 에 deterministic delay (예: 500ms) 주입 + nickname `perfStateMarker` | Example app ✓ + perfRoot ✓. nickname marker ✗, delayed mock ✗ | (a) Example 의 authClient override 에 delay (b) `Text(store.nickname)` 에 `perfStateMarker`. **단 rendering signal 작음 — interaction-delay probe 성격** | **Phase 1.5** (honest: 측정 가치 작음, network-latency probe 로 기록) |
| —  | Auth | `FeatureAuthExample` | — | 이번 VoC 우선순위 아님 | — | — | Example app + smoke 있음 | — | **Excluded** |
| —  | Onboarding | `FeatureOnboardingExample` | — | 이번 VoC 우선순위 아님 | — | — | Example app + smoke 있음 | — | **Excluded** |
| —  | ProofPhoto | — | 실제 PHPicker / camera permission flow | OS picker / 권한 popup 측정 | OS-level UI 측정 | PHPickerResultClient 신규 protocol 등 | 부재 | scope 확장 → **Phase 2** | **Phase 2** |
| —  | All | — | SwiftUI template trace | view-tree work 직접 가시화 | launch 모드 + signpost env var | xctrace --launch + UITest driver 동시 attach 필요 | attach 모드에서 "no SwiftUI data" 확인됨 | launch-mode 자동화 인프라 필요 → **Phase 2** | **Phase 2** |

## Phase 1 included targets

확장된 Phase 1 measurement pack (재수집 또는 신규 + 작은 인프라 추가 허용):

1. **Home feed scroll** — `pass3-rendering-before` 새 tag 기준 재수집
2. **Home calendar week sweep** — 재수집
3. **GoalDetail reaction-tap rapid fire** — 신규 (identifier + test)
4. **GoalDetail initial render** — 기존 ColdLaunchTests 활용 (xctrace 측정만)
5. **GoalDetail idle (8s)** — 신규 짧은 test (FlyingReactionOverlay TimelineView idle CPU 측정)
6. **ProofPhoto preview + comment with prefilled image** — 신규 (fixture inject + test)
7. **Stats heavy scroll** — 기존 ScrollTests 재사용 (`scroll-heavy` 200-cell seed 추가 권고)
8. **Stats cold render** — 기존 ColdLaunchTests 활용

총 8 시나리오 × Time Profiler + Animation Hitches × 3 reps = **48 traces** (각 ~70s 드라이버 + ~50s xctrace = 약 90 분 실측 + 분석).

## Phase 1.5 targets

- **Stats calendar month swipe** — StatsDetailView 에 `feature.stats.calendar` identifier 추가 + 새 test (Home calendar sweep 패턴 복제)
- **Settings nickname delayed transition** — authClient mock delay + nickname marker + 새 test. **honest 한계**: 단일 Text update 는 rendering signal 작음, "network latency / loading transition probe" 로 분류

## Phase 2 (defer)

- **SwiftUI template launch-mode 자동화** — env var + launch-mode + UITest 동시 driver 파이프라인 연구
- **ProofPhoto 실제 OS picker / 카메라 권한 flow** — PHPickerResultClient 같은 mock protocol 신규
- **GoalDetail photo-log scrollable content** — view 구조 변경
- **Auth / Onboarding** — 별도 VoC 발생 시
- **StatsDetailView dateCellBackground 최적화** — Pass 1 smell inventory 의 inline AnyView 제거 (rendering 측정이 아니라 코드 cleanup)

## Honest caveats

1. **Settings nickname**: 단일 Text 의 1회성 state transition 은 Time Profiler trace 에서 의미 있게 잡히지 않을 가능성 큼. Animation Hitches 의 interaction-delay 항목으로 "ready marker 늦게 뜸" 정도가 캡처 가능. **렌더링 최적화** 가 아닌 **로딩 지연 측정** 으로 framing 필요.
2. **GoalDetail scrollable content 부재**: detail view 는 ScrollView 없음 → scroll-based rendering scenario 자체가 불가능. reaction-tap 의 flying particle animation + TimelineView 60Hz 가 유일한 heavy rendering 신호.
3. **SwiftUI template 미해결**: Phase 1 의 authoritative metric 은 **Time Profiler + Animation Hitches** 두 가지로 한정. SwiftUI signpost trace 는 Phase 2 로 이연. 이 한계 final report 에 명시 필요.
4. **48 traces 의 시간 비용**: device 에서 측정 시 약 90분. 측정 도중 device 가 sleep / 충전 / 통화 등 외부 영향 없도록 주의. 실패한 rep 는 폐기 후 재수집.

## Recommendation

**Now (baseline 재수집 전 마지막 단계)**:
1. Phase 1 의 신규 인프라 (GoalDetail reaction identifier, ProofPhoto fixture inject, idle test) 를 1–2 commit 으로 추가.
2. Stats `scroll-heavy` seed 추가 (선택, 큰 비용 아님).
3. 모든 신규 driver test 가 sim + device 단독 실행 OK 인지 확인.
4. **그 다음** 8 시나리오 × 2 template × 3 reps = 48 traces 일괄 수집.
5. workspace 에 `pass3-before-pack.md` 로 baseline 표 정리.

**Defer to Phase 1.5 (베이스라인 1차 완료 후)**:
- Stats calendar swipe scenario
- Settings nickname loading scenario (honest "loading-delay probe" framing)

**Phase 2** 는 향후 별도 작업.

## What NOT to do (지침)

- 측정 전에 최적화 commit 진입 금지
- 좌표 버그 fix 전후 trace 섞기 금지
- Production App E2E / login / onboarding 진입 금지
- 실제 OS picker / 카메라 권한 / 서버 업로드 측정 금지
- SwiftUI template launch-mode 자동화에 시간 쏟지 말 것 (Phase 2)
- Auth/Onboarding 측정 금지 (별도 VoC 시 추가)
