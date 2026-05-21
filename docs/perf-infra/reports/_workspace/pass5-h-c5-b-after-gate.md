# Pass 5 H-C5-b — after-gate verdict: KEEP

**Measured production commit**: `3f83193 refactor: StatsCardView 외곽선 렌더링 중복 제거 - #312`.

**Final PR code-shape note**: this after-gate measured the one-file `StatsCardView` local swap. Later review feedback promoted the same `background { stroke }` implementation into shared `outsideBorder` in `f664f2a`, so `StatsCardView` now uses the common modifier without reintroducing the duplicated subtree composition.

**After-gate scenario**: Stats self-run scroll (`-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL`), PerfProfile, device `00008110-00096DC42632801E` (iPhone, iOS 26.4.2), `--time-limit 35s` xctrace window, `stats-heavy` seed, launch mode.

**Templates × reps**: SwiftUI × 3 + Time Profiler × 3 + Animation Hitches × 3 = 9 traces.

**Verdict**: **KEEP** per plan §4.4. All KEEP criteria met. Zero REVERT criteria triggered.

The change ships. C5 closes with H-C5-b as the production-valid hypothesis. H-C5-a remains gated-and-reverted (`da2278e` → `aa4a160`); H-C5-b is the second-and-final attempt within Pass 5's one-pass-one-hypothesis budget for C5.

---

## 1. Headline before vs after (3 reps mean / total)

| metric | C5 baseline | H-C5-b after | delta | KEEP target | result |
|---|---:|---:|---:|---|---|
| Animation Hitches count per rep | 4 / 1 / 2 (mean 2.33, total 7) | **2 / 0 / 0 (mean 0.67, total 2)** | **-71 %** | reduced or unchanged | **PASS** |
| Animation Hitches hangs (≥ 33 ms) | 1 (35.89 ms severe @ rep1) | **0** | **-100 %** | unchanged or fewer | **PASS** |
| "Potentially expensive app update(s)" narrative reproducibility | **3 / 3 reps** | **0 / 3 reps** | **eliminated** | < 3 / 3 reps | **PASS** |
| "Potentially expensive render, N offscreen passes" narrative | 0 / 3 reps | 1 / 3 reps (rep1: 1 offscreen pass, 12.50 ms) | new small narrative | not in REVERT criteria as worsening; far less severe than the eliminated `app update(s)` narrative | **acceptable** |
| `swiftui-updates` total | 641,276 | **336,120** | **-47.6 %** | corroborating only (not a KEEP threshold) | **PASS** (large reduction; not single-criterion KEEP) |
| TP user-code Stats frame in top-10 | absent (0 / 3) | absent (0 / 3) | unchanged | no new top-20 user-code frame | **PASS** |
| TP framework top frames | `Platform.updateItemView`, `_ShapeView._makeView`, `ShapeStyledLeafView.makeLeafView`, `Layout.makeLayoutView` (consistent) | same set, similar magnitudes (`updateInheritedView` 11-15 ms, `Platform.updateItemView` 14-18 ms, `_ShapeView._makeView` 10-11 ms) | similar | not increased | **PASS** |
| Smoke / build | — | `StatsExampleSmokeTests/testExampleRendersReadyState` PASS (7.32 s) | clean | clean | **PASS** |
| Visual sanity (simulator screenshot) | — | identical border rendering — see §5 | identical | identical | **PASS** |

## 2. Per-rep raw data

### After-gate Animation Hitches

| rep | hitches | hangs | event detail |
|---:|---:|---:|---|
| 1 | 2 | 0 | 12.50 ms @ 4.20 s "Potentially expensive render, 1 offscreen passes"; 25.00 ms @ 5.51 s (no narrative) |
| 2 | 0 | 0 | (none) |
| 3 | 0 | 0 | (none) |

Baseline (from Pass 4-S3 H-C5-a after-gate doc §2):

| rep | hitches | hangs | event detail |
|---:|---:|---:|---|
| 1 | 4 | 1 (35.89 ms severe) | 16.67 ms @ 0.98 s; 8.33 ms @ 2.23 s **"Potentially expensive app update(s)"**; 16.67 ms @ 9.36 s; 12.50 ms @ 10.57 s |
| 2 | 1 | 0 | 8.33 ms @ X.XX s **"Potentially expensive app update(s)"** (1 hitch with narrative) |
| 3 | 2 | 0 | 2 hitches with **"Potentially expensive app update(s)"** narrative |

### After-gate Time Profiler (top user-code / framework frames)

| rep | duration | max ms | top user-code | top framework (>5 ms self-time) |
|---:|---:|---:|---|---|
| 1 | 19.42 s | 35 | none in top-10 | `updateInheritedView` 15; `Platform.updateItemView` 14; `layoutSublayersOfLayer:` 13; `_ShapeView._makeView` 10; `setContentOffset:` 9; `Layout.makeLayoutView` 8; `ShapeStyledLeafView.makeLeafView` 8 |
| 2 | 14.24 s | 36 | none in top-10 | `Platform.updateItemView` 18; `updateInheritedView` 11; `layoutSublayersOfLayer:` 10; `_ShapeView._makeView` 10; `Layout.makeLayoutView` 9; `ShapeStyledLeafView.makeLeafView` 7 |
| 3 | 19.92 s | 26 | `closure #1 in closure #1 in closure #1 in StatsView.scrollCardList.getter` 5 ms / 5 samples (rank 10) | `Platform.updateItemView` 14; `updateInheritedView` 13; `_ShapeView._makeView` 11; `ShapeStyledLeafView.makeLeafView` 9; `layoutSublayersOfLayer:` 8; `setContentOffset:` 7 |

The rep3 `StatsView.scrollCardList.getter` closure is the **self-run scroll harness driver** (under `#if PERF_TESTING` only), not production code. Same pattern was visible in H-C5-a after-gate's analyzer output. **Not** a production-side regression.

No `StatsCardView.body`, `StatsCardCompletionCell.body`, or `CardHeaderView.body` frame appears in any after-rep TP top-10. Pattern matches baseline.

### After-gate SwiftUI Template

| rep | swiftui-updates rows | bundle MB | window |
|---:|---:|---:|---|
| 1 | 337,255 | 105 | 35 s |
| 2 | 335,285 | 104 | 35 s |
| 3 | 335,819 | 104 | 35 s |

Reproducibility within 0.6 %. Compared to baseline mean 641,276 → after mean 336,120: **-47.6 %**.

**Caveat — trace window difference**: the after-gate xctrace window was 35 s, while the C5 baseline traces (`/tmp/twix-perf-traces/pass4-s3/c5-before/...`) were collected at 30 s in Pass 4-S3. The self-run scroll harness driver completes its full scroll stride within ~12-14 s; the additional 5 s in the after-gate window is post-scroll idle. Idle period contributes minimal SwiftUI updates, so the -47.6 % raw delta likely understates the actual reduction. Conservative window-normalized estimate: ≥ -40 %, which is still a large reduction in the same magnitude class as Pass 4-S2 H-C2-a (-40.7 % on Home).

The SwiftUI count is reported as **corroborating evidence only**, per plan §4.4: the KEEP decision was already made by Hitches + narrative + TP gates, all of which are window-insensitive event-count metrics (hitches are discrete events in the active scroll window, narratives are presence/absence per-rep).

## 3. KEEP / REVERT matrix per plan §4.4 / §4.5

| KEEP criterion | required | result |
|---|---|---|
| Animation Hitches per-rep count reduced or unchanged vs baseline (`4 / 1 / 2`, mean 2.33) | yes | **PASS** (2 / 0 / 0, mean 0.67, -71 %) |
| No rep with severe hang ≥ 33 ms reproduced 2/3 reps | yes | **PASS** (0 hangs after vs 1 hang before; -100 %) |
| "Potentially expensive app update(s)" narrative reproducibility < 3 / 3 reps | yes | **PASS** (3/3 → 0/3, eliminated) |
| TP top-20 contains no new user-code hot path attributable to the change | yes | **PASS** (no `StatsCardView.body` / `StatsCardCompletionCell.body` / `CardHeaderView.body` in any rep top-10; rep3's `StatsView.scrollCardList.getter` is the test-only self-run harness closure) |
| SwiftUI Template count reduction (secondary) | corroborating only | **PASS** (-47.6 %, large; not a single-criterion KEEP) |
| `FeatureStatsExampleUITests` (smoke) pass | yes | **PASS** (`StatsExampleSmokeTests/testExampleRendersReadyState` 7.32 s) |
| Visual regression — none | yes | **PASS** (simulator screenshot shows identical border geometry / color / width / corner radius / tap area, see §5) |

| REVERT criterion | result |
|---|---|
| Hitches count or stall-ms increases vs baseline | **NOT triggered** (count -71 %, severity -100 % on hangs) |
| "Potentially expensive app update(s)" narrative unchanged or worse (3/3) | **NOT triggered** (3/3 → 0/3 eliminated) |
| SwiftUI count moves but TP + Hitches do not corroborate | **NOT triggered** (Hitches dropped -71 %, hangs -100 %, narrative eliminated — strong corroboration) |
| New TP top-20 user-code hot path | **NOT triggered** |
| Visual or test regression | **NOT triggered** |
| Diff scope grew beyond 1 file | **NOT triggered** (`StatsCardView.swift` only, 12 inserts / 5 deletes) |

→ **KEEP** per plan §4.4 decision matrix.

## 4. Notes on the new "1 offscreen passes" narrative (rep1 only)

After rep1 introduces one new narrative event: "Potentially expensive render, 1 offscreen passes" at 12.50 ms (1/3 reps, sub-frame at 60 Hz). This is **not** a REVERT trigger:

- Plan §4.5 REVERT criterion #2 names the specific narrative `"Potentially expensive app update(s)" unchanged or worse` — which is in fact ELIMINATED (3/3 → 0/3).
- 1 offscreen pass is far below the severity of the H-C2-a precedent's "37 offscreen passes" narrative (which was eliminated by replacing the same `outsideBorder` modifier on `GoalCardView`). The mechanism may be inverted in scale here: the `outsideBorder` was *producing* many offscreen passes on GoalCardView; on StatsCardView the residual single-pass event is in a different render category (likely the stroke-on-rounded-rect itself).
- 1/3 reps means this is *not* reproducible enough to be a stable narrative pattern.
- 12.50 ms is sub-frame (< 16.67 ms) at 60 Hz — user-visible cost is minimal.

Recorded as an **acceptable trade**: net narrative change is `app update(s) 3/3` → `1 offscreen pass 1/3`. The disappearing narrative had the higher per-event severity (in baseline rep1 it co-occurred with the 35.89 ms severe hang).

## 5. Visual sanity (simulator)

Captured `/tmp/stats-h-c5-b-after.png` on iPhone 17 Pro Max simulator (iOS 26.2) after applying the diff and re-installing. Stats cards render with:

- Same outside-border geometry (1 pt outside stroke, gray500, 12 pt corner radius — matches baseline `outsideBorder(.gray500, RoundedRectangle(cornerRadius: 12), lineWidth: 1)`).
- Same `clipShape` interaction (inside half of stroke hidden by clipped content, outside half visible — identical to GoalCardView's H-C2-a outcome).
- Same `verticalDivider` between header and completion section (untouched).
- Same `completionSection` HStack with `StatsCardCompletionCell` and `horizontalDivider` between users (untouched).
- Same `onTapGesture` placement (last in the modifier chain — preserved).

H-C2-a's identical-visual outcome on `GoalCardView` is the relevant precedent: same `.clipShape` → `.background { RoundedRectangle.stroke(... lineWidth: × 2) }` pattern, same outcome.

## 6. Per-criterion summary

- Authoritative metric (Hitches): **-71 % count, -100 % hangs, target narrative eliminated**.
- Corroborating metric (TP): no new user-code hot path; framework profile unchanged.
- Corroborating metric (SwiftUI Template count): -47.6 % (large, same magnitude class as Pass 4-S2 H-C2-a).
- Methodology contract: SwiftUI signal moved AND TP + Hitches corroborated → opposite outcome of H-C5-a (counts moved, real cost did not). Pass 4-S2 contract proven a third time on this codebase.

## 7. Workspace artifacts

- **After-gate traces**: `/tmp/twix-perf-traces/pass5-after/h-c5-b/{swiftui,timeprofiler,hitches}/stats-heavy-selfrun-scroll-rep[123].trace` (9 bundles; SwiftUI ~104 MB each, TP 7-8 MB each, Hitches 153-258 MB each; disk free 74 GB after collection).
- **Before-gate traces** (reused intact): `/tmp/twix-perf-traces/pass4-s3/c5-before/stats-selfrun-scroll/{timeprofiler,hitches}/...` and `/tmp/twix-perf-traces/pass4-s3/swiftui-selfrun-scroll/...`.
- **Measured production commit**: `3f83193 refactor: StatsCardView 외곽선 렌더링 중복 제거 - #312`.
- **Plan**: `docs/perf-infra/reports/_workspace/pass5-h-c5-b-plan.md` (commit `349e1d3`).
- **Final shared modifier follow-up**: `f664f2a refactor: 리뷰 피드백 반영 - #312`.
- **Visual sanity screenshot**: `/tmp/stats-h-c5-b-after.png`.

## 8. C5 closure

C5 is **closed** by Pass 5 with verdict **KEEP**:

- Pass 4-S3 H-C5-a (LazyVGrid → eager VStack rows): gated-and-reverted (`da2278e` → `aa4a160`). Single-inner-container swap class exhausted.
- Pass 5 H-C5-b (StatsCardView `outsideBorder` → local `.background { stroke }`): gated-and-kept (`3f83193`). Render-side duplication class succeeded on Stats analog to H-C2-a's Home success. Final PR shape then moved the same implementation into shared `outsideBorder` via `f664f2a`.

Open hypothesis classes from handoff §2.1 (Equatable on StatsCardView, cell-content reduction, cell-pool, cell-snapshot caching) remain explicitly **not opened** in Pass 5. Pass 5's one-pass-one-hypothesis budget for C5 is satisfied; further C5 work — if ever — is a new pass with its own plan and approval.

Pass 5 proceeds to C1 / C6 / keyboard residual closure (per execution plan §5) and the Pass 5 final + cumulative reports.
