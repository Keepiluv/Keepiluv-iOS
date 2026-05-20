# Pass 4-S3 — Stats self-running scroll SwiftUI Template gate (plan draft)

**Status**: DRAFT — not yet executed. Successor to Pass 4-S2 (closed at `d015879`) targeting Pass 4-S audit candidate **C5 — Stats `ScrollViewChildContainerSize` re-query / Stats heavy scroll container churn**.

**This document is candidate-discovery + gate plan only. No production code is to be written without explicit user approval after the TP + Animation Hitches gate has produced evidence.**

---

## 1. Why C5 is next

- **Pass 4-S2 reference implementation succeeded.** The C2 Home scroll self-run pattern produced a kept production optimization (commit `d3f66be`) that survived SwiftUI Template + Time Profiler + Animation Hitches gates simultaneously. C5 is structurally the closest remaining candidate to C2.
- **Highest remaining Pass 4-S audit magnitude that has not been gated.** C1 (TXNavigationBar) is in the same magnitude class as C3 / C4, which both failed their idle gates. C6 (ImageAccessibilityProvider) was partially addressed as a side effect of H-C2-a (~-50 % event count) and should be re-measured before being opened as a separate track. C5 is the only Pass 4-S candidate that (a) had a non-trivial Pass 4-S idle signal, (b) has not been gated yet, and (c) has a self-run pattern proven on the sibling Home scenario.
- **Stats Pass 4-S idle signal already pointed at scroll/lazy-container cost.** This is the cleanest hypothesis class for the self-run approach.

## 2. What Pass 4-S already showed for Stats (idle)

From `pass4-s-swiftui-template-audit.md` Stats heavy idle and Stats scroll-50 idle rows (3 reps each, mean):

| metric | Stats scroll-50 idle | Stats heavy idle |
|---|---:|---:|
| total `swiftui-updates` rows | ~10,145 | ~9,621 |
| `View Body Updates` total | ~227 | ~223 |
| `Layout: ScrollViewChildContainerSize` events / µs | ~249 ev × ~2,028 µs | ~249 ev × ~1,994 µs |
| `LazySubviewPlacements<LazyVStackLayout>` events / µs | ~4 ev × ~6,644 µs (heavier per-event than Home) | ~4 ev × ~6,680 µs |
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` events / µs | ~60 ev × ~14,084 µs | ~60 ev × ~14,370 µs |
| `SecondaryLayerGeometryQuery` events / µs | ~74 ev × ~9,219 µs | ~74 ev × ~9,328 µs |
| user-code `StatsCardCompletionCell.body` events | ~20 | ~20 |

The 249-event `ScrollViewChildContainerSize` re-query on a static idle window is the headline signal. `LazySubviewPlacements` per-event µs is ~2× heavier than Home heavy idle — suggests Stats layout pipeline is doing more per placement event, likely because Stats cards (`StatsCardView`) contain a denser stamp grid via `LazyVGrid` rather than Home's flat row.

Hypothesis class for the self-run scroll scenario: when Stats actually scrolls under self-run, the per-placement work (already heavier than Home at idle) compounded across many materialization windows should produce a measurable TP / Hitches signal — analogous to what C2 produced on the Home side.

## 3. Read-only files to inspect first (no edits in this plan stage)

| file | what to confirm |
|---|---|
| `Projects/Feature/Stats/Example/Sources/StatsApp.swift` | `UITestMode` wiring and seed selector. `stats-heavy` produces 200 deterministic `Stats.StatsItem` rows. `WindowGroup` wraps `StatsCoordinatorView`, marker is `feature.stats.ready`. |
| `Projects/Feature/Stats/Sources/Stats/StatsView.swift` | `cardList` is `ScrollView { LazyVStack(spacing: 16) { ForEach(store.items ?? [], id: \.self.goalId) { StatsCardView(...) } } }`. `goalId` (Int64) is the stable identity — usable directly as `ScrollViewProxy.scrollTo` target. Lines 74–93. |
| `Projects/Feature/Stats/Sources/Stats/StatsReducer+Impl.swift` | confirm no timer / TimelineView / auto-emit in idle path; confirm `items` is populated by `statsClient.fetchStats` on appear and stable thereafter. |
| `Projects/Feature/Stats/Interface/Sources/Stats/StatsReducer.swift` | confirm `State.items: [Stats.StatsItem]?` shape and any computed properties read by the view. |
| `Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardView.swift` | confirm cell composition; identify any expensive shared modifiers (`outsideBorder` is used here per Pass 4-S2 grep — note for cross-feature awareness, NOT for change in this plan). |
| `Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardCompletionCell.swift` | this view appears 20 ev / rep at Pass 4-S idle (Stats audit row); check whether it contains a `LazyVGrid` of stamp cells — likely the per-placement µs amplifier vs Home. |
| `Projects/Shared/DesignSystem/Sources/Components/Calendar/Navigation/TXCalendarMonthNavigation.swift` | already read during Pass 4-S2 C3 investigation; confirm idle-state stability. Stats uses this view above the scroll, so its idle behavior under self-run scroll should be unchanged. |
| `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift` | confirm current self-run flags (`isSwiftUISelfRunTyping`, `isSwiftUISelfRunFeedScroll`) — add the Stats flag next to them following the same shape. |

## 4. Proposed self-run harness

Mirrors the Pass 4-S2 Home pattern. All gated behind `UITestMode.isEnabled && UITestMode.isSwiftUISelfRunStatsScroll`; flag default `false`.

### 4.1 New launch flag (UITestMode)

```swift
/// Pass 4-S3 — Stats feed self-running scroll. Analogous to
/// `isSwiftUISelfRunFeedScroll` (Pass 4-S2) but for the Stats
/// `StatsCardView` LazyVStack under `stats-heavy` seed. Example/perf-only.
public static var isSwiftUISelfRunStatsScroll: Bool {
    arguments.contains("-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL")
}
```

### 4.2 Harness location

`StatsView.cardList` already wraps `ScrollView { LazyVStack { ForEach { ... } } }` at lines 74–93. Same structural choice as Home:

- **(a) preferred**: a `HomeApp`-style `StatsExampleHost` wrapper in `StatsApp.swift` that wraps `StatsCoordinatorView` in a `ScrollViewReader`. **Risk**: same as Pass 4-S2 — the actual ScrollView is several levels deep through StatsCoordinatorView → NavigationStack → StatsView; proxy reach is brittle. Likely will need fallback (b).
- **(b) fallback**: a `#if PERF_TESTING`-gated branch inside `StatsView.cardList` that wraps the existing `ScrollView { ... }` in a `ScrollViewReader { proxy in ... }` and dispatches the self-run Task from `onAppear`. Identical pattern to the Pass 4-S2 `HomeContentSection` change. Production code path under `#else` unchanged.

Decision: go straight to (b) in the implementation step. Pass 4-S2 demonstrated (b) is the cleaner path for NavigationStack-wrapped coordinators; no benefit to re-trying (a).

### 4.3 Self-run sequence

```swift
@State private var selfRunScrollStarted: Bool = false
@State private var selfRunScrollDone: String = "false"

private func startSelfRunStatsScrollIfNeeded(proxy: ScrollViewProxy) {
    guard !selfRunScrollStarted else { return }
    selfRunScrollStarted = true
    let allIds = (store.items ?? []).map(\.goalId)
    let stridedTargets = stride(from: 5, to: allIds.count, by: 5)
        .compactMap { allIds.indices.contains($0) ? allIds[$0] : nil }
    let preRollNanos: UInt64 = 1_000_000_000
    let stepIntervalNanos: UInt64 = 300_000_000
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: preRollNanos)
        for id in stridedTargets {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .top)
            }
            try? await Task.sleep(nanoseconds: stepIntervalNanos)
        }
        selfRunScrollDone = "true"
    }
}
```

200-item `stats-heavy` seed × stride 5 = 39 `scrollTo` calls × 300 ms = ~11.7 s self-run + 1 s pre-roll = ~12.7 s active window. Trace window 30 s allows full sequence + settle.

### 4.4 Marker

`feature.stats.marker.swiftui-selfrun-scroll.true` surfaced via a `perfStateMarker` on the ScrollView wrapper. Same shape as `feature.home.marker.swiftui-selfrun-scroll.true`.

### 4.5 What is NOT in the harness

- No reducer / state / model / identity changes.
- No `StatsCardView` / `StatsCardCompletionCell` / `TXCalendarMonthNavigation` / `StatsView` production behavior change.
- No shared modifier change (`outsideBorder` etc. stay untouched per cross-cutting rule).
- No private API.
- No `ScrollViewReader` outside the `#if PERF_TESTING` branch.

## 5. CLI invocation (planned)

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

Same shape as Pass 4-S2 Home CLI, only bundle id and seed change.

## 6. Phase A — SwiftUI Template discovery (2 reps)

| field | value |
|---|---|
| scenario | `stats-heavy` self-run scroll |
| template | SwiftUI |
| reps | 2 |
| window | 30 s |
| device / config | `00008110-00096DC42632801E` / PerfProfile |
| trace root | `/tmp/twix-perf-traces/pass4-s3/swiftui-selfrun-scroll/` |

**Success criteria** (all required to proceed to Phase B):

1. `swiftui-updates` rows > 0 in both reps.
2. Target process = `FeatureStatsExample` (not XCTest runner). Verifiable via TOC `<process … pid="…" name="FeatureStatsExample">`.
3. `-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL` visible in TOC `process arguments`.
4. Marker fingerprint check: scroll-related rows (`LazySubviewPlacements<LazyVStackLayout>`, `StatsCardView.body`) scale ≥ 2× the Pass 4-S Stats heavy idle baseline. Specifically: `LazySubviewPlacements` event count ≥ 8 (vs idle ~4); `StatsCardView.body` events ≥ 40 (vs idle ~5).
5. Per-rep reproducibility within ±20 % on the headline counts.

If any of the 5 criteria fails → stop, record failure, do NOT proceed to Phase B.

## 7. Phase B — SwiftUI Template confirmation (1 rep)

Only after Phase A passes. Adds 1 SwiftUI rep at identical settings → total 3 SwiftUI reps for the Pass 4-S3 fingerprint baseline.

## 8. Authoritative gate — Time Profiler × 3 + Animation Hitches × 3

| field | value |
|---|---|
| templates | Time Profiler × 3, Animation Hitches × 3 |
| scenario | same `stats-heavy` self-run scroll |
| window | 30 s |
| device / config | same |
| trace root | `/tmp/twix-perf-traces/pass4-s3/c5-before/stats-selfrun-scroll/{timeprofiler,hitches}/` |

Required extractions:

- TP: top-20 user-code frames per rep with summed self-time; specifically watch for `StatsCardView.body.getter`, `StatsCardCompletionCell.body.getter`, `StatsView.body.getter`, `TXCalendarMonthNavigation.body.getter`, and framework `LazyVStack` / `LazyVGrid` / `ScrollView` frames.
- Animation Hitches: `potential-hangs` rows count, `hitches` rows count and durations, narrative tags.

## 9. Production entry criteria (do NOT propose a commit unless ALL met)

Per the methodology contract recorded in `pass4-s2-closeout.md` §4:

1. **SwiftUI Template signal** scales with self-run scroll: scroll-related rows (`LazySubviewPlacements`, `DynamicContainerInfo`, `StatsCardView.body`, or `Layout: ScrollViewChildContainerSize`) ≥ 2× Pass 4-S Stats idle baseline AND reproducible across 3 / 3 reps within ±20 %.
2. **Time Profiler** shows EITHER (a) a Stats user-code body frame (`StatsView.body.getter`, `StatsCardView.body.getter`, `StatsCardCompletionCell.body.getter`) in top-20 with summed self-time ≥ 5 ms per rep, reproducible 2 / 3 reps, OR (b) cumulative `LazyVStack` / `LazyVGrid` / `ScrollView` framework self-time ≥ 5 % of trace, reproducible 2 / 3 reps.
3. **Animation Hitches** shows EITHER (a) ≥ 1 hitch / hang in 2 / 3 reps with duration ≥ 33 ms, OR (b) a consistent "Potentially expensive app update(s)" / "Potentially expensive render, N offscreen passes" narrative across 2 / 3 reps.

ALL THREE required. SwiftUI Template signal alone is never enough.

## 10. If gate fails

- Write `docs/perf-infra/reports/_workspace/pass4-s3-stats-selfrun-scroll-result.md` with the trace inventory, per-view counts, TP top-20, Hitches detail, and SKIP verdict matching the structure of `pass4-s2-home-selfrun-scroll-result.md`.
- Mark C5 as SKIPPED per gate (analogous to C3 / C4 outcome).
- Do NOT propose any production change. Do NOT modify Stats / StatsCardView / shared modifiers.
- The harness commit (if made) remains as future infra; the gate's failure is the closure event.

## 11. If gate passes

- Report exact hot frames, exact hitches, likely source files, smallest possible production hypothesis, expected risk, proposed one-commit plan — same structure as `pass4-s2-home-selfrun-scroll-result.md` §6–§12.
- Do NOT implement. Ask explicit user approval before any production change.
- The production-side hypothesis must follow Pass 4-S2's rules: one file by default; widen only if read-only investigation proves the actual hot location is a shared modifier or call site graph; one hypothesis per commit.

## 12. Stop conditions

Pass 4-S3 stops immediately if any of:

1. **Infra time-box exceeded.** 30 min cap on harness implementation. If `tuist generate` + xcodebuild + `ScrollViewReader` proxy capture still misbehaves after 30 min, stop and report.
2. **Zero SwiftUI rows.** Phase A returns 0 `swiftui-updates` rows in either rep despite clean `exit(0)` and correct process attribution. Equivalent to attach-mode reproduction.
3. **scrollTo not reaching.** `LazySubviewPlacements<LazyVStackLayout>` event count stays at Pass 4-S idle baseline (~4) instead of rising with scroll-step count. Indicates the proxy did not actually drive scroll.
4. **TP + Hitches gate fails.** §9 criteria not met — close as SKIP per §10. NOT a stop on the infra itself, but a stop on production-change progression.
5. **Marker unreachable.** `feature.stats.ready` does not fire in 2 / 3 collection attempts. Stop, fix harness, retry once.
6. **Harness requires intrusive production code.** If the read-only investigation reveals that `StatsView.cardList` cannot be safely wrapped in `ScrollViewReader` without changing production layout / behavior (e.g. `LazyVStack` has to move, container hierarchy needs reshape), stop and document. Do NOT push through with a riskier harness.
7. **Total infra + collection wall-clock > 45 min** without producing usable Phase A data. Hard limit.

Any stop event → write `pass4-s3-stats-selfrun-scroll-result.md` with the stop trigger and raw trace counts; close Pass 4-S3 without production commit.

## 13. Explicitly NOT in scope

- Home / GoalDetail / ProofPhoto / Settings / Auth / Onboarding (per user scope).
- C1 (TXNavigationBar), C6 (ImageAccessibilityProvider) — separate tracks if ever opened.
- Pass 3 SKIP commits (Commit 4 / 5 / 6) — not revivable without independent TP / Hitches evidence from THIS Stats scenario.
- Shared modifier changes (`outsideBorder` etc.) — even though `StatsCardView` uses `outsideBorder` per Pass 4-S2 grep, no shared modifier change in this plan; if Stats also benefits from the GoalCardView-style local replacement, it would be a separate one-file Stats-only commit AFTER the gate passes AND user approves.
- Image pipeline / Kingfisher / icon caching.
- Reducer / state / identity / Equatable conformance changes.
- `compositingGroup()`.

## 14. Expected output

Plan stage:
- `docs/perf-infra/reports/_workspace/pass4-s3-stats-selfrun-scroll-plan.md` (this document).

Execution stages (each requires explicit user approval before starting):
- Phase A implementation + 2 traces → no separate doc, results folded into the result doc below.
- Phase B + gate collection → trace bundles + summary TSV under `/tmp/twix-perf-traces/pass4-s3/`.
- `docs/perf-infra/reports/_workspace/pass4-s3-stats-selfrun-scroll-result.md` after the gate runs.
- If gate passes and a production change is approved + implemented: `pass4-s3-h-c5-a-comparison.md` (or similar) with the after-gate KEEP / REVERT verdict.
- `pass4-s3-closeout.md` at the end of the track.

No code changes anywhere unless separately approved at each stage.

---

## Appendix: implementation cost summary (for plan-approval review)

### Expected files to touch (3 files max, all perf-infra-gated, all in the harness phase)

1. `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift` — +5 lines (`isSwiftUISelfRunStatsScroll`).
2. `Projects/Feature/Stats/Sources/Stats/StatsView.swift` — `#if PERF_TESTING` branch around `cardList`'s `ScrollView` to wrap it in `ScrollViewReader` and dispatch the self-run Task from `onAppear`. ~40 lines under the gate. Production `#else` path identical.
3. `Projects/Feature/Stats/Example/Sources/StatsApp.swift` — optional, ONLY if the marker plumbing requires it. Likely not — the marker can live alongside the harness inside StatsView's gated branch.

Total: 2 files most likely; 3 maximum.

### Expected trace count

- Phase A: 2 SwiftUI traces.
- Phase B: 1 SwiftUI trace (total SwiftUI = 3) — only if Phase A passes.
- TP + Hitches gate: 6 traces (3 + 3) — only if Phase B passes.

**Max: 9 traces. Min: 2 if Phase A fails.**

### Expected wall-clock runtime

- Infra implementation: 15–30 min (within stop condition #1's 30-min cap).
- Tuist regenerate + on-device install: ~5 min.
- Phase A SwiftUI × 2: ~5 min including export + analyzer.
- Phase B SwiftUI × 1: ~3 min.
- TP × 3 + Hitches × 3: ~8 min.
- Analysis + report drafting: ~30 min.

**Total: 60–90 min if everything works; 30–45 min if Phase A or a stop condition fires early.**

### What counts as a real actionable signal

Identical 3-AND criterion as Pass 4-S2 §9 / closeout §4 methodology contract:

1. SwiftUI Template scroll-related rows scale ≥ 2× idle baseline and are reproducible 3 / 3.
2. TP shows Stats user-code body frame OR ≥ 5 % framework self-time in top-20, reproducible 2 / 3.
3. Animation Hitches shows ≥ 1 hitch ≥ 33 ms in 2 / 3 OR consistent expensive-update / offscreen-pass narrative in 2 / 3.

All three required to even propose a production hypothesis to user. SwiftUI signal alone is never enough.

---

## End of plan

Awaiting approval to proceed with Phase A (harness implementation + 2 SwiftUI Template reps).
