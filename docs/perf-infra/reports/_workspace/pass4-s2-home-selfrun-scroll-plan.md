# Pass 4-S2 — Home self-running scroll SwiftUI Template gate (plan draft)

**Status**: DRAFT — not yet executed. Successor to Pass 4-S retry feasibility commit `79b6393`. Purpose: investigate Pass 4-S audit candidate **C2 Home LazyVStack adaptor revalidation** using the now-validated state-driven self-run path.

**This document is candidate-discovery + gate plan only. No production code is to be written without explicit user approval after the TP+Hitches gate has produced evidence.**

---

## 1. Why C2 is the first target

From `pass4-s-swiftui-template-audit.md` §C2 and the per-scenario inventory (§4 Home heavy idle table):

| signal | value |
|---|---|
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | **101 events × ~22 ms / rep on idle** (SwiftUI internal, LazyVStack adaptor) |
| `LazySubviewPlacements<LazyVStackLayout>` | 4 events × ~2.3 ms / rep |
| `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` | 214 events × ~5.8 ms / rep |
| `TXCalendarDateCell.body` | 21 events / rep (C3 — already SKIPPED on idle gate) |
| `GoalCardView.body` | 6 events × 0.65 ms / rep |
| `TXNavigationBar.body` | 2 events × 3.3 ms / rep (C1 — same magnitude class as C3) |

Three reasons C2 ranks first:

1. **Highest SwiftUI-internal magnitude in the entire Pass 4-S audit.** 22 ms / rep on a static idle window is the largest single SwiftUI internal signal we have. If any candidate's cost is visible to Time Profiler, this one is most likely.
2. **Strict superset under scroll.** Self-running scroll forces the LazyVStack to materialize / dematerialize cells, which is precisely where `DynamicLayoutViewAdaptor` and `LazySubviewPlacements` do their work. Idle traces only show the post-layout-settled steady state; a self-run scroll trace captures the materialization pulse that XCUITest attach mode cannot.
3. **Pass 3 Commit 6 left an open question.** Pass 3 investigated `GoalCardView` input stability and SKIPPED it because Time Profiler showed no GoalCard frames in the top-20 under feed scroll. The SwiftUI Template idle inventory now points at *adjacent* layers (lazy container, image accessibility provider) — NOT at GoalCardView's input shape. Pass 4-S2 is the cleanest way to test whether the cost is real at that adjacent layer, without re-litigating Commit 6.

C1 (TXNavigationBar) is lower priority because its magnitude class matches C3, which already failed its gate. C5 (Stats ScrollViewChildContainerSize) is structurally identical to C2 but in a different feature; if C2 produces a clean methodology and a real signal, C5 becomes an easy follow-up.

---

## 2. Self-run scroll harness design (public SwiftUI APIs only)

### 2.1 Where the harness lives

`Projects/Feature/Home/Example/Sources/HomeApp.swift` currently does:

```swift
WindowGroup {
    HomeCoordinatorView(store: ...)
        .perfRoot("home")
        .perfReadyMarker("home")
}
```

The harness adds a thin `HomeExampleHost` wrapper analogous to ProofPhoto's `ExampleHost` — owns `@State` markers and the self-run Task. Does not modify `HomeCoordinatorView`, `HomeView`, `HomeReducer`, or any production composition.

### 2.2 New launch flag (UITestMode)

`Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift`:

```swift
public static var isSwiftUISelfRunFeedScroll: Bool {
    arguments.contains("-UITEST_SWIFTUI_SELF_RUN_FEED_SCROLL")
}
```

Default `false`. Production builds and existing scenarios untouched.

### 2.3 Scroll surface

`HomeView.HomeContentSection` already wraps the LazyVStack in `ScrollView { ... }` (line 159) and the ForEach uses `item.id` (stable `Int64`) as identity (line 175). Public SwiftUI `ScrollViewReader.scrollTo(_:anchor:)` works on any `Identifiable` id, so the harness must place a `ScrollViewReader` around (or just inside) the ScrollView. Two implementation paths, in order of preference:

- **(a) Wrap in HomeExampleHost via a `ScrollViewProxy`-emitting modifier.** The harness installs a `ScrollViewReader` via the Example host's overlay or wrapper, gets the proxy through an `onAppear { proxyHolder = proxy }` pattern, and drives `proxy.scrollTo(...)` from a Task. Risk: `ScrollViewReader` must be an ancestor of the `ScrollView` to receive the proxy — verify that wrapping at the Example host level works; if HomeCoordinatorView's internal layout consumes the proxy in an unexpected way, fall back to (b).
- **(b) Add a `#if PERF_TESTING` ScrollViewReader inside `HomeContentSection`.** Touches a feature file but is gated by `PERF_TESTING` + `UITestMode.isSwiftUISelfRunFeedScroll`. Implementation cost is one extra closure level; production behavior unchanged.

Decision deferred to implementation: try (a) first, fall back to (b) if proxy doesn't reach the ScrollView. Either way the harness must NOT change the LazyVStack identity or item rendering.

### 2.4 Self-run sequence (state-driven, public API)

Once the proxy is captured:

1. Wait 1.0 s for `feature.home.ready` marker semantics + initial layout settle.
2. Choose target item ids from `store.items` — for `home-heavy` seed (200 items) the proposed sweep is **every 5th item from index 5 to 195**, i.e. 39 scrollTo calls.
3. Per step: `withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(targetId, anchor: .top) }` + `await Task.sleep(nanoseconds: 300_000_000)` (300 ms — long enough for animation to settle, short enough that the 25 s trace window captures ~12 s of scroll activity + 13 s of context).
4. After the last scrollTo, flip a `feature.home.marker.swiftui-selfrun-scroll.true` perfStateMarker via `@State`.
5. Total self-run duration ≈ 1 s pre-roll + 39 × 300 ms = 12.7 s. Trace window 25 s allows pre-roll + scroll + 11 s settle.

### 2.5 Honest scope limit (state-driven vs real scroll)

The harness produces `scrollTo`-driven layout updates — programmatic content offset changes wrapped in `.easeInOut(0.25)` SwiftUI animations. This is NOT the same as finger-drag scroll. Differences to record in the eventual report:

| dimension | self-run scrollTo | real finger drag |
|---|---|---|
| triggering surface | SwiftUI `ScrollViewProxy` | UIKit pan gesture |
| content offset trajectory | spring/ease curve, deterministic | gesture-velocity-driven, variable |
| frame cadence | animation block (60 fps target) | gesture phase frames |
| input event load | none | UIKit gesture recognizer cost, hit-testing |
| `_UIScrollViewScrollPipeline` involvement | absent | present |
| memory & rasterization pulse | present (cells materialize / dematerialize) | present, with realistic dirty rect patterns |

Per Pass 4-S retry caveat (`pass4-s-selfrun-swiftui-template-feasibility.md` §2 honest infra caveats): self-run is **a lower bound on real scroll cost.** Any candidate must be confirmed by Time Profiler + Animation Hitches on the same self-run scenario before any production change is considered. Real-finger-drag cost remains addressable only by Pass 3/4 attach-mode TP+Hitches measurement, which already exists for `homeFeedScroll`.

---

## 3. SwiftUI Template collection matrix

### 3.1 Phase A — discovery (2 reps)

| field | value |
|---|---|
| scenario | `home-heavy` self-run scroll |
| template | SwiftUI |
| reps | 2 |
| window | 25 s |
| device | `00008110-00096DC42632801E` |
| configuration | PerfProfile |
| trace root | `/tmp/twix-perf-traces/pass4-s2/swiftui-selfrun-scroll/` |

Success criteria for Phase A → Phase B (mirroring Pass 4-S retry's Step A):

1. `swiftui-updates` rows > 0 in both reps.
2. Target process = `FeatureHomeExample` (not XCTest runner).
3. `-UITEST_SWIFTUI_SELF_RUN_FEED_SCROLL` visible in trace TOC `process arguments`.
4. `feature.home.marker.swiftui-selfrun-scroll.true` reachable (or implicit fingerprint check: GoalCardView / LazyVStack / DynamicContainerInfo events scale with scroll step count).
5. ProofPhoto-style fingerprint reproducibility: per-view event counts within ±20 % across the two reps.

If Phase A fails on any of the 5 criteria → stop, record failure, do NOT proceed to Phase B.

### 3.2 Phase B — confirmation (1 additional rep, total 3 reps for SwiftUI)

Only after Phase A succeeds. Collect one more rep with identical settings to confirm the per-view event-count fingerprint is stable, not a one-off. This brings SwiftUI rep total to 3, matching Pass 4-S audit's 3-rep standard for the official inventory.

### 3.3 Optional control (1 rep, only if interpretation is ambiguous)

Capture 1 control SwiftUI rep on the same `home-heavy` seed WITHOUT the self-run flag (idle), to confirm the differential we expect (more scroll-related SwiftUI rows during self-run vs idle). The existing `pass4-s/swiftui-launch/home/home-heavy-idle-rep1.trace` already provides this baseline; only collect a fresh control if the existing trace appears stale.

---

## 4. Mandatory Time Profiler + Animation Hitches gate

Before any production optimization commit is even *proposed*, collect on the same self-run scroll scenario:

- Time Profiler × 3 reps, 25 s window, PerfProfile, launch mode.
- Animation Hitches × 3 reps, 25 s window, PerfProfile, launch mode.

Identical to the gate that C3 and C4 went through. Captured at `/tmp/twix-perf-traces/pass4-s2/c2-before/home-selfrun-scroll/{timeprofiler,hitches}/`.

Required outputs from the gate:

- Slow functions list (>= 100 ms threshold) per rep.
- Top 20 user-code frames per rep with module attribution.
- Specifically: presence/absence of `HomeView.body`, `HomeContentSection.body`, `GoalCardView.body`, `CardHeaderView.body`, `LazyVStack`-attributed user frames.
- Animation Hitches: `potential-hangs` rows count, `hitches` rows count and durations, narrative tags (e.g. "Potentially expensive app update(s)").

The plan's authoritative metric is **Time Profiler + Animation Hitches**, exactly as in Pass 3 / Pass 4 / Pass 4-S. SwiftUI Template rows are candidate-discovery only.

---

## 5. Keep / skip / revert criteria

Per Pass 4-S established rules, the keep/skip path is decided only after Phase B SwiftUI rows AND the TP+Hitches gate are both collected.

### 5.1 Pre-production-change decision (whether to even propose a commit)

Propose a candidate hypothesis to user IF AND ONLY IF all of:

- SwiftUI Template: Home user-code body / SwiftUI-internal scroll-related row shows clear scaling with scroll step count (e.g. `LazySubviewPlacements<LazyVStackLayout>` events ≈ N × scroll_steps, or `DynamicContainerInfo<DynamicLayoutViewAdaptor>` events at least 2× idle baseline).
- TP: at least one Home user-code frame (`HomeView.body`, `HomeContentSection.body`, `GoalCardView.body`, `HomePresentationLayer.body`, `CardHeaderView.body`, etc.) appears in TP top-20 with self-time ≥ 5 ms summed, OR cumulative LazyVStack-attributable framework frames represent ≥ 5 % of trace self-time.
- Hitches: at least 1 `potential-hangs` or `hitches` row in 2 / 3 reps with duration ≥ 33 ms (= 2 dropped frames), OR consistent "potentially expensive app update(s)" narrative across reps.

If any of those three is missing → **SKIP per gate**, document the SwiftUI rows + TP/Hitches absence, close C2 like C3 / C4.

### 5.2 Post-implementation decision (only after a proposed commit lands a measurable change)

For the proposed commit (if it gets that far), collect after-traces with identical scenario × template × reps.

**KEEP** if all of:

- The targeted SwiftUI internal signal (e.g. `DynamicContainerInfo<...>`) event count and µs reduced by ≥ 20 %.
- TP: targeted user-code frame self-time reduced by ≥ 20 % AND no new user-code frame promoted to top-20.
- Hitches: hang/hitches count reduced or unchanged.
- All Home smoke / rendering UITests pass.
- No visual regression in HomeCoordinatorView / HomeView / GoalCardView.

**REVERT** if any of:

- TP regression (new top-20 frame, total self-time up).
- Hitches regression.
- Visual regression.
- SwiftUI signal "improvement" is not accompanied by TP/Hitches improvement (i.e. the change moved counts but not real cost).
- One-commit-one-hypothesis violated.

**SKIP** if the proposed commit's after-trace shows the change is below noise floor (Pass 4-S2 noise floor must be computed from Phase A/B reps, not borrowed from Pass 3/4).

---

## 6. Stop conditions

The plan stops immediately and is reported as "Pass 4-S2 deferred" if any of the following:

1. **Infra time-box exceeded.** 30 minutes of harness work without a clean SwiftUI Template launch trace that includes `swiftui-updates` rows AND target-process attribution = stop. Do not chase configuration / Tuist / build issues for longer than that.
2. **Zero rows.** Self-run scroll trace returns 0 `swiftui-updates` rows in either rep, despite clean `exit(0)` and correct process attribution. Equivalent to attach-mode reproduction; not actionable.
3. **scrollTo not reaching.** ScrollViewProxy proxy not captured (option a fails) AND option b also fails to land scrolls. Verifiable by inspecting `LazySubviewPlacements` event count: if it stays at idle baseline (~4 events) instead of rising with scroll-step count, scrollTo did not produce SwiftUI-visible scroll work.
4. **No TP/Hitches signal.** Both Time Profiler shows no Home user-code self-time over 5 ms summed across reps AND Animation Hitches shows 0 hangs / 0 hitches across all 3 reps. Per §5.1, do NOT propose a production change; close C2 with the SwiftUI rows + TP/Hitches absence documented.
5. **Test scenario unreachability.** `feature.home.ready` marker does not fire in 2 / 3 collection attempts (suggests example app is failing to reach ready state under the self-run flag). Stop, fix harness, retry once.
6. **Driver-vs-self-run divergence.** If Phase A SwiftUI rows show `LazySubviewPlacements` event count matching idle baseline (i.e. scrollTo executed but SwiftUI didn't see scroll work), the harness has produced misleading data. Stop, do not generalize to Stats / GoalDetail self-run.

Any stop event is recorded in `docs/perf-infra/reports/_workspace/pass4-s2-home-selfrun-scroll-result.md` with raw trace counts and the stop trigger.

---

## 7. Do NOT (explicit guardrails)

- Do NOT revive Pass 3 Commit 4 / 5 / 6 unless this scenario's TP + Hitches gate produces evidence specifically attributable to the respective optimization target. The Pass 4-S2 hypothesis is about *lazy container revalidation cost* (SwiftUI internal), NOT about *GoalCardView input stability* or *HomeView read-set leak* (Pass 3 Commit 4/5/6 targets). They are separate hypotheses; new evidence for one is not evidence for the others.
- Do NOT propose a production code change after only Phase A SwiftUI rows. The TP + Hitches gate is mandatory before any proposal.
- Do NOT use private UIKit / SwiftUI APIs to drive scrolling. `ScrollViewProxy.scrollTo` is the only allowed scroll-driver.
- Do NOT change `HomeView` / `HomeContentSection` / `HomeCoordinatorView` / `HomeReducer` production behavior. The harness wraps or adds gated branches only.
- Do NOT extend the self-run flag to other features in this plan. Stats and GoalDetail self-runs are separate plans (Pass 4-S3 / Pass 4-S4 if ever scheduled), each with its own evidence + gate + approval cycle.
- Do NOT generalize C2 verdict to C1 / C5 / C6. Each candidate gets its own plan / gate.

---

## 8. No production code changes without approval

This plan modifies only:

- `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift` — add `isSwiftUISelfRunFeedScroll` flag.
- `Projects/Feature/Home/Example/Sources/HomeApp.swift` — wrap with `HomeExampleHost` (or extend existing `WindowGroup` content) to install the scroll harness. Gated by the flag.
- Possibly `Projects/Feature/Home/Sources/Home/HomeView.swift` — only if option (a) `ScrollViewReader` at Example-host level cannot capture the proxy and we fall back to option (b) a `#if PERF_TESTING`-gated inner `ScrollViewReader`. Production code path unchanged either way.

No reducer changes. No state-shape changes. No GoalCardView / LazyVStack identity changes. No production behavior changes. Every harness branch must be unreachable under default launch.

If the gate produces evidence and a candidate emerges, the production-side change will be drafted as a separate commit with its own approval cycle.

---

## 9. Reporting expectations

After the plan runs (Phase A + optional Phase B + TP/Hitches gate), produce:

`docs/perf-infra/reports/_workspace/pass4-s2-home-selfrun-scroll-result.md`

Sections:

1. CLI invocation.
2. Trace inventory (per rep: bundle MB, swiftui-updates rows, swiftui-causes rows, swiftui-changes rows, pid, args, termination).
3. Per-view user-code body inventory (Home user-code modules only, with mean count / µs / reps coverage).
4. SwiftUI-internal scroll-related inventory (`DynamicContainerInfo<DynamicLayoutViewAdaptor>`, `LazySubviewPlacements<LazyVStackLayout>`, `Image.ImageViewChild<...AccessibilityProvider>`, etc).
5. Self-run vs idle differential table.
6. TP + Hitches gate results (slow functions, top-20 user-code frames, hangs / hitches rows).
7. Verdict matrix (per §5.1).
8. Honest caveats (state-driven scroll vs finger drag, lower-bound interpretation, configuration drift if any).
9. Workspace artifact paths.

If the gate verdict is SKIP, the document is the final artifact and Pass 4-S2 closes.

If the gate verdict is "propose candidate", the document includes the explicit hypothesis + smallest-possible-commit proposal and stops there. User approves separately before any production code is written.

---

## Appendix: implementation cost summary (for plan-approval review)

### Expected files to touch (3 files max, all perf-infra-gated)

1. `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift` — +5 lines (1 new static var).
2. `Projects/Feature/Home/Example/Sources/HomeApp.swift` — wrap `HomeCoordinatorView` in a `HomeExampleHost` analogous to ProofPhoto's `ExampleHost`; ~40 lines.
3. (Conditional) `Projects/Feature/Home/Sources/Home/HomeView.swift` — only if option (a) ScrollViewReader at host level fails; add a `#if PERF_TESTING`-gated `ScrollViewReader` wrap around the existing `ScrollView { LazyVStack { ... } }`. ~5 lines. Production behavior unchanged.

### Expected trace count

- Phase A discovery: 2 SwiftUI traces.
- Phase B confirmation (if A succeeds): 1 SwiftUI trace (total SwiftUI = 3).
- TP + Hitches gate (if Phase B passes): 6 traces (3 TP + 3 Hitches).
- Optional idle control: 0 (reuse existing) or 1.

**Maximum: 10 traces total. Minimum (if Phase A fails): 2 traces.**

### Expected wall-clock runtime

- Infra implementation: 15–30 min (within stop condition #1's 30 min cap).
- Tuist regenerate + on-device install: ~5 min.
- Phase A SwiftUI × 2: 2 × ~30 s record + analysis = ~5 min.
- Phase B SwiftUI × 1: ~3 min.
- TP × 3 + Hitches × 3: 6 × ~30 s + analyzer parse = ~8 min.
- Analysis + report drafting: ~30 min.

**Total: 60–90 min if everything works; 30–45 min if Phase A or stop condition fires early.**

### What counts as a real actionable signal

A candidate from Pass 4-S2 is **actionable** if and only if all three of the following co-occur in the gate data:

1. **SwiftUI Template attribution**: a Home user-code body update OR a clearly-Home-attributable SwiftUI-internal entry (`DynamicContainerInfo<DynamicLayoutViewAdaptor>` whose root-cause graph traces back to LazyVStack contents inside `HomeContentSection`) scales with scroll-step count and exceeds idle baseline by ≥ 2x.
2. **Time Profiler**: at least one Home user-code frame in TP top-20 with summed self-time ≥ 5 ms per rep, OR cumulative LazyVStack-framework self-time ≥ 5 % of trace, reproducible in 2 / 3 reps.
3. **Animation Hitches**: ≥ 1 hitch / hang in 2 / 3 reps with duration ≥ 33 ms, OR consistent `Potentially expensive app update(s)` narrative attributable to the scroll window.

If any of those three is missing, the candidate is **not actionable** and Pass 4-S2 closes as SKIP. The Pass 4 P4-2 commit set the bar at -35 % stall / -51 % longest hang / 3 / 3 reps decode-frame removal; Pass 4-S2 must produce evidence in the same magnitude class to justify proceeding to a production change proposal.

---

## End of plan

Awaiting approval to proceed with Phase A (harness implementation + 2 SwiftUI Template reps).
