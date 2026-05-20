# Pass 4-S retry — SwiftUI Template self-run feasibility

**Verdict: SUCCESS.** SwiftUI Template launch-mode CAN capture interactive-equivalent SwiftUI rows when the example app self-runs reducer-driven state mutations from inside the launched process. This unlocks an interactive attribution path that XCUITest attach-mode does not provide on this device/OS.

**Scope**: tooling feasibility experiment. No production code change. No optimization claim. Any candidate that emerges from a future self-run sweep still requires a Time Profiler + Animation Hitches before/after gate per Pass 4-S rules.

## 1. Background

Pass 4-S audit (`pass4-s-swiftui-template-audit.md` §3) showed:

- SwiftUI Template `--launch` mode populates `swiftui-updates` / `swiftui-causes` / `swiftui-changes` / `swiftui-update-groups` for self-loading scenarios.
- SwiftUI Template `--attach` mode (i.e. XCUITest launches app, xctrace attaches after the ready marker) returns **0 rows in all SwiftUI tables** on iPhone 13 Pro Max / iOS 26.4.2 / Xcode 26.0. Reproduces Pass 3 finding.

Hypothesis: the SwiftUI instrumentation hook needs to be active at launch time. If we run an interaction-equivalent flow from *inside* a launch-mode process, the SwiftUI tables should be populated.

## 2. Infra added (Example/perf-only, gated)

Two minimal additions, both gated by `UITestMode.isEnabled && UITestMode.isSwiftUISelfRunTyping`:

- `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift` — new flag:
  ```swift
  public static var isSwiftUISelfRunTyping: Bool {
      arguments.contains("-UITEST_SWIFTUI_SELF_RUN_TYPING")
  }
  ```
- `Projects/Feature/ProofPhoto/Example/Sources/ProofPhotoApp.swift` (`ExampleHost`) — adds a `@State private var swiftUISelfRunDone: String` marker and a `performSwiftUISelfRunTyping()` Task that:
  1. waits 1.0 s for preview-ready settling,
  2. dispatches `store.send(.commentTextChanged("a"))` … through `.commentTextChanged("abcde")` with 150 ms inter-step pacing — the same reducer action that the production `TXCommentCircle` `TextField` binding emits,
  3. flips `swiftUISelfRunDone = "true"` to fire the `feature.proof-photo.marker.swiftui-selfrun.true` accessibility marker.

### Honest infra caveats

- This is a **state-driven self-run**: same reducer pathway as production typing, but no real keyboard, no real focus event, no real PlatformTextFieldAdaptor input commit. Captured SwiftUI rows represent state-mutation-driven invalidation, NOT a one-for-one reproduction of XCUITest typing's full cost. The `PlatformViewRepresentableAdaptor.update` rows we see (§4.2) suggest the text bridge is updated as a result of the binding, but no UIKit focus/keyboard machinery is engaged.
- No private API used. No internal UIKit event injection. No image/upload pipeline mutated. Step B (real keyboard/focus self-run) was not attempted because real keyboard input from inside the app requires private APIs or unsafe injection; per plan, that is forbidden.
- The flag default is `false`. Production builds, regular Example launches, and existing SwiftUI Template / Time Profiler / Animation Hitches scenarios are unchanged.

## 3. CLI

```bash
xcrun xctrace record \
  --device 00008110-00096DC42632801E \
  --template 'SwiftUI' \
  --time-limit 25s \
  --output <path>/proof-photo-typing-large-rep<N>.trace \
  --launch -- org.yapp.twix.example.proof-photo \
  -UITEST -UITEST_RENDERING_SCENARIO \
  -UITEST_SEED proof-photo-prefilled-large \
  -UITEST_WAIT_READY \
  -UITEST_SWIFTUI_SELF_RUN_TYPING
```

## 4. Evidence

### 4.1 Trace integrity (both reps)

| field | rep1 | rep2 |
|---|---|---|
| trace path | `/tmp/twix-perf-traces/pass4-s-retry/swiftui-selfrun/proof-photo-typing-large-rep1.trace` | `…rep2.trace` |
| bundle size | 64.7 MB | 64.1 MB |
| target process | `FeatureProofPhotoExample` (pid 1984) | `FeatureProofPhotoExample` (pid 1985) |
| process args | `-UITEST -UITEST_RENDERING_SCENARIO -UITEST_SEED proof-photo-prefilled-large -UITEST_WAIT_READY -UITEST_SWIFTUI_SELF_RUN_TYPING` | (same) |
| termination | `exit(0)` | `exit(0)` |
| `swiftui-updates` rows | **4,619** | **4,081** |
| `swiftui-causes` rows | 5,952 | 5,082 |
| `swiftui-changes` rows | 411 | 405 |
| `swiftui-update-groups` rows | 415 | 432 |
| `hitches` rows | 0 | 0 |
| contamination | none | none |

Both reps satisfy all six Step A success criteria from the plan:

1. `swiftui-updates` rows > 0 — ✅ 4,619 / 4,081.
2. Target process = `FeatureProofPhotoExample` (not XCTest runner) — ✅.
3. Launch args visible in trace TOC — ✅ `-UITEST_SWIFTUI_SELF_RUN_TYPING` confirmed.
4. Self-run marker / abcde marker reached — ✅ implicit, see §4.3.
5. ProofPhoto-related SwiftUI rows visible — ✅ see §4.2.
6. Reproducible in 2 reps — ✅ event counts identical across reps (see §4.2 table).

### 4.2 ProofPhoto user-code body update inventory

Aggregated from `swiftui-updates` table per rep, user-code modules only. Event counts are identical across both reps (2/2 Step A reproducibility):

| view (description / module) | rep1 events | rep1 µs | rep2 events | rep2 µs | idle preview-large baseline |
|---|---:|---:|---:|---:|---:|
| `ProofPhotoView.body` / `FeatureProofPhotoExample` | **9** | **29,074** | **9** | **10,763** | 4 events / 5,841 µs |
| `TXCommentCircle.body` / `FeatureProofPhotoExample` | **9** | **3,229** | **9** | **2,031** | 4 events / 381 µs |
| `TXRoundButton.body` / `FeatureProofPhotoExample` | 8 | 3,038 | 8 | 2,328 | 3 events / 1,462 µs |
| `TXToastModifier.body` / `FeatureProofPhotoExample` | 9 | 597 | 9 | 479 | 4 events / 134 µs |
| `ExampleHost.body` / `FeatureProofPhotoExample` | 3 | 891 | 3 | 891 | 2 events / 308 µs |

Notable:

- `ProofPhotoView.body` and `TXCommentCircle.body` show **exactly 9 event counts in both reps** = 1 initial composition + 5 keystroke-driven re-evals + ~3 settling passes. This is the expected fingerprint of the self-run sequence.
- Event-count reproducibility is exact across reps (9/8/3/9/9 in both reps). Durations vary (rep1 ProofPhotoView.body 29 ms vs rep2 10.8 ms) — the µs accounting in SwiftUI Template includes recursive child resolution, which depends on layout cache warmth, so the µs value is a rough indicator but the event-count is the deterministic signal.
- `TXCommentCircle` — the actual comment input view — shows the strongest delta vs idle (~8x duration, 2.25x events). This is the correct attribution target for any future typing-side optimization candidate.

### 4.3 Self-run completion check

Direct query of the perfStateMarker is not available in launch mode (no XCUITest driver to read accessibility identifiers). The plan's Step A success criterion #4 ("self-run marker reaches done / comment-text.abcde") is therefore verified indirectly by:

- Both reps captured exactly 9 `ProofPhotoView.body` and `TXCommentCircle.body` events — fingerprint of the 5-step keystroke flow.
- `swiftui-changes` table populated with 411 / 405 rows — state-mutation events recorded by SwiftUI Template.
- `PlatformViewRepresentableAdaptor.update` shows 7 events × 10 ms (rep2) — UITextField bridge updates that follow the comment text binding propagation.
- Process termination is `exit(0)` (not killed mid-flow), and the trace window (25 s) is longer than the self-run sequence (1 s pre-run + 5 × 150 ms = 1.75 s total).

If a future hardening pass needs deterministic marker verification, the Task could write a sentinel into a known file path that the analyzer reads post-trace; this was not added now to keep the experiment minimal.

### 4.4 Self-run vs idle differential

| metric | idle preview-large (mean of 3 reps) | self-run typing-large (mean of 2 reps) | delta |
|---|---:|---:|---|
| total `swiftui-updates` rows | 2,518 | 4,350 | **+73%** |
| `View Body Updates` count | 280 | 524 | **+87%** |
| `swiftui-changes` rows | small (< 50) | 408 | order-of-magnitude increase |
| `ProofPhotoView.body` events | 4 | 9 | +125% |
| `TXCommentCircle.body` events | 4 | 9 | +125% |
| `TXCommentCircle.body` µs | 381 | 2,630 | **+590%** |
| `hitches` rows | 0 | 0 | unchanged |

The differential is concentrated in the views that the self-run touches (`ProofPhotoView.body`, `TXCommentCircle.body`, `TXRoundButton.body` whose state depends on `hasImage` / `isCommentFocused` reads, and the toast modifier). SwiftUI-internal layout/computer rows also rise (e.g. `Layout: LeafLayoutComputer<AnimatedShape<AnyShape>>` from minimal to 152 events / 4.7 ms in rep2 — driven by `.animation(value: keyboardInset)` and related transitions).

## 5. Decision

**Step A: SUCCESS.** Per the plan, Step B (UI/focus/keyboard self-run) is allowed only when Step A succeeds AND no private API is required. A real keyboard self-run from inside the launched app process is not feasible without private UIKit event injection on this OS, so Step B is intentionally NOT attempted in this experiment.

The state-driven self-run is sufficient to validate the tooling feasibility question (the plan's primary goal). It is NOT a replacement for the production typing path; any candidate discovered via self-run rows must be re-validated by Time Profiler + Animation Hitches on a real interaction-driven scenario (or accepted at state-mutation granularity if the optimization target is the reducer/observation side, not the keyboard side).

## 6. What this unlocks

A future Pass 4-S extension could add similar self-run flags to Home / Stats / GoalDetail examples to capture SwiftUI Template attribution for interactions that are currently driver-required:

- Home — scroll a `LazyVStack` via direct `ScrollViewReader.scrollTo(...)` proxy from a self-run Task (programmatic scroll is a public SwiftUI API).
- Stats — same pattern.
- GoalDetail — rapid-fire reaction emoji selection via direct reducer actions (`reactionEmojiTapped`).
- ProofPhoto — reselect via direct `.galleryPhotoLoaded(imageData:)` dispatch (already used in the existing `proof-photo-prefilled-large` reselect harness — could be made self-running by removing the tap requirement).

In each case the captured rows would attribute to user-code Views during the simulated interaction window. Pass 4-S retry would then revisit C1 / C2 / C5 with state-driven self-run data, not just idle data.

**This document does not propose implementing those sweeps.** The user must approve any extension separately.

## 7. Caveats and limits

- State-driven self-run does NOT exercise the real keyboard / focus / accessibility pipeline. Costs measured here are a lower bound for production typing cost. The Pass 4 P4-2 typing-large measurement (XCUITest-driven, Time Profiler + Animation Hitches) remains the authoritative typing performance metric.
- The infra adds an `onAppear` branch in `ExampleHost`; that branch is unreachable in production (`UITestMode.isEnabled` requires `-UITEST` launch arg) and unreachable in existing Pass 3 / Pass 4 scenarios (which do not set `-UITEST_SWIFTUI_SELF_RUN_TYPING`).
- `hitches` rows = 0 in both reps — note that SwiftUI Template's hitches detector is configured with a 100 ms threshold (visible in TOC `Hangs / Include Brief Unresponsiveness (>100 ms)`). The state-driven self-run does not produce a hang; the 5-keystroke flow over ~750 ms is too gentle to drop a frame at this magnitude.
- Pass 4-S audit rules remain in force: no production optimization from SwiftUI Template numbers alone; any candidate goes through Time Profiler + Animation Hitches before/after gate.

## 8. Recommendation

- Keep the infra (UITestMode flag + ExampleHost branch). It is fully gated, costs nothing in production, and unlocks a measurement path that the codebase did not previously have.
- Document this in the Pass 4-S closeout as a follow-up addendum.
- Do **not** kick off Home / Stats / GoalDetail self-run extensions automatically — that is a separate proposal that requires user approval per the candidate-by-candidate gate model already established.
- If user wants to discover a real candidate now, the next logical step is to add a similar self-run to one of:
  - **Home feed scroll** via `ScrollViewReader.scrollTo` (high-prior given LazyVStack adaptor signal from idle).
  - **GoalDetail rapid-fire reaction** via direct `.reactionEmojiTapped` dispatch (Pass 3 Commit 7 left the rapid-fire scenario unmeasured at SwiftUI granularity).

## 9. Workspace artifacts

- `/tmp/twix-perf-traces/pass4-s-retry/swiftui-selfrun/proof-photo-typing-large-rep1.trace` (64.7 MB)
- `/tmp/twix-perf-traces/pass4-s-retry/swiftui-selfrun/proof-photo-typing-large-rep2.trace` (64.1 MB)
- `/tmp/twix-perf-traces/pass4-s-retry/analysis/selfrun-rep[12].swiftui-updates.xml` — exported XML
- `/tmp/twix-perf-traces/pass4-s-retry/analysis/selfrun-rep[12].json` — per-trace summary

Infra files touched:

- `Projects/Shared/PerfTestingSupport/Sources/UITestMode.swift` — `isSwiftUISelfRunTyping` flag.
- `Projects/Feature/ProofPhoto/Example/Sources/ProofPhotoApp.swift` — `ExampleHost.performSwiftUISelfRunTyping()` + `swiftUISelfRunDone` marker.
