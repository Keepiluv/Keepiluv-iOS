# Pass 5 — Execution Plan (revised)

**Status**: revised draft. Stats C5 promoted to **primary track**. H-C5-b must execute at least one serious production hypothesis with before/after gate and close C5 with KEEP / REVERT / SKIP / CLOSED — not documentation-only.

Pass 5 is the **final** pass. "Final" = decisive closure of C5, not lazy close.

---

## 1. Inputs

- Handoff: `docs/perf-infra/reports/_workspace/pass5-rendering-candidate-handoff.md`
- Pass 4 final: `docs/perf-infra/reports/2026-05-20-render-pass-4.md`
- Earliest baseline (for cumulative report anchor): tag `baseline-render-pass-1` = `56b5b63`, recorded 2026-05-17, configuration **Profile** (pre-PerfProfile split at `5d507fa`).
- Per-pass tags: `pass3-rendering-before`, `pass4-rendering-before`.
- Reusable harnesses: ProofPhoto typing (`79b6393`), Home scroll (`fde7d41`), Stats scroll (`caa26be`, committed Pass 4-S3). All default-off under `#if PERF_TESTING`.

## 2. Methodology contract (carried from Pass 4)

```
SwiftUI Template signal (launch-mode self-run for interactive)
  → Time Profiler + Animation Hitches gate (authoritative)
  → one small commit (one file by default, one hypothesis)
  → after-gate (same scenario × template × reps)
  → keep or revert per documented criteria
```

- SwiftUI Template counts alone never justify a production change.
- Visual regression → revert. New top-20 TP hot path → revert. Worse Hitches → revert.
- 1 commit = 1 hypothesis = 1 file by default.
- All 8 Pass 5 DO NOTs from handoff §4 apply.

## 3. Pass 5 priority

1. **Stats C5 — primary**. Must close with KEEP / REVERT / SKIP / CLOSED via at least one serious production hypothesis (H-C5-b).
2. **C1 TXNavigationBar** — only after C5 closes, and only if time + evidence remain.
3. **C6 Image accessibility** — re-measure residual after Pass 4-S2 H-C2-a side effect; close.
4. **ProofPhoto keyboard residual** — CLOSED-out-of-scope, documented in cumulative report under "future risk / known unresolved".

---

## 4. Stats C5 — H-C5-b track (primary)

### 4.1 What Pass 4-S3 already established

| signal | finding | interpretation |
|---|---|---|
| Experiment A (remove entire stamp grid) | -69 % swiftui-updates, narrative eliminated | the cost SOURCE is the stamp-grid subtree (LazyVGrid + per-stamp content + cell composition) |
| Experiment B (replace TXVector with Circle) | -10 % only | TXVector content is NOT the primary cost (≤10 % of signal) |
| H-C5-a (LazyVGrid → eager VStack/HStack rows) | -15 % swiftui-updates, Hitches +60 % | inner-container swap is **not** enough; cost moved to other SwiftUI layout machinery |
| TP top-10 (baseline) | 0 / 3 reps contained Stats user-code | body re-eval count is NOT the dominant cost on TP |
| Animation Hitches (baseline) | `4 / 1 / 2` per rep, 1 hang (35.89 ms) | residual rendering pressure, primarily framework-layout side |

**Honest read**: the SwiftUI signal source is cell *materialization layout work* (LazyVGrid + 30 children + composition), not body re-eval count and not TXVector content. The cell-internal container swap (H-C5-a) fails because removing one container increases work on adjacent containers / layouts.

### 4.2 Read-only inspection results (StatsCardView / StatsCardCompletionCell)

**Inputs (StatsCardView)**:

| input | type | Equatable? | stable during scroll? |
|---|---|---|---|
| `item: StatsCardItem` | struct | **yes** (with `CompletionInfo`, `StampColor` both Equatable) | yes — `state.items` mutates only on `fetchedStats` (month change), not during scroll |
| `isOngoing: Bool` | Bool | yes | yes during scroll |
| `onTap: (Int64) -> Void` | closure | **no** (closure identity unstable per parent body eval) | parent body re-eval would change identity, but parent body does NOT re-eval during scroll (no observable store mutation) |

**Inputs (StatsCardCompletionCell)**:

| input | type | Equatable? | closure? |
|---|---|---|---|
| `info: StatsCardItem.CompletionInfo` | struct | yes | no |
| `stampIcon: TXVector.Icon` | enum | yes | no |
| `goalCount: Int` | Int | yes | no |
| `showsStampGrid: Bool` | Bool | yes | no |

→ **`StatsCardCompletionCell` is already fully Equatable-clean**. Wrapping it in `EquatableView` (or `.equatable()`) is technically safe.

**Closure identity inside `StatsCardView.body`**:

- `var header` constructs `CardHeaderView(... onTap: { onTap(item.goalId) }, rightContent: { ... })` — new closure per body eval.
- `var completionSection` ForEach builds `StatsCardCompletionCell(...)` — no closure passed to cell ✓.
- The trailing `.onTapGesture { onTap(item.goalId) }` on the root VStack — new closure per body eval.

**Body invalidation triggers (during scroll)**:

- Parent (`StatsView.scrollCardList`): `store.items`, `store.isOngoing` — both stable during scroll.
- `onTap: { goalId in store.send(.statsCardTapped(goalId: goalId)) }` — **created in `StatsView.scrollCardList` body**. Identity changes if and only if `StatsView.body` re-evaluates. During scroll, no observable store change → no parent re-eval expected.
- Therefore **scroll-time invalidation of `StatsCardView` is unlikely to be caused by closure identity churn**. Instead, materialization on viewport entry is the primary call site.

**`outsideBorder` usage (StatsCardView.swift:55-59)**: yes, `StatsCardView` uses the same `outsideBorder` modifier that H-C2-a removed on `GoalCardView`. Per handoff §4.5 this is allowed only with independent gate evidence (which Pass 5 will collect, if we choose that path).

### 4.3 Three hypothesis candidates evaluated

Below are three concrete H-C5-b candidates. Each has a different theory of cost source. We must pick **one**, gate it, and decide. We do not run all three.

#### 4.3.A `EquatableView` / `.equatable()` on `StatsCardCompletionCell` (composition-skip via input stability)

- **Theory**: cells materialize with stable inputs; SwiftUI should skip cell-internal body re-eval on input-equality. Wrapping `StatsCardCompletionCell` in `.equatable()` (or `EquatableView`) lets SwiftUI fast-path the diff.
- **Diff scope**: ≤ 2 lines in `StatsCardView.completionSection`, or 1-line wrapper in `StatsCardCompletionCell` itself. 1 file.
- **Risk**: cell inputs are fully Equatable (verified above), so closure-capture-stability is not an issue at the cell level. But: SwiftUI may already be performing this fast-path internally; explicit `.equatable()` may not move metrics. Same trap as H-C5-a (counts may not move, or move without TP/Hitches benefit).
- **Probability of producing real TP / Hitches improvement**: **LOW**. Baseline TP shows no Stats user-code in top-10 → body re-eval was not the bottleneck → reducing body re-evals will not produce TP/Hitches movement. This is the H-C5-a failure mode at a different layer.
- **Verdict**: technically clean, low risk, but **predictably will move SwiftUI count without moving TP/Hitches**. Documenting this in advance.

#### 4.3.B `EquatableView` / `.equatable()` on `StatsCardView` (parent-level input stability)

- **Theory**: same as A, but at the `StatsCardView` level. Would skip subtree re-eval if `StatsCardView`'s body would otherwise re-run with equal inputs.
- **Diff scope**: needs to either (a) drop closure from input — too large, or (b) make Equatable conformance that intentionally ignores closure identity — Pass 3 Commit 6 territory exactly.
- **Risk**: HIGH. Closure-capture stability is the documented Pass 3 Commit 6 failure mode. Stale `onTap` closure capturing a stale `goalId` route is a real bug if not extremely carefully wired. Requires a closure-capture test before gate.
- **Probability of producing real TP / Hitches improvement**: **LOW** for the same reason as A — body re-eval is not the bottleneck on TP.
- **Verdict**: high risk × low expected benefit. **Recommend SKIP**. The Pass 5 prompt explicitly warns: "Pass 3 Commit 6의 Home GoalCardView input-stability 실패를 그대로 반복하지 않는다."

#### 4.3.C `outsideBorder` → local `.background { stroke }` on `StatsCardView` (render-side duplication elimination, analog to H-C2-a)

- **Theory**: `outsideBorder` re-overlays `self` to draw the stroke, causing render-side duplication. H-C2-a on `GoalCardView` proved this is real and produces TP+Hitches movement (Animation Hitches `0/2/4 → 0/0/0`, GoalCardView.body events -94 %, Image.ImageViewChild side-effect -50 %).
- **Diff scope**: 1 file (`StatsCardView.swift`), ~5 lines replacement of the `.outsideBorder(...)` modifier with `.background { RoundedRectangle(cornerRadius: ...).stroke(...).inset(...) }` or equivalent local stroke. Identical visual output.
- **Risk**: LOW. Visual sanity already validated by H-C2-a's identical-screenshot result. Stroke geometry must match `outsideBorder`'s 1pt outside-the-bounds positioning.
- **Probability of producing real TP / Hitches improvement**: **MEDIUM-HIGH**. Same mechanism (render duplication) as H-C2-a. Stats baseline narrative is `Potentially expensive app update(s)` 3/3 reps — same narrative class. H-C5-a Experiment A's -69 % may have been over-removal, but the residual SwiftUI cost may still be partially in render-side duplication that H-C5-a's inner-container swap left untouched.
- **Caveat (handoff §4.5)**: "Do NOT cross-transfer Pass 4-S2 H-C2-a's fix to other features WITHOUT independent gate evidence." Pass 5 will collect that independent gate evidence. The rule prohibits blind cross-transfer; it does not prohibit gate-and-decide cross-transfer.
- **Tension with prompt's framing**: the prompt frames H-C5-b as "composition-skip / input-stability". `outsideBorder` removal is render-side, not composition-skip. It is in a different hypothesis class. Honest disclosure to user required before proceeding.
- **Verdict**: **highest-EV candidate** by evidence, but requires user re-confirmation that an analog-to-H-C2-a hypothesis is acceptable as H-C5-b.

### 4.4 Recommendation (for user approval)

**Honest engineering read**:

- 4.3.A (cell `.equatable()`) is safe but **predictably will not move TP/Hitches** because the baseline TP shows no Stats user-code in top-10. We would commit one round of measurement to confirm the predictable null result, then need a second hypothesis anyway.
- 4.3.B (parent `EquatableView` with closure-stripping) is the riskiest path with the lowest expected benefit. **SKIP**.
- 4.3.C (`outsideBorder` analog) is the highest-EV option. It is **not in the composition-skip class** that the prompt initially framed, but it satisfies all of the H-C5-b constraints (≤2 files, no stamp grid hiding, no TXVector caching, no Canvas, no cell-pool, no multi-file rewrite, not relying on SwiftUI count alone for KEEP).

**Recommended H-C5-b**: **4.3.C** (`outsideBorder` → local `.background { stroke }` on `StatsCardView`), with full disclosure that this is the render-duplication hypothesis class, not the composition-skip class.

**If user prefers strict composition-skip framing**: **4.3.A** (cell `.equatable()`) is the only safe candidate; 4.3.B is rejected on Pass 3 Commit 6 grounds. We would gate 4.3.A and accept the high probability of SKIP outcome (counts move, TP/Hitches do not).

**If user wants both attempted**: 4.3.C first (higher EV); if KEEP, optionally try 4.3.A on top of the already-improved baseline. Each is a separate commit with its own gate.

### 4.5 Concrete gate plan (whichever candidate is chosen)

**Scenario**: Stats self-run scroll, harness `-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL`, PerfProfile, launch mode.

**Trace collection**:

- before-gate: **reuse** `/tmp/twix-perf-traces/pass4-s3/c5-before/` (3 SwiftUI + 3 TP + 3 Hitches) since baseline = `pass4-rendering-before` and no production change since.
  - Re-verify the trace bundles still exist and are non-empty; if `/tmp` was cleared, re-collect before-gate fresh.
- after-gate: 3 SwiftUI + 3 TP + 3 Hitches reps at `/tmp/twix-perf-traces/pass5-after/h-c5-b/`.

**KEEP criteria (all must hold)**:

- SwiftUI Template `swiftui-updates` total drops ≥ 20 % (lower bar than H-C5-a's 30 %, because H-C5-b targets render-side, not container-swap mechanics — large absolute SwiftUI count drops are not the primary success metric).
- Animation Hitches count `≤` baseline mean of 2.33 hitches/rep (no regression on count) AND no severe hang ≥ 33 ms reproduced 2/3 reps.
- "Potentially expensive app update(s)" narrative reproducibility `<` 3/3 reps (any reduction in narrative reproducibility is positive).
- TP top-20 contains no new user-code hot path.
- Visual sanity: simulator screenshot identical to baseline (`outsideBorder` 1pt outside stroke equivalent rendering).
- `FeatureStatsExampleUITests` (existing tests) pass.

**REVERT criteria (any one triggers revert)**:

- Animation Hitches count or stall ms increases.
- "Potentially expensive app update(s)" narrative reproducibility unchanged or worse.
- New TP top-20 user-code hot path.
- Visual or test regression.
- SwiftUI count moves but TP + Hitches do not corroborate.
- Diff scope grew beyond ≤ 2 files.

**Documentation**: full headline table (same format as Pass 4-S3 H-C5-a after-gate) + KEEP/REVERT verdict + closeout note added to Pass 5 final report.

---

## 5. C1 / C6 / keyboard residual disposition

| # | Candidate | Disposition | When |
|---:|---|---|---|
| 2 | **C1 TXNavigationBar** | Conditional — only attempted if C5 closes and time + evidence allow; otherwise CLOSED-as-deferred with handoff §4.5 rationale (cross-feature scope, §4.8 one-file violation, no interaction harness). | Post-C5 |
| 3 | **C6 Image accessibility** | Re-measure from existing Pass 4-S2 H-C2-a after-gate data (already shows -50 % events / -21 % µs / no TP top-30 / no Hitches narrative). CLOSED with documented residual collapse below noise floor. | Anytime; no new trace |
| 4 | **ProofPhoto keyboard residual** | CLOSED-out-of-scope per handoff §2.4. Recorded under "future risk / known unresolved" in cumulative report. | Anytime; no work |

## 6. Pass 5 deliverables

1. **This execution plan** (revised) — committed once user approves.
2. **H-C5-b plan file** (separate, after-approval): `docs/perf-infra/reports/_workspace/pass5-h-c5-b-plan.md` with the chosen hypothesis (4.3.A / C / both), diff sketch, gate plan, KEEP/REVERT criteria.
3. **H-C5-b production commit** (or REVERT commit pair if it fails after-gate).
4. **H-C5-b after-gate result doc**: `docs/perf-infra/reports/_workspace/pass5-h-c5-b-after-gate.md`.
5. **C1 / C6 / keyboard residual closure notes** — inline in Pass 5 final report.
6. **Pass 5 final report** at `docs/perf-infra/reports/2026-05-21-render-pass-5.md`.
7. **Rendering final cumulative report** at `docs/perf-infra/reports/2026-05-21-rendering-final-cumulative-report.md`.
8. **Working tree clean.**

## 7. What this plan deliberately does NOT do

- Does NOT hide / cap the stamp grid (visual change).
- Does NOT pursue TXVector caching as the first candidate (Experiment B ruled it out).
- Does NOT jump to Canvas / ImageRenderer / cell-pool / multi-file rewrite.
- Does NOT trust SwiftUI count alone for KEEP.
- Does NOT revive H-C5-a's diff (inner-container swap exhausted).
- Does NOT make `StatsCardView` Equatable with closure stripping (Pass 3 Commit 6 failure mode).

## 8. Approval gate

The plan above requires user approval on the **H-C5-b candidate selection**:

- **(C) `outsideBorder` → local `.background { stroke }` on `StatsCardView`** — recommended. Highest EV. Render-duplication hypothesis class, analog to H-C2-a, requires §4.5 independent gate evidence (which Pass 5 collects).
- **(A) `EquatableView` / `.equatable()` on `StatsCardCompletionCell`** — fallback strict-composition-skip option, lower expected benefit, predictably likely to SKIP.
- **(C then A)** — try C first; if KEEP, optionally also gate A as an adjacent commit (separate hypothesis, separate gate, max 1 extension per Pass 4 extension rule).
- **(A then C)** — try A first to be true to the original composition-skip framing; if it SKIPs, try C as the actual EV-positive hypothesis.

**After approval**, draft the chosen H-C5-b plan file with concrete diff sketch, secure user approval on the diff, then execute the gate.
