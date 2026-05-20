# Pass 4-S2 — Closeout (Home self-running scroll)

**Status**: closed. First Pass 4-S candidate to survive **all three** gate layers — SwiftUI Template → Time Profiler → Animation Hitches — and produce a kept production optimization on this codebase.

## 1. Outcome

- **C2 Home self-running scroll gate PASSED.** All three plan §5.1 criteria met: SwiftUI Template signal scaled an order of magnitude vs idle baseline; `GoalCardView.body.getter` appeared in Time Profiler top-10 at 5–6 ms in 2 / 3 reps; Animation Hitches showed a reproducible "Potentially expensive app update(s)" narrative including a 133.34 ms Brief Unresponsiveness in rep2 and a "37 offscreen passes" render hitch in rep3. Detailed evidence in `pass4-s2-home-selfrun-scroll-result.md`.
- **H-C2-a GoalCardView outside-border fix was implemented and kept.** Single-file diff in `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardView.swift` (commit `d3f66be`) replacing the shared `outsideBorder(...)` modifier usage with a local `.background { RoundedRectangle(...).stroke(..., lineWidth: borderWidth * 2) }`. Removes the duplicated subtree composition that `outsideBorder` produced via its internal `.overlay(self)` trick. After-gate verdict KEEP recorded in commit `68e2cb9`. Detailed before/after numbers in `pass4-s2-h-c2-a-comparison.md`.

## 2. Headline numbers (before-gate mean of 3 reps vs after-gate mean of 3 reps)

| metric | before | after | delta |
|---|---:|---:|---:|
| `swiftui-updates` total rows | 204,598 | 121,310 | **-40.7 %** |
| `View Body Updates` total | 6,892 | 2,245 | **-67.4 %** |
| `GoalCardView.body` events | 2,642 | 166 | **-93.7 %** |
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` events | 1,709 | 918 | **-46 %** |
| Animation Hitches rows | 0 / 2 / 4 | 0 / 0 / 0 | **-100 %** |
| `GoalCardView.body.getter` in TP top-10 (reps with the frame present) | 2 / 3 | 0 / 3 | eliminated |
| 133.34 ms severe hitch (Brief Unresponsiveness) reproducibility | 1 / 3 | 0 / 3 | eliminated |
| "Potentially expensive render, 37 offscreen passes" narrative reproducibility | 1 / 3 | 0 / 3 | eliminated |
| `FeatureHomeExampleUITests` (PerfProfile, iOS Simulator) | — | 8 / 8 pass | clean |
| Visual sanity (simulator screenshot of `home-heavy` seed) | — | OK | no regression |

## 3. Why this matters

- **First Pass 4-S candidate that survived all three gates.** Pass 4-S audit C3 (TXCalendarDateCell) and C4 (GoalDetailView) both passed the SwiftUI Template signal layer but failed when their TP + Animation Hitches gates returned 0 hangs / 0 hitches / no user-code frames above noise floor on idle scenarios. Pass 4-S2 broke that pattern by (a) moving to a state-driven self-run interaction scenario that exposes scroll-time materialization cost the idle gate could not, and (b) finding a single-file production change whose after-trace was decisive on TP, Animation Hitches, AND SwiftUI Template simultaneously.
- **SwiftUI Template self-run is validated as a candidate-discovery tool, NOT as final production evidence by itself.** The self-run path proved usable for surfacing per-view event/duration scaling under interaction (where attach-mode produces 0 rows on this device / OS). But the KEEP verdict for H-C2-a rests on the Time Profiler frame elimination and Animation Hitches row reduction, not on the SwiftUI Template counts. SwiftUI Template counts that moved without TP/Hitches corroboration would have triggered REVERT per plan §5.2.

## 4. Methodology contract (preserved for future candidates)

Any candidate opened from the Pass 4-S audit, or any future audit, must follow the same rule:

```
SwiftUI Template signal (launch-mode self-run if interactive)
  → Time Profiler + Animation Hitches gate (the authoritative metric)
  → one small commit (one file by default, one hypothesis)
  → after-gate (same scenario × template × reps)
  → keep or revert per documented criteria
```

SwiftUI Template counts alone never justify a production change. A SwiftUI signal that improves without a corresponding TP / Animation Hitches improvement = revert. Visual regression = revert. New top-20 hot path = revert.

Pass 4-S2 H-C2-a (commits `b325943` + `d3f66be` + `68e2cb9`) is the reference implementation of this contract.

## 5. Remaining candidates — DEFERRED, not rejected

- **C1 — `TXNavigationBar` idle re-evaluation** (Pass 4-S audit cross-feature signal). Magnitude class matched Pass 4-S C3, which failed its idle TP/Hitches gate. A self-run-driven scenario is the next step before any production change is even considered.
- **C5 — Stats `ScrollViewChildContainerSize` re-query** (Pass 4-S audit, structurally analogous to C2 but in Stats). **Recommended next candidate.** Reuses the same self-run pattern proven in Pass 4-S2: extend `UITestMode` with a `-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL` flag, add a `#if PERF_TESTING`-gated `ScrollViewReader` branch in the Stats list, drive `proxy.scrollTo(...)` across the `stats-heavy` seed, then run SwiftUI Template → TP → Animation Hitches gate. Same plan template as Pass 4-S2; same approval cycle required.
- **C6 — `Image.ImageViewChild<…AccessibilityProvider>` churn** (Pass 4-S audit, classified weak). The Pass 4-S2 H-C2-a fix already reduced this signal by ~50 % as a side effect (fewer cell re-evaluations means fewer image accessibility re-resolutions). Re-evaluate residual magnitude before opening C6 as a separate track — it may already be addressed.

These three are **deferred, not rejected**. Opening any of them requires a fresh plan with explicit user approval.

## 6. Recommended next candidate: C5 Stats self-running scroll

**Do NOT start until explicitly approved.** When approved, the plan should mirror Pass 4-S2 §1–§9 structure:

- new `UITestMode.isSwiftUISelfRunStatsScroll` flag.
- `StatsExample` host wrapper or a `#if PERF_TESTING`-gated `ScrollViewReader` branch inside the Stats list view, depending on read-only investigation.
- self-run sequence using public `ScrollViewProxy.scrollTo(_:anchor:)` across a stride of `stats-heavy` items.
- SwiftUI Template × 2 (Phase A) → +1 if reproducible (Phase B) → TP × 3 + Animation Hitches × 3 (gate) → small commit proposal only if all three criteria pass.

## 7. Pass 4-S2 commit log

| commit | what |
|---|---|
| `d35efec` | infra — SwiftUI Template self-run feasibility (Pass 4-S retry, the prerequisite that unlocked Pass 4-S2) |
| `10dc39b` | docs — Pass 4-S2 plan draft |
| `b325943` | infra + before-gate result (Home self-run scroll harness, UITestMode flag, gate evidence) |
| `d3f66be` | production fix — GoalCardView outside-border render duplication removed |
| `68e2cb9` | docs — H-C2-a after-gate KEEP verdict |
| (this commit) | docs — Pass 4-S2 closeout |

## 8. Close

Pass 4-S2 closed. No follow-up production commit. Future candidate work (C1 / C5 / C6 or any new audit finding) requires a separate planning cycle and explicit user approval before any infra or production change.
