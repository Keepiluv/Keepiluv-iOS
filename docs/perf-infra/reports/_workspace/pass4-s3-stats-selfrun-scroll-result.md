# Pass 4-S3 — Stats self-running scroll gate result

**Candidate (renamed)**: C5 — **Stats heavy scroll LazyVGrid / stamp-cell / TXVector materialization churn** (formerly "ScrollViewChildContainerSize re-query"; the original idle-mode label is no longer accurate — Phase A showed `ScrollViewChildContainerSize` actually *decreased* from idle while real scroll-time cost concentrated in `LazySubviewPlacements<LazyVGridLayout>`, `StatsCardView.body`, `StatsCardCompletionCell.body`, `TXVector.body`, and `DynamicContainerInfo<DynamicLayoutViewAdaptor>`).

**Verdict: DEFER production fix; root cause identified.** The C5 baseline gate's 3-AND production-entry criterion failed at the Time Profiler layer (no Stats user-code in top-10; cumulative scroll/layout framework self-time < 1 % of trace; Animation Hitches reproduces "Potentially expensive app update(s)" narrative 3 / 3 reps but only 1 / 3 has ≥ 33 ms). However, two perf-only ablation experiments (§13) decomposed the SwiftUI signal source: removing `StatsCardCompletionCell`'s entire stamp `LazyVGrid` drops `swiftui-updates` by 69 % and eliminates the expensive-update narrative entirely, while removing only the per-stamp `TXVector` (keeping the grid container) drops `swiftui-updates` by only 10 %. The dominant cost is in the **LazyVGrid container + ForEach placement work**, not in TXVector's SVG rendering. **C5 is NOT closed as "no issue."** A production hypothesis **H-C5-a** is identified in §13.7 (replace `LazyVGrid(columns: 7)` with explicit `VStack / HStack` rows in `StatsCardCompletionCell`) but **deferred** pending its own plan, user approval, and full gate.

No production change implemented. Harness sources (`UITestMode.swift` flag + `StatsView.swift` `#if PERF_TESTING` branch) remain uncommitted pending user direction.

## 1. CLI

```bash
xcrun xctrace record \
  --device 00008110-00096DC42632801E \
  --template '<SwiftUI|Time Profiler|Animation Hitches>' \
  --time-limit 30s \
  --output <path>.trace \
  --launch -- org.yapp.twix.example.stats \
  -UITEST -UITEST_RENDERING_SCENARIO \
  -UITEST_SEED stats-heavy \
  -UITEST_WAIT_READY \
  -UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL
```

## 2. Trace inventory

| phase | template | rep | bundle MB | swiftui-updates | hangs | hitches | pid | term | notes |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| A | SwiftUI | 1 | 143.1 | 640,591 | 0 | 15 | 2663 | exit(0) | OK |
| A | SwiftUI | 2 | 142.8 | 641,132 | 0 | 22 | 2664 | exit(0) | OK |
| B | SwiftUI | 3 | 142.6 | 642,106 | 0 | (n/a in this re-check) | 2708 | exit(0) | first attempt was malformed (96 B); re-collected |
| gate | Time Profiler | 1 | 9.6 | — | 0 | — | 2687 | exit(0) | TOC race in analyzer; raw count = 0 hangs / 0 hitches |
| gate | Time Profiler | 2 | 9.2 | — | 0 | — | 2688 | exit(0) | OK |
| gate | Time Profiler | 3 | 8.8 | — | 0 | — | 2689 | exit(0) | OK |
| gate | Animation Hitches | 1 | 254.0 | — | **1** | **4** | 2690 | exit(0) | OK |
| gate | Animation Hitches | 2 | 144.1 | — | 0 | 1 | 2700 | exit(0) | OK |
| gate | Animation Hitches | 3 | 138.1 | — | 0 | 2 | 2704 | exit(0) | OK |

Contamination: none across 10 traces. 1 malformed bundle (Phase B rep3 first attempt) replaced with a clean retry.

## 3. SwiftUI Template per-view inventory (Phase A + B mean, 3 reps)

Reproducibility on the 3 SwiftUI reps is exceptionally tight (rep1 / rep2 / rep3 swiftui-updates: 640,591 / 641,132 / 642,106 → spread 0.2 %).

### User-code (FeatureStatsExample / SharedDesignSystem)

| description | events / rep (mean) | µs / rep (mean) | reproducibility | type |
|---|---:|---:|---|---|
| `TXVector.body` | **10,584** | ~13,000 | 3 / 3 reps within 0.01 % | View Body Updates |
| `StatsCardView.body` | 1,902 | ~32,600 | 3 / 3 reps within 1 % | View Body Updates |
| `StatsCardCompletionCell.body` | 534 | ~18,700 | 3 / 3 reps within 3 % | View Body Updates |
| `CardHeaderView.body` | 343 | ~12,700 | 3 / 3 reps within 4 % | View Body Updates |
| `SecondaryLayerGeometryQuery` (Stats-attributed) | 42 | ~94,300 | 3 / 3 reps | Other Updates |

### SwiftUI internal scroll-related

| description | events / rep | µs / rep | Pass 4-S idle baseline | scale |
|---|---:|---:|---:|---:|
| `LazySubviewPlacements<LazyVStackLayout>` | 808 | ~468,000 | 4 ev × ~6,680 µs | **204× ev / 70× µs** |
| `LazySubviewPlacements<LazyVGridLayout>` | **11,346** | ~202,000 | ≈ idle low | order-of-magnitude |
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | 1,501 | ~323,000 | 60 × 14,000 | 25× ev / 23× µs |
| `UpdatedHostingScrollView` | 880 | ~225,000 | absent | order-of-magnitude |
| `Image.ImageViewChild<…AccessibilityProvider>` | 460 | ~14,000 | 42 × ~2,400 | ~11× |
| `Layout: AnimatableFrameAttributeVFD` | 23,623 | ~64,000 | unknown | massive |
| `ScrollViewChildContainerSize` | ~8 | small | 249 × ~2,000 | **DECREASED** — see §6 |

### Phase A vs Phase B (3rd rep) reproducibility check

Phase B rep3 swiftui-updates total: 642,106 (vs Phase A 640,591 / 641,132). All within 0.2 %. Per-view event counts identical or within 1–5 %. Phase B confirms Phase A.

Plan §6 / §9 criterion #1 (SwiftUI signal scales with self-run scroll, reproducible 3 / 3 within ±20 %): **MET** by a wide margin.

## 4. Time Profiler — top user-code per rep

Sampling windows: rep1 20.01 s, rep2 19.88 s, rep3 14.73 s. Slow functions (≥ 100 ms self-time): **0 / 3 reps**. Max single-function self-time: 39–52 ms (all individual SwiftUI framework calls; none from Stats user-code).

### rep1 (truncated by analyzer to top-10; rep1 TP had TOC export race in analyzer; counts re-verified clean)

| frame | self-time ms | samples | type |
|---|---:|---:|---|
| `DisplayList.ViewUpdater.Platform.updateItemView(_:index:item:state:)` | 21 | 21 | SwiftUI framework |
| `DisplayList.ViewUpdater.updateInheritedView(container:from:parentState:)` | 16 | 16 | SwiftUI framework |
| `static _ShapeView._makeView(view:inputs:)` | 14 | 14 | SwiftUI framework (shape rasterization) |
| `-[UIView(CALayerDelegate) layoutSublayersOfLayer:]` | 13 | 13 | UIKit |
| `static ShapeStyledLeafView.makeLeafView(...)` | 10 | 10 | SwiftUI framework |
| `-[UIScrollView setContentOffset:]` | 8 | 8 | UIKit |
| `specialized static Layout.makeLayoutView(root:inputs:body:)` | 7 | 7 | SwiftUI framework |
| `makeSecondaryLayerView<A>(...)` | 7 | 7 | SwiftUI framework |
| `specialized ColorProvider._apply(color:to:)` | 6 | 6 | SwiftUI framework |
| `HostingScrollView.updateContext(_:)` | 6 | 6 | SwiftUI framework |

### rep2 (top-10)

| frame | self-time ms | samples |
|---|---:|---:|
| `DisplayList.ViewUpdater.Platform.updateItemView(...)` | 18 | 18 |
| `static _ShapeView._makeView(view:inputs:)` | 16 | 16 |
| `DisplayList.ViewUpdater.updateInheritedView(...)` | 13 | 13 |
| `-[UIView layoutSublayersOfLayer:]` | 10 | 10 |
| `static ShapeStyledLeafView.makeLeafView(...)` | 10 | 10 |
| `specialized static Layout.makeLayoutView(...)` | 7 | 7 |
| `static StrokeShapeView._makeView(view:inputs:)` | 6 | 6 |
| `DisplayList.ViewUpdater.updateItemView(container:from:localState:)` | 6 | 6 |
| `makeSecondaryLayerView<A>(...)` | 5 | 5 |
| `-[UIScrollView setContentOffset:]` | 5 | 5 |

### rep3 (top-10)

| frame | self-time ms | samples |
|---|---:|---:|
| `DisplayList.ViewUpdater.updateInheritedView(...)` | 19 | 19 |
| `DisplayList.ViewUpdater.Platform.updateItemView(...)` | 19 | 19 |
| `static _ShapeView._makeView(view:inputs:)` | 15 | 15 |
| `static ShapeStyledLeafView.makeLeafView(...)` | 12 | 12 |
| `makeSecondaryLayerView<A>(...)` | 10 | 10 |
| `-[UIView layoutSublayersOfLayer:]` | 8 | 8 |
| `HostingScrollView.updateContext(_:)` | 7 | 7 |
| `-[UIScrollView setContentOffset:]` | 7 | 7 |
| `DisplayList.ViewUpdater.Platform._makeItemView(item:state:)` | 7 | 7 |
| `specialized static Layout.makeLayoutView(...)` | 6 | 6 |

### Plan §9 criterion #2 evaluation

- Part (a): "Stats user-code body frame in top-20 ≥ 5 ms summed, reproducible 2 / 3" — **NOT MET.** No `StatsCardView.body.getter`, `StatsCardCompletionCell.body.getter`, `TXVector.body.getter`, `CardHeaderView.body.getter`, or `StatsView.body.getter` in top-10 of any rep. The Pass 4-S2 Home gate had `GoalCardView.body.getter` at 5–6 ms in 2 / 3 reps; the Stats equivalent does not appear.
- Part (b): "Cumulative LazyVStack / DynamicContainer / ScrollView framework self-time ≥ 5 % of trace, 2 / 3" — **NOT MET.** Cumulative top-10 SwiftUI / UIKit scroll-pipeline self-time per rep is ~96–110 ms out of ~15–20 s sampling = ~0.5–0.75 % of trace. Far under 5 %.

Criterion #2: **NOT MET (both parts).**

## 5. Animation Hitches — gate detail per rep

| rep | hangs | hitches | longest hitch | longest hang | narratives |
|---:|---:|---:|---:|---:|---|
| 1 | 1 | 4 | 16.67 ms | **35.89 ms** | "Potentially expensive app update(s)" (1+) |
| 2 | 0 | 1 | 16.67 ms | — | "Potentially expensive app update(s)" |
| 3 | 0 | 2 | 16.67 ms | — | "Potentially expensive app update(s)" |

### Plan §9 criterion #3 evaluation

- Part (a): "≥ 1 hitch / hang ≥ 33 ms in 2 / 3 reps" — **NOT MET (1 / 3 strictly).** Only rep1 has a 35.89 ms event; rep2 and rep3 max at 16.67 ms.
- Part (b): "Consistent expensive-app-update / offscreen-pass narrative in 2 / 3 reps" — **MET (3 / 3 reps).** All three reps tag at least one event with "Potentially expensive app update(s)". No render-side / offscreen-pass narrative (rep3 of Home gate had "37 offscreen passes"; this Stats gate does not surface that narrative).

Criterion #3: **MET via the narrative branch (3 / 3 reps).**

## 6. 3-AND verdict

| criterion | result |
|---|---|
| #1 SwiftUI Template scaling ≥ 2× idle, 3 / 3 reps reproducible | **MET** (~200× on LazySubviewPlacements; 0.2 % cross-rep spread) |
| #2 TP Stats user-code frame in top-20 ≥ 5 ms, 2 / 3 reps OR framework ≥ 5 % | **NOT MET** (0 / 3 reps for any Stats user-code frame; framework ~0.5–0.75 % of trace) |
| #3 Hitches ≥ 33 ms in 2 / 3 reps OR consistent narrative in 2 / 3 reps | MET via narrative branch |

3-AND: **FAILS on criterion #2** at the baseline gate.

→ **DEFER per gate** at the baseline scenario; the ablation experiments in §13 then identify the actual cost source (LazyVGrid container, not TXVector content). No production change is implemented at this point. The deferred production hypothesis H-C5-a is named in §13.7 and will be planned separately.

## 7. Why criterion #2 fails despite massive SwiftUI Template signal

The SwiftUI Template signal is genuinely large — 640 k swiftui-updates / rep, 11 k LazyVGrid placements, 10 k TXVector body events, 1.9 k StatsCardView body events. But none of that work concentrates in any single user-code function call ≥ 1 ms (the Time Profiler sampling bucket). Likely structural reasons:

- **`StatsCardView` body is a thin composition** that delegates to many smaller subviews (CardHeaderView + StatsCardCompletionCell + LazyVGrid of stamp cells + TXVector icons). Each subview body cost is sub-millisecond; the aggregate work lands in SwiftUI framework frames (`DisplayList.ViewUpdater`, `ShapeStyledLeafView`, `_ShapeView._makeView`) which TP does not attribute to user code.
- **The 11 k `LazySubviewPlacements<LazyVGridLayout>` events** are the smoking gun for the stamp grid being the dominant work, but each placement is a SwiftUI internal operation. The user-code `StatsCardCompletionCell.body` runs 534× / rep but each invocation is fast enough not to bucket.
- **`TXVector.body`** at 10,584 events / rep is the most surprising signal — likely 200 cards × ~50 stamp icons average. Each TXVector.body is a tiny SVG path resolution; individually invisible to TP.
- **No single offscreen-pass narrative** appears in the Stats gate (unlike Home's rep3 "37 offscreen passes"). The render side is not hitting the Hitches Instrument's render-cost detector.

This is the same pattern Pass 4-S audit C3 (TXCalendarDateCell) and C4 (GoalDetailView) demonstrated on idle: SwiftUI Template signal moves but TP cannot find a corresponding user-code hot spot. Pass 4-S2 H-C2-a succeeded because GoalCardView's `outsideBorder` chain created a *single concentrated* cost (the `.overlay(self)` re-render) that bucketed to a TP frame. Stats has no analogous single concentrated location at the user-code layer in the current evidence.

## 8. Likely source-files (for future, post-evidence work)

For information only — NOT a production-change proposal. Anything below would require its own evidence cycle.

- `Projects/Feature/Stats/Sources/Stats/StatsView.swift` — list root.
- `Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardView.swift` — per-cell composition; uses `outsideBorder` per Pass 4-S2 grep (same shared modifier that Pass 4-S2 H-C2-a worked around locally for GoalCardView).
- `Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardCompletionCell.swift` — stamp grid; likely the `LazyVGrid` source.
- `Projects/Shared/DesignSystem` — `TXVector` location (whatever path it lives in); the 10 k events / rep suggests per-stamp SVG resolution may be cacheable, but again — needs evidence.

The Pass 4-S2 H-C2-a-style fix (local `.background { stroke }` replacement) is **technically applicable** to StatsCardView because StatsCardView also uses `outsideBorder` — but applying it here without independent gate evidence would violate the methodology contract (a side-effect-of-Home win does NOT constitute independent gate evidence for Stats). If StatsCardView's `outsideBorder` is to be touched, it requires its own gate (e.g. a smaller Stats-card-isolated scenario or interaction-time TP that bucketed StatsCardView frames).

## 9. Verdict matrix vs Pass 4-S2 H-C2-a (for comparison)

| dimension | Pass 4-S2 H-C2-a (KEPT) | Pass 4-S3 C5 (SKIP) |
|---|---|---|
| SwiftUI Template criterion | met (17× scale) | met (200× scale, even larger) |
| TP user-code frame criterion | **met** — GoalCardView.body.getter 5–6 ms / 2 of 3 | **not met** — no Stats user-code frame in top-10 |
| TP framework ≥ 5 % criterion | not separately measured | not met (~0.7 %) |
| Hitches criterion | met (133.34 ms hitch + "37 offscreen passes" narrative, both reproducible 2 of 3) | met via narrative branch (3 / 3) |
| 3-AND outcome | PASS | FAIL on #2 |
| Production change | proposed + kept | not proposed |

The contrast confirms the gate's discriminative power: a candidate with a 3× larger SwiftUI Template signal than Pass 4-S2 still gets SKIP because TP does not concentrate the cost in a single addressable user-code location. Per the methodology contract recorded in `pass4-s2-closeout.md` §4, "SwiftUI Template counts alone never justify a production change." This is that rule in action.

## 10. Honest caveats

- The Stats SwiftUI Template gate hitches counts (15 / 22) are higher than the dedicated Animation Hitches gate counts (4 / 1 / 2 plus 1 hang). Both use the same `hitches` table schema. The most likely cause is detection-window difference between the SwiftUI template's bundled hitch detector and the Animation Hitches template — I did not investigate further because the Animation Hitches template is the authoritative source per plan, and even it does meet the narrative criterion across 3 / 3 reps.
- The "Potentially expensive app update(s)" narrative across all 3 Hitches gate reps IS real signal — it just doesn't concentrate in a TP-bucketable user-code frame. A future, larger investigation could attempt to attribute it via Instruments.app GUI with the Hitches inspector's stack viewer (which the xctrace CLI does not surface directly).
- Phase B rep3 had to be re-collected after the first attempt produced a 96-byte malformed bundle. The retry was successful and within 0.2 % of Phase A reps. The malformed bundle was likely an xctrace transient — no contamination indicator in the logs.
- Pass 4-S audit's original C5 label "Stats ScrollViewChildContainerSize re-query" was an idle-mode characterization that does not survive interactive scrolling (idle: 249 events; self-run: 8). The candidate has been renamed in this document and should be renamed in the audit follow-up if Pass 4-S2-style methodology is applied to other candidates.

## 11. Recommendation

- **C5: DEFER production fix; root cause identified.** The baseline gate failed criterion #2, but the §13 ablation experiments isolated the cost source (LazyVGrid container/ForEach placement in `StatsCardCompletionCell`, not TXVector). The deferred production hypothesis H-C5-a is in §13.7 and will be drafted as a separate plan with its own approval cycle.
- **Do NOT apply the Pass 4-S2 H-C2-a fix to StatsCardView's `outsideBorder` usage** without independent gate evidence. Cross-feature transfer of a fix violates the one-hypothesis-one-gate contract.
- **Working tree state**: ablation source changes have been reverted. Only the Stats self-run scroll harness remains (`UITestMode.isSwiftUISelfRunStatsScroll` + the `#if PERF_TESTING` `ScrollViewReader` branch in `StatsView.cardList`), which will be used by H-C5-a's after-gate. No DesignSystem files are modified.
- **Pass 4-S3 is closeable as "deferred, root cause identified"** rather than "SKIP." The methodology contract holds: SwiftUI Template signal alone is not enough; the ablation provided perf-only attribution of the cost source; H-C5-a will run its own TP+Hitches gate.

## 12. Workspace artifacts

- Phase A traces: `/tmp/twix-perf-traces/pass4-s3/swiftui-selfrun-scroll/stats-heavy-selfrun-scroll-rep[12].trace`
- Phase B trace: `/tmp/twix-perf-traces/pass4-s3/swiftui-selfrun-scroll/stats-heavy-selfrun-scroll-rep3.trace`
- TP gate traces: `/tmp/twix-perf-traces/pass4-s3/c5-before/stats-selfrun-scroll/timeprofiler/stats-heavy-selfrun-scroll-rep[123].trace`
- Hitches gate traces: `/tmp/twix-perf-traces/pass4-s3/c5-before/stats-selfrun-scroll/hitches/stats-heavy-selfrun-scroll-rep[123].trace`
- Per-trace SwiftUI XML + JSON: `/tmp/twix-perf-traces/pass4-s3/analysis/selfrun-scroll-rep[12].{swiftui-updates.xml,json}` (Phase A); rep3 analysis on demand
- Collection scripts: `/tmp/pass4-s3-gate.sh`
- Plan doc (committed): `docs/perf-infra/reports/_workspace/pass4-s3-stats-selfrun-scroll-plan.md`
- Harness sources (uncommitted):
  - `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift` (M — `isSwiftUISelfRunStatsScroll` flag)
  - `Projects/Feature/Stats/Sources/Stats/StatsView.swift` (M — `#if PERF_TESTING` ScrollViewReader branch)
- Pre-build simulator screenshot: `/tmp/pass4-s3-visual/stats-default.png` (no self-run; visual sanity reference)

---

## 13. Addendum — root-cause decomposition via ablation experiments

The gate-failure verdict in §6 was correct in spirit but masked the actual cost source. Two perf-only ablation experiments under `#if PERF_TESTING` + new launch flags were run to discriminate where the SwiftUI signal comes from. **No production change was made.** Sources remain uncommitted pending direction.

### 13.1 Ablation flags

| flag | scope |
|---|---|
| `-UITEST_SWIFTUI_SELF_RUN_STATS_ABLATE_STAMP_GRID` | Experiment A — replace the entire `LazyVGrid` of stamps with a `Color.clear` placeholder of similar height. |
| `-UITEST_SWIFTUI_SELF_RUN_STATS_ABLATE_TXVECTOR` | Experiment B — keep `LazyVGrid` + `ForEach(0..<goalCount)` + spacing intact; replace each per-stamp `TXVector` with `Circle().fill(Color.Gray.gray200)` at the same frame size. |

Deterministic precedence in StatsView: if both flags are set, A wins and B is forced to `false`. Single-flag runs only.

### 13.2 Baseline vs A vs B — head-to-head (Stats self-run scroll, PerfProfile, 30 s window)

Means across reps (A: 2 SwiftUI; B: 2 SwiftUI; baseline: 3 SwiftUI + 3 Hitches gate).

| metric | C5 baseline | Experiment A (ABLATE_STAMP_GRID) | Experiment B (ABLATE_TXVECTOR) |
|---|---:|---:|---:|
| `swiftui-updates` total | 641,276 | 199,108 (**-69 %**) | 576,525 (**-10 %**) |
| `View Body Updates` total | 15,388 | 4,490 (-71 %) | _not separately extracted_ |
| `swiftui-changes` rows | 104,650 | 35,702 (-66 %) | 116,220 (**+11 %**) |
| `swiftui-causes` rows | 1,165,586 | 291,475 (-75 %) | 1,072,344 (-8 %) |
| `TXVector.body` events | 10,584 | **0** (-100 %) | _LazyVGrid kept → still many; not separately extracted_ |
| `LazySubviewPlacements<LazyVGridLayout>` events | 11,346 | **0** (-100 %) | _LazyVGrid kept → still ~11K_ |
| `StatsCardView.body` events | 1,902 | 2,065 | _not separately extracted_ |
| Animation Hitches `hitches` (Hitches gate, 3 reps) | 7 total (4 / 1 / 2) | 1 total (0 / 0 / 1) | _SwiftUI Template counts: 8 / 4 → mean 6; TP/Hitches gate NOT run, see §13.4_ |
| `potential-hangs` (Hitches gate, 3 reps) | 1 total (rep1: 35.89 ms hang) | 0 total | _not collected_ |
| "Potentially expensive app update(s)" narrative reproducibility | 3 / 3 reps | 0 / 3 reps | _not collected (gate not run; SwiftUI-template-recorded hitches drop from 19 mean to 6 mean, ~-68 %)_ |

### 13.3 Per-experiment trace bundle / process integrity

| experiment | rep | bundle MB | termination | pid | args confirmed |
|---|---:|---:|---|---:|---|
| A | 1 | 91.9 | exit(0) | 2730 | ✓ |
| A | 2 | 91.7 | exit(0) | 2731 | ✓ |
| B | 1 | 134.0 | exit(0) | 3151 | ✓ |
| B | 2 | 133.6 | exit(0) | 3152 | ✓ |

A's bundles are 91 MB (matching Home Pass 4-S2's ~91 MB self-run bundle size); B's bundles are 133 MB (closer to baseline's 143 MB, consistent with LazyVGrid placements still firing).

### 13.4 Why TP / Hitches gate was NOT run for Experiment B

Per plan §5: "If Experiment B does not materially reduce SwiftUI signal, do not run TP/Hitches; write the conclusion and stop." The B vs baseline delta on `swiftui-updates` is **-10 %** (576,525 vs 641,276), and `swiftui-changes` actually rose +11 %. This is well below the "material reduction" threshold A demonstrated (-69 %). Per the plan, TP / Hitches × 3 was skipped and B's conclusion is drawn from SwiftUI Template alone — with the explicit caveat that SwiftUI Template counts alone do not justify a production change.

The Hitches *table* (which the SwiftUI Template records alongside SwiftUI events) dropped from 19 mean (baseline SwiftUI-template-recorded) to 6 mean (B) — a 68 % drop. This is meaningful but less than A's 92 % drop and is not authoritative without a dedicated Animation Hitches gate.

### 13.5 Verdict — LazyVGrid-primary; A is over-removal, not production-valid; B rules out TXVector

Per plan §4 evaluation matrix:

- "**If B ≈ baseline**: LazyVGrid/container/ForEach layout is the primary cause, not TXVector. Production candidate should investigate replacing LazyVGrid with explicit row stacks or capping/virtualizing stamp rendering."

B's `swiftui-updates` and `swiftui-changes` are essentially baseline; only the Hitches table (informally) drops. Removing TXVector while keeping LazyVGrid does NOT recover the gains Experiment A produced. Therefore:

→ **C5 attribution: LazyVGrid container / `ForEach(0..<goalCount)` placement work in `StatsCardCompletionCell` is the primary SwiftUI signal amplifier in Stats self-run scroll. TXVector contributes to per-frame render cost (8 / 4 informal SwiftUI-template-recorded hitches vs A's 1 / 0 / 1) but is NOT the dominant SwiftUI-count source.**

**Critical caveats about the experiments themselves:**

- **Experiment A is an over-removal, NOT a production-valid fix.** It hides the stamp grid entirely behind `Color.clear`, which would remove the visible stamp UI users see. A's 69 % drop demonstrates the cost SOURCE; it does NOT mean "removing the stamp grid is the solution." A production fix must preserve the rendered stamp output.
- **Experiment B rules out the TXVector-caching hypothesis as the primary fix class.** Replacing `TXVector` with `Circle` (a simpler view with no SVG path resolution) does not recover A's gains — so caching TXVector or replacing it with a static `Image` would NOT address the dominant cost. The primary cost is the container layout (LazyVGrid placement of N slots per cell × M visible cells), independent of what's inside each slot.

This is consistent with the Pass 4-S audit's observation that Stats `LazySubviewPlacements` µs is ~2× heavier per event than Home — the per-placement work in LazyVGrid (column-flexible layout, ForEach materialization, slot-level placement) accumulates across hundreds of cells during self-run scroll regardless of what content fills each slot.

### 13.6 Caveats

- B was 2 SwiftUI reps only (matching plan §3 / §4). No TP / Hitches gate. Production claim requires a separate gate per the methodology contract.
- The Circle replacement may be lighter than TXVector at the rasterization layer, which could account for the informal Hitches drop without a corresponding SwiftUI-count drop. The Hitches drop is therefore not interpreted as "TXVector contributes meaningful CPU cost" without TP corroboration.
- LazyVGrid + ForEach(0..<N) over an Int range with `id: \.self` is itself a known SwiftUI scroll-cost pattern, but no production change is proposed here — that's a separate hypothesis with its own gate.
- The `swiftui-changes` rising +11 % in B vs baseline is curious — possibly the simpler Circle re-triggers more layout changes because its size is computed at draw-time differently from TXVector's SVG path. Not investigated further; cosmetic to the LazyVGrid-primary verdict.
- All ablation code stays under `#if PERF_TESTING + UITestMode.isEnabled + flag`. Production default `false` everywhere; production behavior unchanged.

### 13.7 Next production hypothesis — H-C5-a (DEFERRED, not implemented)

**Identified, not started.** H-C5-a is the smallest-scope candidate that addresses the LazyVGrid-primary attribution while preserving production visual output:

- **H-C5-a — Stats stamp grid `LazyVGrid` → explicit `VStack` of `HStack` rows.**
  - File target: `Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardCompletionCell.swift` (one file).
  - Change shape: replace `LazyVGrid(columns: 7-flexible-column GridItem array, spacing: 4) { ForEach(0..<goalCount, id: \.self) { stampView(at:) } }` with `VStack(spacing: 4) { ForEach(0..<rowCount) { row in HStack(spacing: ?) { ForEach((row * 7)..<min((row + 1) * 7, goalCount)) { stampView(at: $0) } } } }`. Eager layout; no Lazy materialization for the 1–5 rows actually present per cell (`goalCount` 0–30 in `stats-heavy`).
  - Visual preservation: identical iconSize, identical row spacing, identical column count (7), identical per-stamp `TXVector` content. Slight rendering shift possible at the last-row column spacing (since `LazyVGrid(.flexible())` distributes column width while `HStack` would need explicit column-equal sizing) — visual sanity must verify.
  - Explicitly NOT in H-C5-a scope: no TXVector caching, no stamp count cap, no `Canvas` / `ImageRenderer`, no shared `outsideBorder` modifier touched.
  - After-gate (mandatory before keep): same Stats self-run scroll scenario, SwiftUI × 3 + TP × 3 + Animation Hitches × 3 on the same device + PerfProfile.
  - **KEEP** only if:
    - `swiftui-updates` total drops ≥ 30 % (intermediate target between B's -10 % and A's -69 %; A is unrealistic upper bound since it removes content).
    - `LazySubviewPlacements<LazyVGridLayout>` events drop substantially or become `LazySubviewPlacements<HStackLayout>` (or equivalent) at lower count.
    - Animation Hitches: hitch count reduced or unchanged AND the "Potentially expensive app update(s)" narrative reproducibility drops below 3 / 3 reps.
    - TP: no new user-code frame promoted to top-20; aggregate scroll/layout framework self-time not increased.
    - All `FeatureStatsExampleUITests` pass.
    - Simulator screenshot: stamps visible, identical sizing/spacing, no visual regression.
  - **REVERT** if: visual regression, SwiftUI-only improvement without TP/Hitches support, new hot path, test regression.

Other candidate classes that were considered and rejected as **first** hypothesis (each carries higher risk and is not on the table for H-C5-a; they may be revisited if H-C5-a fails its gate):

- Cap rendered stamp count at viewport-visible — would visually change the rendered count.
- Move stamp grid behind a lazy `onAppear` reveal — would introduce pop-in.
- Cache the stamp grid as a static `Image` / `Canvas` — would require image lifecycle management and pay first-paint cost.

The plan for H-C5-a will live at `docs/perf-infra/reports/_workspace/pass4-s3-h-c5-a-plan.md` (separate document, draft-only until user approves execution).

### 13.8 Recommendation

- **C5 verdict: DEFER production fix; root cause identified.** Not "no issue," not "skip indefinitely."
- **Ablation source changes have been reverted.** Only the Stats self-run scroll harness remains in the working tree (`UITestMode.isSwiftUISelfRunStatsScroll` + the `#if PERF_TESTING` `ScrollViewReader` branch in `StatsView.cardList`). DesignSystem files are at baseline. The harness will be used by H-C5-a's gate.
- **C5 attribution recorded.** The candidate is no longer "ScrollViewChildContainerSize re-query" nor "TXVector caching" — it is "Stats heavy scroll LazyVGrid container/ForEach materialization in `StatsCardCompletionCell`."
- **H-C5-a is the next production hypothesis, deferred.** Awaiting user approval of its plan + execution.
- **No further experiments at this stage.** Plan §5 stop condition triggered (B did not materially reduce SwiftUI signal); ablation has done its job.
