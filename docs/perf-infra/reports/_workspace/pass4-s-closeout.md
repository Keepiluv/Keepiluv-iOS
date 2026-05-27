# Pass 4-S — Closeout

**Status**: closed as inventory + tooling-validation track. **No production code change.**

Pass 4-S investigated SwiftUI Template as an app-wide candidate-discovery layer on top of Pass 3 / Pass 4's Time Profiler + Animation Hitches measurement system. The intent was always candidate discovery, not optimization — and the Time Profiler / Animation Hitches before-gates run on the most promising candidates show that no Pass 4-S finding clears the bar for a production change at this time.

## 1. SwiftUI Template launch mode succeeded

CLI shape (validated, see `pass4-s-swiftui-template-audit.md` §1):

```
xcrun xctrace record \
  --device <UDID> --template 'SwiftUI' --time-limit 20s \
  --output <path>.trace \
  --launch -- <bundle-id> -UITEST -UITEST_RENDERING_SCENARIO -UITEST_SEED <seed> -UITEST_WAIT_READY
```

- `--launch` accepts the on-device bundle id directly.
- `-UITEST*` arguments are forwarded; example apps self-load via `UITestMode.configureApplication()` and seed branching.
- Capture target = the launched example app (not an XCTest runner).
- All SwiftUI tables (`swiftui-updates`, `swiftui-causes`, `swiftui-changes`, `swiftui-update-groups`, three `SwiftUIFilteredUpdates` variants, `hitches-*`) are populated with real row data per rep.

## 2. Attach mode reproduced the Pass 3 tooling limit

`pass4-s-swiftui-template-audit.md` §3: one driver-required scenario (`testRendering_proofPhotoCommentTypingWithLargeFixtureImage`) ran via XCUITest, xctrace attached after the `image-ingested.fixture-large` marker.

- 2 / 2 reps: 0 rows in `swiftui-updates`, `swiftui-causes`, `swiftui-changes`, `swiftui-update-groups`.
- Schemas present in TOC; data empty.
- Trace bundles otherwise valid (63 MB each, `exit(0)`).
- Reproduces the Pass 3 "no SwiftUI data" attach-mode finding under Xcode 26.0 / iOS 26.4.2.

Interactive scenarios (Home feed scroll, Stats heavy scroll, GoalDetail rapid-fire, ProofPhoto typing / reselect) cannot be measured with SwiftUI Template via the xctrace CLI on this device / OS. Recorded as a tooling limit.

## 3. Launch-mode collection inventory

21 / 21 official traces, all `exit(0)`, 0 contamination:

| scenario | reps | swiftui-updates rows / rep (mean) | view-body updates / rep (mean) |
|---|---:|---:|---:|
| ProofPhoto preview-1024 | 3 | 2,521 | 284 |
| ProofPhoto preview-large | 3 | 2,518 | 280 |
| GoalDetail initial-reactionbar | 3 | 3,750 | 295 |
| Home scroll-50 idle | 3 | 11,387 | 573 |
| Home heavy idle | 3 | 11,022 | 570 |
| Stats scroll-50 idle | 3 | 10,145 | 227 |
| Stats heavy idle | 3 | 9,621 | 223 |

Per-scenario user-code body inventory + cross-scenario candidate shortlist: see `pass4-s-swiftui-template-audit.md` §4–§5.

## 4. C3 investigated and SKIPPED

`pass4-s-c3-txcalendardatecell.md`. Read-only investigation + Time Profiler × 3 + Animation Hitches × 3 on Home home-heavy idle, launch mode.

- Read-only root-cause hypothesis: `TXCalendar` weekly mode pre-renders ±1 pages with `TXCalendarDateItem` instances created via `UUID()` default initializer → identity drift fans out one TXCalendar.body re-eval (driven by SwiftUI `External: Time` / `_GraphInputs.Phase` ticks) into 21 cell body events.
- Gate result: **0 hangs / 0 hitches / 0 calendar user-code frames in TP top-30** across 3 reps. SwiftUI Template 21 × 1.5 ms signal is below TP sampling resolution and far below Hitches threshold.
- Verdict: **SKIP per gate.** Any change would reduce only SwiftUI Template counts without TP / Hitches support — exact "skip" condition.

## 5. C4 investigated and SKIPPED

`pass4-s-c4-goaldetailview.md`. Read-only + TP × 3 + Hitches × 3 on GoalDetail initial-reactionbar, launch mode.

- Read-only check: Pass 3 Commit 7's `FlyingReactionOverlay` idle TimelineView guard is intact. `GoalDetailReducer.onAppear` is a one-shot fetch; no idle ticker.
- Gate result: `GoalDetailView.body.getter` (2–3 ms / 2–3 samples) and `GoalDetailView.myCard.getter` (2 ms / 2 samples) DO appear in TP top-N — the only Pass 4-S candidate where user-code body frames are visible at all. But aggregate self-time is **0.03–0.07% of total CPU per rep**. Hitches: 1 / 3 reps shows a single 16.67 ms (one frame) hitch tagged "Potentially expensive app update(s)" at 0.9 s into the trace; 0 hangs in all reps.
- Verdict: **SKIP per gate.** Signal present, magnitude does not justify production change risk. C4 is the closest any Pass 4-S candidate came to clearing the gate — and it still didn't.

## 6. C1 / C2 / C5 are NOT pursued

Per user direction and the C3 gate outcome, candidates whose magnitude class matches or undershoots C3 are not separately gated:

- **C1 TXNavigationBar idle re-eval** (~3.0–4.4 ms × 1–3 evals/rep cross-feature): same magnitude class as C3; C3 before-gate TP already confirmed `TXNavigationBar.body` is absent from TP top-30 on the same Home idle scenario. Idle-scenario gate would fail.
- **C2 Home LazyVStack adaptor revalidation** (SwiftUI-internal `DynamicContainerInfo<DynamicLayoutViewAdaptor>` 101 × 22 ms/rep): SwiftUI-internal signal, not directly user-attributable. Idle-scenario gate would need to detect user-code improvement after any change — also weak in the absence of an interactive scenario.
- **C5 Stats `ScrollViewChildContainerSize` re-query** (SwiftUI-internal 249 × 2 ms/rep): same reasoning as C2.
- **C6 Image accessibility provider churn**: already classified as "weak signal" in the audit.
- **C7 ProofPhoto preview-1024 vs preview-large differential**: already resolved by Pass 4 P4-2.
- **C8 Driver-required SwiftUI Template attribution**: tooling limit, not a candidate.

## 7. Future actionable path

Pass 4-S findings would become actionable through one of:

1. **Launch-mode self-running interactive scenarios.** Add infra to example apps so scenarios like "scroll the feed 100 px every 200 ms" or "tap reaction emoji every 150 ms" run autonomously after `-UITEST_WAIT_READY` is signaled. SwiftUI Template would then capture interaction-time body / update / invalidation attribution, which is where the magnitudes plausibly cross TP / Hitches thresholds. Cost: new XCUITest-side helper or a tiny "scenario runner" mode in each Example app.
2. **Manual Instruments.app GUI sessions** for the same scenarios, with a person performing the interactions. Lower repeatability, no CI integration, but immediately available. Useful as a one-shot diagnostic when a candidate is high-priority.
3. **Accept TP + Animation Hitches as the only attribution layer** for interactive scenarios (the current Pass 3 / Pass 4 default). This is the status quo and remains valid — it's how Pass 4 P4-2 was justified and shipped.

Pass 5+ planning should pick (1) only if a specific candidate's expected payoff justifies the infra cost. The current finding is that none of the C1–C6 candidates show that level of payoff on idle scenarios.

## 8. Workspace inventory

Committed documents (`docs/perf-infra/reports/_workspace/`):

- `pass4-s-plan-draft.md` — original Pass 4-S plan draft.
- `pass4-s-swiftui-template-audit.md` — launch-mode sweep + candidate inventory + attach-mode trial result.
- `pass4-s-c3-txcalendardatecell.md` — C3 gate + SKIP verdict.
- `pass4-s-c4-goaldetailview.md` — C4 gate + SKIP verdict.
- `pass4-s-closeout.md` — this document.

Trace artifacts (host `/tmp`, not committed):

- `/tmp/twix-perf-traces/pass4-s-trial/` — Step 0 / Step 1 CLI trials (2 SwiftUI traces).
- `/tmp/twix-perf-traces/pass4-s/swiftui-launch/{proof-photo,goal-detail,home,stats}/` — launch-mode sweep (21 SwiftUI traces).
- `/tmp/twix-perf-traces/pass4-s/swiftui-attach/` — attach-mode trial (2 SwiftUI traces, both empty).
- `/tmp/twix-perf-traces/pass4-s/analysis/` — exported `swiftui-updates` XML + per-trace JSON summaries.
- `/tmp/twix-perf-traces/pass4-s/c3-before/home-heavy-idle/` — C3 TP × 3 + Hitches × 3.
- `/tmp/twix-perf-traces/pass4-s/c4-before/goal-detail-initial/` — C4 TP × 3 + Hitches × 3.

Collection / extraction scripts (host `/tmp`):

- `/tmp/pass4-s-launch-sweep.sh` — launch-mode sweep collector.
- `/tmp/pass4-s-attach-trial.sh` — attach-mode trial collector.
- `/tmp/pass4-s-aggregate.sh` — per-trace `swiftui-updates` XML export + JSON.
- `/tmp/pass4-s-extract.py` — row-by-row parser for `swiftui-updates` XML.
- `/tmp/pass4-s-inventory.py` — per-scenario candidate inventory builder.
- `/tmp/pass4-s-c3-before.sh`, `/tmp/pass4-s-c4-before.sh` — TP+Hitches before-gate collectors.

## 9. Honest summary

- **Tooling: validated.** SwiftUI Template via xctrace launch mode is a usable candidate-discovery layer for self-loading scenarios on this codebase. Attach mode is not usable on this device / OS.
- **Discovery: completed.** 21 traces + per-scenario inventory + 8-entry candidate shortlist (`pass4-s-swiftui-template-audit.md`).
- **Optimization: zero.** No production code was changed in Pass 4-S. Both top candidates that were gated (C3 + C4) failed their before-gates.
- **Pass 4-S exists as evidence for future passes.** The candidate inventory and the gate-failure record are persistent context: if a future pass attempts a SwiftUI-side optimization in Home / Stats / GoalDetail, this document set is the baseline to revisit, and the "launch-mode self-running interactive scenarios" infra path is the lever that would re-open the gate.

Pass 4-S closed.
