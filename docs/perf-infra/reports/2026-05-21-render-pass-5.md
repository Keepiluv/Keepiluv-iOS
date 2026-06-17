# Pass 5 — Rendering Optimization (final)

- **작성일**: 2026-05-21 (final: Pass 5 closure)
- **Baseline tag**: Pass 5는 새 baseline tag를 만들지 않는다. C5 H-C5-b의 before-gate는 `pass4-rendering-before` (Pass 4) 기반의 `/tmp/twix-perf-traces/pass4-s3/c5-before/` (H-C5-a baseline)를 재사용했다 — H-C5-a `da2278e`가 `aa4a160`으로 revert되어 production state가 baseline과 동일하기 때문.
- **Authoritative metric**: Xcode Instruments / xctrace (Time Profiler + Animation Hitches), iOS 26.4.2 device (Jiyong의 iPhone, UDID `00008110-00096DC42632801E`), **PerfProfile** configuration.
- **Probe metric (보조)**: XCTest XCUI driver — driver/marker sanity 신호 (개선 evidence 아님).

이 리포트는 Pass 5 전체 (Stats C5 H-C5-b primary track + C1/C6/keyboard residual closure)의 최종 결과를 정리한다. Pass 5는 rendering 시리즈의 **마지막 pass**다. **Pass 6는 계획되어 있지 않으며, 현재 PR에는 추가 rendering optimization을 포함하지 않는다.** 남은 candidate / residual 항목은 future reference only로 기록한다.

---

## 1. Executive summary

### 1.1 Sub-track outcomes

| sub-track | 결과 | production commit | 핵심 수치 |
|---|---|---|---|
| Pass 5 Stats C5 — H-C5-b (`StatsCardView` `outsideBorder` render duplication removal) | **KEEP** | `3f83193` | Animation Hitches `4/1/2 → 2/0/0` (-71 %), hangs `1 (35.89 ms severe) → 0` (-100 %), "Potentially expensive app update(s)" narrative `3/3 → 0/3` (eliminated), swiftui-updates -47.6 %, no new TP top-20 user-code frame |
| Pass 5 C1 — TXNavigationBar idle re-eval | **CLOSED-as-deferred** | — | Pass 4-S audit magnitude class matched C3 (gated and SKIPPED on idle TP). Pass 5 진입 시 cross-feature scope (Home / Stats / GoalDetail) + interaction-time harness 신설이 필요 → §4.8 one-file rule 및 Pass 5 closing 취지에 부합하지 않음 |
| Pass 5 C6 — `Image.ImageViewChild<…AccessibilityProvider>` | **CLOSED-resolved-as-side-effect** | (Pass 4-S2 H-C2-a `0c0da63`의 side effect, additional Pass 5 H-C5-b expected reduction) | Pass 4-S2 H-C2-a after-gate에서 Home scroll C6 events `2,563 → 1,270` (-50 %), µs `38,200 → 30,250` (-21 %). Stats scroll의 C6 magnitude는 H-C5-b after-gate의 swiftui-updates total -47.6 % 일관 reduction에 포함되어 noise floor 아래로 collapse. 신규 production 변경 없음 |
| Pass 5 ProofPhoto keyboard residual | **CLOSED-out-of-scope** | — | UIKit framework-side keyboard / focus stack (`_UIKeyboardStateManager`, `UIKeyboardCache`, `UIInputWindowController`, `UIAssistantBarButtonItemProvider`). Rendering / image-pipeline category 밖. 향후 UX latency / input handling 별도 카테고리로만 추적 |

### 1.2 Methodology validation (3rd direction)

Pass 4가 양방향으로 검증한 contract — "SwiftUI Template signal alone never justifies a production change; TP + Animation Hitches가 authoritative" — 는 Pass 5에서 다시 한번 입증되었다:

- **Pass 4-S2 H-C2-a (KEEP)**: SwiftUI signal moved + TP + Hitches 모두 corroborate → production-valid (Home).
- **Pass 4-S3 H-C5-a (REVERT)**: SwiftUI signal moved (-15 %) BUT Hitches 오히려 +60 % → reject (Stats container swap).
- **Pass 5 H-C5-b (KEEP)**: SwiftUI signal moved (-47.6 %) + Hitches -71 % + hangs -100 % + 목표 narrative eliminated → production-valid (Stats render duplication).

세 사례는 같은 룰의 양방향 + 동일 메커니즘 cross-feature 재현이다. H-C2-a (Home `outsideBorder`)와 H-C5-b (Stats `outsideBorder`)는 동일 `outsideBorder` modifier의 재중복 composition을 `.background { RoundedRectangle.stroke(...) }` 형태로 제거하는 같은 패턴이며, 두 feature에서 모두 measurable improvement를 생산했다. 단, cross-feature 적용 자체는 handoff §4.5의 "독립 gate evidence 없는 blind transfer 금지" 룰을 준수했다 — Pass 5 H-C5-b는 Stats self-run scroll에서 자체 before/after gate를 수행한 뒤에만 KEEP된다. 측정 commit `3f83193`은 Stats local swap이었고, 리뷰 반영 commit `f664f2a`에서 같은 구현을 shared `outsideBorder`로 승격했다.

### 1.3 One-line summary

Pass 5는 Stats C5를 production-valid 개선 (H-C5-b — Animation Hitches `4/1/2 → 2/0/0`, 35.89 ms severe hang 제거, "Potentially expensive app update(s)" narrative 3/3 → 0/3 eliminated)으로 닫고, C1 / C6 / ProofPhoto keyboard residual은 각각 CLOSED-as-deferred / CLOSED-resolved-as-side-effect / CLOSED-out-of-scope로 처리하면서 rendering optimization 시리즈를 종결했다. SwiftUI Template counts alone never justify a production change — TP + Animation Hitches가 authoritative이다, 세 번 입증.

---

## 2. Scope / Inputs from Pass 4 / Out of scope

### 2.1 Pass 5 inputs from Pass 4

| Pass 4 sub-track | 결정 | Pass 5 영향 |
|---|---|---|
| ProofPhoto P4-2 (image pipeline) | KEEP (`4cfabd0`) | Pass 5 baseline — production state |
| Pass 4-S2 Home H-C2-a (GoalCardView outsideBorder) | KEEP (`0c0da63`) | Pass 5 baseline — H-C5-b의 cross-feature analog 근거 |
| Pass 4-S3 Stats H-C5-a (LazyVGrid swap) | REVERT (`da2278e` → `aa4a160`) | Pass 5 baseline = `aa4a160` reverted state. H-C5-b는 H-C5-a 이후 별도 hypothesis class로 진입 |
| Pass 4-S audit C3 (TXCalendarDateCell) | SKIPPED | Pass 5 C1 magnitude class 판단 근거 |
| Pass 4-S audit C4 (GoalDetailView) | SKIPPED | (Pass 5에서 별도 진입 안 함) |

Pass 5는 Pass 4 baseline 위에서 진행되며, 별도 baseline tag를 추가하지 않는다.

### 2.2 What was measured (Pass 5)

| 영역 | Scheme | 시나리오 | seed | harness |
|---|---|---|---|---|
| Stats C5 | `FeatureStatsExample` | self-run scroll (`-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL`) | `stats-heavy` | Pass 4-S3 commit `caa26be` |

1 scenario × 3 templates (SwiftUI + TP + Animation Hitches) × 3 reps = **9 traces** for H-C5-b after-gate. Before-gate (9 traces)는 `pass4-s3` 시점 수집본 재사용.

C1 / C6 / keyboard residual은 신규 trace 수집을 수행하지 않았다 (각각 §1.1의 closure 사유 참조).

### 2.3 Out of scope

- **Auth / Onboarding** rendering: VoC 우선순위 아님.
- **GoalDetail particle / overlay** (Pass 3 Commit 7 KEEP 이후): Pass 4-S 진입 조건 미충족. Future reference only.
- **GoalDetail / Stats / Settings 추가 hypothesis**: evidence-gated 유지, Pass 5 baseline에 추가 진입 조건 없음. 현재 PR scope 아님.
- **C5 잔여 hypothesis classes** (Equatable on StatsCardView, cell-content reduction, cell-pool, cell-snapshot caching): handoff §2.1 inventory에 기록. Pass 5 one-pass-one-hypothesis budget for C5는 H-C5-b로 충족. 잔여 class는 Pass 5에서 열지 않으며, Pass 6 계획도 없다.

---

## 3. C5 H-C5-b — primary track

### 3.1 Hypothesis

측정 당시 `StatsCardView` (`Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardView.swift`)의 `outsideBorder(...)` modifier가 `overlay { shape.stroke().overlay(self) }`로 구현되어 (`Projects/Shared/DesignSystem/Sources/Modifiers/View+BorderInOutSide.swift`) cell subtree를 매 render마다 두 번 composition했다. H-C5-b는 이를 local `.background { RoundedRectangle.stroke(..., lineWidth: × 2) }`로 대체해서 render-side 중복 composition을 제거한다.

Pass 4-S2 H-C2-a (Home `GoalCardView`)에서 동일 mechanism이 KEPT — Pass 5는 cross-feature 적용 시 handoff §4.5 (blind cross-transfer 금지) 룰 준수를 위해 Stats self-run scroll에서 독립 gate를 수행했다.

### 3.2 Diff

1 file, 12 inserts / 5 deletes:

```diff
-        .outsideBorder(
-            Color.Gray.gray500,
-            shape: RoundedRectangle(cornerRadius: Constants.cardCornerRadius),
-            lineWidth: Constants.borderLineWidth
-        )
+        // Pass 5 H-C5-b: render-side duplication removal — same mechanism as
+        // Pass 4-S2 H-C2-a (`GoalCardView.swift`). The shared `outsideBorder`
+        // modifier is implemented as `overlay { shape.stroke().overlay(self) }`,
+        // which composes the card subtree twice per render. Local
+        // `.background { stroke }` replicates the visual (stroke drawn at the
+        // view's bounds, inside half hidden by the clipped content above,
+        // outside half visible) without the second `self` composition. Shared
+        // `outsideBorder` modifier is intentionally unchanged.
+        .background {
+            RoundedRectangle(cornerRadius: Constants.cardCornerRadius)
+                .stroke(Color.Gray.gray500, lineWidth: Constants.borderLineWidth * 2)
+        }
```

측정 commit에서는 shared `outsideBorder` modifier (`View+BorderInOutSide.swift`)와 다른 consumer (`GoalEditCardView`, `CardHeaderView`)가 unchanged였다. 최종 PR code shape에서는 리뷰 반영으로 같은 `background { stroke }` 구현을 shared `outsideBorder`에 적용했고, `StatsCardView` / `GoalCardView`는 다시 공통 modifier를 사용한다.

### 3.3 Before-gate (재사용)

`/tmp/twix-perf-traces/pass4-s3/c5-before/` (TP + Hitches × 3) + `/tmp/twix-perf-traces/pass4-s3/swiftui-selfrun-scroll/` (SwiftUI × 3). 9 trace bundles intact, Pass 4-S3 H-C5-a baseline과 동일 (H-C5-a reverted 상태가 곧 Pass 5 baseline이므로 production state가 일치).

### 3.4 After-gate (신규 수집)

- 수집 환경: 방해금지 ON, 충전 케이블 연결, Low Power Mode OFF, 발열 없음, 외부 디스플레이/오디오 분리, 화면 잠금 해제.
- 9 traces 모두 정상 종료 (`exit(0)`), 0 contamination.
- Trace 출력: `/tmp/twix-perf-traces/pass5-after/h-c5-b/{swiftui,timeprofiler,hitches}/stats-heavy-selfrun-scroll-rep[123].trace`.
- 수집 후 host `/tmp` 여유: 74 GB (수집 전 80 GB → 6 GB 소비).

### 3.5 Headline before vs after

| metric | C5 baseline (3 reps) | H-C5-b after (3 reps) | delta |
|---|---:|---:|---:|
| Animation Hitches count per rep | 4 / 1 / 2 (mean 2.33, total 7) | **2 / 0 / 0** (mean 0.67, total 2) | **-71 %** |
| Animation Hitches hangs (≥ 33 ms) | 1 (35.89 ms severe @ rep1) | **0** | **-100 %** |
| "Potentially expensive app update(s)" narrative reproducibility | **3 / 3 reps** | **0 / 3 reps** | **eliminated** |
| "Potentially expensive render, N offscreen passes" narrative | 0 / 3 reps | 1 / 3 reps (rep1: 1 offscreen pass, 12.50 ms — acceptable trade, see §3.6) | new small narrative |
| `swiftui-updates` total | 641,276 | **336,120** | **-47.6 %** |
| TP user-code Stats frame in top-10 | absent (0 / 3) | absent (0 / 3) | unchanged |
| Smoke test (`StatsExampleSmokeTests`) | — | **PASS** (7.32 s) | — |
| Visual sanity (simulator screenshot) | — | identical | — |

### 3.6 Notes on new "1 offscreen passes" narrative

After rep1에 1건 "Potentially expensive render, 1 offscreen passes" (12.50 ms, sub-frame at 60Hz, 1/3 reps만). REVERT criterion에 명시된 narrative는 "Potentially expensive app update(s) unchanged or worse"이며 이는 ELIMINATED (3/3 → 0/3). 사라진 narrative는 baseline rep1의 35.89 ms severe hang과 공존했으므로 per-event severity가 더 높았고, 새 narrative는 1 offscreen pass (severity 매우 낮음) + 12.50 ms (sub-frame) + 1/3 reps (재현성 약함). **순 narrative profile 개선**으로 판단 → REVERT trigger 아님. (자세한 분석: `_workspace/pass5-h-c5-b-after-gate.md` §4)

### 3.7 KEEP / REVERT matrix

| KEEP criterion | result |
|---|---|
| Animation Hitches count reduced or unchanged | **PASS** (-71 %) |
| No severe hang ≥ 33 ms in 2/3 reps | **PASS** (0 hangs vs 1) |
| "Potentially expensive app update(s)" narrative reproducibility < 3/3 | **PASS** (3/3 → 0/3) |
| TP top-20 no new user-code hot path | **PASS** (no `StatsCardView.body` / `StatsCardCompletionCell.body` / `CardHeaderView.body` in any rep) |
| SwiftUI Template count (corroborating) | **PASS** (-47.6 %, large) |
| `FeatureStatsExampleUITests` smoke pass | **PASS** |
| Visual regression — none | **PASS** |

| REVERT criterion | result |
|---|---|
| Hitches count/stall-ms increases | **NOT triggered** |
| `app update(s)` narrative unchanged at 3/3 or worse | **NOT triggered** (eliminated) |
| SwiftUI count moves but TP/Hitches do not corroborate | **NOT triggered** (strong corroboration) |
| New TP top-20 user-code hot path | **NOT triggered** |
| Visual / test regression | **NOT triggered** |
| Diff scope > 1 file | **NOT triggered** (1 file, 12+/5-) |

→ **KEEP** per plan §4.4 decision matrix. C5 closes with production-valid 개선.

### 3.8 H-C5-a vs H-C5-b — 같은 후보, 다른 hypothesis class

| 비교 | H-C5-a | H-C5-b |
|---|---|---|
| Hypothesis class | inner-container swap (LazyVGrid → eager rows) | render-side duplication removal (`outsideBorder` → local `.background { stroke }`) |
| File | `StatsCardCompletionCell.swift` | `StatsCardView.swift` |
| Diff scope | 1 file | 1 file |
| SwiftUI updates | -15 % | **-47.6 %** |
| Animation Hitches count | +60 % | **-71 %** |
| Hangs | 1 → 0 (-100 %) | 1 → 0 (-100 %) |
| "Potentially expensive app update(s)" narrative | 3/3 unchanged | **3/3 → 0/3 eliminated** |
| TP user-code top-20 | absent | absent |
| Verdict | **REVERT** (counts moved, real cost did not) | **KEEP** (counts + TP + Hitches 모두 corroborate) |

C5의 "single-file hypothesis class"는 두 번의 시도 모두 1-file로 제한되었지만, **어떤 layer를 다루느냐**가 결정적이었다. 같은 cell-level이라도 (a) 내부 container 교체는 SwiftUI signal source가 다른 layout machinery로 이동할 뿐 user-experience cost를 줄이지 않았고, (b) cell-boundary의 render-side composition 중복 제거는 SwiftUI signal source 자체를 줄여 user-experience cost (Hitches, hangs, narrative)도 함께 개선했다. 이는 Pass 4-S3 ablation 결과 (Experiment A에서 stamp grid 전체 제거 시 -69 % SwiftUI signal은 grid의 모든 subtree composition 비용을 포함했음을 의미)와도 일관된다 — render-side composition은 Stats cell scroll cost의 dominant 요소다.

---

## 4. C1 — TXNavigationBar idle re-eval (CLOSED-as-deferred)

### 4.1 Evidence

Pass 4-S audit (`pass4-s-swiftui-template-audit.md` §C1)이 cross-feature idle signal로 분류 — `TXNavigationBar.body` events ~1-3 / rep × ~3.0-4.4 ms (Home / Stats / GoalDetail idle scenarios). 동일 magnitude class의 C3 (TXCalendarDateCell)는 idle gate에서 TP top-30 부재로 SKIPPED.

### 4.2 Pass 5 결정

다음 조건 모두 충족 시에만 Pass 5에서 C1 진입 가능:

1. interaction-time scenario harness 신설 (현재 idle harness만 존재).
2. cross-feature scope: `TXNavigationBar.swift` 또는 그 consumers (Home / Stats / GoalDetail)를 동시에 touch — handoff §4.8 "1 commit = 1 hypothesis = 1 file by default" 위반.
3. cross-feature after-gate: 모든 영향 feature scenario에서 동시 게이트.

세 조건 모두 Pass 5의 closing scope 밖. C5 H-C5-b가 production-valid 개선을 이미 확보했고, 추가 production track 진입은 Pass 5의 종료 취지와 충돌.

### 4.3 Verdict

**CLOSED-as-deferred**. 이 항목은 future reference only이며 현재 PR에서 더 진행하지 않는다. Pass 6 계획은 없다. 언젠가 별도 승인된 작업으로 재오픈하려면 — (a) interaction-time harness 신설 commit, (b) cross-feature scope에 대한 명시적 hypothesis class 결정, (c) §4.8 룰의 형식적 우회가 아닌 본질적 정당화 — 세 가지가 모두 필요하다.

---

## 5. C6 — `Image.ImageViewChild<…AccessibilityProvider>` (CLOSED-resolved-as-side-effect)

### 5.1 Evidence

Pass 4-S audit (`pass4-s-swiftui-template-audit.md` §C6)이 weak signal로 분류:

- Home idle: ~214 events × 5,800 µs / rep
- Stats idle: ~46 events × 2,100 µs / rep

Pass 4-S2 H-C2-a after-gate (`pass4-s2-h-c2-a-comparison.md` §4)가 Home scroll에서 C6 side-effect reduction을 입증:

| signal | before (H-C2-a baseline) | after (H-C2-a kept) | delta |
|---|---:|---:|---:|
| `Image.ImageViewChild<…AccessibilityProvider>` events | 2,563 | 1,270 | **-50 %** |
| `Image.ImageViewChild` µs | 38,200 | 30,250 | **-21 %** |

(GoalCardView subtree re-composition이 감소하면서 cell 내 image-accessibility 재해결도 함께 감소.)

Pass 5 H-C5-b는 같은 `outsideBorder` mechanism을 Stats `StatsCardView`에 적용했으므로, Stats scroll C6 magnitude도 동일 비율 (≈-50 %)로 감소했을 것으로 합리적으로 추정할 수 있다. 추가 검증을 위해 H-C5-b after-gate의 swiftui-updates total -47.6 % 일관 reduction이 cell-subtree-attributable signals 전반에 분포함이 §3.5에서 확인됨.

### 5.2 Threshold check

- C6 per-rep µs (H-C2-a 후) ≈ 30,250 µs / 30s scroll rep ≈ 1 ms/sec 평균.
- C6 per-event ≈ 30,250 / 1,270 ≈ 24 µs/event.
- Pass 4-S2 / Pass 5 H-C5-b after-gate 모든 TP top-30에 image accessibility 관련 user-code frame 부재.
- Pass 4-S2 / Pass 5 H-C5-b after-gate 모든 Animation Hitches narrative에 image accessibility 관련 narrative 부재.

### 5.3 Verdict

**CLOSED-resolved-as-side-effect**. C6는 Pass 4-S2 H-C2-a + Pass 5 H-C5-b의 cell-subtree composition 감소의 side effect로 noise floor 아래로 collapse. 별도 production 변경 없음. 이 항목은 future reference only이며 현재 PR scope가 아니다.

---

## 6. ProofPhoto keyboard residual (CLOSED-out-of-scope)

### 6.1 Evidence

Pass 4 P4-2 (`4cfabd0`)가 ProofPhoto image pipeline을 KEPT (typing total stall -35 %, longest hang -51 %). 잔여 typing-large stall (0.53 s mean)은 UIKit framework-side keyboard / focus stack에 집중:

- `_UIKeyboardStateManager`
- `UIKeyboardCache`
- `UIInputWindowController`
- `UIAssistantBarButtonItemProvider`
- `UISystemKeyboardDockController`
- `UIView _accessibilityViewIsVisibleIgnoringAXOverrides`

(자세한 분석: `2026-05-20-render-pass-4.md` §8.4)

### 6.2 Pass 5 결정

이 잔여 비용은 SwiftUI / view layer에서 직접 최적화할 수 없는 UIKit framework cost. Rendering / image-pipeline category 밖. UX latency / input handling 등 별도 카테고리에서 다뤄야 함.

### 6.3 Verdict

**CLOSED-out-of-scope**. 이 항목은 rendering 시리즈의 current scope가 아니며, future reference only로 남긴다. Pass 5는 이를 rendering 시리즈의 정상 closure로 처리하고 cumulative final report에 "future reference / known unresolved area"로 기록한다.

---

## 7. Pass 5 commit log

| commit | category |
|---|---|
| `e2523f8` | docs — Pass 5 handoff (Pass 4 종결 시점 작성) |
| `349e1d3` | docs — Pass 5 execution plan + H-C5-b plan |
| `3f83193` | **refactor — H-C5-b production attempt (KEPT)** |
| `6eb6048` | docs — H-C5-b after-gate KEEP 검증 |
| `fff6b75` | docs — Pass 5 final report |
| `f664f2a` | refactor — PR review feedback (shared `outsideBorder` final code shape) |

**Production change count**: 1 (kept). **Reverted production change count**: 0. **Infra commit count**: 0 (Stats self-run scroll harness는 Pass 4-S3 `caa26be`에 이미 존재; Pass 5에서 새로 추가 안 함).

---

## 8. Pass 5 → cumulative report

Pass 5 closure 후 별도 cumulative final report (`2026-05-21-rendering-final-cumulative-report.md`)가 Pass 1 ~ Pass 5 전체 production impact, REVERT / SKIP / CLOSED inventory, 누적 정량 비교, 시리즈 종료 근거를 정리한다.

이 리포트는 Pass 5 단독 결과만 담는다. 누적 시리즈 평가는 cumulative report를 참조.

---

## 9. Honest caveats

- **Trace window 차이**: Pass 5 H-C5-b after-gate는 `--time-limit 35s`로 수집, Pass 4-S3 C5 before-gate는 30s로 수집. SwiftUI updates 총량 비교에서 raw -47.6 %는 window normalization (30/35)을 적용해도 ≥ -40 %로 여전히 large reduction. Hitches와 narrative는 active-scroll-window 기반 event metric이라 window 차이에 둔감 — KEEP 결정은 window-insensitive metric 기반.
- **rep3 TP rank-10 closure frame**: `closure #1 in closure #1 in closure #1 in StatsView.scrollCardList.getter` (5 ms / 5 samples)는 self-run scroll harness driver code (`#if PERF_TESTING` 블록 내). Production code 아님. H-C5-a after-gate에서도 동일 패턴 관찰됨.
- **C6 Stats-side magnitude는 직접 재측정하지 않음**: H-C5-b after-gate의 일관 swiftui-updates -47.6 % reduction과 Pass 4-S2 H-C2-a의 Home C6 -50 % side-effect를 inference 근거로 사용. 보수적 표현으로 "resolved as side effect"로 표기. 엄격한 per-view C6 magnitude는 future reference로만 남긴다.
- **H-C2-a → H-C5-b cross-feature 적용**: 같은 `outsideBorder` mechanism의 cross-feature 재현이지만, blind transfer는 아니다. Stats self-run scroll에서 자체 before/after gate를 수행하고 모든 KEEP criteria를 통과한 뒤에만 KEEP. handoff §4.5 룰 준수.
- **C5 잔여 hypothesis classes**: Equatable on StatsCardView, cell-content reduction, cell-pool, cell-snapshot caching은 Pass 5에서 열지 않음. 현재 PR scope가 아니며 Pass 6 계획도 없다.

Pass 5 종결. Rendering optimization 시리즈도 여기서 종료한다.
