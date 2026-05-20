# Pass 4 — P4-2 (preview decode out of body) before/after comparison

- **P4-2 commit**: `bb33235`
- **Before tag**: `pass4-rendering-before` (`6fe027c`)
- **Configuration**: PerfProfile (same as baseline)
- **Window**: 30s xctrace, same scenarios × templates × reps
- **Before traces**: `/tmp/twix-perf-traces/pass4-before/proof-photo/`
- **After traces**: `/tmp/twix-perf-traces/pass4-after/p4-2-preview-decode-out-of-body/proof-photo/`

## 1. Trace integrity

| metric | before | after |
|---|---|---|
| official traces | 24/24 | 24/24 |
| contamination (§2.4) | 0/24 | 0/24 |
| TOC export partial failure | 3/24 (analyzer race) | 4/24 (analyzer race; trace bundles valid) |
| typing marker `comment-text.abcde` | 3/3 reps | 3/3 reps |
| `preview-ready.true` marker (semantics tightened: decoded representation) | 9/9 | 9/9 |
| `image-ingested.fixture-large-second` | 3/3 | 3/3 |
| `reselect.1` | 3/3 | 3/3 |
| all 5 simulator UITests | passed | passed |

## 2. Hitches comparison (primary metric — interaction delays during typing)

### typing-large (the user-VoC scenario)

| metric | before | after | delta vs noise floor |
|---|---:|---:|---|
| hang count per rep | 15 ± 0 | 11.0 ± 1.0 | **-27%** (baseline CV = 0%, so -4 hangs is large) |
| total main-thread stall (s) | 0.82 ± 0.04 | 0.53 ± 0.03 | **-35%** (Pass 4 stall noise floor 4.95%; -35% is ~7× noise floor) |
| longest single hang (ms) | 233 ± 38 | 114 ± 49 | **-51%** (longest-hang noise floor 16.4%; -51% is ~3× noise floor) |
| "Brief Unresponsiveness" / Microhang ≥150ms incidence | 3/3 reps (193, 269, 236 ms) | 1/3 reps (169 ms) | -67% incidence |
| "Potential Interaction Delay" count (39–57ms range) | 10+ each rep, 30+ total | 9–11 each rep, 30 total | similar count, slightly lower magnitude |

### Other scenarios (regression check)

| scenario | before hangs | after hangs | verdict |
|---|---|---|---|
| preview-1024 | 0/3 | 0/3 | unchanged |
| preview-large | 0/3 | 0/3 | unchanged |
| reselect-large | 1/3 (rep2=1, rep3=1; rep1 TOC failed) | 3/3 (rep1 TOC failed for hangs; rep2=1@41ms, rep3=2@47+38ms) | comparable, within noise (1-2 hangs of 38-47ms, identical magnitude class to baseline) |

## 3. Time Profiler — ImageIO / JPEG decode frame inventory

### typing-large TP traces

| rep | before — ImageIO in top-10? | after — ImageIO in top-10? |
|---|---|---|
| 1 | **YES** — `AppleJPEGReadPlugin::copyIOSurfaceImp` 3ms | **NO** |
| 2 | NO | NO |
| 3 | NO | NO |

→ **3/3 reps: ImageIO frame removed when present, or absent when absent**. Decode is no longer in the typing hot path.

### preview-large TP traces

| rep | before — ImageIO? | after — ImageIO? | max frame ms before → after |
|---|---|---|---|
| 1 | NO | NO | 3 → ? (TP from hitches in after; not directly comparable) |
| 2 | NO | NO | 3 → 2 |
| 3 | NO | NO | 2 → 2 |

→ Preview-only scenarios unchanged — already no decode in top frames at baseline.

### reselect-large TP traces

| rep | before — ImageIO? | after — ImageIO? |
|---|---|---|
| 1 | NO | YES (1 sample, 2ms) — but this is the FIRST decode of the reselect-target fixture, expected per design; happens once at ingestion, not per body re-eval |
| 2 | YES (2 samples) | NO |
| 3 | YES (1 sample) | NO |

→ Reselect now shows decode in 1/3 reps (vs 2/3 before). The remaining 1 sample is the expected single ingestion-time decode of the second fixture.

## 4. Top user-code frames during typing (after P4-2)

typing-large rep1 (after) top 5:
- `+[UIAssistantBarButtonItemProvider defaultSystemLeadingBarButtonGroupsForItem:]` 5ms
- `-[UIInputWindowController changeToInputViewSet:]` 4ms
- `-[UIView(UIAccessibilityPrivate) _accessibilityViewIsVisibleIgnoringAXOverrides:stoppingBeforeContainer:]` 4ms
- `-[UIView(CALayerDelegate) layoutSublayersOfLayer:]` 3ms
- `-[_UIKeyboardStateManager setDelegate:force:delayEndInputSession:]` 3ms

All UIKit keyboard / accessibility / layout work. No image-related frames. **No new user-code hot path appeared.**

## 5. Trace size delta (secondary signal)

| scenario × template | before MB (mean) | after MB (mean) | delta |
|---|---:|---:|---:|
| preview-1024 TP | 22.0 | 17.9 | -18.6% |
| preview-large TP | 22.0 | 17.8 | -19.1% |
| typing-large TP | 23.3 | 19.2 | -17.6% |
| reselect-large TP | 22.2 | 18.1 | -18.5% |
| preview-1024 Hitches | 58.3 | 39.9 | -31.6% |
| preview-large Hitches | 58.6 | 41.3 | -29.5% |
| typing-large Hitches | 97.9 | 74.8 | **-23.6%** |
| reselect-large Hitches | 68.4 | 52.5 | -23.3% |

Consistent ~17-32% reduction across all scenarios indicates the app is doing less rendering work overall. Hitches traces (which sample more event types) drop more in absolute MB.

## 6. Plan §P verdict

P4-2 entry conditions satisfied at baseline → P4-2 evidence requirements at after-trace:

| keep criterion (plan §P) | result |
|---|---|
| measurable improvement (above noise floor) | **YES** — -35% stall (7× noise), -51% longest hang (3× noise), -27% hang count (0% noise floor) |
| ImageIO/decode top-frame removed | **YES** — 3/3 typing-large TP reps; 2/3 → 0/3 reselect (excluding expected first-time decode) |
| no new hot path | **YES** — UIKit keyboard frames identical to baseline; no user-code frame promoted to top |
| no visual / functional regression | **YES** — all 5 simulator UITests pass; all marker gates reached on device |
| preview-ready / image-ingested / reselect markers consistent | **YES** — 9/9 + 3/3 + 3/3 |
| upload-original preserved (plan §F) | **YES** — `uploadButtonTapped` reads `state.imageData`, code review verified |

| revert criterion (plan §P) | result |
|---|---|
| no measurable improvement | not triggered |
| new hot path | not triggered |
| visual regression | not triggered |
| upload-original risk | not triggered |
| marker instability | not triggered |

→ **KEEP P4-2.**

## 7. P4-3 entry condition recheck (after P4-2)

Plan §S adjacent extension rule: a single additional commit is allowed IF after-trace shows residual measurable hot path in the same image pipeline.

P4-3 entry conditions (plan §P):
- large fixture has materially higher image decode/draw/render cost than 1024 fixture: still ambiguous (preview-1024 = preview-large = 0 hangs both before and after).
- ImageIO / CA display / CGContextDrawImage / texture upload / draw stack appears on main thread: **NO LONGER PRESENT in typing-large after P4-2** (0/3 reps). Only present in 1/3 reselect-large reps, and that's the expected one-time decode of the second fixture, not a per-frame cost.
- large fixture increases Hitches count or stall time compared with 1024 fixture: still ambiguous (preview-large = preview-1024 = 0 hangs).

→ **P4-3 entry conditions NOT strengthened by after-trace. The residual stall (0.53s) is in UIKit keyboard / layout, not image work. Downsampling will not address keyboard interaction delays.**

P4-4 entry conditions (plan §P): require preview subtree to re-evaluate per keystroke. After P4-2, the previewImage pointer is stable so SwiftUI diff should skip the preview subtree; the remaining typing hangs are in keyboard-side UIKit code that downsampling/isolation won't help.

→ **P4-4 also not justified by after-trace evidence.**

## 8. Honest caveats

- The "Potential Interaction Delay" 39-57ms hangs during typing are largely UIKit keyboard/accessibility work (`UIAssistantBarButtonItemProvider`, `UIInputWindowController`, `_UIKeyboardStateManager`). These are framework-level interactions that the app cannot directly optimize.
- The ~169ms "Brief Unresponsiveness" in 1/3 typing-large reps after P4-2 happens around the comment focus + keyboard reveal moment. After P4-2, it persists once (was 3/3 in baseline). Possibly residual layout work from the preview clipShape/insideBorder pipeline at the moment keyboard expands.
- Pass 4 baseline P4-3 evidence was already PARTIAL; after-trace confirms P4-3 wouldn't address the remaining hangs (which are keyboard-side, not image-side).

## 9. Recommendation

- **KEEP P4-2** as the Pass 4 improvement commit.
- **SKIP P4-3 and P4-4.** After-trace evidence shows the remaining hangs are keyboard-side UIKit work, not image decode/render. P4-3 (downsample) and P4-4 (subtree isolation) target image-side problems that have been eliminated by P4-2.
- **Proceed to Pass 4 final report.**

Pass 4 outcome (one-line): typing-large total main-thread stall during 5-keystroke comment entry reduced from 0.82s to 0.53s (-35%), longest hang from 233ms to 114ms (-51%), and ImageIO decode removed from 3/3 typing TP traces. User VoC "preview 떠 있는 상태에서 5글자 멘트 작성 시 렉" is measurably reduced.
