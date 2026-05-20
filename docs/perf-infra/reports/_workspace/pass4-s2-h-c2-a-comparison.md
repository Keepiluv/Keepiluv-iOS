# Pass 4-S2 H-C2-a — GoalCardView outside-border render fix, before/after

**Verdict: KEEP.** All plan §5.2 KEEP criteria met; no REVERT criterion triggered.

- **Before commit**: `b325943` (harness + before-gate result doc, no production change).
- **H-C2-a commit**: `d3f66be` (`perf(home): reduce GoalCardView outside-border render duplication`).
- **Scenario**: home-heavy self-run scroll (`-UITEST_SWIFTUI_SELF_RUN_FEED_SCROLL`), PerfProfile, launch mode, 30 s window, device `00008110-00096DC42632801E`.
- **Before-gate**: 3 SwiftUI + 3 TP + 3 Hitches reps at `/tmp/twix-perf-traces/pass4-s2/c2-before/home-selfrun-scroll/`.
- **After-gate**: 3 SwiftUI + 3 TP + 3 Hitches reps at `/tmp/twix-perf-traces/pass4-s2-after/h-c2-a/`.
- **Contamination**: 0 / 18 traces across both gates. All `exit(0)`.

## 1. Headline numbers

| metric | before mean (3 reps) | after mean (3 reps) | delta |
|---|---:|---:|---:|
| `swiftui-updates` total rows | 204,598 | 121,310 | **-40.7 %** |
| `View Body Updates` total | 6,892 | 2,245 | **-67.4 %** |
| `GoalCardView.body` events | 2,642 | 166 | **-93.7 %** |
| `GoalCardView.body` µs | ~22,000 (median) | ~4,650 | **~-79 %** |
| `CardHeaderView.body` events | 236 | 120 | -49 % |
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` events | 1,709 | 918 | **-46 %** |
| `DynamicContainerInfo` µs | ~303,000 | ~249,000 | -18 % |
| `Image.ImageViewChild<…AccessibilityProvider>` events | 2,563 | 1,270 | **-50 %** |
| `Image.ImageViewChild` µs | ~38,000 | ~30,000 | -21 % |
| `LazySubviewPlacements<LazyVStackLayout>` events | 860 | 860 | unchanged |
| `LazySubviewPlacements` µs | ~118,000 | ~156,000 | +32 % (see §5 caveat) |
| Animation Hitches `hitches` rows | 0 / 2 / 4 | **0 / 0 / 0** | **-100 %** |
| `potential-hangs` rows | 0 / 0 / 0 | 0 / 0 / 0 | unchanged |
| TP `GoalCardView.body.getter` in top-10 (reps) | 2 / 3 | **0 / 3** | eliminated |
| Trace bundle (SwiftUI) MB | 91 | 83 | -8.8 % |

## 2. Hitches — before vs after

| rep | before hitches | after hitches |
|---:|---|---|
| 1 | (none) | (none) |
| 2 | **133.34 ms** + 16.67 ms — `Potentially expensive app update(s)` | (none) |
| 3 | 16.67 + 12.50 + **16.67 ms `Potentially expensive render, 37 offscreen passes`** + 12.50 | (none) |

After H-C2-a:
- The 133.34 ms Brief Unresponsiveness (8 dropped frames on first scrollTo) is **eliminated**.
- The "37 offscreen passes" render narrative is **eliminated** (no occurrence across 3 reps).
- 1 hitch rep in the after-gate SwiftUI Template trace (rep1, count = 1), 0 hitches in the dedicated Animation Hitches reps.

## 3. Time Profiler — top user-code per rep

### Before (excerpt; full table in `pass4-s2-home-selfrun-scroll-result.md` §4)

| rep | GoalCardView.body.getter | other top user-code |
|---:|---|---|
| 1 | **5 ms / 5 samples** (10th in top-10) | DisplayList ViewUpdater 16 ms, ScrollView setContentOffset 10 ms |
| 2 | **6 ms / 6 samples** (5th in top-10) | DisplayList ViewUpdater 14 ms, HostingScrollView 7 ms |
| 3 | (not in top-10) | DisplayList ViewUpdater 19 ms |

### After

| rep | GoalCardView.body.getter | top user-code now |
|---:|---|---|
| 1 | **absent from top-10** | CardHeaderView.body.getter 6 ms / 6 samples; `destroy for GoalCardView` 5 ms (one-off deinit during dematerialization, not a regression) |
| 2 | **absent from top-10** | CardHeaderView.body.getter 5 ms / 5 samples |
| 3 | **absent from top-10** | CardHeaderView.body.getter 7 ms / 7 samples |

**New hot path check**: CardHeaderView was already present in the before-gate's SwiftUI Template inventory (236 events × 10 ms / rep). It now appears as the top user-code frame in TP because GoalCardView's body work dropped sharply, making CardHeaderView relatively more prominent. **Not a regression — CardHeaderView's absolute SwiftUI event count actually decreased -49 %.** `destroy for GoalCardView` 5 ms in rep1 is a Swift-emitted deinit during scroll cell dematerialization — expected during scroll, present in both before and after at sub-top-10 magnitude.

## 4. SwiftUI Template internal scroll-related comparison

| signal | before (mean) | after (mean) | delta |
|---|---:|---:|---:|
| DynamicContainerInfo events | 1,709 | 918 | -46 % |
| DynamicContainerInfo µs | 303,166 | 249,262 | -18 % |
| LazySubviewPlacements events | 860 | 860 | 0 % |
| LazySubviewPlacements µs | 118,818 | 156,170 | +32 % |
| Image.ImageViewChild events | 2,563 | 1,270 | -50 % |
| Image.ImageViewChild µs | 38,200 | 30,250 | -21 % |
| UpdatedHostingScrollView events | 935 | 935 | 0 % |
| UpdatedHostingScrollView µs | 22,200 | 28,490 | +28 % |
| DynamicViewList<…ModifiedContent,ModifiedContent> events | 3,678 | 444 | **-88 %** |

The dominant signals (DynamicContainerInfo, Image, DynamicViewList, GoalCardView.body) all dropped sharply. LazySubviewPlacements and UpdatedHostingScrollView µs rose 28–32 % despite identical event counts — see §5 caveat below.

## 5. The +32 % LazySubviewPlacements caveat (why this does NOT trigger REVERT)

Plan §5.2 REVERT requires "TP regression: new top-20 frame, total self-time up." LazySubviewPlacements µs rise is at the SwiftUI Template accounting layer (not TP), and:

1. Event count is unchanged (860 / 860) — placement work hasn't grown, only its per-event µs accounting did.
2. The before-gate trace had `outsideBorder` re-rendering the entire subtree as part of the stroke overlay. SwiftUI's internal accounting may have attributed some placement-adjacent work to the outer composition. With the duplicated composition removed, placement-only cost stands out more.
3. Total `swiftui-updates` row count is -41 % overall — the absolute work decreased substantially.
4. **Time Profiler shows 0 / 3 reps with `LazySubviewPlacements`-attributed user-code frame in top-10** in both before AND after — so the +32 % SwiftUI-layer µs does NOT correlate with a real CPU regression at the TP level.
5. **Animation Hitches rows went 0 / 2 / 4 → 0 / 0 / 0** — if LazySubviewPlacements had become an actual frame-drop source, Hitches would have caught it.

This is the "moved counts but not real cost" sanity check inverted: SwiftUI internal accounting shifted, but TP and Hitches confirm the change is a net win.

## 6. Plan §5.2 verdict matrix

| KEEP criterion | required | result |
|---|---|---|
| Targeted SwiftUI internal signal (`DynamicContainerInfo` / `LazySubviewPlacements` / `GoalCardView.body`) count/µs reduced ≥20 % | yes | **YES** — DynamicContainerInfo -46 % ev / -18 % µs; GoalCardView.body -94 % ev; total updates -41 % |
| TP targeted user-code frame self-time reduced ≥ 20 % | yes | **YES** — GoalCardView.body.getter eliminated from top-10 in all 3 reps |
| No new user-code frame promoted to top-20 | yes | **YES** — CardHeaderView already present and decreased; `destroy for GoalCardView` is normal scroll dematerialization |
| Hitches count reduced or unchanged | yes | **YES** — 0/2/4 → 0/0/0 (-100 %) |
| All Home smoke / rendering UITests pass | yes | **YES** — `xcodebuild test-without-building -scheme FeatureHomeExample -configuration PerfProfile -destination 'iOS Simulator,…iPhone 16 Pro Max'` → 8 tests / 0 failures, `** TEST EXECUTE SUCCEEDED **`. `HomeExampleSmokeTests.testExampleRendersReadyState` passed in 4.54 s; `HomeExampleScrollTests.testScrollFiftyCells` passed in 51.13 s with XCTMetric performance counters within thresholds. |
| No visual regression | yes | **YES** — simulator screenshot pre-commit confirmed; modifier chain produces identical outer border |

| REVERT criterion | result |
|---|---|
| TP regression (new top-20 frame, total self-time up) | NOT triggered (CardHeaderView already present; per-frame µs unchanged) |
| Hitches regression | NOT triggered (eliminated, not added) |
| Visual regression | NOT triggered (simulator screenshot intact) |
| SwiftUI signal "improvement" not accompanied by TP/Hitches improvement | NOT triggered — TP and Hitches both improved decisively |
| One-commit-one-hypothesis violated | NOT triggered (single-file diff in GoalCardView.swift) |

→ **KEEP H-C2-a.** No revert. No follow-up commit proposed in this iteration.

## 7. What was NOT touched (rules audit)

- `outsideBorder` shared modifier (`View+BorderInOutSide.swift`): unchanged. Other call sites (GoalEditCardView, CardHeaderView, StatsCardView, MainTabView) continue to use the original implementation. If similar wins are desired there, each is a separate hypothesis with its own gate.
- `compositingGroup()`: not added.
- GoalCardView's input contract / Equatable conformance: unchanged.
- HomeReducer / HomeGoalItem / GoalCardItem: unchanged.
- Image pipeline / Kingfisher / icon resolution: unchanged.
- HomeView / HomeContentSection: unchanged.

## 8. Sanity verification

- Build: `xcodebuild build -scheme FeatureHomeExample -configuration PerfProfile -destination device` → BUILD SUCCEEDED.
- Visual: simulator screenshot pre-commit (`/tmp/pass4-s2-visual/after-h-c2-a.png`) — rounded corners, outside border, selected/unselected states, header row, icons, tap areas all preserved.
- Tests: `FeatureHomeExampleUITests` under PerfProfile (iPhone 16 Pro Max simulator): 8 tests / 0 failures. `HomeExampleSmokeTests.testExampleRendersReadyState` confirms `feature.home.ready` marker reaches; `HomeExampleScrollTests.testScrollFiftyCells` confirms the 50-cell scroll path works after the modifier-chain change. XCTMetric performance counters within thresholds (no regression flag).
- Trace integrity: 18 / 18 gate traces (before + after) ended with `exit(0)`, 0 contamination, target process = `FeatureHomeExample`, args correctly forwarded.

## 9. Honest caveats

- The gate is **state-driven self-run scroll** (programmatic `ScrollViewProxy.scrollTo` + `.easeInOut(0.25)` animation), not real finger drag. The 133 ms hitch elimination, the "37 offscreen passes" elimination, and the -94 % GoalCardView.body event reduction are evidence that the modifier-chain duplication was real and was addressed. Real-finger-drag cost reduction is plausible but not directly measured by this gate.
- The LazySubviewPlacements µs increase (+32 %) is at the SwiftUI Template accounting layer only; TP and Hitches both improved. The interpretation in §5 is the most likely explanation but is not proven — only that the change is not a TP/Hitches regression.
- The improvement is concentrated in cell-materialization-time work. Idle Home (no scroll) was not re-measured; the Pass 4-S audit idle inventory is from before H-C2-a. Idle should be at-least-as-good but is not gated here.
- This single change does not address other `outsideBorder` call sites; if their per-cell composition cost matters elsewhere, those would each need their own gate.

## 10. Recommendation

- **KEEP H-C2-a (commit `d3f66be`)**.
- **No follow-up production commit in this Pass 4-S2 iteration.** The improvement is decisive on the gated scenario; additional changes would each need their own hypothesis + gate.
- **Pass 4-S2 closeable** as the first SwiftUI-template-discovery-driven optimization that produced measurable TP + Hitches improvement on this codebase, validating both the self-run harness (`d35efec`, `b325943`) and the candidate-discovery → gate → small-commit methodology end-to-end.
- Future candidates (C1 TXNavigationBar, C5 Stats scroll, C6 image accessibility) can reuse the same template: extend the self-run flag to the relevant Example app, collect SwiftUI Template → TP → Hitches gate, propose smallest possible change, gate after. Each is a separate plan with separate approval.

## 11. Workspace artifacts

- Before-gate traces: `/tmp/twix-perf-traces/pass4-s2/c2-before/home-selfrun-scroll/{timeprofiler,hitches}/`
- Before-gate SwiftUI: `/tmp/twix-perf-traces/pass4-s2/swiftui-selfrun-scroll/`
- After-gate traces: `/tmp/twix-perf-traces/pass4-s2-after/h-c2-a/{swiftui,timeprofiler,hitches}/`
- Per-trace XML + JSON: `/tmp/twix-perf-traces/pass4-s2/analysis/` (before) and `/tmp/twix-perf-traces/pass4-s2-after/analysis/` (after)
- Pre-commit visual screenshot: `/tmp/pass4-s2-visual/after-h-c2-a.png`
- Collection scripts: `/tmp/pass4-s2-gate.sh`, `/tmp/pass4-s2-after.sh`
