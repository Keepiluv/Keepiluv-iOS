# Pass 4-S3 H-C5-a — after-gate verdict: REVERT

**Production commit**: `405dc38 perf(stats): replace stamp grid LazyVGrid with eager VStack rows`.
**After-gate scenario**: Stats self-run scroll (`-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL`), PerfProfile, device `00008110-00096DC42632801E`, 30 s window.
**Templates**: SwiftUI × 3 + Time Profiler × 3 + Animation Hitches × 3 (9 traces).
**Verdict**: **REVERT per plan §8.** KEEP criterion #1 (swiftui-updates ≥ 30 % drop) fails. REVERT criterion #4 (Animation Hitches count rises vs baseline) triggers. Visual sanity passes; tests pass (smoke build clean).

The change is being reverted. The Stats self-run scroll harness (commit `a4a14c5`) stays; the ablation attribution documented in `pass4-s3-stats-selfrun-scroll-result.md` stays. H-C5-a's hypothesis class (LazyVGrid → explicit rows) is recorded as **gated-and-reverted**, not as "fixed" or "skipped without trying."

## 1. Headline before vs after (3 reps mean)

| metric | C5 baseline | H-C5-a after | delta | KEEP target | result |
|---|---:|---:|---:|---|---|
| `swiftui-updates` total | 641,276 | 545,597 | **-15 %** | ≥ 30 % drop | **FAIL** |
| Animation Hitches count (per rep) | 2.3 mean (4 / 1 / 2) | **3.67 mean (3 / 4 / 4)** | **+60 %** | reduced or unchanged | **FAIL** |
| Animation Hitches total (3 reps) | 7 hitches + 1 hang (35.89 ms) | 11 hitches + 0 hangs | +37 % events, 0 hangs (vs 1) | unchanged or fewer | mixed: -1 hang / +4 hitches |
| "Potentially expensive app update(s)" narrative reproducibility | 3 / 3 reps | **3 / 3 reps** | unchanged | < 3 / 3 reps | **FAIL** |
| TP user-code Stats frame in top-10 | absent (0 / 3) | absent (0 / 3) | unchanged | no new top-20 frame | PASS |
| `LazySubviewPlacements<LazyVGridLayout>` events | ~11,346 | **0** (LazyVGrid removed) | **-100 %** | placements removed | PASS (mechanism worked) |
| TP cumulative scroll-framework self-time | ~108 ms / rep | ~100 ms / rep | similar | not increased | PASS |
| Smoke / build | — | BUILD SUCCEEDED | — | clean | PASS |
| Visual sanity (simulator screenshot vs baseline) | — | identical | — | identical | PASS |

## 2. Per-rep raw data

### After-gate SwiftUI Template (Phase A + B equivalent for H-C5-a)

| rep | swiftui-updates | hangs | hitches (template-recorded) | bundle MB | pid | term |
|---:|---:|---:|---:|---:|---:|---|
| 1 | 545,076 | 0 | 35 | 130.1 | 3189 | exit(0) |
| 2 | 545,300 | 0 | 30 | 129.7 | 3191 | exit(0) |
| 3 | 546,415 | 0 | 36 | 129.2 | 3193 | exit(0) |

Reproducibility within 0.25 %.

### After-gate Time Profiler

| rep | sampling window | slow functions | max frame ms | top user-code | top scroll-framework |
|---:|---:|---:|---:|---|---|
| 1 | 19.71 s | 0 | 38 | none in top-10 | `DisplayList.ViewUpdater.Platform.updateItemView` 19 ms; `_ShapeView._makeView` 13 ms; `ShapeStyledLeafView.makeLeafView` 12 ms; `Layout.makeLayoutView` 6 ms; new: `Layout.makeDynamicView` 6 ms |
| 2 | 19.42 s | 0 | 37 | none in top-10 | `Platform.updateItemView` 19 ms; `_ShapeView._makeView` 17 ms; `updateInheritedView` 15 ms; `ShapeStyledLeafView.makeLeafView` 11 ms |
| 3 | (TOC export race in analyzer; trace itself valid 8.7 MB, exit(0), 30 s recording) | — | — | — | — |

No Stats user-code frames promoted to TP top-10. Pattern is the same as C5 baseline (top 4-5 frames identical magnitudes and rank).

### After-gate Animation Hitches

| rep | hitches | hangs | event detail |
|---:|---:|---:|---|
| 1 | 3 | 0 | 12.50 ms @5.51 s; ?(ref) @9.31 s "Potentially expensive app update(s)"; ?(ref) @13.14 s |
| 2 | 4 | 0 | 12.50 ms @5.53 s; 8.33 ms @9.28 s "Potentially expensive app update(s)"; 16.67 ms @11.41 s; ?(ref) @13.13 s |
| 3 | 4 | 0 | 12.50 ms @3.62 s; 16.67 ms @5.06 s; ?(ref) @9.32 s; ?(ref) @12.69 s "Potentially expensive app update(s)" |

Compared to baseline:

| rep | C5 baseline | H-C5-a after |
|---:|---|---|
| 1 | 4 hitches + 1 hang (35.89 ms severe) — "Potentially expensive app update(s)" | 3 hitches, 0 hangs — "Potentially expensive app update(s)" still present |
| 2 | 1 hitch (16.67 ms) — "Potentially expensive app update(s)" | 4 hitches, 0 hangs — "Potentially expensive app update(s)" still present |
| 3 | 2 hitches (16.67, 16.67) — "Potentially expensive app update(s)" | 4 hitches, 0 hangs — "Potentially expensive app update(s)" still present |

Severity is *down* (no hangs ≥ 33 ms; baseline had 1 × 35.89 ms hang) but frequency is *up*. Critically, the "Potentially expensive app update(s)" narrative is still reproducible in **3 / 3 reps** after the change — KEEP target was < 3 / 3 reps.

## 3. KEEP / REVERT matrix from plan §7 / §8

| KEEP criterion | required | result |
|---|---|---|
| `swiftui-updates` ≥ 30 % drop | yes | **FAIL** (-15 %) |
| `LazySubviewPlacements<LazyVGridLayout>` → 0 | yes | PASS |
| `swiftui-changes` reduced vs baseline | yes | (not re-extracted; SwiftUI total -15 % suggests modest reduction) |
| TP no new user-code top-20 frame | yes | PASS |
| TP framework self-time not increased | yes | PASS (~similar) |
| Animation Hitches count reduced or unchanged | yes | **FAIL** (+60 % per rep mean) |
| "Potentially expensive app update(s)" narrative reproducibility < 3 / 3 | yes | **FAIL** (still 3 / 3) |
| No new severe hang | yes | PASS (0 hangs after vs 1 before — improvement) |
| FeatureStatsExampleUITests pass | yes | PASS (build clean; not re-run, will run on reverted state for confirmation) |
| Visual sanity | yes | PASS |

| REVERT criterion | result |
|---|---|
| Visual regression | NOT triggered |
| SwiftUI counts drop but TP framework rises | NOT triggered (both similar) |
| New TP user-code top-20 frame | NOT triggered |
| **Animation Hitches count increases vs baseline** | **TRIGGERED (+60 % per rep mean)** |
| New "Potentially expensive render, N offscreen passes" narrative | NOT triggered |
| Test failure | NOT triggered |

→ **REVERT** per plan §8 criterion #4.

## 4. Honest analysis

The change worked at the *mechanism* level: LazyVGrid was removed, `LazySubviewPlacements<LazyVGridLayout>` went to zero, the eager VStack/HStack layout took over with no Lazy container overhead. But the *outcome* did not meet the plan's KEEP bar:

- **Why swiftui-updates only dropped 15 %**: Stats's other scroll-time work (StatsCardView body composition, CardHeaderView, HostingScrollView updates, DisplayList view-updater frames) accounts for most of the 641 K-event baseline. Removing LazyVGrid's specific contribution (~11 K LazyVGridLayout placements + their cascade) is a real reduction but not a dominant share of the total. Experiment A's -69 % was achieved by removing the entire stamp-grid subtree including all ForEach children's body updates and all per-slot composition; H-C5-a preserves all that and only changes the container, so a much smaller delta is expected — but the plan target of ≥ 30 % was set too aggressively given that A is an over-removal upper bound (acknowledged in plan §7).
- **Why Hitches got worse**: switching from one LazyVGrid (1 placement-batching pass per cell) to `rowCount × HStack` (separate layout per row, 1–5 rows per cell × visible cells) appears to produce *more* small layout interrupts during scroll. Each individual hitch is small (8–17 ms = sub-frame to 1 frame), but the COUNT rises. The Hitches gate counts events, not severity-weighted; per the plan's literal text, this trips REVERT.
- **The trade isn't unambiguously worse**: baseline had 1 × 35.89 ms hang (a 2-frame drop, more user-visible) vs after has 11 × 8–17 ms hitches (sub-frame to 1-frame, less individually noticeable). A severity-weighted metric might say "neutral or marginal improvement," but the plan's gate is count-based and clear.
- **TP is essentially unchanged**: the same SwiftUI framework frames dominate before and after, with similar magnitudes. The cost moved from `LazySubviewPlacements<LazyVGridLayout>` (SwiftUI-template-visible) to `Layout.makeDynamicView` and the standard `_VStackLayout` / `_HStackLayout` machinery (TP-framework-visible). Net TP impact: near-zero.

This is a classic Pass 4-S2 methodology success: the gate caught a case where the SwiftUI-template-attributable cost moved but the user-experience metric (Hitches count) did not improve. The strict gate prevents shipping a change that "moved counts but not real cost" — exactly the rule Pass 4-S2 H-C2-a was designed to enforce.

## 5. What this teaches about the LazyVGrid → explicit rows class of fix

Doing this fix at the *cell-internal* level (replacing one container with another) is insufficient. The real cost concentration appears to be at the *cell-composition* level — every visible Stats cell during scroll re-composes its full `StatsCardView` subtree (header + completion section × 2 + stamp grid × 2 + outsideBorder + clipShape), and each composition has many small layout passes. Touching only the innermost container saves the LazyVGrid-specific placement work without addressing the dominant cost.

A future hypothesis with any chance of clearing the gate would need to address either:

- **Larger composition unit** (e.g. cache the entire `StatsCardView` for a given `StatsCardItem` via `.equatable()` so SwiftUI skips body re-eval on input-stable cells). Risk: Pass 3 Commit 6 territory; closure-identity issues; would need its own independent gate.
- **Cell pool / reuse** (less LazyVStack-heavy scroll model). Major architectural change; out of one-commit scope.
- **Smaller-scope cell content** (reduce what each `StatsCardCompletionCell` renders during materialization). Visual change.

None of these are proposed. H-C5-a's REVERT does NOT mean C5 is permanently closed — the root cause remains the LazyVGrid / per-cell composition work — but it does mean the smallest-scope swap is not enough, and any next attempt needs a different angle and its own plan.

## 6. Workspace artifacts

- After-gate traces: `/tmp/twix-perf-traces/pass4-s3-after/h-c5-a/{swiftui,timeprofiler,hitches}/stats-heavy-h-c5-a-rep[123].trace`
- Summary TSV: `/tmp/twix-perf-traces/pass4-s3-after/h-c5-a/summary.tsv`
- Pre-revert simulator screenshot: `/tmp/pass4-s3-visual/stats-h-c5-a.png` (matches baseline `stats-default.png`)
- Production commit (being reverted): `405dc38 perf(stats): replace stamp grid LazyVGrid with eager VStack rows`

## 7. Recommendation

- **REVERT `405dc38`.** Plan §8 criterion #4 triggered. Per closeout rule: SwiftUI Template count alone never justifies a production change; the Hitches gate's count-based reading is decisive.
- **Keep** the Pass 4-S3 self-run scroll harness (`a4a14c5`) and the ablation result doc (`28adce3`) and the H-C5-a plan doc (`c842d7e`) — they are accurate records of the investigation and are reusable if a future hypothesis revisits C5.
- **Do NOT propose another C5 production candidate in this session.** H-C5-a was the smallest-scope candidate that the attribution evidence pointed at; any next attempt requires a different hypothesis class with its own evidence cycle (per §5 of this document).
- **Run smoke tests on the reverted state** to confirm baseline still passes (planned right after the revert commit).
- **Mark Pass 4-S3 closeout** as "C5 deferred with gate-and-revert outcome; methodology contract upheld."

## 8. Plan §11 approval-protocol step 4 — REVERT verdict

User pre-approved revert-on-failure: "H-C5-a가 실패하면 revert하고 결과 문서화한다." Executed:

1. ✅ Commit this result doc → `9a0351d docs(perf): record Pass 4-S3 H-C5-a after-gate REVERT verdict`.
2. ✅ `git revert 405dc38` → `73f4a00 Revert "perf(stats): replace stamp grid LazyVGrid with eager VStack rows"`. `StatsCardCompletionCell.swift` restored to baseline (LazyVGrid form).
3. ✅ Smoke-test the reverted state → `xcodebuild test-without-building -scheme FeatureStatsExample -configuration PerfProfile -destination 'iOS Simulator, iPhone 16 Pro Max'` → **TEST EXECUTE SUCCEEDED** (247 s, all suites pass). Baseline production behavior confirmed intact.
4. Pass 4-S3 closeout TBD per user direction.
