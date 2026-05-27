# Pass 3 — Official baseline collection plan

Stabilization step before collecting the 48-trace official baseline.
Authoritative metric is real-device xctrace (Time Profiler + Animation
Hitches). XCTest pass/fail is correctness only. SwiftUI template is
Phase 2 follow-up, NOT in Phase 1.

## Official baseline tag

- **Tag**: `pass3-rendering-before`
- **Target commit**: the final Phase 1 measurement infra commit (the
  baseline-collection-plan doc commit, which is the last commit before
  collection starts).
- Existing contaminated tag positions are invalidated.

## Environment

| field | value |
|---|---|
| device | `Jiyong의 iPhone` (UDID `00008110-00096DC42632801E`, iOS 26.4.2) |
| Xcode | 26.2 SDK |
| configuration | `PerfProfile` (all targets; Release-like + `PERF_TESTING`) |
| host | macOS Darwin 25.2.0 |
| trace template (1) | `Time Profiler` |
| trace template (2) | `Animation Hitches` |
| xctrace mode | `--attach <ProcessName>` |
| time-limit per trace | 50s (Animation Hitches) / 60s (Time Profiler), per scenario |
| reps per (scenario, template) | 3 |
| total | 8 × 2 × 3 = **48 traces** |
| trace output root | `/tmp/twix-perf-traces/pass3-before/<feature>/<template>/<scenario>-rep<N>.trace` |

## Schemes / bundle ids

| Feature | Scheme | Bundle id |
|---|---|---|
| Home | `FeatureHomeExample` | `org.yapp.twix.example.home` |
| GoalDetail | `FeatureGoalDetailExample` | `org.yapp.twix.example.goal-detail` |
| ProofPhoto | `FeatureProofPhotoExample` | `org.yapp.twix.example.proof-photo` |
| Stats | `FeatureStatsExample` | `org.yapp.twix.example.stats` |

## Official scenarios

Wall column updated from the dry-run pass (single clean device run per
scenario, Time Profiler attached). Sim wall is shown for comparison;
device is the authoritative time.

| # | Feature | Test class | Test method | Seed | Wall — device (dry-run) | xctrace window |
|---|---|---|---|---|---:|---:|
| 1 | Home | `HomeExampleFeedScrollRenderingTests` | `testRendering_homeHeavyFeedScroll` | `home-heavy` (200) | 151.2s | 60s |
| 2 | Home | `HomeExampleFeedScrollRenderingTests` | `testRendering_homeHeavyCalendarWeekSweep` | `home-heavy` | 50.8s | 50s |
| 3 | GoalDetail | `GoalDetailExampleRenderingTests` | `testRendering_goalDetailInitialRender` | `default` | 11.7s | 8s (target app exits with test) |
| 4 | GoalDetail | `GoalDetailExampleRenderingTests` | `testRendering_goalDetailReactionRapidFire` | `default` | 24.8s | 25s |
| 5 | ProofPhoto | `ProofPhotoExampleRenderingTests` | `testRendering_proofPhotoPreviewWithFixtureImage` | `proof-photo-prefilled` | 12.2s | 8s |
| 6 | ProofPhoto | `ProofPhotoExampleRenderingTests` | `testRendering_proofPhotoCommentTyping` | `proof-photo-prefilled` | 13.6s | 12s |
| 7 | Stats | `StatsExampleRenderingTests` | `testRendering_statsHeavyInitialRender` | `stats-heavy` (200) | 13.2s | 8s |
| 8 | Stats | `StatsExampleRenderingTests` | `testRendering_statsHeavyScroll` | `stats-heavy` | 140.5s | 60s |

**Note on Stats heavy scroll wall**: device wall is consistently around
140s (vs ~65s on iPhone 17 Pro sim). Not a contamination — confirmed
clean run with no notification/Activate/springboard-idle interruption.
The driver does 50 coordinate drags over 200 deterministic cells; the
slowness reflects real rendering / accessibility query cost on device.
Treat 140s as the new baseline expectation, not the contamination
threshold.

## Build configuration

Use `PerfProfile` for Pass 4 and later perf runs. It is Release-like and
keeps the `Profile` symbol/strip settings needed by Time Profiler, but
adds `PERF_TESTING` so `SharedPerfTestingSupport` emits accessibility
markers and probe counters. Plain `Profile` / `Release` builds compile the
same helper calls as no-op modifiers.

## Launch arguments (all rendering scenarios)

- `-UITEST`
- `-UITEST_SEED <seed>`
- `-UITEST_WAIT_READY`
- `-UITEST_RENDERING_SCENARIO`
- NOT `-UITEST_PROBE_SCENARIO`
- `disableAnimations: false` (production-like timing)

## Sequencing recipe (per rep)

```bash
# Per (scenario, template, rep) — start UITest, wait for the driver to
# reach the action phase, then attach xctrace for the trace window.

xcodebuild test-without-building \
  -workspace Twix.xcworkspace \
  -scheme <SCHEME> \
  -configuration PerfProfile \
  -destination 'platform=iOS,id=00008110-00096DC42632801E' \
  -only-testing:<SCHEME>UITests/<TestClass>/<testMethod> \
  >/tmp/twix-perf-uitest-current.log 2>&1 &

# Wait for the scroll/tap phase (driver-specific marker).
# For scroll/swipe drivers, wait for the first `Synthesize event`.
# For idle drivers, wait for `feature.<slug>.ready` then attach immediately.
until grep -q 'Synthesize event\|feature\..*\.ready' /tmp/twix-perf-uitest-current.log; do sleep 1; done

xcrun xctrace record \
  --device 00008110-00096DC42632801E \
  --template '<Time Profiler|Animation Hitches>' \
  --time-limit <50s|60s> \
  --attach <ProcessName> \
  --output /tmp/twix-perf-traces/pass3-before/<feature>/<template>/<scenario>-rep<N>.trace

wait  # let the test runner exit cleanly
```

## Environment checklist (must verify before each rep)

User-confirmable items, asked once at start of collection and
re-confirmed if there's any doubt:

- [ ] Focus / Do Not Disturb ON (no push notifications)
- [ ] Charging cable connected
- [ ] Low Power Mode OFF
- [ ] No active calls / FaceTime / handoff
- [ ] Screen unlocked + auto-lock disabled (or set long)
- [ ] Device not noticeably hot (CPU thermal throttling distorts trace)
- [ ] Same device as previous runs (`00008110-00096DC42632801E`)
- [ ] Bluetooth headphones / external displays disconnected (optional but reduces noise)

## Contamination criteria (discard the trace)

Discard a trace and re-run that specific rep when any of these occur:

1. **SpringBoard activation log lines** in UITest log:
   `Activate org.yapp.twix.example.*` after launch, or repeated
   `Open org.yapp.twix.example.*` lines
2. **`Wait for com.apple.springboard to idle`** recurring during the
   driver action phase
3. **BannerNotification interruption**:
   `Interrupting element BannerNotification ... NotificationShortLookView`
4. **Driver wall-time inflation** beyond approx wall column ±50%
5. **typing marker failure** (only ProofPhoto comment typing scenario):
   `feature.proof-photo.marker.comment-text.abcde` never appears
6. **xctrace error** during recording (target app exited mid-window, etc.)

Document each discard in the final report with the reason.

## Batch order (feature-by-feature, NOT one giant run)

Inspect each batch before moving on. If any rep in a batch is
contaminated, re-run that rep before starting the next batch.

1. **Home batch** (2 scenarios × 2 templates × 3 reps = 12 traces)
   - feed scroll TP × 3
   - feed scroll Hitches × 3
   - calendar sweep TP × 3
   - calendar sweep Hitches × 3
2. **GoalDetail batch** (12 traces)
   - initial render TP × 3
   - initial render Hitches × 3
   - reaction rapid-fire TP × 3
   - reaction rapid-fire Hitches × 3
3. **ProofPhoto batch** (12 traces)
   - preview TP × 3
   - preview Hitches × 3
   - comment typing TP × 3
   - comment typing Hitches × 3
4. **Stats batch** (12 traces)
   - heavy initial TP × 3
   - heavy initial Hitches × 3
   - heavy scroll TP × 3
   - heavy scroll Hitches × 3

## Dry-run gate (one clean rep per scenario BEFORE collection starts)

Before any official rep, run each of the 8 scenarios once with xctrace
attached. For each, confirm:

- [ ] UITest passes
- [ ] No SpringBoard / backgrounding in UITest log
- [ ] No BannerNotification interruption
- [ ] (typing only) `feature.proof-photo.marker.comment-text.abcde` reached
- [ ] xctrace attached, recorded, saved trace bundle (>= 10MB)
- [ ] `mcp__xctrace-analyzer__analyze_trace` parses the trace and returns
      a sensible summary (template-dependent)

If any dry-run fails the checklist, fix the driver / environment before
proceeding to the full 3-rep collection.

## Discarded prior traces (audit)

Moved to `/tmp/twix-perf-traces/_contaminated-pass3/`:

- `pass3-before-coordbug/` — Pass 3 first baseline attempt (3 reps Time
  Profiler feed-scroll). Coordinate bug (feed-normalized drags landing
  off-screen). Plus a partial feed×Hitches rep1 from a re-attempt.
- `pass3-dryrun-coordbug/` — Pass 3 first dry-run set:
  - `device/home-heavy-feed-scroll.trace` — coord bug era
  - `device-hitches/home-heavy-feed-scroll.trace` — Animation Hitches
    dryrun, captured 1 severe hang 15.74s but mixed with SpringBoard
  - `device-swiftui/*.trace` — SwiftUI template attach failures
    ("no SwiftUI data"); confirmed Phase 2 follow-up

All marked `INVALID_DO_NOT_USE.txt` in the parent folder. None of these
trace bundles will appear in the Pass 3 final report.

## Out of scope (deferred)

- SwiftUI template launch-mode automation — Phase 2
- Real OS Photos picker / camera capture — Phase 2
- StatsDetailView calendar dateCellBackground optimization — Phase 2 (it
  is a code-quality cleanup, not a rendering-measurement task)
- Settings nickname delayed-loading scenario — Phase 1.5
- Auth / Onboarding — excluded (no current VoC priority)
- Optimization commits — NOT until Phase 1 baseline collection completes

## When this plan freezes

The `pass3-rendering-before` tag moves to the commit that adds **this
file** (or to the most recent Phase 1 infra commit if no docs-only
commit is made). After that point the collection sequence above is the
single source of truth. Any change to the driver, the seed, the
identifiers, or the launch arguments requires moving the tag and
restarting the collection.
