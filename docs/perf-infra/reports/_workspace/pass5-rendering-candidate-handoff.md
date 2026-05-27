# Pass 5 — Rendering candidate handoff

**Status**: handoff document. Pass 4 is closed (commit `78b592c docs: Pass 4 렌더링 최종 리포트 정리 - #310`). This document carries Pass 4's deferred / unfinished candidates into Pass 5's scope.

**This document is information only. Do NOT start Pass 5 implementation from it.** Each candidate below requires a fresh plan, explicit user approval, and its own SwiftUI Template + Time Profiler + Animation Hitches gate before any infra or production change.

---

## 1. Methodology contract (must be respected by Pass 5)

The Pass 4 outcome demonstrates the contract in both directions:

- **Pass 4-S2 H-C2-a (KEPT, `0c0da63`)**: SwiftUI Template signal moved (-41 % `swiftui-updates`, -94 % `GoalCardView.body` events), Time Profiler corroborated (`GoalCardView.body.getter` eliminated from top-10 in 2/3 reps), Animation Hitches confirmed (`0/2/4 → 0/0/0`, 133.34 ms severe hitch eliminated, "37 offscreen passes" narrative eliminated). All three layers agreed → production-valid.
- **Pass 4-S3 H-C5-a (REVERTED, `da2278e` → `aa4a160`)**: SwiftUI Template signal moved (-15 % `swiftui-updates`, `LazySubviewPlacements<LazyVGridLayout>` → 0), but Time Profiler stayed flat and Animation Hitches actively regressed (`4/1/2 → 3/4/4`, +60 % count; narrative reproducibility unchanged at 3/3). Counts moved, real cost did not improve → reverted.

Rule for any Pass 5 candidate:

```
SwiftUI Template signal (launch-mode self-run if interactive)
  → Time Profiler + Animation Hitches gate (authoritative metric)
  → one small commit (one file by default, one hypothesis)
  → after-gate (same scenario × template × reps)
  → keep or revert per documented criteria
```

**SwiftUI Template counts alone never justify a production change.** A candidate that improves SwiftUI counts without a corresponding TP / Animation Hitches improvement = revert. Visual regression = revert. New top-20 TP hot path = revert.

---

## 2. Remaining candidates (deferred from Pass 4)

### 2.1 Stats C5 — heavy-scroll LazyVGrid / cell-composition cost (DEFERRED with gate-and-revert)

**State**: Root cause partially identified by Pass 4-S3 ablation (`687901c`):

- LazyVGrid container / `ForEach(0..<goalCount)` placement work in `StatsCardCompletionCell` is the primary SwiftUI signal amplifier (Experiment A: -69 % `swiftui-updates` when entire stamp grid removed — but A is over-removal, not production-valid).
- TXVector content is NOT the primary cost (Experiment B: -10 % only).
- H-C5-a (inner-container swap `LazyVGrid` → eager `VStack` of `HStack` rows) gate-and-reverted by Pass 4-S3.
- The cell-internal container swap hypothesis class is exhausted.

**Reusable infrastructure**: Stats self-run scroll harness committed at `caa26be`. UITestMode flag `isSwiftUISelfRunStatsScroll` + `#if PERF_TESTING` `ScrollViewReader` branch in `StatsView.cardList`. Default-off; production path unchanged.

**Available hypothesis classes for Pass 5 (each requires fresh plan)**:

- **Equatable on `StatsCardView`** (composition-skip via SwiftUI's input-stability shortcut). Pass 3 Commit 6 territory — closure-identity issues are documented risk. High risk; requires its own gate including a test for stale closure capture.
- **Cell-content reduction** (cap rendered stamp count at viewport-visible, or show summary only when scrolling). Visual change. Out of single-commit scope.
- **Cell-pool / reuse model** (less-Lazy scroll architecture). Major architectural change. Out of any near-term Pass scope.
- **Cell-snapshot caching** (rasterize the stamp grid once per cell into an `Image` or `Canvas`, invalidate only when `monthlyCount` changes). First-paint cost; lifecycle complexity. Out of one-commit scope.

**Documents to read before opening C5 again**:
- `pass4-s3-stats-selfrun-scroll-plan.md`
- `pass4-s3-stats-selfrun-scroll-result.md` (especially §13 ablation findings)
- `pass4-s3-h-c5-a-plan.md`
- `pass4-s3-h-c5-a-after-gate.md`
- `pass4-s3-closeout.md`

### 2.2 C1 — `TXNavigationBar` idle re-evaluation (DEFERRED)

**State**: Pass 4-S audit identified `TXNavigationBar.body` as a cross-feature idle signal (~3.0–4.4 ms × 1–3 evals/rep across Home, Stats, GoalDetail idle scenarios — `pass4-s-swiftui-template-audit.md` §C1). Same magnitude class as Pass 4-S C3 (TXCalendarDateCell) which was gated on idle and SKIPPED.

**Pass 4 decision**: Idle gate was not run separately for C1 because the magnitude class matched C3, which had already failed. The Pass 4-S C3 before-gate TP traces confirmed `TXNavigationBar.body` was also absent from TP top-30 on the same scenario.

**Pass 5 options**:
- If C1 is opened, it must use an **interaction-time** scenario (not idle) — for example, repeated navigation transitions or `onAction` taps via self-run pattern. Pass 4-S audit's idle finding is necessary but not sufficient evidence; the interactive cost is what would need to be measured and gated.
- Cross-feature scope means a fix in `TXNavigationBar.swift` (or its consumers) would touch Home / Stats / GoalDetail / others simultaneously. Any production change must be evaluated on all of these in its after-gate, not just one.

**Documents to read**: `pass4-s-swiftui-template-audit.md` §C1, `pass4-s-c3-txcalendardatecell.md` (for the gate-failure precedent at the same magnitude class).

### 2.3 C6 — `Image.ImageViewChild<…AccessibilityProvider>` (partially addressed; DEFERRED)

**State**: Pass 4-S audit classified C6 as a "weak signal" (~214 events × 5.8 ms / rep on Home idle, ~46 × 2.1 ms on Stats idle — `pass4-s-swiftui-template-audit.md` §C6). Pass 4-S2 H-C2-a's GoalCardView change reduced C6's events by ~50 % as a side effect (fewer cell re-evaluations means fewer image accessibility re-resolutions) — see `pass4-s2-h-c2-a-comparison.md` §3.

**Pass 5 decision required**: Re-measure C6's residual magnitude **after** the Pass 4-S2 H-C2-a baseline change. If post-H-C2-a residual is still substantial, a fresh plan can investigate; if it has collapsed below noise floor, C6 can be closed.

**Pass 5 options if re-measure shows residual signal**:
- Audit per-cell `Image(systemName:)` vs `Image.Illustration.*` resolution patterns; check whether icons are being re-constructed inline rather than reused.
- Investigate `.accessibilityLabel` / `.accessibilityIdentifier` modifier chains that may trigger per-cell accessibility re-resolution.

**Documents to read**: `pass4-s-swiftui-template-audit.md` §C6, `pass4-s2-h-c2-a-comparison.md` for the H-C2-a side-effect on C6.

### 2.4 ProofPhoto residual keyboard / focus latency (out of image-pipeline scope)

**State**: After Pass 4 P4-2 (`4cfabd0`), the typing-large scenario's remaining stall (0.53 s mean) is concentrated in framework keyboard / accessibility frames (`UIAssistantBarButtonItemProvider`, `UIInputWindowController`, `_UIKeyboardStateManager`, `UIKeyboardCache`, `UISystemKeyboardDockController`, `UIView _accessibilityViewIsVisibleIgnoringAXOverrides`). See `2026-05-20-render-pass-4.md` §8.4.

**Pass 5 decision**: This is **out of the rendering / image-pipeline category**. It is UIKit framework-side latency that the app cannot directly optimize at the SwiftUI / view layer. Recorded for future investigation under a different category (e.g. "UX latency / input handling") if ever opened.

**Pass 5 must NOT** treat this as a Pass 5 rendering candidate — it belongs to a separate track if pursued.

---

## 3. Pass 4 outcomes for reference

| sub-track | outcome | key commits |
|---|---|---|
| ProofPhoto P4-2 (image pipeline) | KEPT — typing stall -35 %, longest hang -51 % | `4cfabd0`, `a9eea07` |
| Pass 4-S audit (idle inventory) | closed inventory-only; C3/C4 SKIPPED | `fb83216`, `8f17d45`, `b7a791f`, `79b6393` |
| Pass 4-S2 Home (H-C2-a) | KEPT — Hitches `0/2/4 → 0/0/0` | `fde7d41`, `0c0da63`, `bf15856`, `b6297f0` |
| Pass 4-S3 Stats (H-C5-a) | REVERTED — counts moved, cost did not | `caa26be`, `da2278e` → `aa4a160`, `ac1f73c`, `21c734d`, `7873646` |
| Pass 4 final report | finalized | `78b592c` |

---

## 4. Explicit DO NOTs for Pass 5

These rules carry over from Pass 4 methodology and the closeout commits. Pass 5 must observe them at the entry of any candidate.

### 4.1 Do NOT retry H-C5-a as-is

The single-file inner-container swap (LazyVGrid → eager VStack/HStack) was gated and reverted by Pass 4-S3. Repeating the same diff with cosmetic variations (different spacer strategy, different row-stride) without a meaningfully different hypothesis class will produce the same gate failure. If C5 is reopened, the hypothesis class must change (Equatable on StatsCardView, cell-content reduction, cell-snapshot caching, or cell-pool model — each its own larger-scope plan).

### 4.2 Do NOT treat Experiment A as production-valid

Pass 4-S3 Experiment A (ABLATE_STAMP_GRID, -69 % swiftui-updates) **removes the visible stamp UI**. It is a perf-only experiment that demonstrates the cost SOURCE — it is NOT a production-valid fix. Any future Stats candidate must preserve the rendered stamp output.

### 4.3 Do NOT pursue TXVector caching as the first Stats hypothesis

Pass 4-S3 Experiment B (ABLATE_TXVECTOR, -10 % swiftui-updates) ruled out the TXVector-content axis as the primary cost source. Replacing TXVector with `Image` snapshots, caching SVG path results, or memoizing per-icon renders would address ≤ 10 % of the SwiftUI signal and would carry lifecycle / first-paint complexity. If C5 is reopened, the first hypothesis must target the LazyVGrid container / cell composition level, not TXVector content.

### 4.4 Do NOT use SwiftUI Template counts alone for production commits

The Pass 4-S2 closeout's methodology contract is mandatory:

> SwiftUI Template signal (launch-mode self-run if interactive)
>   → Time Profiler + Animation Hitches gate (authoritative metric)
>   → one small commit (one file by default, one hypothesis)
>   → after-gate (same scenario × template × reps)
>   → keep or revert per documented criteria

A candidate whose SwiftUI Template count moves but whose Time Profiler / Animation Hitches gate does not corroborate is **not actionable**. Pass 4-S3 H-C5-a is the canonical example of why this rule exists; do not bypass it.

### 4.5 Do NOT cross-transfer Pass 4-S2 H-C2-a's fix to other features without independent gate evidence

`StatsCardView` and several other cards use the same shared `outsideBorder` modifier that Pass 4-S2 H-C2-a addressed for `GoalCardView`. Applying the same local `.background { stroke }` replacement to Stats / EditGoal / etc. WITHOUT independent SwiftUI Template + TP + Animation Hitches gate evidence violates the one-hypothesis-one-gate contract. Each cross-feature application is a separate hypothesis with its own approval and gate.

### 4.6 Do NOT revive Pass 3 SKIP commits (4 / 5 / 6) without new evidence

Pass 3 Commits 4, 5, 6 were investigated and SKIPPED on idle gates. Pass 4-S audit C2 (Home LazyVStack adaptor revalidation) pointed at *adjacent* surfaces (lazy container behavior, not user-code input stability), and Pass 4-S2 H-C2-a fixed a *different* layer (render-side `outsideBorder` duplication). Neither revives Commits 4 / 5 / 6 as such; if any Pass 5 candidate touches Home input stability or `GoalCardView` shape, it must come with its own scenario, gate, and evidence — not as a Pass 3 Commit 6 retry.

### 4.7 Do NOT skip the harness step

Both Pass 4-S2 and Pass 4-S3 committed the self-run scroll harness as separate `test:` commits **before** the production change, so the before-gate evidence is reproducible and the production diff is isolated. Pass 5 candidates that require new infrastructure must follow the same separation: infra + before-gate evidence as one commit, production change as a second commit with its own after-gate.

### 4.8 Do NOT extend a single Pass 5 candidate to multiple files

Pass 4 enforced "one commit = one hypothesis = one file by default" for production changes. Pass 4-S2 H-C2-a stayed in `GoalCardView.swift` (1 file). Pass 4-S3 H-C5-a stayed in `StatsCardCompletionCell.swift` (1 file). If a Pass 5 hypothesis requires touching ≥ 2 production files, that is a signal to stop and re-scope — the hypothesis class is likely too broad for a single gate.

---

## 5. Reusable infrastructure available to Pass 5

- **ProofPhoto self-run typing harness**: commit `79b6393`. UITestMode flag `isSwiftUISelfRunTyping` + `ExampleHost.performSwiftUISelfRunTyping()`. Production default off.
- **Home self-run scroll harness**: commit `fde7d41`. UITestMode flag `isSwiftUISelfRunFeedScroll` + `#if PERF_TESTING` `ScrollViewReader` branch in `HomeContentSection`. Production default off.
- **Stats self-run scroll harness**: commit `caa26be`. UITestMode flag `isSwiftUISelfRunStatsScroll` + `#if PERF_TESTING` `ScrollViewReader` branch in `StatsView.cardList`. Production default off.
- **Pass 4 / 4-S2 / 4-S3 trace bundles**: `/tmp/twix-perf-traces/pass4-*/` and `/tmp/twix-perf-traces/pass4-s*/`. Treat as transient (host `/tmp`); regenerable from the committed harnesses.

---

## 6. Pass 5 starting point (when a fresh plan opens)

1. Read this document.
2. Read `2026-05-20-render-pass-4.md` (final Pass 4 report).
3. Read the sub-track docs for the chosen candidate (see §2 above).
4. Draft a Pass 5 candidate plan that respects §1 methodology contract and §4 DO NOTs.
5. Submit plan for explicit user approval.
6. Do NOT execute any code or trace collection before approval.

Pass 5 implementation is out of this document's scope. This is handoff only.
