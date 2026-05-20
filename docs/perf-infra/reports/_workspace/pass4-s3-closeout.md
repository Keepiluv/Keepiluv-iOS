# Pass 4-S3 — Closeout (Stats self-running scroll investigation)

**Status**: closed. Pass 4-S3 produced **no production performance change**; it produced (a) the Stats self-run scroll harness as perf infrastructure, (b) a root-cause attribution for the C5 SwiftUI signal, and (c) a gate-and-revert outcome on the first production hypothesis (H-C5-a). The methodology contract was upheld.

## 1. Outcome summary

- **No production code change.** `StatsCardCompletionCell.swift` is at baseline. The Pass 4-S3 production attempt (`405dc38 perf(stats): replace stamp grid LazyVGrid with eager VStack rows`) was reverted by `73f4a00`. Post-revert smoke test (`FeatureStatsExampleUITests` under PerfProfile / iOS Simulator iPhone 16 Pro Max) → **TEST EXECUTE SUCCEEDED**. Baseline production behavior intact.
- **Self-run scroll harness committed and kept** as `a4a14c5 perf(infra): add Stats self-run scroll harness for Pass 4-S3` — reusable by any future C5 investigation. UITestMode flag `isSwiftUISelfRunStatsScroll` + `#if PERF_TESTING ScrollViewReader` branch in `StatsView.cardList`. Production path under `#else` and the default-flag branch is identical to current behavior.
- **Root cause for the Stats C5 SwiftUI signal documented.** From the ablation work (`28adce3`): the dominant signal source is the `LazyVGrid` container / `ForEach(0..<goalCount)` placement work in `StatsCardCompletionCell`, not the per-stamp `TXVector` content. The H-C5-a after-gate (`9a0351d` + `88ae481`) further proved that *swapping the inner container alone* is insufficient — the real cost concentration is at the cell-composition level (every visible cell re-composes its full subtree on materialization), not at the inner-container level.
- **C5 status: deferred with gate-and-revert outcome.** Not permanently closed. Not a successful optimization. The methodology was strictly applied: SwiftUI Template counts moved, but the authoritative Time Profiler + Animation Hitches gate did not corroborate a user-visible improvement, so the change was reverted.

## 2. C5 investigation timeline

| step | commit | what |
|---|---|---|
| 1. Plan | `55047c2` | `docs(perf): draft Pass 4-S3 Stats self-running scroll plan` |
| 2. Harness + before-gate baseline | `a4a14c5` (plus baseline traces) | `perf(infra): add Stats self-run scroll harness for Pass 4-S3` — Phase A + B SwiftUI x3 + gate TP x3 + Hitches x3. Baseline 3-AND failed on TP criterion #2 (no Stats user-code in TP top-10). |
| 3. Ablation attribution doc + DEFER verdict (with addendum §13) | `28adce3` | `docs(perf): record Pass 4-S3 C5 ablation attribution and defer production fix`. Experiment A (ABLATE_STAMP_GRID): -69 % swiftui-updates, 0 narratives — over-removal, not production-valid. Experiment B (ABLATE_TXVECTOR): -10 % only — rules out TXVector-content as primary. Root cause = LazyVGrid container / ForEach placement work. |
| 4. H-C5-a plan | `c842d7e` | `docs(perf): draft Pass 4-S3 H-C5-a stamp grid explicit rows plan` — one file, no TXVector caching, no shared modifier change, no Equatable refactor, no Canvas. |
| 5. H-C5-a implementation | `405dc38` (reverted) | `perf(stats): replace stamp grid LazyVGrid with eager VStack rows`. Visual sanity passed (simulator screenshot identical to baseline). |
| 6. H-C5-a after-gate verdict | `9a0351d` | `docs(perf): record Pass 4-S3 H-C5-a after-gate REVERT verdict`. 9 traces collected; KEEP criterion #1 failed (-15 % vs ≥ 30 % target); REVERT criterion #4 triggered (Hitches +60 %); narrative reproducibility unchanged at 3/3. |
| 7. Revert | `73f4a00` | `Revert "perf(stats): replace stamp grid LazyVGrid with eager VStack rows"` — `StatsCardCompletionCell.swift` restored to baseline LazyVGrid form. |
| 8. Revert + smoke confirmation doc | `88ae481` | `docs(perf): record Pass 4-S3 H-C5-a revert + smoke confirmation` — `FeatureStatsExampleUITests` TEST EXECUTE SUCCEEDED on reverted state. |
| 9. Closeout | (this commit) | `docs(perf): close Pass 4-S3 Stats self-run scroll investigation`. |

## 3. Headline table

| metric | C5 baseline (3 reps) | H-C5-a after-gate (3 reps) | delta | criterion / result |
|---|---:|---:|---:|---|
| `swiftui-updates` total | 641,276 | **545,597** | **-15 %** | KEEP target ≥ 30 % → **MISS** |
| Animation Hitches count per rep | 4 / 1 / 2 (mean 2.3) | **3 / 4 / 4 (mean 3.67)** | **+60 %** | REVERT criterion (Hitches rises) → **TRIGGER** |
| Animation Hitches total (3 reps) | 7 hitches + 1 hang (35.89 ms) | 11 hitches + 0 hangs | +37 % events; 0 hangs (vs 1) | mixed: severity ↓, count ↑ |
| `LazySubviewPlacements<LazyVGridLayout>` events | ~11,346 | **0** (container removed) | **-100 %** | mechanism success (PASS) |
| "Potentially expensive app update(s)" narrative reproducibility | 3 / 3 reps | **3 / 3 reps** | unchanged | KEEP target < 3 / 3 → **MISS** |
| TP Stats user-code frame in top-10 | absent (0 / 3) | absent (0 / 3) | unchanged | no new top-20 (PASS) |
| TP cumulative scroll-framework self-time | ~108 ms / rep | ~100 ms / rep | similar | not increased (PASS) |
| Visual sanity (simulator screenshot) | baseline | identical | none | no regression (PASS) |
| Post-revert smoke (`FeatureStatsExampleUITests`) | — | **TEST EXECUTE SUCCEEDED** | — | baseline intact (PASS) |

## 4. Final verdict

- **H-C5-a REVERTED.** Production commit `405dc38` reverted by `73f4a00`. `StatsCardCompletionCell.swift` is at baseline `LazyVGrid` form. Post-revert smoke confirms baseline behavior.
- **No production performance change from Pass 4-S3.** Stats's scroll behavior on device is identical to its state at the start of the pass.
- **Stats self-run scroll harness kept as perf infrastructure** (`a4a14c5`). UITestMode flag + `#if PERF_TESTING` branch in `StatsView.cardList`. Default-off; no production impact.
- **C5 remains deferred, not closed forever.** The root cause (LazyVGrid / cell-composition work) is identified and documented; the smallest-scope hypothesis class (inner-container swap) has been gated and refuted. Any future C5 attempt requires a fresh plan with explicit user approval and its own gate.

## 5. Methodology lesson

Pass 4-S3 is the **counterexample that validates the methodology contract**. Pass 4-S2 H-C2-a (kept) demonstrated the contract working positively: SwiftUI Template flagged a candidate, TP + Animation Hitches corroborated, the production change was kept and produced a real user-visible improvement (133 ms severe hitch eliminated, 100 % Hitches drop). Pass 4-S3 demonstrates it working in reverse:

- **SwiftUI Template found a huge signal** (640 K updates / rep, ~3× Home Pass 4-S2's signal).
- **Ablation discriminated which sub-region of the cell was responsible** (LazyVGrid container, not TXVector content).
- **A production hypothesis was implemented at minimum-scope** (inner container swap, one file, no shared modifier touched, no Equatable refactor).
- **The after-gate refused to keep it.** SwiftUI count moved (-15 %) but Time Profiler stayed flat and Animation Hitches actively regressed (+60 % count). The methodology contract from Pass 4-S2 closeout — "SwiftUI Template counts alone never justify a production change" — caught a textbook "moved counts but not real cost" change.

The lesson: **SwiftUI Template counts are necessary but never sufficient. The Time Profiler + Animation Hitches gate is the authoritative metric.** When the two disagree (Template ↓ but Hitches → unchanged or ↑), the production change is rejected even if the SwiftUI mechanism worked exactly as designed.

This rule has now been demonstrated in both directions on this codebase: positive (Pass 4-S2 H-C2-a) and negative (Pass 4-S3 H-C5-a). The contract is operational, not aspirational.

## 6. What this teaches about C5 specifically

The "single inner container swap" hypothesis class is **exhausted**. The remaining hypothesis classes for any future C5 attempt all carry meaningfully larger scope or risk:

- **Larger-scope composition skip** (e.g. `Equatable` conformance on `StatsCardView` so SwiftUI skips body re-eval on input-stable cells). Pass 3 Commit 6 territory; closure-identity issues; would need its own independent gate. **Higher risk; do NOT pursue without fresh plan + approval.**
- **Cell-content reduction** (e.g. cap rendered stamp count at viewport-visible; show summary only when scrolling). Visual change. **Out of one-commit scope.**
- **Cell-pool / reuse model** (less-Lazy scroll architecture). Major architectural change. **Out of any near-term Pass 4-S* scope.**
- **Cell-snapshot caching** (rasterize the stamp grid once per cell into an `Image` or `Canvas`, invalidate only when `monthlyCount` changes). First-paint cost; lifecycle complexity. **Out of one-commit scope.**

None of these are proposed. None should be opened without:
1. A fresh plan with its own evidence + scope + KEEP/REVERT criteria.
2. Explicit user approval.
3. Its own SwiftUI Template + TP + Animation Hitches gate.

## 7. Future follow-up (recorded, NO action)

If C5 is ever reopened, the entry conditions remain:

- Use the existing Stats self-run scroll harness (commit `a4a14c5`).
- Reuse the C5 baseline gate at `/tmp/twix-perf-traces/pass4-s3/c5-before/` as the reference, OR re-collect if the device/OS/configuration drifts meaningfully.
- Apply the methodology contract: SwiftUI Template signal → Time Profiler + Animation Hitches gate (authoritative) → one small commit → after-gate → keep/revert per documented criteria. SwiftUI Template counts alone never justify a production change.
- Read this closeout's §5–§6 before drafting any new C5 hypothesis. The smallest-scope inner-container swap is already gated and refuted; new hypothesis must be a different class.

## 8. Pass 4-S3 commit log

| commit | category |
|---|---|
| `55047c2` | docs (plan) |
| `a4a14c5` | infra (harness, kept) |
| `28adce3` | docs (ablation attribution + DEFER) |
| `c842d7e` | docs (H-C5-a plan) |
| `405dc38` | perf (H-C5-a production attempt) |
| `9a0351d` | docs (H-C5-a after-gate REVERT verdict) |
| `73f4a00` | **revert** of `405dc38` |
| `88ae481` | docs (revert + smoke confirmation) |
| (this commit) | docs (closeout) |

## 9. Honest summary

- **Pass 4-S3 produced no production performance change.** Stats scroll behavior is at baseline.
- **Pass 4-S3 produced perf infrastructure** (the Stats self-run scroll harness) and **substantive documentation**: a baseline gate, two ablation experiments with attribution, a hypothesis plan, an after-gate with full evidence, a revert, and this closeout. Together they form a complete C5 investigation record.
- **The methodology contract was upheld.** The H-C5-a revert is not a failure mode — it is the contract working as designed. SwiftUI Template counts moved; TP + Hitches did not corroborate; the change was rejected.
- **C5 is deferred, not closed forever.** Any future attempt requires a fresh plan + explicit user approval. The smallest-scope hypothesis class is exhausted; larger-scope candidates remain available but each carries meaningfully larger risk.

Pass 4-S3 closed.
