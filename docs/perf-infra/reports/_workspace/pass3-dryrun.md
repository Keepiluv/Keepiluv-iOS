# Pass 3 — Phase D Instruments dry-run

Single trace recorded to verify the end-to-end pipeline before collecting
before/after rendering traces. **Not** a baseline. **Not** rendering
improvement evidence.

## Conditions

| field | value |
|---|---|
| date | 2026-05-18 |
| device | Jiyong의 iPhone (iOS 26.4.2, UDID `00008110-00096DC42632801E`) |
| scheme | FeatureHomeExample |
| configuration | Profile |
| bundle id | `org.yapp.twix.example.home` |
| driver commit | `5fabeb2` |
| UITest | `HomeExampleFeedScrollRenderingTests.testRendering_homeHeavyFeedScroll` |
| launch arguments | `-UITEST -UITEST_SEED home-heavy -UITEST_WAIT_READY -UITEST_DISABLE_ANIMATIONS -UITEST_RENDERING_SCENARIO` |
| seed | `home-heavy` (200 cells) |
| scroll | 20× swipeUp over `feature.home.feed` |
| probe harness | OFF (guardrail XCTAssertFalse passed — `feature.home.perf.toast-show` absent) |
| xctrace template | Time Profiler |
| xctrace mode | `--attach FeatureHomeExample` |
| time limit | 30s |
| UITest wall time | 63.0s (full driver) |
| trace path | `/tmp/twix-perf-traces/pass3-dryrun/device/home-heavy-feed-scroll.trace` |
| trace bundle size | 20MB |

## Pipeline verification

- ✅ UITest passed (0 failures, 63.0s)
- ✅ Probe harness guardrail held — rendering launch did not activate
  `perfActionHarness`, `PerfRebuildProxyPing`, calendar marker,
  `PerfToastPresentationHarness`, or `perfCounterMarkers`.
- ✅ xctrace attached to the running app (PID 11647) without race.
- ✅ Trace bundle on disk, complete (`Trace1.run`, `corespace`,
  `instrument_data`, `shared_data`, `symbols`, `form.template`, etc.).
- ✅ MCP `analyze_trace` parsed the trace and produced a top-user-code
  frame table.

## Sequencing recipe (for the next agent)

The dry-run used a manual two-step sequence because xctrace must attach
to a running process. Reproduce as follows for before/after collections:

```bash
# 1. Start the UITest driver in the background. It launches the app with
#    the correct launch arguments and drives the scroll.
xcodebuild test-without-building \
  -workspace Twix.xcworkspace \
  -scheme FeatureHomeExample \
  -configuration Profile \
  -destination 'platform=iOS,id=00008110-00096DC42632801E' \
  -only-testing:FeatureHomeExampleUITests/HomeExampleFeedScrollRenderingTests/testRendering_homeHeavyFeedScroll \
  >/tmp/twix-perf-uitest.log 2>&1 &

# 2. Wait for the driver to launch the app and reach the scroll phase.
#    The dry-run reached `Synthesize event` for the first swipe by ~t=14s
#    wall clock from test start.
until grep -q 'Synthesize event' /tmp/twix-perf-uitest.log; do sleep 1; done

# 3. Attach xctrace. The recording window should cover the scroll phase
#    (~50s from first swipe to last). Stop early or extend as needed.
xcrun xctrace record \
  --device 00008110-00096DC42632801E \
  --template 'Time Profiler' \
  --time-limit 45s \
  --attach FeatureHomeExample \
  --output /tmp/twix-perf-traces/<phase>/device/home-heavy-feed-scroll.trace

# 4. Wait for the UITest to finish (xcodebuild will exit on its own once
#    the test completes — the driver is single-test).
wait
```

`xctrace` exits with `Target app exited, ending recording...` when the
UITest tears down the app. This is the normal end of a single-driver run.

## Top user-code frames inside the 30s trace

(MCP analyzer reported an 8.32s analyzed window over 6 threads — small,
because the driver is mostly waiting on accessibility idle between
swipes. Real before/after collections may want a longer window or a
denser scroll pattern.)

```
-[UIView(CALayerDelegate) layoutSublayersOfLayer:]                        18ms (0.2%)  UIKit
DisplayList.ViewUpdater.updateInheritedView(container:from:parentState:)   10ms (0.1%)  SwiftUI
-[UIViewController __updateContentOverlayInsetsWithOurRect:...]            8ms (0.1%)  UIKit
DisplayList.ViewUpdater.Platform.updateItemView(_:index:item:state:)       7ms (0.1%)  SwiftUI
-[UINavigationController _calculateTopLayoutInfoForViewController:]        6ms (0.1%)  UIKit
-[UIScrollView setContentOffset:]                                          6ms (0.1%)  UIKit
-[UIView(Geometry) setFrame:]                                              6ms (0.1%)  UIKit
-[UIScrollView _smoothScrollSyncWithUpdateTime:]                           5ms (0.1%)  UIKit
HostingScrollView.updateContext(_:)                                        5ms (0.1%)  SwiftUI
UpdatedHostingScrollView.updateValue()                                     4ms (0.0%)  SwiftUI
```

## Observations (dry-run only, **not** rendering conclusions)

1. The pipeline works end-to-end on real device.
2. Top frames inside the dry-run window are UIKit/SwiftUI framework code,
   not Home user code. This mirrors the Pass 2 cold-launch observation —
   but the dry-run window is small (~8s analyzed). A real before/after
   collection should:
   - run a denser scroll (e.g., increase swipe count, reduce wait between
     swipes, or use a flick gesture) so a higher fraction of the window
     is user-code work, AND/OR
   - record a longer window (60s+) to widen the sample, AND/OR
   - use the `SwiftUI` template (where available) for view-tree work.
3. The driver's per-swipe pause (`Wait for ... to idle`) dominates wall
   clock. The recorded user-code time inside the window is small enough
   that interpretation must be cautious — Pass 3 fixes should be picked
   based on the broader trace, not on this dry-run sample.

## What this dry-run does NOT establish

- This is **not** a Pass 3 rendering baseline.
- The 8.32s analyzed window is too small to declare any frame "hot".
- No before/after comparison is possible from a single trace.
- The numbers above are pipeline-validation only.

## Next step

1. Pick the scroll cadence and recording template for the authoritative
   before/after collection (likely Time Profiler + a denser scroll).
2. Tag the current HEAD (`5fabeb2` or its successor before any Phase E
   fix) as the rendering before-baseline. Suggested tag name:
   `pass3-rendering-before`.
3. Collect the before trace using the sequencing recipe above. Save to
   `/tmp/twix-perf-traces/pass3-before/device/`.
4. Apply Phase E commits one at a time.
5. After each fix, collect an after trace using the same sequencing
   recipe with the same device / template / driver / seed.
6. Use `mcp__xctrace-analyzer__compare_traces` for the diff.
