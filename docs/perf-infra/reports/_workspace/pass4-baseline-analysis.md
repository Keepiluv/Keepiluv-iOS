# Pass 4 — baseline analysis (24 traces under `pass4-rendering-before`)

- **Date**: 2026-05-19
- **Baseline tag**: `pass4-rendering-before = cd989de`
- **Configuration**: PerfProfile (caveat: Pass 3 official = Profile; PerfProfile/PERF_TESTING introduced post-Pass 3 by `5d507fa`)
- **Device**: Jiyong의 iPhone (UDID `00008110-00096DC42632801E`, iOS 26.4.2)
- **Traces**: `/tmp/twix-perf-traces/pass4-before/proof-photo/`
- **Window**: 30s xctrace (Time Profiler + Animation Hitches), attached after `image-ingested.<source>` marker

## 1. Trace contamination

| metric | value |
|---|---|
| official traces | 24/24 |
| contamination per §2.4 (SpringBoard activate / BannerNotification / wait-springboard-idle / driver wall ±50% / xctrace mid-window error) | **0 / 24** |
| analyzer TOC export failure (intermittent; trace itself recorded) | 2/24 — `tp/preview-1024-rep1`, `hitches/reselect-large-rep1`, `hitches/reselect-large-rep3` are partially exportable; trace bundle present, hangs readable |
| typing marker `comment-text.abcde` reached | 3/3 (typing-large reps) |
| `preview-ready.true` marker reached | 9/9 (all preview/typing/reselect reps) |
| `image-ingested.fixture-large-second` reached | 3/3 (reselect reps) |
| `reselect.1` reached | 3/3 |

## 2. Time Profiler — top user-code / framework image stack inventory

| scenario | rep | TP window (s) | max frame ms | image decode/draw stacks in top-10? |
|---|---|---:|---:|---|
| preview-1024 | 1 | 4.73 (TOC export partial) | 3 | NO |
| preview-1024 | 2 | 5.93 | 3 | NO |
| preview-1024 | 3 | 6.08 | 2 | NO |
| preview-large | 1 | 5.94 | 3 | NO |
| preview-large | 2 | 5.38 | 3 | NO |
| preview-large | 3 | 5.76 | 2 | NO |
| typing-large | 1 | 7.11 | 15 | **YES** — `AppleJPEGReadPlugin::copyIOSurfaceImp` 3ms |
| typing-large | 2 | 7.09 | 14 | NO (in top 10) |
| typing-large | 3 | 7.51 | 16 | NO (in top 10) |
| reselect-large | 1 | 6.81 | 8 | NO |
| reselect-large | 2 | 7.48 | 8 | **YES** — `IIOImageProviderInfo::CopyIOSurface` 2ms + `AppleJPEGReadPlugin::copyIOSurfaceImp` 2ms |
| reselect-large | 3 | 7.59 | 9 | **YES** — `IIOImageProviderInfo::CopyIOSurface` 1ms |

Observations:
- ImageIO JPEG decode (`AppleJPEGReadPlugin::copyIOSurfaceImp`, `IIOImageProviderInfo::CopyIOSurface`) appears in framework stacks of **3/12 TP traces** (1/3 typing, 2/3 reselect). Magnitudes are small (1–3 ms) because the analyzer windows to active CPU and the decode is one-off per ingestion.
- Preview scenarios (both 1024 and large) show **no** image decode in top frames during the 6s idle. SwiftUI uses CA's lazy/deferred decode for off-screen ingestion; decode only triggers on display commit which here happens once before the idle window.
- typing-large traces have max frame ~14–16 ms (~1 frame at 60Hz) vs preview scenarios ~2–3 ms — a 5× increase in CPU activity per sampled function, consistent with interactive workload.

## 3. Animation Hitches — hang / interaction delay inventory

| scenario | reps with hangs | total hangs | longest hang | total stall | "Potential Interaction Delay" ≥40ms (per rep) |
|---|---|---:|---:|---:|---|
| preview-1024 | 0/3 | 0 | — | — | 0 |
| preview-large | 0/3 | 0 | — | — | 0 |
| typing-large | **3/3** | 15 + 15 + 15 = **45** | 193 / 269 / 236 ms | 0.78 + 0.86 + 0.81 = **2.45 s** | 10+ each rep |
| reselect-large | 2/3 (rep1 TOC export partial) | 1 + 1 = 2 | 42 / 42 ms | 0.04 + 0.04 s | 1 each |

Key observations:
- **Preview-only scenarios show zero hangs.** Image SIZE alone (1024 vs 4032×3024) does NOT produce hangs during static idle render.
- **typing-large is consistent 3/3 reps** with 15 hangs each + one "Brief Unresponsiveness" or "Microhang" in the 193–269 ms range (occurring within first ~0.8s, aligned with `commentCircle.tap()` → focus + keyboard reveal + layout pass that includes the full 4032×3024 preview).
- **10+ Potential Interaction Delays per typing rep** in the 39–57 ms range during the 5-keystroke window. Each keystroke triggers body re-eval through the `perfStateMarker(comment-text)` modifier, which causes SwiftUI to re-evaluate the entire `ZStack { mainContent; floatingCommentOverlay }`. The image branch of `photoPreview` is in that tree.
- **reselect produces a single ~42 ms interaction delay per rep** — the cost of swapping `state.imageData` and re-rendering the preview branch with new bytes.

## 4. Pass 4 noise floor (rep-to-rep coefficient of variation, n=3)

| metric | mean | std | CV% |
|---|---:|---:|---:|
| TP trace size (bytes-on-disk) | 22.0–23.3 MB | — | 0–0.26% |
| Hitches trace size | 58.3–97.9 MB | — | 2.1–8.1% |
| typing-large total stall (s) | 0.82 | 0.04 | **4.95%** |
| typing-large hang count | 15 | 0 | **0.00%** |
| typing-large longest hang (ms) | 232.67 | 38.11 | **16.38%** |
| TP analyzed-window duration (s) | 5.69 / 7.24 | 0.29 / 0.24 | 3.27 / 5.02% |

Pass 3 reference: ±10.4% rep-to-rep on total trace time.

Pass 4 noise floor:
- **Hang count: 0% CV** (very tight signal, n=15 hangs always per typing rep). Use this as the primary discriminator.
- **Total stall time: ~5% CV** (tight). A >10% reduction in total stall would be measurable.
- **Longest hang duration: ~16% CV** (loose). A reduction must exceed ~20% to be statistically meaningful at n=3 reps.

## 5. P4-2 / P4-3 entry-condition evaluation (per plan §P)

### P4-2 — preview decode out of body

Plan §P requires **at least one** of:

| evidence criterion | result |
|---|---|
| `UIImage(data:)` / `+[UIImage initWithData:]` / ImageIO stack in user-code top or framework stack | **YES** — `AppleJPEGReadPlugin::copyIOSurfaceImp` / `IIOImageProviderInfo::CopyIOSurface` in 3/12 TP traces |
| image decode/draw stack during 5-keystroke typing window | **YES** in 1/3 TP typing reps; the typing scenario has 30+ Potential Interaction Delays in 3/3 Hitches reps |
| decode/draw stack repeats in proportion to keystrokes | NO direct evidence — 2–3 decode samples per typing rep, not 5× |
| Animation Hitches shows image-related severe hang / standard hang / interaction delay | **YES** — 3/3 reps consistent, 15 hangs each, 0.82s total stall, 10+ interaction delays per rep. Absent in 0/3 preview-1024 and 0/3 preview-large |

→ **P4-2 entry condition SATISFIED** (3 of 4 criteria met; the 4th is missing only because we cannot count individual decode events at the analyzer's sample granularity).

### P4-3 — preview downsample

Plan §P requires **at least one** of:

| evidence criterion | result |
|---|---|
| large fixture has materially higher image decode/draw/render cost than 1024 fixture | **AMBIGUOUS** — preview-1024 (max 3ms) ≈ preview-large (max 3ms) in TP, both 0 hangs. But Pass 4 has no typing-1024 or reselect-1024 to compare against |
| ImageIO / CA display / CGContextDrawImage / texture upload / draw stack appears on main thread | **YES** — `AppleJPEGReadPlugin` is ImageIO |
| large fixture increases Hitches count or stall time compared with 1024 fixture | **AMBIGUOUS** — preview-large = preview-1024 = 0 hangs. Comparison incomplete for interaction scenarios |

→ **P4-3 entry condition PARTIAL**. One criterion (ImageIO on main thread) is met, but the size-dependent differential cannot be cleanly established with the current Pass 4 scenario set (we have only preview-1024 as the small-fixture baseline, not typing-1024 or reselect-1024).

→ **Recommendation: defer P4-3 until P4-2 after trace evidence shows whether residual decode/draw cost is size-dependent.** P4-2 alone may eliminate or reduce the typing-large hangs; the remaining cost (if any) then determines whether downsampling is needed.

### P4-4 — preview subtree isolation

Per plan §S, this only enters consideration if P4-2 or P4-3 KEEP. Defer pending P4-2 after trace.

## 6. Read of the user-VoC reproduction

The user's VoC ("preview가 떠 있는 상태에서 5글자 멘트 작성할 때 렉이 체감됨") is **directly reproduced and quantified** in the baseline:

- typing scenario with large preview: 3/3 reps, 15 hangs each, 30+ interaction delays >40ms, one "Brief Unresponsiveness" 193–269 ms (the focus-and-keyboard-appear moment).
- typing scenario without preview-fixture (could be inferred from Pass 3 1024 fixture; not directly in Pass 4 baseline): per Hitches inventory, the 4032 fixture's typing produces hangs absent in 4032 preview. This implicates the interaction × image rendering interaction, not the image alone.

## 7. Recommendation

**Proceed with P4-2** (preview decode out of body / decoded preview representation in state). Entry conditions satisfied. Expected effect: eliminate per-body-eval `UIImage(data:)` decode on the preview branch; the typing scenario's interaction delays should reduce or disappear.

**Defer P4-3** (downsample) until P4-2 after trace evidence shows residual size-dependent cost. The current Pass 4 baseline lacks a typing-1024 comparison to cleanly justify P4-3 entry independently.

**Defer P4-4** until P4-2/P4-3 outcomes are known.

Hitches measurements (hang count, total stall, interaction delay count) are the primary discriminator for P4-2 keep/skip decision. TP frame removal is secondary because the decode is intermittent in sampling.
