# Pass 4-S C4 — GoalDetailView initial body cost

**Status**: read-only investigation + Time Profiler / Animation Hitches before-gate. **Verdict: SKIP per gate.**

## 1. Signal recap (from Pass 4-S audit §C4)

SwiftUI Template launch mode, scenario `goal-detail-initial-reactionbar` (3 reps, 20s windows):

| field | value |
|---|---|
| description | `GoalDetailView.body` |
| module | `FeatureGoalDetailExample` |
| update-type | `View Body Updates` |
| mean count / rep | 4.0 |
| mean µs / rep | ~10,400 (≈ 10.4 ms summed across 4 evals) |
| reps | 3/3 |
| derived per-eval cost | ~2.6 ms |

This was the heaviest single user-code body update across all 7 Pass 4-S idle scenarios — only candidate where per-eval magnitude (2.6 ms) sits inside Time Profiler's 1 ms sampling resolution.

## 2. Read-only code findings

### 2.1 GoalDetailView.body composition

`Projects/Feature/GoalDetail/Sources/Detail/GoalDetailView.swift:64-119`

Body is a `VStack` whose children read many store properties:

- `store.item` (gate for whole subtree)
- `store.isCompleted`, `store.currentCompletedGoal?.status`, `store.isFrontMyCard`, `store.myCard*`, `store.partnerCard*`, `store.selectedReactionEmoji`, `store.pendingEditedImageData`
- `store.goalName`, `store.naviBarRightText`, `store.bottomButtonText`, `store.createdAt`
- `store.commentText`, `store.isCommentFocused`, `store.isEditing`
- `store.toast`, `store.isSavingPhotoLog`
- `store.isPresentedProofPhoto`, `store.isCameraPermissionAlertPresented`

Body also owns five `@State` and one `@StateObject`:

- `rectFrame`, `keyboardFrame`, `cardOffset`, `isCrossingDuringDrag`, `didPlayMyEmojiAppearAnimation`
- `myEmojiFlyingReactionEmitter: FlyingReactionEmitter` (ObservableObject)

Many computeds in `GoalDetailReducer.State` (`currentCompletedGoal`, `currentCard`, `myCard`, `myCardIsCompleted`, `isCompleted`, `naviBarRightText`, `isShowReactionBar`, `isLoading`, `isFrontMyCard`, …) are read in body. With TCA `@ObservableState`, each computed expands to the set of underlying stored properties it touches.

### 2.2 FlyingReactionOverlay idle TimelineView guard

`Projects/Feature/GoalDetail/Sources/Detail/FlyingReactionSupport.swift:55-92`

Pass 3 Commit 7's guard is intact:

```swift
if reactions.isEmpty {
    // Idle guard: when there are no active particles, do not
    // run the 60Hz TimelineView. ...
    Color.clear
} else {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ... }
}
```

On idle, `myEmojiFlyingReactionEmitter.reactions` is empty → `Color.clear` branch → no TimelineView ticking. Confirmed unchanged.

### 2.3 GoalDetailReducer effects

`Projects/Feature/GoalDetail/Sources/Detail/GoalDetailReducer+Impl.swift:89-100`

`.onAppear` returns a single `.run` Effect that calls `goalClient.fetchGoalDetail(...)` and dispatches `.fethedGoalDetailItem` once. No timer, `Task.sleep` loop, `TimelineView`, or repeating effect. After initial fetch + populate, state is stable on idle.

### 2.4 Likely decomposition of 4 idle-window body evals

1. Initial body eval at scene appear (`store.item == nil`).
2. Body eval after `.fethedGoalDetailItem` populates `state.item` (the heaviest one — full reaction-bar subtree composes for the first time).
3. SwiftUI layout / preference settling pass (1–2 evals).

After settling (within ~1 s of scene appear), no further evals are expected on idle. 10.4 ms total over the 20 s window is dominated by the post-fetch initial composition.

## 3. Before-gate evidence (Time Profiler + Animation Hitches)

### 3.1 Method

| field | value |
|---|---|
| device | iPhone 13 Pro Max, iOS 26.4.2 (`00008110-00096DC42632801E`) |
| configuration | PerfProfile |
| scenario | GoalDetail initial-reactionbar, launch mode, args `-UITEST -UITEST_RENDERING_SCENARIO -UITEST_WAIT_READY` (matches Pass 4-S SwiftUI scenario `goal-detail-initial`) |
| templates | Time Profiler × 3 + Animation Hitches × 3 |
| window | 20 s per trace |
| trace root | `/tmp/twix-perf-traces/pass4-s/c4-before/goal-detail-initial/` |

### 3.2 Animation Hitches (3 reps)

| metric | rep1 | rep2 | rep3 |
|---|---:|---:|---:|
| potential-hangs rows | 0 | 0 | 0 |
| hitches rows | 0 | **1** | 0 |
| termination | exit(0) | exit(0) | exit(0) |
| bundle MB | 74.8 | 80.4 | 78.2 |
| contamination | none | none | none |

The single rep2 hitch detail (raw `hitches` table):

| field | value |
|---|---|
| start | 00:00.897.447 (≈ 0.9 s into trace, during initial render) |
| duration | **16.67 ms** (= one frame at 60 Hz, smallest visible hitch unit) |
| process | FeatureGoalDetailExample (1948) |
| is-system | No (app-attributable) |
| narrative | "Potentially expensive app update(s)" |

Reproducibility: 1 / 3 reps. Magnitude: minimum unit (single dropped frame). Severity tag: "potential", not severe / hang / interaction-delay.

### 3.3 Time Profiler (3 reps)

| metric | rep1 | rep2 | rep3 |
|---|---:|---:|---:|
| slow functions (≥100 ms) | 0 | 0 | 0 |
| max single-function ms | 7 | 8 | 6 |
| `GoalDetailView.body.getter` in top-N | 2 ms / 2 samples | 2 ms / 2 samples | **3 ms / 3 samples (TOP)** |
| `GoalDetailView.myCard.getter` in top-N | absent | 2 ms / 2 samples | 2 ms / 2 samples |
| `closure #1 in GoalDetailView.body.getter` | 2 ms / 2 samples | 2 ms / 2 samples | absent |
| total GoalDetail user-code self-time | ~4 ms | ~6 ms | ~5 ms |
| sampling window | 11.08 s | 8.95 s | 17.13 s |
| GoalDetail user-code share of total CPU | ~0.04% | ~0.07% | ~0.03% |
| termination | exit(0) | exit(0) | exit(0) |

User-code GoalDetail frames **are present** in Time Profiler top-N across all reps — unlike C3, where Calendar / NavigationBar frames were absent from top-30 entirely. This is the strongest evidence Pass 4-S has produced. But the magnitude is 2–3 ms self-time over 9–17 s windows.

### 3.4 Verdict against the gate

User-supplied measurement gate for C4 (verbatim):

> - GoalDetailView.body or related GoalDetail user-code frame appears in TP top frames or meaningful self-time.
> - Animation Hitches has potential hangs / hitches / stall rows.
> - No contamination.
> - No new unrelated issue.
>
> Decision:
> - If C4 also has no TP/Hitches evidence, close Pass 4-S as inventory-only.
> - If C4 has real TP/Hitches evidence, report the exact hypothesis and ask for approval before any production change.

Result against each clause:

- **TP top frames**: yes — `GoalDetailView.body.getter` (3 ms top frame in rep3), `GoalDetailView.myCard.getter` (2 ms in rep2/rep3). **Meaningful self-time: no.** Aggregate self-time is ~0.03–0.07% of CPU per rep. No frame exceeds the 100 ms slow-function threshold.
- **Hitches / hangs / stall**: 1 / 3 reps shows a single 16.67 ms hitch tagged "Potentially expensive app update(s)" at the initial render moment. 0 hangs in all reps. 0 stall ms accumulated.
- **No contamination, no new unrelated issue**: confirmed.

The "real TP/Hitches evidence" condition is borderline — there is presence but not magnitude. To frame it against the existing Pass-team bar:

- Pass 4 P4-2 was committed because it produced **-35% main-thread stall, -51% longest hang, and removed an ImageIO decode frame in 3/3 reps** on a measured user VoC.
- C4 here produces **0.03–0.07% CPU self-time spread across 2 ms / 3 ms / 2 ms samples and 1/3 reps with one minimum-unit (16.67 ms, single dropped frame) hitch tagged "potentially expensive"**.

Risk vs. benefit: any production GoalDetail refactor (reducing body reads, extracting subtrees, splitting reaction-bar) would introduce architectural change to a feature already touched by Pass 3 Commits 4/5/6/7 (some kept, some skipped). The expected after-gate improvement would be sub-millisecond TP delta and ±1 hitch (within noise) — not separable from rep-to-rep variability.

→ **C4: SKIP per gate.** The signal exists but does not clear the magnitude bar that justifies production change risk.

## 4. Honest caveats

- This gate captured initial-render + idle settling. Interactive scenarios (rapid-fire reaction tap from Pass 3) are out of scope here and were measured by Pass 3 Commit 7 separately.
- TP rep1 sampling window was 11 s (xctrace deferred-stop). Effective sampling time is shorter than the 20 s recording window. rep3 captured the full 17 s. Even so, the relative self-time numbers are consistent across reps.
- The "Potentially expensive app update(s)" hitch in rep2 has no associated stack in the hitches table (only schema columns are start / duration / process / narrative). Without a deeper signpost-anchored hitch root cause, we cannot definitively attribute it to GoalDetailView body re-eval — it could be any main-thread expensive update around the 0.9 s mark (UIKit scene activation, hosting controller init, etc.).
- Pass 4-S audit rule reaffirmed: "do not optimize from SwiftUI Template numbers alone." Honored — TP/Hitches evidence is the gate, and it does not support a production change.
- rep2 hitches trace had a memory-table export race (analyzer warned about virtual-memory export). Does not affect the hitch row count or TP frame inventory used here.

## 5. Recommendation

- Close C4 as **SKIP per gate**.
- Note that C4 is the closest any Pass 4-S candidate came to clearing the gate — and it did not. This validates the gate (it does not rubber-stamp small magnitudes) and confirms the Pass 4-S finding that idle/initial-render launch-mode signals are not, by themselves, sufficient to drive production changes on this codebase.
- Pass 4-S as a whole should now be closed as an **inventory + tooling-validation track** with no production commits. See `pass4-s-closeout.md` for the wrap-up.

## 6. Workspace artifacts

- `/tmp/twix-perf-traces/pass4-s/c4-before/goal-detail-initial/timeprofiler/*.trace` (3 reps)
- `/tmp/twix-perf-traces/pass4-s/c4-before/goal-detail-initial/hitches/*.trace` (3 reps)
- `/tmp/twix-perf-traces/pass4-s/c4-before/goal-detail-initial/summary.tsv`
- `/tmp/twix-perf-traces/pass4-s/c4-before/goal-detail-initial/collection.log`
- `/tmp/pass4-s-c4-before.sh`
