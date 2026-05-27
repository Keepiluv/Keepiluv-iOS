# Pass 3 — Before baseline (rendering)

Authoritative rendering baseline trace set captured before any Phase E
optimization commit. Three repetitions on real device for noise-floor
estimation.

## Conditions

| field | value |
|---|---|
| date | 2026-05-18 |
| baseline tag | `pass3-rendering-before` |
| baseline commit | `af07cc4` |
| device | Jiyong의 iPhone (iOS 26.4.2, UDID `00008110-00096DC42632801E`) |
| scheme | FeatureHomeExample |
| configuration | Profile |
| bundle id | `org.yapp.twix.example.home` |
| seed | `home-heavy` (200 deterministic cells) |
| driver | `HomeExampleFeedScrollRenderingTests.testRendering_homeHeavyFeedScroll` |
| launch args | `-UITEST -UITEST_SEED home-heavy -UITEST_WAIT_READY -UITEST_RENDERING_SCENARIO` (no `-UITEST_DISABLE_ANIMATIONS`, no `-UITEST_PROBE_SCENARIO`) |
| scroll | 25× bottom→top drag (press 0.01s) + 25× top→bottom drag = 50 interactions |
| xctrace template | Time Profiler |
| xctrace mode | `--attach FeatureHomeExample` |
| time limit | 60s |
| reps | 3 |
| trace paths | `/tmp/twix-perf-traces/pass3-before/device/home-heavy-feed-scroll-rep{1,2,3}.trace` |

## Per-rep stats (Time Profiler exec time captured inside 60s window)

| rep | exec time | threads | avg fn | max fn | trace size |
|---|---:|---:|---:|---:|---:|
| 1 | 49.54s | 7 | 1.25ms | 81ms | 28MB |
| 2 | 54.69s | 8 | 1.31ms | 72ms | 30MB |
| 3 | 53.87s | 7 | 1.28ms | 84ms | 29MB |

UITest driver wall time on device: ~63s (consistent with single-rep dry-run).

## Top user-code frames (Time Profiler symbolicated)

Frames are framework-attributed top-of-stack samples within the captured
window. All values are total time (samples × 1ms).

| frame | rep1 | rep2 | rep3 |
|---|---:|---:|---:|
| `-[UIView(CALayerDelegate) layoutSublayersOfLayer:]` | 64 ms | 61 ms | 67 ms |
| `DisplayList.ViewUpdater.Platform.updateItemView(_:index:item:state:)` | 26 | 23 | 28 |
| `DisplayList.ViewUpdater.updateInheritedView(container:from:parentState:)` | 24 | 21 | 25 |
| `-[UIViewController __updateContentOverlayInsetsWithOurRect:...]` | 22 | 24 | 25 |
| `HostingScrollView.updateContext(_:)` | 16 | 17 | 17 |
| `-[UIScrollView setContentOffset:]` | 14 | 15 | 15 |
| `-[UINavigationController _calculateEdgeInsetsForChildViewController:...]` | 14 | 16 | 14 |
| `UpdatedHostingScrollView.updateValue()` | 17 | 15 | 14 |
| `-[UIView(Geometry) setFrame:]` | 12 | – | – |
| `-[UIViewController _contentScrollViewHeuristic]` | 12 | – | 13 |
| `-[UIViewController _updateContentOverlayInsetsFromParentIfNecessary]` | – | 13 | 13 |
| `-[UIScrollView _smoothScrollSyncWithUpdateTime:]` | – | – | 11 |

Sum of top-10 user-attributed frames ≈ 200 ms over ~50 s captured
window ≈ **0.4 % of trace**. No user-code frame (HomeView, HomeGoalItem,
HomeReducer) appears in the top 10 in any rep.

## Rep-to-rep noise floor

`mcp__xctrace-analyzer__compare_traces` (rep1 baseline vs rep2 current):

- Total time change: **+10.4 %** (rep1 49.5s → rep2 54.7s).
- 5 regressions / 4 improvements among top-tier frames.
- Largest single-frame swing: `__RawDictionaryStorage.find<A>(_:)` +54%
  (24 ms → 37 ms). This is Swift stdlib hashing, not user code — well
  within run-to-run variance.

**Implication**: any Pass 3 fix needs a delta clearly larger than
~10 % at the trace-total-time level (or larger than ~10 % at a specific
user-attributable frame) to be distinguishable from baseline noise on
this device. Otherwise add more reps for tighter stats, or compare on
specific frames the fix is known to touch.

## Honest observations (baseline only, no fix evidence)

1. Even with dense coordinate-based scroll over 200 deterministic cells
   and animations enabled, **top user-attributed frames are entirely
   UIKit + SwiftUI framework code**. Home user code (HomeView body,
   HomeGoalItem ==, HomeReducer getters) does not show up in the top
   10 of any rep.
2. The Pass 2 finding (cold launch top-frame share dominated by
   framework) reproduces in scroll workload too.
3. The 60s window captured ~50s of CPU-active time per rep, meaning the
   driver / OS / framework keeps the CPU mostly busy — the recording
   window is well-utilized.
4. Pass 3 fix selection should be guided by these baseline traces.
   Fixes that target frames NOT in this top-10 list will be hard to
   verify with the current driver / template. If a planned fix targets
   a user-code path that is invisible here, consider:
   - re-recording with the `SwiftUI` template to surface view-tree work
     more directly;
   - increasing scroll density / count to amplify any user-code work;
   - or accepting that the fix is structural cleanup, not measurable
     rendering improvement.

## What this baseline does NOT establish

- It is not a verdict on whether any specific Pass 3 fix will help.
- It is not a final report — Pass 3 fixes are not applied yet.
- It does not measure memory / allocations / leaks (Time Profiler
  template only). Separate templates required for those signals.

## Next step

1. Apply Phase E commits one at a time on top of `pass3-rendering-before`.
2. After each commit, repeat the 3-rep collection into
   `/tmp/twix-perf-traces/pass3-after-<commit>/device/`.
3. Compare with `mcp__xctrace-analyzer__compare_traces`. Look for
   - changes in the top-10 frame list (new entries or disappearances),
   - >15 % total-time change (clearly above noise floor),
   - >15 % single-frame change on frames the fix is known to touch.
4. If Phase E commits do not move the trace, record that as honest
   "architecture cleanup, no measurable rendering improvement".
