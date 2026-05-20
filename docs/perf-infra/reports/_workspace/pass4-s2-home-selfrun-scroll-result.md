# Pass 4-S2 — Home self-running scroll gate result

**Status**: gate PASSES per plan §5.1. Production change NOT implemented. Hypothesis + one-commit plan + risk register below.

## 1. CLI

```bash
xcrun xctrace record \
  --device 00008110-00096DC42632801E \
  --template '<SwiftUI|Time Profiler|Animation Hitches>' \
  --time-limit 30s \
  --output <path>.trace \
  --launch -- org.yapp.twix.example.home \
  -UITEST -UITEST_RENDERING_SCENARIO \
  -UITEST_SEED home-heavy \
  -UITEST_WAIT_READY \
  -UITEST_SWIFTUI_SELF_RUN_FEED_SCROLL
```

## 2. Trace inventory

| phase | template | rep | bundle MB | swiftui-updates | hangs | hitches | pid | term |
|---|---|---:|---:|---:|---:|---:|---:|---|
| A | SwiftUI | 1 | 91.8 | 205,195 | — | 2 | 2438 | exit(0) |
| A | SwiftUI | 2 | 91.1 | 205,169 | — | 2 | 2440 | exit(0) |
| B | SwiftUI | 3 | 91.9 | **203,429** | — | 2 | (rerun) | exit(0) |
| gate | TP | 1 | 7.8 | — | 0 | — | 2508 | exit(0) |
| gate | TP | 2 | 7.3 | — | 0 | — | 2511 | exit(0) |
| gate | TP | 3 | 7.7 | — | 0 | — | 2512 | exit(0) |
| gate | Hitches | 1 | 227.8 | — | 0 | **0** | 2513 | exit(0) |
| gate | Hitches | 2 | 193.9 | — | 0 | **2** | 2520 | exit(0) |
| gate | Hitches | 3 | 185.5 | — | 0 | **4** | 2521 | exit(0) |

Contamination: none. Marker / self-run: succeeded (all 9 traces; per-view event-count fingerprint consistent with the scroll-step count).

Phase B SwiftUI rep3 reproducibility: 203,429 vs Phase A 205,195 / 205,169 → within 0.86 %, well inside the ±20 % bound.

## 3. SwiftUI Template per-view inventory (3 reps, mean)

Aggregated from the three `swiftui-updates` traces. Idle baseline from `pass4-s-swiftui-template-audit.md` Home heavy idle row.

| view (description / module) | idle baseline | self-run scroll mean (3 reps) | scale | type |
|---|---:|---:|---:|---|
| `GoalCardView.body` / FeatureHomeExample | 6 ev × 0.65 ms | **~2,640 ev × 40 ms** | **~440× ev / 63× ms** | View Body Updates |
| `CardHeaderView.body` / FeatureHomeExample | 11 ev × 0.44 ms | **~236 ev × 10 ms** | ~21× ev / 22× ms | View Body Updates |
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` / SwiftUI | 101 ev × 22 ms | **~1,710 ev × 303 ms** | ~17× ev / 13.8× ms | Other Updates |
| `LazySubviewPlacements<LazyVStackLayout>` / SwiftUI | 4 ev × 2.3 ms | **~860 ev × 118 ms** | **~215× ev / 52× ms** | Other Updates |
| `Image.ImageViewChild<…AccessibilityProvider>` / SwiftUI | 214 ev × 5.8 ms | **~2,563 ev × 38 ms** | ~12× ev / 6.6× ms | Other Updates |
| `DynamicViewList<_ConditionalContent<ModifiedContent, ModifiedContent>>` / SwiftUI | small | ~3,678 ev × 48 ms | order-of-magnitude | Other Updates |
| `UpdatedHostingScrollView` / SwiftUI | absent | ~935 ev × 22 ms | order-of-magnitude | Other Updates |
| `TXNavigationBar.body` / FeatureHomeExample | 2 ev × 3.3 ms | ~2 ev × ~4 ms | unchanged | View Body Updates |

Plan §5.1 criterion #1 (SwiftUI Template scaling ≥ 2× idle baseline): **met** by 7 rows simultaneously.

## 4. Time Profiler — top user-code frames per rep

Recording windows: rep1 14.92 s, rep2 15.02 s, rep3 14.49 s (effective sampling time within the 30 s recording window). Slow functions (≥ 100 ms self-time): **0 / 3 reps**. Max single-function self-time: 36–44 ms.

### rep1 top user-code (top 10 of analyzer output)

| frame | self-time ms | samples |
|---|---:|---:|
| `DisplayList.ViewUpdater.updateInheritedView(container:from:parentState:)` | 16 | 16 |
| `DisplayList.ViewUpdater.Platform.updateItemView(_:index:item:state:)` | 13 | 13 |
| `-[UIScrollView setContentOffset:]` | 10 | 10 |
| `-[UIView layoutSublayersOfLayer:]` | 9 | 9 |
| `specialized static ShapeStyledLeafView.makeLeafView(...)` | 7 | 7 |
| `DisplayList.ViewUpdater.updateItemView(container:from:localState:)` | 6 | 6 |
| `-[UIScrollView setBounds:]` | 6 | 6 |
| `Image.NamedImageProvider.resolve(in:)` | 5 | 5 |
| `specialized static Layout.makeStaticView(root:inputs:properties:list:)` | 5 | 5 |
| **`GoalCardView.body.getter`** | **5** | **5** |

### rep2 top user-code

| frame | self-time ms | samples |
|---|---:|---:|
| `DisplayList.ViewUpdater.Platform.updateItemView(_:index:item:state:)` | 14 | 14 |
| `DisplayList.ViewUpdater.updateInheritedView(container:from:parentState:)` | 13 | 13 |
| `-[UIView layoutSublayersOfLayer:]` | 10 | 10 |
| `HostingScrollView.updateContext(_:)` | 7 | 7 |
| **`GoalCardView.body.getter`** | **6** | **6** |
| `-[UIScrollView setContentOffset:]` | 6 | 6 |
| `specialized static ShapeStyledLeafView.makeLeafView(...)` | 6 | 6 |
| `specialized static Layout.makeLayoutView(root:inputs:body:)` | 5 | 5 |
| `makeSecondaryLayerView<A>(secondaryLayer:alignment:inputs:body:flipOrder:)` | 5 | 5 |
| `Image.NamedImageProvider.resolve(in:)` | 4 | 4 |

### rep3 top user-code

| frame | self-time ms | samples |
|---|---:|---:|
| `DisplayList.ViewUpdater.updateInheritedView(container:from:parentState:)` | 19 | 19 |
| `-[UIView layoutSublayersOfLayer:]` | 13 | 13 |
| `DisplayList.ViewUpdater.Platform.updateItemView(_:index:item:state:)` | 10 | 10 |
| `-[UIScrollView setContentOffset:]` | 7 | 7 |
| `DisplayList.ViewUpdater.Platform._makeItemView(item:state:)` | 6 | 6 |
| `HostingScrollView.updateContext(_:)` | 6 | 6 |
| `static _BackgroundStyleModifier.makeShapeView(modifier:inputs:shapeIsBackground:body:)` | 5 | 5 |
| `specialized static Layout.makeLayoutView(root:inputs:body:)` | 5 | 5 |
| `Image.NamedImageProvider.resolve(in:)` | 5 | 5 |
| `DisplayList.ViewUpdater.updateItemView(container:from:localState:)` | 5 | 5 |

GoalCardView.body.getter is NOT in rep3 top-10. Cumulative LazyVStack / scroll framework self-time (DisplayList + UIScrollView + HostingScrollView frames) ≈ 60–70 ms per rep, out of ~15 s effective sampling — that is < 1 % of trace, far below the plan's "≥ 5 %" alternative.

Plan §5.1 criterion #2: **first sub-clause met** ("Home user-code frame in TP top-20 with summed self-time ≥ 5 ms per rep, reproducible 2/3 reps" — `GoalCardView.body.getter` 5 ms in rep1, 6 ms in rep2 → 2/3 reps). The "5 % of trace" alternative is not met but the criterion is OR.

## 5. Animation Hitches detail (per rep)

| rep | hitch # | start | duration | narrative |
|---:|---:|---|---:|---|
| 1 | — | — | — | (no hitches) |
| 2 | 1 | 00:01.080 | **133.34 ms** | Potentially expensive app update(s) |
| 2 | 2 | 00:01.217 | 16.67 ms | Potentially expensive app update(s) |
| 3 | 1 | 00:01.040 | 16.67 ms | Potentially expensive app update(s) |
| 3 | 2 | 00:02.144 | 12.50 ms | Potentially expensive app update(s) |
| 3 | 3 | 00:05.569 | 16.67 ms | **Potentially expensive render, 37 offscreen passes** |
| 3 | 4 | 00:13.799 | 12.50 ms | Potentially expensive app update(s) |

Plan §5.1 criterion #3:

- "≥ 1 hitch in 2/3 reps with duration ≥ 33 ms": only rep2 has ≥ 33 ms hitches strictly; rep3's max is 16.67 ms. 1/3 reps under strict reading.
- **OR**: "consistent expensive-app-update narrative": rep2 and rep3 both consistently tag hitches with `Potentially expensive app update(s)`. rep3 additionally surfaces `Potentially expensive render, 37 offscreen passes`. Consistent across 2/3 reps.

Criterion #3 met via the consistent-narrative branch. The 133.34 ms hitch in rep2 (8 dropped frames) is a Brief Unresponsiveness — visible to the user.

## 6. Gate verdict

| plan §5.1 criterion | result |
|---|---|
| #1 SwiftUI scaling ≥ 2× idle | **MET** (7 rows ≥ 12× simultaneously) |
| #2 Home user-code in TP top-20 ≥ 5 ms, 2/3 reps OR framework ≥ 5 % | **MET** (`GoalCardView.body.getter` 5 ms / rep1, 6 ms / rep2) |
| #3 Hitches ≥ 33 ms 2/3 reps OR consistent narrative | **MET via narrative branch** (rep2 + rep3 both tagged "Potentially expensive app update(s)"; rep2 has 133 ms severe hitch) |

All three criteria met. **Gate PASSES.** Per plan §4, do NOT implement a fix yet; report hot frames + hitches + hypothesis + risk + one-commit plan for user approval.

## 7. Exact hot frames

User-code (reproducible across 2/3 reps):

- `GoalCardView.body.getter` — `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardView.swift:55-83`. 5–6 ms / rep self-time; 2,620–2,663 events / rep at the SwiftUI Template layer.

User-code (single-rep appearances):

- `CardHeaderView.body` — same module. 230–241 events / rep at SwiftUI Template layer; does not bucket as a top-10 TP frame (sub-ms per call) but contributes to overall scroll work.

Framework (consistent across all 3 reps, scroll pipeline):

- `DisplayList.ViewUpdater.updateInheritedView` — 13–19 ms / rep.
- `DisplayList.ViewUpdater.Platform.updateItemView` — 10–14 ms / rep.
- `-[UIView layoutSublayersOfLayer:]` — 9–13 ms / rep.
- `-[UIScrollView setContentOffset:]` / `-[UIScrollView setBounds:]` — 6–16 ms / rep.
- `HostingScrollView.updateContext(_:)` — 6–7 ms / rep2 + rep3.
- `Image.NamedImageProvider.resolve(in:)` — 4–5 ms / rep (icon resolution per card materialization).
- `ShapeStyledLeafView.makeLeafView` / `Layout.makeStaticView` / `_BackgroundStyleModifier.makeShapeView` — 5–7 ms / rep (shape rasterization).

## 8. Exact hitches

- **rep2 133.34 ms** at 1.08 s — directly after the 1 s pre-roll, on the first `scrollTo` invocation. Cold-cache materialization of multiple GoalCardView cells in one frame.
- rep3 4 hitches at 16.67 / 12.50 / **16.67 ms with "37 offscreen passes" narrative at 5.57 s** / 12.50 ms — distributed across the scroll window.
- rep1 0 hitches.

The "Potentially expensive render, 37 offscreen passes" narrative in rep3 hitch #3 is the strongest single-row evidence of a render-side cost (GPU offscreen rasterization), distinct from SwiftUI body re-eval cost.

## 9. Likely source files (read-only inspection)

| file | role | observation |
|---|---|---|
| `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardView.swift` | the View whose body re-evaluates ~2,640 times / rep | top-level body has `.clipShape(RoundedRectangle)` + `.outsideBorder(...)` modifiers (lines 78–82). Each `contentCell` (lines 113–148) adds `.clipShape(UnevenRoundedRectangle)` + `.contentShape(Rectangle())` + `.overlay(alignment:)`. A single card composes at least 6 SwiftUI layers that can trigger offscreen passes during scroll. |
| `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardItem.swift` | input data | confirm `GoalCardItem: Equatable` for any Equatable-conformance hypothesis. |
| `Projects/Feature/Home/Sources/Home/HomeView.swift:175` | call site | `ForEach(store.items) { item in goalCard(for: item).perfCell(slug: "home", stableId: item.id) }`. Closures `onHeaderTapped` / `onCheckButtonTapped` / `actionLeft` / `actionRight` recreated per `HomeContentSection.body` re-eval (lines 184–197 of HomeView.swift). |
| `Projects/Feature/Home/Interface/Sources/Home/HomeGoalItem.swift` | `HomeGoalItem: Equatable, Identifiable; id: Int64` | `card: GoalCardItem` re-derived from `goal` via `makeCard(from:)`. |

## 10. Smallest possible production hypothesis

Per plan rule #6: "Do not revive Pass 3 Commit 6 automatically. This is C2 Home scroll container/cell churn, not the old GoalCardView input-stability hypothesis."

Framed correctly for C2 (scroll churn, not idle input stability):

- **H-C2-a (Render-side, GPU)**: GoalCardView's modifier chain produces multiple offscreen passes per cell during scroll. The rep3 "37 offscreen passes" hitch points here. A small change — e.g. `.compositingGroup()` on the outer VStack to flatten the layer tree before clipShape + outsideBorder; or replacing the outer `.clipShape(RoundedRectangle) + .outsideBorder(...)` with a single combined `.background(RoundedRectangle.strokeBorder(...))` pattern that avoids the second clipping pass — should reduce offscreen-pass count without changing visual output.

- **H-C2-b (CPU body cost, frequency reduction)**: GoalCardView.body re-evaluates ~2,640 times per scroll window even though most cells' visible content is unchanged from one scrollTo to the next. SwiftUI cannot short-circuit body without `Equatable` view conformance because the stored properties include closures (`onHeaderTapped`, etc.) that are recreated per parent body call. A small change — conform `GoalCardView` to `Equatable` only over `item` (ignoring closure identity), and wrap the call site with `.equatable()` modifier — would let SwiftUI skip body re-eval when `item` hasn't changed. Risk: stale closure capture if the action closures need to update their referenced state; would need to verify the closures only forward `store.send(...)` actions, which are inherently stable references.

- **H-C2-c (Image work)**: `Image.NamedImageProvider.resolve(in:)` at 4–5 ms / rep across all 3 reps suggests the `goalEmoji: Image` resolution is happening per cell materialization. Could prefetch / cache resolved CGImage at HomeApp init. Risk: changes the icon ownership story; not surgical.

**Recommended first hypothesis**: H-C2-a (render-side offscreen pass reduction). Reasons:

1. The "37 offscreen passes" hitch in rep3 is the most specific evidence we have.
2. Render-side fixes typically have lower correctness risk than view-shape changes (no Equatable contract to maintain).
3. The change can be A/B-trace tested in a single commit.
4. It addresses the rep2 133 ms hitch's likely root cause (cold-cache cell composition where multiple layers must rasterize in one frame).

Explicitly NOT proposed as first hypothesis:
- H-C2-b conflicts with the Pass 3 Commit 6 SKIP decision in spirit (although the framing is different); requires a re-investigation of closure stability that overlaps Commit 6 territory.
- H-C2-c is broader scope.

## 11. Expected risk

For H-C2-a (offscreen-pass reduction):

- **Visual regression**: the modifier chain affects rounded-corner rendering, border drawing, and clip behavior. `.compositingGroup()` is well-documented and side-effect-free for layout. A direct combined-stroke replacement requires careful verification of identical rounded-rect + inside-border-color rendering. Mitigation: side-by-side screenshots of single-cell + multi-cell layouts before/after.
- **Smoke / rendering test regression**: existing FeatureHomeExampleSmokeTests / FeatureHomeExampleRenderingTests run against unchanged identifiers; behavior unchanged from a marker / tap-target standpoint.
- **Performance regression elsewhere**: `.compositingGroup()` adds a single offscreen pass for the whole VStack. If the cell is small enough that the old "many small passes" path was actually cheaper, the change could be a regression. The after-trace gate catches this.
- **Cross-feature reach**: GoalCardView is used in Home and EditGoalList (per Pass 4-S audit context). Changes to GoalCardView affect both. The gate scenario only covers Home; EditGoalList would need its own sanity check.

## 12. Proposed one-commit plan (for user approval, NOT executed)

If approved:

1. **Branch**: same `refactor/#310/TWI-91`.
2. **Scope**: single commit modifying `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardView.swift` only. No HomeView / HomeReducer / HomeContentSection change. No new flags.
3. **Change shape (TBD pending detailed read)**: add `.compositingGroup()` at the outer body VStack OR collapse the outer `.clipShape(RoundedRectangle) + .outsideBorder(...)` into a single shape-with-border modifier. The plan would commit only to ONE of these (whichever has lower visual-regression risk after read-only inspection). One commit = one hypothesis.
4. **Tag**: `pass4-s2-c2-before = <current HEAD on the harness-uncommitted branch>` (commit the harness first since the gate already used it).
5. **After-gate**: collect SwiftUI × 3 + TP × 3 + Hitches × 3 on the same self-run scroll scenario.
6. **Keep**: requires (per plan §5.2) ≥ 20 % reduction in `DynamicContainerInfo` / `LazySubviewPlacements` / `GoalCardView.body` SwiftUI counts AND ≥ 20 % reduction in `GoalCardView.body.getter` TP self-time AND no new hot frame AND hitches count not increased AND smoke / rendering UITests pass AND no visual regression.
7. **Revert**: any of the above unmet, or "moved counts but not real cost."

Sequencing question for user:
- **Commit the harness first** (`UITestMode.isSwiftUISelfRunFeedScroll` + HomeView gated branch) as `perf(infra): Home self-running scroll harness`, separate from any GoalCardView change. This makes the C2 before/after traces reproducible against a stable tag.
- THEN, if approved, propose H-C2-a as a separate `perf(home): GoalCardView offscreen-pass reduction` commit.

## 13. Honest caveats

- Self-run scroll is state-driven (`ScrollViewProxy.scrollTo` + `.easeInOut(0.25)` animation) — not a real finger drag. Hitches captured here are a **lower bound** on real-scroll cost. The 133 ms hitch at 1.08 s is the cold-cache materialization burst; real finger drag may produce a different burst pattern.
- TP slow-function threshold (≥ 100 ms) was not breached in any rep — the cost is "many small operations" not "one big stall." The actionable signal comes from the *combination* of (a) one severe hitch in rep2, (b) consistent expensive-app-update / offscreen-pass narrative, and (c) the SwiftUI Template scroll-attributable rows that scaled by orders of magnitude vs idle.
- `Image.NamedImageProvider.resolve(in:)` at 4–5 ms / rep is consistent across all 3 reps but the cause (per-cell goalEmoji resolution) is incidental to C2's container/cell-churn focus. Recorded for later if H-C2-a does not pass its after-gate.
- Pass 3 Commit 6 was about GoalCardView **input stability**. C2 is about GoalCardView **per-cell scroll work**. Same file, different surface. The proposed H-C2-a does not modify GoalCardView's input contract or Equatable shape — it changes the rendering modifier chain.

## 14. Workspace artifacts

- Phase A SwiftUI traces: `/tmp/twix-perf-traces/pass4-s2/swiftui-selfrun-scroll/home-heavy-selfrun-scroll-rep[12].trace`
- Phase B SwiftUI trace: `/tmp/twix-perf-traces/pass4-s2/swiftui-selfrun-scroll/home-heavy-selfrun-scroll-rep3.trace`
- Per-trace XML + JSON: `/tmp/twix-perf-traces/pass4-s2/analysis/selfrun-scroll-rep[12].{swiftui-updates.xml,json}`
- TP gate traces: `/tmp/twix-perf-traces/pass4-s2/c2-before/home-selfrun-scroll/timeprofiler/home-heavy-selfrun-scroll-rep[123].trace`
- Hitches gate traces: `/tmp/twix-perf-traces/pass4-s2/c2-before/home-selfrun-scroll/hitches/home-heavy-selfrun-scroll-rep[123].trace`
- Collection script: `/tmp/pass4-s2-gate.sh`
- Gate summary TSV: `/tmp/twix-perf-traces/pass4-s2/gate-summary.tsv`
- Harness source changes (uncommitted, gated): `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift`, `Projects/Feature/Home/Sources/Home/HomeView.swift`

## 15. Awaiting approval

- (a) Commit the harness (UITestMode flag + HomeView `#if PERF_TESTING` gated branch + this result doc) as `perf(infra): Home self-running scroll harness + C2 gate result`?
- (b) After (a), proceed with H-C2-a one-commit production change proposal? Or pick a different hypothesis from §10?
- (c) If neither is approved, hold the position and consider Pass 4-S2 closed as "gate passed, no fix implemented."

No code change until you direct (b) or (c).
