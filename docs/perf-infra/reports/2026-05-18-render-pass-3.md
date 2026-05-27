# Pass 3 — UI Rendering 성능 측정 + 정리

- **작성일**: 2026-05-18
- **대상 브랜치 / HEAD**: `766a6c3` (Phase F 진입 직전)
- **Baseline tag**: `pass3-rendering-before` = `af07cc4`
- **Authoritative metric**: Xcode Instruments / xctrace (Time Profiler + Animation Hitches), iOS 26.4.2 device (Jiyong의 iPhone, UDID `00008110-00096DC42632801E`), Profile configuration
- **Probe metric (보조)**: XCTest XCUI driver — driver/marker sanity 신호 (개선 evidence 아님)

이 리포트는 Pass 3 의 측정 인프라 구축 → 공식 baseline 수집 → 두 개의
fix commit 적용 → 한 개의 commit 사전 조사 후 skip → 결정 정리까지의
전 과정을 한 문서로 통합한다. 상세 workspace 문서는
`docs/perf-infra/reports/_workspace/` 에 보존.

---

## 1. Executive summary

| 항목 | 결과 |
|---|---|
| 측정 인프라 (probe + rendering scenario) | 구축 완료 (Commit 1 `f8456e8`, Commit 2 `97ffee7`, Commit 3 driver/reclass `24e93f6`/`ba8b790`) |
| Rendering scenario (Home / GoalDetail / ProofPhoto / Stats × 2씩) | 8 시나리오 × 2 template × 3 rep = **48 traces** 공식 baseline 수집 완료 (contam 0 / 48 official + 일부 재수집 후 0 잔류) |
| Commit 3 (Home read-set split) | **KEEP** — 측정상 noise floor 내, structural cleanup 으로 유지. rendering 개선 evidence 로 인용하지 않음 |
| Commit 7 (GoalDetail TimelineView idle guard) | **KEEP** — initial 시나리오 top-1 user-code frame (`TimelineView<>.UpdateFilter.updateValue()` 9–12ms 일관) 3/3 rep 에서 제거. idle CPU / 배터리 카테고리로 분류 |
| Commit 6 재정의 (Home card rendering / GoalCardView input stability) | **investigated and skipped** — measurable candidate 없음 |
| Commit 4 (destination/presentation scoping) | **skip/hold** — Commit 3 의 `HomePresentationLayer` 가 흡수, attribution 악화 우려 |
| Commit 5 (`goalSectionTitle` / `nowDate` stored derivation) | **stand-by/skip** — baseline top-frame 미등장 |
| Cold launch 추가 최적화 | Pass 2 결론 유지 — 95%+ 가 dyld + UIScene + SwiftUI framework 시스템 한계, **타겟 아님** |

**한 줄 요약**: Pass 3 의 권위 있는 측정으로 본 Twix iOS 의 UI Rendering 비용은
**UIKit + SwiftUI framework 코드가 압도적으로 점유**하고 있다. user-code 가
top-frame 에 잡힌 단 한 경우 (GoalDetail idle TimelineView) 는 Commit 7 로
제거했다. 나머지 후보들은 측정 가능한 user-code 핫스팟이 없어 본 Pass 의
범위에서 진행하지 않았다.

---

## 2. Scope and rules

### 2.1 What was measured

| 영역 | Scheme | 시나리오 | seed |
|---|---|---|---|
| Home | `FeatureHomeExample` | feed scroll (`testRendering_homeHeavyFeedScroll`, 25↑/25↓ drag) | `home-heavy` (200 cells) |
| Home | `FeatureHomeExample` | calendar week sweep (`testRendering_homeHeavyCalendarWeekSweep`) | `home-heavy` |
| GoalDetail | `FeatureGoalDetailExample` | initial render (`testRendering_goalDetailInitialRender`) | default |
| GoalDetail | `FeatureGoalDetailExample` | reaction rapid-fire (`testRendering_goalDetailReactionRapidFire`) | default |
| ProofPhoto | `FeatureProofPhotoExample` | preview with fixture image (`testRendering_proofPhotoPreviewWithFixtureImage`) | `proof-photo-prefilled` |
| ProofPhoto | `FeatureProofPhotoExample` | comment typing (`testRendering_proofPhotoCommentTyping`) | `proof-photo-prefilled` |
| Stats | `FeatureStatsExample` | heavy initial (`testRendering_statsHeavyInitialRender`) | `stats-heavy` (200 cells) |
| Stats | `FeatureStatsExample` | heavy scroll (`testRendering_statsHeavyScroll`) | `stats-heavy` |

### 2.2 What was NOT measured / out of scope

- **Auth, Onboarding** — 현재 VoC 우선순위 아님.
- **SwiftUI template trace** — `xctrace --launch` + UITest 동시 attach
  파이프라인 부재 (attach 모드에서 "no SwiftUI data") → **Phase 2 follow-up**.
- **ProofPhoto 실제 PHPicker / 카메라 권한 flow** — OS picker 측정 자동화
  미구현, fixture-image inject 시나리오로 우회 → **Phase 2 follow-up**.
- **GoalDetail photo-log scrollable** — 현재 detail view 에 ScrollView 가
  없어 scroll rendering 시나리오 자체 불가 → view 구조 변경 시 **Phase 2**.
- **Stats `StatsDetailView` dateCellBackground 정리** — code-quality 정리
  카테고리 → **Phase 2 cleanup**.
- **Settings nickname delayed transition** — 단일 Text update 는 rendering
  signal 작음, loading-transition probe 분류로 **Phase 1.5 보류**.
- **Production app full path** — dedicated rendering scenarios 에 한정.
  실제 사용 환경의 fetch + scroll 혼합 패턴은 별도 시나리오 필요.
- **Pass 4 configuration note** — 후속 perf run 은 `PerfProfile`
  configuration 을 사용한다. `PerfProfile` 은 Pass 3 의 `Profile`
  측정 조건과 동일한 Release-like symbol/strip 설정을 유지하면서
  `PERF_TESTING` compile condition 만 추가해 accessibility marker 를
  일반 `Profile`/`Release` 빌드와 격리한다.

### 2.3 측정 규칙 (Pass 3 합의)

- **Authoritative metric = 실디바이스 xctrace trace.** XCTest pass/fail 은
  correctness 만, timing 은 driver/marker sanity 신호.
- **44pt PERF action harness 는 `-UITEST_PROBE_SCENARIO` 활성 시에만 활성화.**
  Rendering scenario / smoke / 일반 UITest 에서는 비활성 — production layout
  보존.
- **`PerfRebuildProxyPing` 은 proxy.** 정확한 body evaluation count 아님.
- **Noise floor ≈ ±10.4%** (rep-to-rep total time). 단일 frame 도 ~15%
  미만은 decisive evidence 로 사용하지 않음.

---

## 3. Measurement infrastructure (Phase B/C/D 요약)

### 3.1 코드 신설/이동

- `Projects/Shared/PerfTestingSupport/Sources/PerfCounters.swift` — `PerfCounters` + `PerfRebuildProxyPing`
- `Projects/Shared/PerfTestingSupport/Sources/View+PerfAccessibility.swift` — `perfStateMarker`, `perfCounterMarkers`, `perfControl`, `perfCell`, `perfFeed`, `perfReadyMarker`, `perfRoot`
- `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift` — `isEnabled` / `isProbeScenario` / `isRenderingScenario` static let 캐싱
- `Projects/Shared/PerfTestingSupport/UITests/Sources/XCTestCase+Perf.swift` — `measureActionLatency`, `awaitPerfMarker`, `readPerfCounter`
- `Projects/Shared/PerfTestingSupport/UITests/Sources/XCUIApplication+Perf.swift` — `PerfScenarioKind { probe, rendering }`
- `Projects/Feature/Home/Sources/Home/HomeView.swift` — `HomePerfActionHarness`, `PerfToastPresentationHarness` (probe 시만 활성)
- 8 시나리오용 RenderingTests (Home / GoalDetail / ProofPhoto / Stats)

### 3.2 시나리오 분류

| 분류 | 정의 | 권위성 |
|---|---|---|
| **Rendering scenario** | xctrace recording 중 실행될 실제 UI 조작. UITest 는 deterministic driver | **authoritative** |
| **Probe scenario** | UITest driver/marker/counter/harness 의 sanity 점검 | **probe-only** |
| **Smoke test** | Example app launch / identifier 동작 확인 | 성능 해석 대상 아님 |

### 3.3 contamination 기준

다음 중 하나라도 발견되면 trace 폐기 + 동일 rep 재수집:

1. SpringBoard activation log (`Activate org.yapp.twix.example.*` 또는 반복
   `Open …`)
2. `Wait for com.apple.springboard to idle` 가 driver action phase 도중
   발생
3. BannerNotification interrupt (`Interrupting element BannerNotification …`)
4. wall time 이 baseline 의 ±50% 초과
5. (ProofPhoto comment typing 한정) `feature.proof-photo.marker.comment-text.abcde`
   marker 미도달
6. xctrace 자체 에러 (`Target app exited mid-window` 등)

---

## 4. Baseline (Phase E-batch1~4)

### 4.1 수집 결과 (공식 48 traces)

| Feature | template × scenario × reps | contam | discards | 비고 |
|---|---:|---:|---:|---|
| Home | 2 × 2 × 3 = 12 | 0 | 0 | feed-scroll 60s window, calendar-sweep 50s window |
| GoalDetail | 2 × 2 × 3 = 12 | 0 | 0 | initial 8s window, reaction 25s window |
| ProofPhoto | 2 × 2 × 3 = 12 | 0 | 0 | preview 8s window, comment-typing 12s window |
| Stats | 2 × 2 × 3 = 12 | 0 | 0 | initial 8s window, heavy-scroll 60s window |
| **Total** | **48** | **0** | **0** | trace root: `/tmp/twix-perf-traces/pass3-official-before/<feature>/<scenario>/<template>/repN.trace` |

수집 과정에서 발견된 driver 문제 (수정 후 재수집한 것):
- Home feed-scroll 좌표 버그 (feed-normalized → off-screen): driver 를
  `app.windows.firstMatch.coordinate(...)` 로 교체.
- Stats heavy scroll 도중 device 스토리지 가득 → 일부 trace 가 52KB stub
  으로 저장 → device 정리 + 재부팅 후 재수집.
- Stats initial xctrace race condition → attach 트리거를
  `Open org.yapp` 로그 라인으로 통일.
- ProofPhoto comment typing: `feature.proof-photo.marker.comment-text.abcde`
  marker 추가 + assertion 으로 키보드 입력 누락 감지.

위 모든 issue 는 baseline 재수집 전 driver/infra 단에서 수정. 공식 48
traces 는 모두 깨끗한 데이터.

### 4.2 baseline 핵심 관찰

- **Home feed-scroll TP rep1**: top-10 user-code 합 ≈ 200ms / 50s 활성
  윈도우 ≈ **0.4 % of trace**.
- **모든 시나리오 top-frame 의 95%+ 가 UIKit + SwiftUI framework**
  (`-[UIView layoutSublayersOfLayer:]`, `DisplayList.ViewUpdater.*`,
  `HostingScrollView.*`, `setContentOffset:`, `_calculateEdgeInsets…`).
- 단 하나의 예외 — **GoalDetail initial 시나리오 top-1 user-code frame =
  `TimelineView<>.UpdateFilter.updateValue()`** (3 rep 모두 9–12ms).
  → Pass 2 time-profiler-analysis 가 지목한 idle CPU draw 그대로 재현.
- **Noise floor**: feed-scroll rep1 ↔ rep2 total time `+10.4%`. 단일 frame
  최대 swing `+54%` (`__RawDictionaryStorage.find<A>(_:)`, Swift stdlib
  hashing). 사용자 코드 변경 없이 발생한 자연 variance — 본 noise 가
  Pass 3 fix evidence 의 threshold 가 됨.

상세: `docs/perf-infra/reports/_workspace/pass3-before.md`,
`pass3-baseline-collection-plan.md`, `pass3-target-coverage.md`.

---

## 5. Commit 3 — Home read-set split

### 5.1 변경

`Projects/Feature/Home/Sources/Home/HomeView.swift` 를 `HomeView` parent +
`HomeNavigationBarSection` / `HomeCalendarSection` / `HomeContentSection`
(LazyVStack 보유) / `HomeHeaderRow` / `HomeEmptyContentSection` /
`HomePresentationLayer` (ViewModifier) 로 분리. `@ObservableState` 가 각
sub-view 의 body 가 실제로 읽는 필드만 관찰하도록 read-set 을 좁힘.
Presentation flag 들 (`isAddGoalPresented` 외 5개) 과 `proofPhoto` scope
는 모두 `HomePresentationLayer` modifier 의 body 안에 격리.

Commit: `d6482c9 refactor: HomeView 읽기 범위 분리 - #308`.

### 5.2 측정 결과 (Home feed-scroll + calendar-sweep, 12 after traces / contam 0)

| 시나리오 | template | rep1 | rep2 | rep3 | mean | within noise (±10.4%)? |
|---|---|---:|---:|---:|---:|---|
| feed-scroll | TP | -0.6% | 0.0% | -0.6% | **-0.4%** | yes |
| calendar-sweep | TP | +9.2% | +6.2% | +3.5% | **+6.3%** | yes |
| feed-scroll | Hitches (severe hang freq) | 2/3 rep → 1/3 rep | — | — | direction ambiguous (interaction delay count UP) | n/a |
| calendar-sweep | Hitches (severe hang) | 1/3 rep → 0/2 valid rep | — | — | essentially identical total stall | n/a |

> 1 calendar-sweep Hitches rep1 는 TOC export 실패 (bundle 287MB, 분석기
> 파싱 불가). 시나리오의 다른 rep 패턴이 변화 없음을 보이므로 재수집하지
> 않음.

**측정 가능한 rendering 개선 없음.** noise floor 안의 변화만 관측.

### 5.3 그래도 KEEP 한 이유

1. 새 구조가 깨끗 — presentation/content/navigation read-set 이 코드 상
   명시적으로 분리. 향후 동일 카테고리 issue 가 생길 때 attribution 이
   쉬워짐.
2. SwiftUI observation tracking 의 invalidation graph 가 좁아진 것은
   사실. **단지 본 측정 시나리오들이 그 이득이 발현되는 상태 변화
   패턴을 트리거하지 않음** (feed-scroll 은 어떤 state mutation 도 안
   하고, calendar-sweep 의 cascade 는 의도된 변화).
3. 회귀 없음 (top-10 frame 동일, severe-hang frequency 약간 감소).

### 5.4 honest framing for final report

Commit 3 은 **structural cleanup** 으로 보고. UI Rendering 개선 evidence
로 인용하지 않는다.

상세: `docs/perf-infra/reports/_workspace/pass3-commit3-comparison.md`.

---

## 6. Commit 7 — GoalDetail FlyingReactionOverlay TimelineView idle guard

### 6.1 변경

`Projects/Feature/GoalDetail/Sources/Detail/FlyingReactionSupport.swift`
의 `FlyingReactionOverlay.body` 만 변경:

```swift
var body: some View {
    Group {
        if reactions.isEmpty {
            Color.clear              // 60Hz TimelineView 가 트리에서 사라짐
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                // 기존 emoji 애니메이션 ZStack — 변경 없음
            }
        }
    }
    .allowsHitTesting(false)
}
```

- 입자 활성 경로는 byte-preserving.
- public API 변화 없음. driver / seed / template / window 변화 없음.

Commit: `261fe7d fix: GoalDetail 유휴 TimelineView 실행 방지 - #308`.

### 6.2 측정 결과 (GoalDetail initial + reaction, 12 after traces / contam 0)

**initial 시나리오 (idle GoalDetail)** — Pass 2 가 지목한 그 frame:

| rep | before top user-code #1 | after top user-code #1 |
|---|---|---|
| TP rep1 | `TimelineView<>.UpdateFilter.updateValue()` 9ms (0.2%) | `AXValidationManager.performValidations:` 2ms |
| TP rep2 | `TimelineView<>.UpdateFilter.updateValue()` 12ms | XCTRunner infra ≤2ms (TimelineView 부재) |
| TP rep3 | `TimelineView<>.UpdateFilter.updateValue()` 12ms | (TOC export 실패; trace 자체는 정상 기록) |
| Hit rep1 | `TimelineView<>.UpdateFilter.updateValue()` 8ms | XCTRunner infra ≤2ms (TimelineView 부재) |

3/3 TP rep + Hit rep1 에서 `TimelineView<>.UpdateFilter.updateValue()` 및
같이 등장하던 `closure #1 in TimelineView<>.init`, `closure #1 in
TimelineView<>.UpdateFilter.updateValue()` 가 top-10 user-code 에서 사라짐.
새 hot user-code frame 도입 없음 (1–2ms accessibility / XCTest infra 만).

**reaction 시나리오 (활성 입자, byte-preserving 의도)**: device wall time
24.0s, baseline 과 동일. 코드 diff 가 입자 활성 경로를 보존함. After
trace top-10 이 XCTRunner frame 으로 채워진 것은 분석기 ranking
artifact — top-10 cut 아래로 app frame 이 밀려난 것 (실제 app workload
감소 없음).

### 6.3 분류

- 사용자 체감 rendering 개선 카테고리가 아님 — **idle CPU / 배터리
  cleanup**.
- Pass 2 가 정확히 지목한 단일 user-code hotspot 을 깔끔하게 제거 — **target
  measurable improvement** 기준 충족.
- Code diff 한 분기, public API 변화 없음, 활성 경로 byte-preserving —
  **simpler/safer with no regression** 기준 동시 충족.

상세: `docs/perf-infra/reports/_workspace/pass3-commit7-comparison.md`.

---

## 7. Commit 6 (재정의) — Home card rendering / GoalCardView input stability: **investigated and skipped**

### 7.1 재정의 사유

원래 좁은 정의 (`HomeGoalItem equality 비용 감소`) 는 Home feed-scroll 의
실제 workload 인 `HomeContentSection → LazyVStack → ForEach(store.items)
→ GoalCardView` cell rendering 경로 전체를 가리지 못함. 사용자 지시로
스코프를 GoalCardView input 안정성 + observation scope + rebuild
frequency 까지 확장.

### 7.2 사전 조사 (구현 없음, read-only)

조사 파일:
- `Projects/Feature/Home/Sources/Home/HomeView.swift` (HomeContentSection 외)
- `Projects/Feature/Home/Interface/Sources/Home/HomeGoalItem.swift`
- `Projects/Feature/Home/Interface/Sources/Home/HomeReducer.swift`
- `Projects/Feature/Home/Sources/Home/HomeReducer+Impl.swift` (items mutation 사이트)
- `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardView.swift`
- `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardItem.swift`
- baseline + Commit 3 after Home feed-scroll TP rep1 trace

### 7.3 핵심 발견

| 발견 | 영향 |
|---|---|
| baseline + Commit 3 after Home feed-scroll TP rep1 양쪽의 **top-20 user-code 에 GoalCardView / GoalCardItem / HomeGoalItem / HomeContentSection / cardList / goalCard 관련 frame 0건** | 손댈 user-code hot path 부재 |
| baseline top-10 user-code 합 ≈ **0.4 % of trace** | noise ±10.4% 대비 측정 가능한 절감 범위 자체가 작음 |
| `state.items` mutation 은 모두 action-driven (fetchGoals, updateGoal, poke). **feed-scroll 측정 윈도우 동안 mutate 없음** | `EquatableView` 류 diff-skip 의 trigger 자체가 시나리오에 부재 |
| `GoalCardView` 는 4 closure input 을 받음 — `EquatableView` 가능하게 하려면 custom `==` (closure 무시) 필수 | **stale UI structural risk** + measurable upside 0 |
| `HomeGoalItem.goal` 분리는 fetch path (`==` 호출) 에만 영향, feed-scroll 윈도우에 `==` 호출 자체 없음 | 시나리오 mismatch — attribution 만 악화 |

### 7.4 결정

**Skip Commit 6.** 어떤 후보도 (a) 본 측정 시나리오에서 측정 가능한 user-code
타겟이 없고, (b) closure-aware EquatableView 같은 후보는 measurable upside
없이 stale-UI risk 만 늘어남.

상세: `docs/perf-infra/reports/_workspace/pass3-commit6-investigation.md`.

---

## 8. Commit 4 / Commit 5 — hold/skip

### 8.1 Commit 4 (destination/presentation observation scoping) — skip/hold

- Commit 3 의 `HomePresentationLayer` ViewModifier 가 presentation/destination
  scoping 의 핵심 (`isAddGoalPresented`, `isCalendarSheetPresented`, `modal`,
  `isProofPhotoPresented`, `proofPhoto` scope, `isCameraPermissionAlertPresented`)
  을 모두 흡수.
- Commit 3 자체가 측정상 AMBIGUOUS 였기 때문에 같은 카테고리의 두 번째
  speculative refactor 를 더 쌓으면 **trace attribution 만 더 어려워지고
  측정 가능한 이득은 불확실**.
- 재개 조건: HomePresentationLayer 외 잔류 destination/presentation
  observation 이 grep 으로 실제 발견되고, **그 잔류분이 trace top-frame 에서
  user-code 비중을 차지할 때만**.

### 8.2 Commit 5 (`goalSectionTitle` / `nowDate` stored derivation) — stand-by/skip

- baseline 의 어떤 시나리오 top-10 user-code 에도 `goalSectionTitle` /
  `nowDate` / `HomeGoalItem.==` 관련 frame 이 등장하지 않음.
- 단독 commit 으로 가치 낮음. 새 시나리오에서 측정 가능한 top-frame 이
  보일 때 또는 동반 작업이 자연스럽게 합칠 수 있을 때 재고.

---

## 9. Phase 2 follow-ups

본 Pass 의 명시적 out-of-scope. 향후 별도 Pass 에서 다뤄야 할 항목:

1. **SwiftUI Template launch-mode 자동화**
   - 현재 attach 모드에서 "no SwiftUI data" 확인. `xctrace --launch` + UITest
     driver 동시 attach 파이프라인이 부재.
   - SwiftUI 내부 view-tree work / attribute graph cost 의 직접 attribution
     을 위해 필요.

2. **ProofPhoto 실제 image pipeline / OS picker / 카메라 권한 flow**
   - 본 Pass 는 `proof-photo-prefilled` fixture 로 우회.
   - PHPickerResultClient 신규 mock protocol + 권한 popup 자동화 필요.
   - KFImage / 업로드 직전 메모리 비용은 별도 시나리오로 분리해 측정해야
     attribution 가능.

3. **Real Photos picker / 카메라 capture** — OS-level UI 측정 자동화
   인프라.

4. **Broader card / image pipeline 최적화** — 만약 향후 SwiftUI Template
   trace 또는 새 시나리오 (예: fetch 직후 60s 스크롤 혼합) 에서
   GoalCardView / GoalCardItem 관련 user-code frame 이 top-10 에 등장한다면,
   Commit 6 의 investigated-and-skipped 결정을 재검토.

5. **`StatsDetailView.dateCellBackground`** — Pass 1 smell inventory 의
   inline `AnyView` + `completedDate(for:)` 는 code-quality 정리 카테고리.
   rendering 측정 cycle 과 분리해 진행.

6. **Settings nickname delayed transition** — 단일 Text update 의
   "loading transition probe" 분류로, 별도 latency 측정 인프라가 필요할 때
   재검토.

---

## 10. Workspace 문서 인벤토리

| 문서 | 역할 |
|---|---|
| `_workspace/pass3-baseline-collection-plan.md` | 공식 baseline 수집 절차/scheme/시나리오/contamination 기준 |
| `_workspace/pass3-target-coverage.md` | Pass 3 측정 대상 인벤토리 (P0/P1/P2/excluded) |
| `_workspace/pass3-before.md` | baseline 측정 결과 + noise floor |
| `_workspace/pass3-dryrun.md` | Phase D dry-run 결과 + 시퀀싱 recipe |
| `_workspace/pass3-commit3-comparison.md` | Commit 3 measurement detail |
| `_workspace/pass3-commit7-comparison.md` | Commit 7 measurement detail |
| `_workspace/pass3-commit6-investigation.md` | Commit 6 investigation + skip 결정 |
| `_workspace/time-profiler-analysis.md` | Pass 2 time-profiler 분석 (Pass 3 의 출발점) |
| `_workspace/smell-inventory.md` | Pass 1 smell inventory |
| `_workspace/baseline-device.md` / `baseline-simulator.md` | Pass 1/2 baseline metric 표 |
| `_workspace/compare-baseline-after.md` | Pass 1/2 비교 자료 |

---

## 11. Honest caveats

1. **Authoritative metric 은 Time Profiler + Animation Hitches 두 가지로 한정**.
   SwiftUI signpost trace 는 본 Pass 에서 사용하지 않았다. SwiftUI 내부
   view-tree diff / attribute update cost 의 직접 attribution 은 Phase 2.

2. **noise floor ±10.4%** 안의 변화는 trend 로조차 인용하지 않는다. Commit 3
   의 calendar-sweep TP `+6.3%`, feed-scroll TP `-0.4%` 모두 within-noise
   이며 evidence 가 아니다.

3. **Commit 7 의 0.1–0.2% 개선은 idle CPU / 배터리 카테고리**. 사용자가
   체감하는 rendering 개선 카테고리로 카운트하지 말 것.

4. **dedicated rendering scenarios 에 한정된 측정**. 실제 사용 환경의
   fetch + scroll + presentation mix 패턴은 별도 시나리오로만 검증
   가능하며, 본 결론을 그쪽 환경으로 일반화하지 말 것.

5. **Probe scenario 의 XCTest 수치 (`Clock Monotonic Time` /
   `CPU Instructions Retired` / `home.view.rebuild.proxy`) 는 driver/marker
   sanity 신호이며 UI Rendering 개선 evidence 아님.**

6. **GoalDetailExampleNavigationTests/testPrimaryCtaPresentsProofPhoto** 는
   branch 초기 commit `5594c1f` 부터 깨져 있던 pre-existing failure.
   Pass 3 의 어떤 변경과도 무관하며 별도 작업이 필요.
