# 렌더링 최적화 최종 성과 요약

- **작성일**: 2026-05-21
- **범위**: Pass 3 → Pass 4 → Pass 5 production decision 요약
- **상태**: rendering optimization series 완료. Pass 5가 최종 pass이며 Pass 6는 계획되어 있지 않다.
- **주요 근거 문서**:
  - `docs/perf-infra/reports/2026-05-18-render-pass-3.md`
  - `docs/perf-infra/reports/2026-05-20-render-pass-4.md`
  - `docs/perf-infra/reports/2026-05-21-render-pass-5.md`
  - `docs/perf-infra/reports/2026-05-21-rendering-final-cumulative-report.md`

이 문서는 사람 / PR reviewer가 최종 성과를 빠르게 확인할 수 있도록 만든 standalone 요약이다. 다른 workflow 문서의 required input이 아니며, report tree 구조를 바꾸지 않는다.

---

## 1. Executive summary

Rendering optimization series는 **완료**되었다. Pass 3 → Pass 4 → Pass 5 동안 production에 남긴 변경들은 ProofPhoto typing, Home scroll, Stats scroll, GoalDetail idle CPU에서 측정 가능한 개선을 만들었다.

현재 PR에는 더 이상의 rendering optimization 구현이 포함되지 않는다. 남은 candidate / residual 항목은 **future reference only**이며 active scope가 아니다. **Pass 6는 계획되어 있지 않다.**

가장 큰 production 성과는 다음 네 가지다.

- ProofPhoto typing-large: total stall `0.82s → 0.53s` (-35%), longest hang `233ms → 114ms` (-51%).
- Home self-run scroll: Animation Hitches `0/2/4 → 0/0/0`, 133.34ms severe hitch 및 "37 offscreen passes" narrative 제거.
- Stats self-run scroll: Animation Hitches `4/1/2 → 2/0/0` (-71%), hangs `1 → 0`, "Potentially expensive app update(s)" narrative `3/3 → 0/3` 제거.
- `outsideBorder` duplicated-subtree issue를 Home과 Stats 두 feature에서 독립 gate로 확인하고 각각 수정했다.

---

## 2. Baseline framing

가장 이른 documented baseline은 `baseline-render-pass-1 = 56b5b63`이다. 다만 이 baseline부터 최종 HEAD까지 하나의 전역 개선률을 계산하지 않는다.

비교 제한은 명확하다.

- Pass 3 official traces는 **Profile** configuration으로 수집되었다.
- Pass 4 / Pass 5 official traces는 **PerfProfile** configuration으로 수집되었다.
- Pass 4 ProofPhoto large fixture는 4032×3024 / 7.46 MiB JPEG로, Pass 3 ProofPhoto fixture와 workload가 다르다.
- Pass 5 H-C5-b after-gate는 35s window, C5 before-gate는 30s window다. Hitches / narrative는 active-scroll-window event metric이라 비교 가능하지만, raw `swiftui-updates`는 보수적으로 해석한다.

따라서 이 보고서는 fake global percentage를 만들지 않고, **same-workload before/after**가 있는 항목만 정량 개선으로 인용한다.

---

## 3. Production improvements kept

| Pass | Commit | Area | Change | Main measured result | Final status |
|---|---|---|---|---|---|
| Pass 3 Commit 3 | `d6482c9` | Home | `HomePresentationLayer` 중심 read-set split | 측정 수치는 noise floor 내. Structural cleanup이며 rendering win으로 인용하지 않음 | KEEP |
| Pass 3 Commit 7 | `aae16d3` | GoalDetail | `TimelineView` idle guard | TimelineView idle frame 9-12ms가 3/3 reps에서 top user-code frame에서 제거 | KEEP |
| Pass 4 P4-2 | `4cfabd0` | ProofPhoto | preview decode out of body + decoded preview representation | typing total stall `0.82s → 0.53s` (-35%), longest hang `233ms → 114ms` (-51%), ImageIO/JPEG decode top-frame 3/3 typing reps에서 제거 | KEEP |
| Pass 4-S2 H-C2-a | `0c0da63` | Home | `GoalCardView` `outsideBorder` render duplication removal | `swiftui-updates` -40.7%, `GoalCardView.body` events -93.7%, Animation Hitches `0/2/4 → 0/0/0`, 133.34ms severe hitch 제거, "37 offscreen passes" narrative 제거 | KEEP |
| Pass 5 H-C5-b | `5085d27` | Stats | `StatsCardView` `outsideBorder` render duplication removal | Hitches `4/1/2 → 2/0/0` (-71%), hangs `1 → 0`, "Potentially expensive app update(s)" `3/3 → 0/3`, `swiftui-updates` `641,276 → 336,120` (-47.6%) | KEEP |

요약하면 production에 남은 성과는 5건이다: rendering 개선 3건, idle CPU cleanup 1건, structural cleanup 1건.

---

## 4. Reverted / rejected hypotheses

| Hypothesis | What was attempted | Why it was reverted/skipped | What was learned |
|---|---|---|---|
| Stats H-C5-a LazyVGrid → eager VStack/HStack rows | `StatsCardCompletionCell` 내부 container를 `LazyVGrid`에서 eager rows로 교체 | `swiftui-updates`는 -15%에 그쳤고, Hitches는 `4/1/2 → 3/4/4`로 악화, "Potentially expensive app update(s)" narrative는 3/3 유지. `da2278e`를 `aa4a160`으로 revert | SwiftUI count가 움직여도 UX cost가 줄지 않으면 ship하지 않는다. C5의 inner-container swap hypothesis class는 exhausted |
| P4-3 downsample | ProofPhoto preview downsample 후보 검토 | P4-2 후 typing TP에서 ImageIO/JPEG decode top-frame이 0/3으로 사라짐. 남은 stall은 keyboard-side UIKit | 남은 비용은 image pixel workload가 아니므로 downsample이 해결책이 아님 |
| P4-4 preview subtree isolation | preview subtree를 별도 isolated / Equatable input view로 분리하는 후보 검토 | `previewImage` 도입으로 image subtree issue가 이미 해결됨. 추가 분리는 measurable upside 없이 stale UI risk만 증가 | 단순 subtree isolation은 trace evidence 없이는 진행하지 않는다 |
| C3 / C4 idle SwiftUI candidates | `TXCalendarDateCell`, `GoalDetailView` idle candidate gate | idle TP / Hitches gate가 production action을 지지하지 않음 | SwiftUI Template idle signal은 candidate discovery일 뿐이며, TP/Hitches corroboration이 필요 |
| C1 / C6 / ProofPhoto keyboard residual | Pass 5 closure에서 disposition 정리 | C1은 cross-feature + interaction harness 필요로 CLOSED-as-deferred, C6는 side effect로 noise floor 아래로 collapse되어 CLOSED-resolved-as-side-effect, ProofPhoto keyboard residual은 UIKit framework cost라 CLOSED-out-of-scope | 남은 항목은 current scope가 아니라 future reference only |

---

## 5. Methodology validation

이번 series의 가장 중요한 방법론 결론은 명확하다.

SwiftUI Template launch-mode는 candidate discovery에 유용했다. Self-loading 또는 self-run scenario에서 `swiftui-updates`, `swiftui-causes`, `swiftui-changes`, `swiftui-update-groups` row를 실제로 수집했고, Home / Stats scroll attribution에 도움을 줬다.

반대로 attach-mode는 이 환경에서 XCUITest-driven interaction에 대해 0 rows를 반환했다. iOS 26.4.2 / Xcode 26.0 조합에서는 driver가 app을 띄운 뒤 `xctrace --attach`로 SwiftUI Template을 붙이면 schema는 보이나 row가 비어 있었다. 그래서 interactive attribution은 self-run scenario로 우회했다.

하지만 SwiftUI Template count만으로 production change를 결정하지 않았다. 권위 있는 metric은 계속 **Time Profiler + Animation Hitches**였다.

Positive example:

- H-C2-a: SwiftUI signal, TP, Hitches가 모두 개선되어 Home fix를 KEEP했다.
- H-C5-b: SwiftUI signal -47.6%, Hitches -71%, hangs -100%, app-update narrative 제거가 함께 확인되어 Stats fix를 KEEP했다.

Negative example:

- H-C5-a: SwiftUI count는 줄었지만 Hitches가 악화되어 revert했다. 이 사례가 bad optimization을 production에 남기지 않게 막았다.

따라서 최종 contract는 그대로 유지된다: **SwiftUI Template counts alone never justify a production change. TP + Animation Hitches are authoritative.**

---

## 6. Overall improvement framing

전역 단일 개선률은 만들지 않는다. 대신 category별 same-workload 개선을 최종 성과로 정리한다.

| Category | Final framing |
|---|---|
| ProofPhoto typing latency | typing-large total stall -35%, longest hang -51%, ImageIO/JPEG decode top-frame 제거 |
| Home self-run scroll | measured scenario에서 scroll hitches 제거, 133.34ms severe hitch 제거, "37 offscreen passes" narrative 제거 |
| Stats self-run scroll | hitches -71%, hangs 제거, "Potentially expensive app update(s)" narrative 제거, `swiftui-updates` -47.6% |
| Render-side duplication | `outsideBorder`가 subtree를 중복 composition하던 문제를 Home `GoalCardView`와 Stats `StatsCardView`에서 각각 독립 gate 후 수정 |
| Risk control | Stats H-C5-a는 count-only optimization으로 판정되어 revert 후 ship되지 않음 |

---

## 7. Regression safety

회귀 방지는 다음 기준으로 확인했다.

- 실패한 production attempt는 revert했다: Stats H-C5-a `da2278e`는 `aa4a160`으로 되돌렸다.
- Smoke / UITests는 documented 범위에서 통과했다:
  - Pass 4 P4-2: `FeatureProofPhotoExampleUITests` 통과.
  - Pass 4-S2 H-C2-a: `FeatureHomeExampleUITests` 8/8 통과.
  - Pass 4-S3 H-C5-a revert 이후: `FeatureStatsExampleUITests` 통과.
  - Pass 5 H-C5-b: `StatsExampleSmokeTests/testExampleRendersReadyState` 통과 (7.32s).
- Visual sanity는 documented 범위에서 수행했다:
  - ProofPhoto preview / typing / reselect visual 동일.
  - Home `GoalCardView` border / corner / color 동일.
  - Stats `StatsCardView` border / corner / color 동일.
- Pass 5 execution plan의 deliverable에는 "Working tree clean"이 포함되어 있었고, closeout은 production code 변경 없이 완료 상태로 정리되었다.
- 현재 PR에는 더 이상의 production experiment나 rendering optimization 구현이 포함되지 않는다.

---

## 8. Final conclusion

Rendering optimization series는 완료되었다.

Pass 5가 최종 pass다. **Pass 6는 계획되어 있지 않다.** 현재 PR에는 추가 rendering optimization이 포함되지 않는다.

남은 notes / candidates / residual items는 **future reference only**이며 current scope가 아니다. 최종 production 성과는 ProofPhoto typing latency 개선, Home scroll hitch 제거, Stats scroll hitch 감소, 그리고 Home / Stats의 `outsideBorder` duplicated-subtree issue 수정으로 정리한다.
