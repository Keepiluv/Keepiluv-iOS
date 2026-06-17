# Pass 3 — Commit 3 (HomeView read-set split) comparison

Before/after analysis for commit `d6482c9 refactor: HomeView 읽기 범위 분리 - #308`.
Authoritative metric is Instruments
xctrace. XCTest timing is correctness only.

## Commit measured

- commit: `d6482c9`
- before baseline tag: `pass3-rendering-before` = `af07cc4`
- after trace path: `/tmp/twix-perf-traces/pass3-after/commit3-home-readset/home/`

## Collection

- expected: 12 (2 scenarios × 2 templates × 3 reps)
- collected: 12
- contamination (SpringBoard / Activate / BannerNotification / interruption / keyboard marker): **0**
- discards / retries: **0**
- measurement defects (no contamination keyword but artifact present):
  1 — `calendar-sweep/hitches/rep1.trace` has bundle TOC export failure
  so `analyze_trace` cannot parse hangs. Trace bundle size (287MB)
  suggests recording captured data but the trace container is partially
  unreadable. Not re-collected because the calendar-sweep Hitches
  pattern across rep2/rep3 already shows essentially no change.

## Time Profiler results (total exec time delta)

| Scenario | rep1 | rep2 | rep3 | mean | within noise (±10%)? |
|---|---:|---:|---:|---:|---|
| feed-scroll | -0.6% (-0.36s) | 0.0% (0s) | -0.6% (-0.34s) | **-0.4%** | yes |
| calendar-sweep | +9.2% (+3.68s) | +6.2% (+2.59s) | +3.5% (+1.46s) | **+6.3%** | yes (within ±10.4% baseline noise) |

No frame-level regression > 17% in any rep. Top user-code frames remain
framework-attributed (`-[UIView layoutSublayersOfLayer:]`,
`DisplayList.ViewUpdater.*`, `__CFStringAppendFormatCore`) — consistent
with Pass 2 / Phase D baseline findings. No Home user-code (HomeView,
HomeReducer, HomeGoalItem) appears in top-10 of any rep.

## Animation Hitches results (hang count + stall time)

### feed-scroll

| Rep | Before window | Before sev/std hangs | Before total stall | After window | After sev/std hangs | After total stall |
|---|---:|---|---:|---:|---|---:|
| 1 | 49.7s | 1 severe 2.14s + 1 std 1.39s | 7.81s | 50.8s | 0 / 0 | 5.03s |
| 2 | 41.6s | 1 severe 2.59s | 4.80s | 50.8s | 0 / 0 | 4.66s |
| 3 | 17.7s¹ | 0 / 0 (1 micro 0.38s) | 1.44s | 50.8s | 1 severe 3.39s + 1 std 0.82s | 8.16s |

¹ Before rep3 window 17.7s is a Hitches collector artifact (despite the
test running 143s, the trace contains only 17.7s of usable data — same
issue surfaced in the original baseline collection report). Direct
hang-count comparison with the 50.8s after rep3 is not apples-to-apples.

**Reading**:
- Severe hangs: 2/3 reps before vs 1/3 reps after.
- Severe hang total time: 6.12s before vs 3.39s after.
- Sub-100ms interaction delay count: ~52 mean before vs ~89 mean after (UP).
- Tentative weak improvement in severe-hang frequency, BUT
  interaction-delay count went up. Net direction is ambiguous.

### calendar-sweep

| Rep | Before sev/std hangs | Before total stall | After sev/std hangs | After total stall |
|---|---|---:|---|---:|
| 1 | 0 / 0 (246 delays) | 11.20s | (TOC unparseable) | n/a |
| 2 | 1 severe 3.07s | 11.31s | 0 / 0 (250 delays) | 11.87s |
| 3 | 0 / 0 (237 delays) | 10.81s | 0 / 0 (233 delays) | 11.24s |

**Reading**:
- Severe hangs: 1/3 reps before vs 0/2 valid reps after.
- Total stall time: ~11s both before and after.
- Interaction delay count similar (~240) both groups.
- Essentially no change.

## Interpretation

- **Measurable improvement (above noise floor): NONE.**
- **Within-noise changes**:
  - feed-scroll TP: mean -0.4% (well within ±10% noise)
  - calendar-sweep TP: mean +6.3% (within ±10% noise, leaning slightly
    slower but not statistically significant with 3 reps)
  - calendar-sweep Hitches: essentially identical total stall time
- **Tentative signal**: feed-scroll Hitches severe-hang frequency
  reduced (2/3 → 1/3 reps), but offset by increased sub-100ms
  interaction-delay frequency. Net direction unclear with 3 reps.
- **Regressions**: none confirmed.
- **Confidence**: LOW. 3 reps insufficient for Hitches given the
  collector's dynamic sampling produces trace-window variance
  (before-rep3 truncated to 17.7s while after-rep3 captured 50.8s).

## Why no clear signal despite the refactor

Pass 2 + Phase D baseline already established that Home user-code is
NOT a top-10 frame in scroll workloads — framework code (UIView /
DisplayList.ViewUpdater) dominates. The read-set split optimizes
SwiftUI's observation-tracking invalidation graph, which is upstream of
DisplayList building. The downstream framework work (layout, hit
testing, scroll geometry, animation hitches) doesn't shrink just
because invalidation is more scoped — it still has to do the same
amount of layout when scrolling 200 cells.

Said another way: read-set split helps when state changes triggered
re-renders of unaffected views (e.g., a presentation flag flip causing
the entire card list to re-evaluate). The Pass 3 rendering scenarios
don't actually do that — feed-scroll never changes presentation flags;
calendar-sweep changes calendarDate which IS supposed to cascade into
items. The refactor's hypothetical benefit doesn't have a chance to
manifest in these scenarios.

A different scenario — e.g., "scroll while toast appears and
disappears" — would be the right one to measure the read-set isolation
benefit. We deliberately did not build that scenario because it mixes
state changes with scroll work and is harder to interpret.

## Recommendation

**Skip Commit 4. Move to Commit 7.**

Reasons:
1. Commit 3's `HomePresentationLayer` already absorbs the presentation /
   destination observation scoping that Commit 4 was meant to address.
   The remaining presentation modifiers (sheets, modal, fullScreenCover,
   alert) all live inside HomePresentationLayer's body now — there is
   no separately scopable target left in Home presentation flow.
2. Time Profiler shows no measurable Home rendering improvement from
   Commit 3 on the current rendering scenarios. Stacking another
   speculative Home read-set fix without first having a clear signal
   would worsen attribution.
3. Commit 7 (`FlyingReactionOverlay` TimelineView idle guard) targets
   GoalDetail, an independent feature with a documented Pass 2 finding
   (0.12% idle CPU draw from a 60Hz TimelineView running while
   `reactions.isEmpty`). The fix is small (`if reactions.isEmpty {
   EmptyView() } else { TimelineView(...) }`), well-scoped, and likely
   to produce a clean signal on the GoalDetail idle Hitches /
   Time Profiler traces.

The Commit 3 refactor itself is **architecturally good** (clearer
boundaries between presentation / content / navigation read-sets,
smaller parent body, isolated sub-states). It just doesn't move the
needle on the chosen rendering scenarios. Keep the commit; do not
revert.
