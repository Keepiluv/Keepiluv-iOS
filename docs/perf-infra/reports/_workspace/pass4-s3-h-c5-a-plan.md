# Pass 4-S3-H-C5-a — Stats stamp grid `LazyVGrid` → explicit `VStack` of `HStack` rows (plan draft)

**Status**: DRAFT — not yet executed. Production hypothesis derived from Pass 4-S3 C5 ablation attribution (`pass4-s3-stats-selfrun-scroll-result.md` §13). One file. No TXVector caching. No stamp cap. No `Canvas` / `ImageRenderer`. Visual output preserved.

**Do NOT implement without explicit user approval.**

---

## 1. Why H-C5-a

From `pass4-s3-stats-selfrun-scroll-result.md` §13:

- C5 baseline self-run scroll: SwiftUI Template signal ~641 K updates / rep, reproducible 3/3 within 0.2 %. Animation Hitches: 7 hitches + 1 hang across 3 reps; "Potentially expensive app update(s)" narrative 3/3 reps.
- Experiment A (remove entire stamp grid): -69 % updates, 0 hitches narratives — confirms cost source is inside the stamp grid, but A is over-removal (hides stamps) and is not production-valid.
- Experiment B (keep grid, replace TXVector with Circle): -10 % updates only. Rules out TXVector content as primary cost.

→ Primary cost is the **`LazyVGrid` container + `ForEach(0..<goalCount, id: \.self)` placement work**, not the per-slot content. Replacing the lazy container with eager rows preserves visual output and is the smallest-scope production candidate that addresses the identified root cause.

## 2. Target file (one file)

`Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardCompletionCell.swift`

No other production files touched. Cross-feature blast radius: `StatsCardCompletionCell` is internal to `SharedDesignSystem` and currently used only by `StatsCardView` (per Pass 4-S2 / Pass 4-S3 grep).

## 3. Proposed change shape

**Before** (lines 35–44):

```swift
if showsStampGrid {
    LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
        ForEach(0..<goalCount, id: \.self) { count in
            stampView(at: count)
        }
    }
}
```

with `columns = Array(repeating: GridItem(.flexible()), count: 7)` (line 16).

**After** (shape only — exact diff to be finalized at implementation time):

```swift
if showsStampGrid {
    VStack(spacing: Constants.gridSpacing) {
        ForEach(0..<rowCount, id: \.self) { row in
            HStack(spacing: Constants.gridSpacing) {
                ForEach(slotsInRow(row), id: \.self) { slot in
                    stampView(at: slot)
                }
                if row == rowCount - 1, slotsInRow(row).count < Constants.gridColumnCount {
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
```

with helpers:

```swift
private var rowCount: Int {
    max(0, (goalCount + Constants.gridColumnCount - 1) / Constants.gridColumnCount)
}

private func slotsInRow(_ row: Int) -> Range<Int> {
    let start = row * Constants.gridColumnCount
    let end = min(start + Constants.gridColumnCount, goalCount)
    return start..<end
}
```

Decision deferred to implementation: whether the trailing-row `Spacer(minLength: 0)` is needed. `LazyVGrid(.flexible())` distributes column width across the available cell width; an `HStack` without spacers would left-align stamps in a short final row. If visual sanity shows the last row needs to align identically (which the original layout does via `.flexible()`), an explicit `Spacer(minLength: 0)` is the simplest fix. Decided at the visual-sanity step, not now.

## 4. What is NOT changed

- `goalCount` data path — unchanged.
- `stampView(at:)` body — unchanged (still uses `TXVector`).
- `Constants.gridColumnCount`, `Constants.gridSpacing`, `Constants.iconSize`, `Constants.cellPadding`, `Constants.cellVerticalSpacing` — unchanged.
- `StatsCardCompletionCell` init signature — unchanged.
- `StatsCardView` — unchanged.
- `StatsView` (and the Stats self-run scroll harness committed at `28adce3` predecessors) — unchanged.
- `outsideBorder` shared modifier — unchanged (Pass 4-S2 H-C2-a's lesson stays a separate hypothesis if ever needed for Stats).
- Reducer / state / identity / Equatable conformance — unchanged.
- Image / Kingfisher / icon caching — unchanged.

## 5. Build / visual sanity (before commit)

1. `tuist generate --no-open`.
2. `xcodebuild build -workspace Twix.xcworkspace -scheme FeatureStatsExample -configuration PerfProfile -destination 'platform=iOS,id=00008110-00096DC42632801E'` → BUILD SUCCEEDED.
3. Simulator visual sanity (`iPhone 16 Pro Max`):
   - Install with `stats-heavy` seed (no self-run flag).
   - Screenshot the Stats list with multiple cards. Compare to baseline screenshot (`/tmp/pass4-s3-visual/stats-default.png`).
   - Visual checklist:
     - Each stamp icon: identical size (`iconSize` = 18 pt).
     - Row spacing: identical (`gridSpacing` = 4 pt).
     - Column count per row: 7.
     - Last (short) row left-aligned identical to original `LazyVGrid(.flexible())` behavior. If `.flexible()` was distributing column widths, ensure the explicit `HStack` matches — adjust trailing `Spacer(minLength: 0)` decision here.
     - Card outer border / clipping / `outsideBorder` — unchanged.
     - Selected vs unselected card states — unchanged.
   - If any visual discrepancy, **stop**, do NOT commit. Revisit the diff (e.g. column-equal-width via explicit frame, or different Spacer strategy).

## 6. After-gate (mandatory before keep, after commit)

Same scenario, same device, same PerfProfile configuration as the C5 baseline gate. Reuse the harness committed at `b325943`'s predecessor (Stats self-run scroll, `-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL`).

| template | reps | window |
|---|---:|---:|
| SwiftUI | 3 | 30 s |
| Time Profiler | 3 | 30 s |
| Animation Hitches | 3 | 30 s |

Trace root: `/tmp/twix-perf-traces/pass4-s3-after/h-c5-a/`.

## 7. KEEP criteria

**ALL of the following required**:

1. **SwiftUI Template**:
   - `swiftui-updates` total drops ≥ 30 % vs C5 baseline (~641 K). Target range: 380–460 K.
   - `LazySubviewPlacements<LazyVGridLayout>` events go to **zero** (the type is removed from the tree). Equivalent placement events under `LazySubviewPlacements<...>` for `VStack` / `HStack` should be substantially smaller, OR — since `VStack` / `HStack` are eager — should not appear at all in `LazySubviewPlacements` (they're not lazy containers).
   - Total scroll-related SwiftUI internal events (any `LazySubviewPlacements`, `DynamicContainerInfo<DynamicLayoutViewAdaptor>`, `Layout: ...`) reduced. Specifically `swiftui-changes` rows must drop relative to baseline (baseline ~105 K, B was +11 % which is wrong direction; H-C5-a should be substantially lower).

2. **Time Profiler**:
   - No new user-code frame promoted to top-20.
   - Aggregate scroll/layout framework self-time (the sum of `DisplayList.ViewUpdater.*`, `_ShapeView._makeView`, `ShapeStyledLeafView.makeLeafView`, `Layout.*`, UIScrollView frames) does NOT increase vs baseline; ideally decreases.
   - `StatsCardView.body.getter` / `StatsCardCompletionCell.body.getter` may newly appear in top-10 (analogous to Experiment A's effect of unmasking user-code frames) — that is acceptable and does NOT count as "new hot path" for revert purposes, but the magnitude must stay below 10 ms summed / 10 samples per rep.

3. **Animation Hitches**:
   - Hitch count reduced or unchanged vs baseline (baseline mean 2.3 / rep with 1 hang).
   - "Potentially expensive app update(s)" narrative reproducibility drops below 3 / 3 reps (baseline was 3 / 3). Target: ≤ 1 / 3 reps with the narrative.
   - No new severe hang (≥ 100 ms) introduced.

4. **Tests**: `FeatureStatsExampleUITests` 8/8 (or current count) pass under PerfProfile simulator.

5. **Visual**: simulator screenshot matches baseline. No regression in iconSize / row spacing / column alignment / card border / selected-state appearance.

## 8. REVERT criteria

**ANY one triggers REVERT**:

- Visual regression on any item in §5 visual checklist.
- SwiftUI Template counts drop but TP framework self-time INCREASES (means we moved counts without moving real cost — exact "moved counts but not real cost" rule from Pass 4-S2 methodology).
- TP introduces a new user-code top-20 frame above 10 ms / rep summed, reproducible 2/3 reps.
- Animation Hitches count increases vs baseline.
- New "Potentially expensive render, N offscreen passes" narrative appears (would indicate the explicit-row layout creates rasterization regressions).
- Any `FeatureStatsExampleUITests` test fails.

## 9. Stop conditions

The plan stops without commit if any of:

1. **30-min infra cap**: implementation + build + simulator sanity exceeds 30 minutes without producing a buildable variant that passes visual sanity. Likely cause: column-width distribution turns out non-trivial; signals a need to redesign the diff.
2. **Visual sanity fails immediately**: stamp positions, sizes, or row alignment diverge from baseline screenshot. The fix space (explicit column-width frame vs Spacer-balanced HStack vs Grid-based eager equivalent) is broader than expected.
3. **After-gate hitches gate fails**: hitch count rises or new severe hang appears. Revert.
4. **After-gate TP shows new user-code top-20 hot path ≥ 10 ms / rep summed in 2 / 3 reps**.
5. **Sources need to touch any file other than `StatsCardCompletionCell.swift`**. The whole point of H-C5-a is single-file scope. If implementation requires a cross-file change, stop and re-plan.

## 10. Explicitly NOT in scope

- TXVector caching, `Image` snapshot, or any per-stamp content optimization (Experiment B ruled out TXVector as primary).
- Stamp count cap or viewport-virtualization (would visually change the rendered count).
- `Canvas` / `ImageRenderer` rendering (first-paint cost; lifecycle complexity).
- `LazyVGrid` parameter tuning (column count change, spacing change, alignment change) — would visually regress.
- Equatable / input-stability changes (Pass 3 Commit 6 territory; explicitly forbidden).
- Shared modifier (`outsideBorder` etc.) changes (cross-cutting; would require its own gate).
- Reducer / state / identity changes.
- Any other Stats file (`StatsView`, `StatsCardView`, `StatsReducer`, `StatsCoordinator`, etc.).

## 11. Approval protocol

1. **Plan approval (this document)**: user reviews and approves the change shape in §3, the visual sanity rules in §5, the KEEP criteria in §7, the REVERT criteria in §8, and the stop conditions in §9.
2. **Implementation approval**: after the diff is drafted (read-only first), user sees the actual code change in `StatsCardCompletionCell.swift` and approves before any commit.
3. **After-gate execution approval**: user approves running the 9-trace gate after the production commit.
4. **Keep/revert verdict**: user reviews the after-gate result doc and confirms keep or revert. Pass 4-S2 H-C2-a's pattern.

No production code is written and no traces are collected without explicit approval at each step.

## 12. Expected files / cost

| stage | file changes | trace count | wall-clock estimate |
|---|---|---:|---|
| Plan (this doc) | 1 doc file | 0 | done |
| Implementation diff | 1 source file (`StatsCardCompletionCell.swift`) | 0 | ~15 min |
| Build + visual sanity | (no source change) | 0 | ~10 min |
| Commit | (single commit) | 0 | ~5 min |
| After-gate collection | (no source change) | 9 (SwiftUI ×3 + TP ×3 + Hitches ×3) | ~20 min |
| Analysis + verdict doc | 1 new doc file | 0 | ~30 min |
| Keep/revert | (possibly 1 revert commit) | 0 | ~5 min |

**Total wall-clock if approved end-to-end: 85–95 min.** Less if a stop condition fires.

## 13. Expected output

If approved and executed:

- One production commit modifying `StatsCardCompletionCell.swift` only. Commit message: `perf(stats): replace stamp grid LazyVGrid with eager VStack rows`.
- One after-gate result doc: `docs/perf-infra/reports/_workspace/pass4-s3-h-c5-a-after-gate.md`.
- Possibly one closeout doc: `docs/perf-infra/reports/_workspace/pass4-s3-closeout.md` matching Pass 4-S2's pattern.
- If REVERT triggered: one revert commit + an addendum to the result doc.

## End of plan

Awaiting approval to proceed to the implementation diff stage.
