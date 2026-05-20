# Pass 4 — Rendering Optimization (final)

- **작성일**: 2026-05-20 (final: Pass 4-S3 closeout 시점)
- **Baseline tag**: `pass4-rendering-before` = `6fe027c`
- **Authoritative metric**: Xcode Instruments / xctrace (Time Profiler + Animation Hitches), iOS 26.4.2 device (Jiyong의 iPhone, UDID `00008110-00096DC42632801E`), **PerfProfile** configuration
- **Probe metric (보조)**: XCTest XCUI driver — driver/marker sanity 신호 (개선 evidence 아님)

이 리포트는 Pass 4 전체(ProofPhoto image pipeline + Pass 4-S app-wide SwiftUI Template audit + Pass 4-S2 Home self-run scroll + Pass 4-S3 Stats self-run scroll)의 최종 결과를 정리한다.

---

## 1. Executive summary

### 1.1 Sub-track outcomes

| sub-track | 결과 | production commit | 핵심 수치 |
|---|---|---|---|
| Pass 4 ProofPhoto image pipeline (P4-2) | **KEEP** | `bb33235` | typing-large total stall `0.82s → 0.53s` (-35%), longest hang `233ms → 114ms` (-51%), TP ImageIO/JPEG decode top-frame **3/3 reps 제거** |
| Pass 4 ProofPhoto P4-3 (downsample) | **SKIP** | — | P4-2 적용 후 ImageIO frame이 typing TP에서 0/3로 사라짐. 남은 stall은 keyboard-side UIKit |
| Pass 4 ProofPhoto P4-4 (subtree isolation) | **SKIP** | — | image subtree re-render 문제가 P4-2로 해결됨 |
| Pass 4-S App-wide SwiftUI Template Audit (idle scenarios) | **closed — inventory only** | (no production commit) | launch-mode tooling validated; attach-mode 0-row limitation confirmed; 21 idle traces + 8-candidate inventory; C3 (TXCalendarDateCell) + C4 (GoalDetailView) SKIPPED on idle gates |
| Pass 4-S2 Home self-run scroll (H-C2-a) | **KEEP** | `d3f66be` | swiftui-updates -41%, GoalCardView.body events -94%, Animation Hitches `0/2/4 → 0/0/0` (-100%), 133.34 ms severe hitch eliminated, "37 offscreen passes" narrative eliminated, 8/8 UITests pass |
| Pass 4-S3 Stats self-run scroll (H-C5-a) | **REVERT** | `405dc38` (reverted by `73f4a00`) | swiftui-updates -15% (KEEP target ≥30% missed); Animation Hitches `4/1/2 → 3/4/4` (+60%, REVERT trigger); "Potentially expensive app update(s)" narrative reproducibility unchanged 3/3 |

### 1.2 Methodology validation

- **SwiftUI Template launch-mode**: validated as a candidate-discovery layer for self-loading and self-run-able scenarios. Captures `swiftui-updates` / `swiftui-causes` / `swiftui-changes` / `swiftui-update-groups` with real row data and correct target-process attribution.
- **SwiftUI Template attach-mode**: 0-row tooling limitation re-confirmed (Pass 3 finding reproduced under Xcode 26.0 / iOS 26.4.2). Driver-required XCUITest interactions cannot be attributed at the SwiftUI layer.
- **Authoritative metric remains Time Profiler + Animation Hitches.** SwiftUI Template counts are candidate-discovery only; production change requires TP + Hitches before/after gate. Proven in both directions on this codebase: Pass 4-S2 H-C2-a (kept — SwiftUI signal + TP + Hitches all moved) and Pass 4-S3 H-C5-a (reverted — SwiftUI signal moved but TP + Hitches did not corroborate).

### 1.3 One-line summary

Pass 4는 두 production optimization을 성공 (ProofPhoto P4-2 — typing total stall -35%, longest hang -51%; Home H-C2-a — Animation Hitches `0/2/4 → 0/0/0`, 133 ms severe hitch eliminated), 한 production hypothesis는 gate-and-revert (Stats H-C5-a — SwiftUI count는 움직였으나 Hitches가 오히려 상승), 그리고 SwiftUI Template launch-mode self-run methodology를 양방향으로 검증하면서 종결했다. SwiftUI Template counts alone never justify a production change — TP + Animation Hitches가 authoritative이다.

---

## 2. Scope / Inputs from Pass 3 / Out of scope

### 2.1 What was measured (Pass 4)

| 영역 | Scheme | 시나리오 | seed |
|---|---|---|---|
| ProofPhoto | `FeatureProofPhotoExample` | preview render (1024 procedural) | `proof-photo-prefilled` |
| ProofPhoto | `FeatureProofPhotoExample` | preview render (large 4032×3024 bundled JPEG) | `proof-photo-prefilled-large` |
| ProofPhoto | `FeatureProofPhotoExample` | comment typing 5 chars (large fixture) | `proof-photo-prefilled-large` |
| ProofPhoto | `FeatureProofPhotoExample` | image reselect (large fixture A → large fixture B) | `proof-photo-prefilled-large` |

4 scenarios × 2 templates (Time Profiler + Animation Hitches) × 3 reps = **24 traces** per (before / after) collection.

### 2.2 Inputs from Pass 3 (확정)

| Pass 3 commit | 결정 |
|---|---|
| Commit 3 (Home read-set split) | KEEP — structural cleanup |
| Commit 4 (destination/presentation scoping) | SKIP/HOLD |
| Commit 5 (`goalSectionTitle`/`nowDate` stored) | SKIP |
| Commit 6 (Home card / GoalCardView input stability) | investigated and skipped |
| Commit 7 (GoalDetail TimelineView idle guard) | KEEP — idle CPU 카테고리 |

Pass 3의 측정 규칙(authoritative=trace, probe-only=XCTest, noise floor 재계산, 1 commit = 1 hypothesis, §2.4 contamination 정책) 그대로 적용.

### 2.3 Out of scope

- **SwiftUI Template app-wide audit**: 본 Pass에서는 분리되어 `Pass 4-S`로 이관 (§7).
- **GoalDetail / Stats / Settings** 추가 최적화: evidence-gated 유지, Pass 4 baseline에서 진입 조건 미충족.
- **ProofPhoto upload networking**: pre-upload local image pipeline + UI rendering에 한정.
- **Auth / Onboarding**: VoC 우선순위 아님.

### 2.4 Configuration caveat (중요)

Pass 3 official traces는 **`Profile`** configuration으로 수집되었다 (`docs/perf-infra/reports/2026-05-18-render-pass-3.md:6`). Pass 3 이후 commit `5d507fa` (2026-05-19)가 `PerfProfile` configuration + `#if PERF_TESTING` gating을 도입했고, 현재 HEAD에서 `Profile`로 빌드하면 모든 perf marker가 컴파일 아웃된다. Pass 4 official traces는 **PerfProfile** configuration으로 수집되었다.

→ Pass 4 개선 수치는 모두 `pass4-rendering-before` (PerfProfile) vs Pass 4 after (PerfProfile) 비교만 인용한다. Pass 3 `Profile` traces와 Pass 4 `PerfProfile` traces를 **동일 workload의 성능 evidence**로 직접 비교하지 않는다.

### 2.5 Workload caveat

Pass 4 large fixture는 4032×3024 / 7.46 MiB JPEG로, Pass 3 ProofPhoto baseline의 1024×1024 / 1024-class procedural fixture와 **다른 workload**다.

| metric | Pass 3 fixture | Pass 4 large fixture | delta |
|---|---:|---:|---:|
| pixel count | 1,048,576 | 12,192,768 | **+1063%** |
| decoded bitmap footprint estimate | ~4.0 MiB | ~46.5 MiB | **+11.6×** |
| JPEG byte size | ~150 KB (procedural) | 7.46 MiB | **+50×** |

→ "Pass 3 ProofPhoto ms → Pass 4 large fixture ms improved by N%" 같은 동일-workload 직접 비교는 **금지**. Pass 4 개선 주장은 `pass4-rendering-before` vs Pass 4 after에 한정.

---

## 3. Measurement infrastructure (Pass 4 변경분만)

### 3.1 P4-0 commit (`6fe027c`)

- **Bundled fixtures** (`Projects/Feature/ProofPhoto/Example/Resources/`):
  - `proof-photo-prefilled-large.jpg` — 7,826,161 bytes (7.46 MiB), SHA-256 `e7a11b…`
  - `proof-photo-prefilled-large-second.jpg` — 7,825,685 bytes (7.46 MiB), SHA-256 `5c54ea…`
  - 둘 다 4032×3024 / q=0.85 / deterministic xorshift-derived per-pixel noise + diagonal banding + gradient. 두 파일은 byte 단위로 다름 (reselect가 실제 image 교체임을 증명).
- **Generator script**: `Scripts/generate-proof-photo-large-fixture.swift` — `swift Scripts/generate-proof-photo-large-fixture.swift` 한 번이면 두 fixture를 deterministic하게 재생성.
- **Tuist helper 변경**: `Tuist/ProjectDescriptionHelpers/Target/Target+Feature.swift`의 example target resources path를 `Resources/**` → `Example/Resources/**`로 변경. Example target에만 영향, 다른 Example target에는 현재 `Example/Resources/`가 없으므로 동작 변화 없음.
- **신규 seed**: `proof-photo-prefilled-large` (1024 시드는 그대로 유지).
- **신규 시나리오** (`ProofPhotoExampleRenderingTests`):
  - `testRendering_proofPhotoPreviewWithLargeFixtureImage`
  - `testRendering_proofPhotoCommentTypingWithLargeFixtureImage`
  - `testRendering_proofPhotoReselectFixtureImage`
- **신규 markers** (모두 `#if PERF_TESTING` gated):
  - `feature.proof-photo.marker.image-ingested.{fixture|fixture-large|fixture-large-second}` — App layer에서 `store.send(.galleryPhotoLoaded)` 직후 emit
  - `feature.proof-photo.marker.preview-ready.{true|false}` — P4-0에서는 `store.hasImage`, **P4-2 commit에서 `store.previewImage != nil`로 semantics 강화** (plan §D)
  - `feature.proof-photo.marker.reselect.<count>` — App layer @State, `.onChange(of: store.imageData)`에서 old/new 둘 다 non-nil일 때 증가
- **Test harness**: ExampleHost에 hidden Color.clear 44×44 overlay (accessibilityIdentifier `feature.proof-photo.test.reselect-button`) 추가. tap 시 production `.galleryPhotoLoaded(imageData: secondFixture)` dispatch. test-only state setter 아님 (plan §E).

### 3.2 Trace output layout

- before: `/tmp/twix-perf-traces/pass4-before/proof-photo/{timeprofiler,hitches}/<scenario>-rep<N>.trace`
- after (P4-2): `/tmp/twix-perf-traces/pass4-after/p4-2-preview-decode-out-of-body/proof-photo/{timeprofiler,hitches}/<scenario>-rep<N>.trace`

### 3.3 Recording recipe (Pass 3와 동일 구조, configuration만 PerfProfile)

```bash
xcodebuild test-without-building \
  -workspace Twix.xcworkspace \
  -scheme FeatureProofPhotoExample \
  -configuration PerfProfile \
  -destination 'platform=iOS,id=00008110-00096DC42632801E' \
  -only-testing:FeatureProofPhotoExampleUITests/ProofPhotoExampleRenderingTests/<testMethod> \
  >"$LOG" 2>&1 &
UITEST_PID=$!

# Wait for marker gate (ready / image-ingested.<source>) so fixture
# loading completes before xctrace window opens.
until grep -qE "<markerpat>" "$LOG"; do sleep 1; done

xcrun xctrace record \
  --device 00008110-00096DC42632801E \
  --template '<Time Profiler|Animation Hitches>' \
  --time-limit 30s \
  --attach FeatureProofPhotoExample \
  --output "$TRACE_PATH"

wait $UITEST_PID
```

Window: **30s** for both templates (decision: dry-run showed all scenarios ≤20s driver wall; longer windows mostly captured idle tail and bloat Hitches traces).

---

## 4. Pass 4 baseline (`pass4-rendering-before` = `6fe027c`)

### 4.1 Collection results

| metric | value |
|---|---|
| official traces | **24/24** |
| contamination per §2.4 (SpringBoard activate / banner / wait-idle / wall ±50% / xctrace mid-window error) | **0/24** |
| analyzer TOC export partial failure (intermittent xctrace bug; trace bundles valid) | 3/24 (`tp/preview-1024-rep1`, `hitches/reselect-large-rep1`, `hitches/reselect-large-rep3`) |
| typing marker `comment-text.abcde` reached | 3/3 reps |
| `preview-ready.true` marker reached | 9/9 reps |
| `image-ingested.fixture-large-second` reached | 3/3 reselect reps |
| `reselect.1` reached | 3/3 reselect reps |
| host /tmp free space (start of collection) | 128 GB |
| device iOS / UDID | iOS 26.4.2 / `00008110-00096DC42632801E` |
| environment (DND ON / charge / Low Power OFF / unlocked) | confirmed |

Fixture loading cost stays out of trace window because xctrace attaches **after** `image-ingested.<source>` marker fires.

### 4.2 Pass 4 noise floor (rep-to-rep CV, n=3, computed from baseline)

| metric | mean | std | CV% |
|---|---:|---:|---:|
| TP trace size MB | 22.0–23.3 | — | 0–0.26 |
| Hitches trace size MB | 58.3–97.9 | — | 2.1–8.1 |
| typing-large total stall (s) | 0.82 | 0.04 | **4.95** |
| typing-large hang count | 15.00 | 0.00 | **0.00** |
| typing-large longest hang (ms) | 232.67 | 38.11 | **16.38** |
| TP analyzed-window duration (s) | 5.69 / 7.24 | 0.29 / 0.24 | 3.27 / 5.02 |

Pass 3 참고치: ±10.4% rep-to-rep on total trace time. Pass 4의 stall 기반 지표는 더 tight (4.95%) — image-pipeline 변경은 stall 지표에서 ≥10% 변화를 만들어야 측정적으로 유의미.

### 4.3 Baseline top-frame inventory (Time Profiler)

| scenario | rep | TP window (s) | max frame ms | image decode/draw stacks in top-10? |
|---|---:|---:|---:|---|
| preview-1024 | 1 | 4.73 (TOC partial) | 3 | NO |
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

→ ImageIO JPEG decode가 framework stack에 3/12 TP traces에서 등장.

### 4.4 Baseline Hitches inventory

| scenario | reps with hangs | total hangs | longest hang | total stall | "Potential Interaction Delay" ≥40ms |
|---|---|---:|---:|---:|---|
| preview-1024 | 0/3 | 0 | — | — | 0 |
| preview-large | 0/3 | 0 | — | — | 0 |
| typing-large | **3/3** | 45 | 193 / 269 / 236 ms | 2.45 s | 10+ each rep |
| reselect-large | 2/3 (rep1 TOC partial) | 2 | 42 / 42 ms | 0.08 s | 1 each |

핵심 관찰:
- **Preview-only scenarios (1024 + large) → 0 hangs.** 이미지 SIZE 자체는 hang을 만들지 않음.
- **typing-large → 3/3 reps 일관**, 15 hangs/rep, "Brief Unresponsiveness" 193–269 ms (`commentCircle.tap()` 직후 focus + keyboard reveal moment), 10+ Potential Interaction Delays per rep.
- 사용자 VoC가 정량 재현됨.

### 4.5 P4-2 entry condition 충족 (plan §P, baseline 단계)

| 기준 | 결과 |
|---|---|
| `UIImage(data:)` / ImageIO stack in user-code top or framework stack | **YES** (3/12 TP traces) |
| decode/draw stack during typing window | **YES** (1/3 TP typing reps) |
| decode/draw stack repeats per keystroke | NO direct evidence (sampling granularity 한계) |
| Animation Hitches image-related interaction delay | **YES** (3/3 typing reps consistent) |

→ 3 of 4 → **P4-2 entry SATISFIED**.

---

## 5. P4-2 — preview decode out of body (KEEP, `bb33235`)

### 5.1 Hypothesis & change

**Hypothesis**: `ProofPhotoView.swift:139`의 `UIImage(data: imageData)`가 `@ViewBuilder photoPreview` 안에서 body re-eval마다 재호출된다. `ProofPhotoView.swift:74-78`의 top body `perfStateMarker(comment-text, value: store.commentText)`가 keystroke마다 top body re-eval을 강제하므로, typing 중 preview branch가 반복 evaluate되어 (lazy decode가 layer commit path에서 다시 decode를 trigger할 수 있는) ImageIO 작업이 main thread에서 반복된다.

**Change**:
- `ProofPhotoReducer.State.previewImage: UIImage?` 추가 — ingestion time에 한 번 decode 후 보관.
- `.galleryPhotoLoaded(imageData:)` / `.captureCompleted(imageData:)`: `state.imageData = imageData; state.previewImage = UIImage(data: imageData)`.
- `.returnButtonTapped` / `.binding(\.selectedPhotoItem)` nil branch: 둘 다 clear.
- `ProofPhotoView.photoPreview`: `if let image = store.previewImage` (production code에서 `UIImage(data:)` 호출 제거).
- `preview-ready.<true|false>` marker semantics를 `store.previewImage != nil`로 강화 (plan §D).

### 5.2 Upload-original preservation (plan §F)

- `uploadButtonTapped` reducer branch는 계속 `state.imageData`를 읽음 → `ImageUploadOptimizer.optimizedJPEGData(from: imageData)` → `photoLogClient.uploadImageData(...)`.
- `editedImageData` delegate param도 그대로 `imageData` 전달.
- `state.previewImage`는 upload 경로 어디에서도 읽지 않음 — 코드 리뷰 확인.

### 5.3 Risk discussion (plan §G)

`UIImage`는 reference type. auto-derived `Equatable` on State는 NSObject 포인터 동등성을 사용. `previewImage`는 ingestion당 한 번 set되고 클리어/재ingestion 전까지 포인터 안정 → State equality 안정 → observation churn 없음. `UIImage`는 iOS 17+에서 `Sendable`. State에 이미 `AVCaptureSession?` (reference type)가 있어 동일 패턴.

### 5.4 Smoke verification

| step | result |
|---|---|
| `tuist generate --no-open` | success |
| PerfProfile/iphonesimulator build | success |
| Profile/iphonesimulator build (compile-only) | success |
| All 5 `ProofPhotoExampleRenderingTests` on simulator (PerfProfile) | **5/5 passed** (including existing testRendering_proofPhotoCommentTyping with 1024 fixture) |
| Device dry-run of typing-large with marker gate | success, all markers reached |
| Pre-existing Profile-smoke note | `ProofPhotoExampleSmokeTests` fails under Profile because `perfReadyMarker` is `#if PERF_TESTING` (pre-existing condition from `5d507fa`, verified via `git stash` — **not** introduced by P4-2) |

### 5.5 After-trace collection

| metric | value |
|---|---|
| official traces | **24/24** |
| contamination | **0/24** |
| analyzer TOC partial | 4/24 (analyzer race; trace bundles valid) |
| typing marker `comment-text.abcde` reached | 3/3 reps |
| `preview-ready.true` (decoded-rep semantics) reached | 9/9 reps |
| `image-ingested.fixture-large-second` reached | 3/3 reps |
| `reselect.1` reached | 3/3 reps |

### 5.6 Before/after numeric tables

#### typing-large Hitches (primary metric)

| metric | before mean ± std | after mean ± std | delta | vs noise floor |
|---|---:|---:|---:|---|
| hang count per rep | 15 ± 0 | 11.0 ± 1.0 | **-26.7%** | CV=0% before; -4 hangs is large |
| total main-thread stall (s) | 0.82 ± 0.04 | 0.53 ± 0.03 | **-35.1%** | ~7× noise floor (4.95%) |
| longest single hang (ms) | 232.67 ± 38.11 | 114.00 ± 49.00 | **-51.0%** | ~3× noise floor (16.38%) |
| Brief Unresponsiveness ≥150ms incidence | 3/3 reps (193, 269, 236 ms) | 1/3 reps (169 ms only) | **-67%** | clear |
| Potential Interaction Delay 39–57ms count | 10+ each rep, 30+ total | 9–11 each rep, ~30 total | similar count, slightly lower per-event magnitude | within range |

#### typing-large Time Profiler

| rep | before — ImageIO in top-10? | after — ImageIO in top-10? |
|---|---|---|
| 1 | **YES** (`AppleJPEGReadPlugin::copyIOSurfaceImp` 3ms) | **NO** |
| 2 | NO | NO |
| 3 | NO | NO |

→ ImageIO/JPEG decode frame이 typing TP top-frame에서 **0/3 reps**로 완전 제거.

#### preview-1024 / preview-large (regression check)

| scenario | metric | before | after |
|---|---|---|---|
| preview-1024 | hangs / reps | 0/3 | 0/3 |
| preview-large | hangs / reps | 0/3 | 0/3 |
| preview-large | TP max frame ms | 3 | 2 |
| preview-large | ImageIO in top-10 | 0/3 | 0/3 |

→ regression 없음.

#### reselect-large

| metric | before | after |
|---|---|---|
| hangs / reps | 1, 1 (rep2/3), rep1 TOC partial | 0/1/2 (rep1 TOC partial), 1, 2 |
| longest hang ms | 42, 42 | 41, 47 |
| TP ImageIO in top-10 | 2/3 (rep2/3) | **1/3** (rep1 — 두 번째 fixture의 expected ingestion-time decode 1회) |

→ reselect의 ingestion-time decode 1회는 design상 예상되는 비용. per-frame 비용은 사라짐.

#### Trace size delta (secondary signal)

| scenario × template | before MB | after MB | delta |
|---|---:|---:|---:|
| preview-1024 TP | 22.0 | 17.9 | -18.6% |
| preview-large TP | 22.0 | 17.8 | -19.1% |
| typing-large TP | 23.3 | 19.2 | **-17.6%** |
| reselect-large TP | 22.2 | 18.1 | -18.5% |
| preview-1024 Hitches | 58.3 | 39.9 | -31.6% |
| preview-large Hitches | 58.6 | 41.3 | -29.5% |
| typing-large Hitches | 97.9 | 74.8 | **-23.6%** |
| reselect-large Hitches | 68.4 | 52.5 | -23.3% |

전 시나리오에서 17–32% 일관 감소 → 앱이 전체적으로 렌더링 일을 덜 함.

#### Decoded bitmap footprint (estimated)

P4-2는 downsampling이 아니므로 **decoded bitmap footprint는 변하지 않음**. 단 decode 횟수가 줄어들기 때문에 ingestion-time decode 1회의 ~46.5 MiB만 유지된다는 차이가 있다. 정확한 메모리 측정은 본 trace template로 직접 수집하지 않음.

### 5.7 Keep/revert criteria result (plan §P)

| keep criterion | result |
|---|---|
| measurable improvement (above noise floor) | **YES** (-35% stall ≈ 7σ, -51% longest hang ≈ 3σ, -27% hang count vs 0% noise) |
| ImageIO/decode top-frame removed | **YES** (3/3 typing-large TP reps) |
| no new hot path | **YES** (UIKit keyboard frames identical to baseline) |
| no visual / functional regression | **YES** (5/5 simulator UITests, all marker gates 9/9 + 3/3 + 3/3 on device) |
| preview-ready / image-ingested / reselect markers consistent | **YES** |
| upload-original preserved | **YES** (code review verified) |

| revert criterion | result |
|---|---|
| no measurable improvement | not triggered |
| new hot path | not triggered |
| visual regression | not triggered |
| upload-original risk | not triggered |
| marker instability | not triggered |

→ **KEEP P4-2.**

---

## 6. P4-3 / P4-4 — SKIP

### 6.1 P4-3 (preview downsample) — SKIP

**Baseline 단계 (plan §P entry)**: PARTIAL — ImageIO이 main thread에 등장(YES)했지만 size-dependent 차이(preview-large vs preview-1024)는 모호함(둘 다 0 hangs).

**After-trace 재평가**: P4-2 적용 후 typing-large TP에서 ImageIO frame이 **0/3 reps로 사라짐**. 남은 stall은 framework keyboard 영역:
- `UIAssistantBarButtonItemProvider`
- `UIInputWindowController`
- `_UIKeyboardStateManager`
- `UIView _accessibilityViewIsVisibleIgnoringAXOverrides`

→ Downsample은 이미지 픽셀 워크로드를 줄이는 최적화인데, **남은 stall은 image pixel 워크로드 비용이 아니다**. P4-3을 적용해도 keyboard interaction delay를 해결할 수 없음. **SKIP.**

reselect의 1/3 ImageIO 잔여는 두 번째 fixture의 expected one-time decode이며 per-frame 비용이 아님.

### 6.2 P4-4 (preview subtree isolation) — SKIP

**원래 의도**: typing 중 preview branch가 반복 re-eval/re-decode되는 SwiftUI diff 비용을 줄이기 위해 `photoPreview`를 Equatable-input only `View struct`로 추출.

**After-trace 평가**: P4-2 commit의 `previewImage` 포인터 안정성으로 SwiftUI Equatable check가 preview subtree를 자동으로 skip하게 됨. typing TP에서 image-related frame이 사라졌으므로 **추출의 측정 가능한 잔여 효과가 없다**. Pass 3 Commit 6과 동일한 함정(EquatableView 류는 stale UI risk만 더하고 measurable upside 없음). **SKIP.**

### 6.3 Pass 4 extension rule (plan §S) 적용 결과

Plan §S는 P4-2 또는 P4-3 KEEP 후 ProofPhoto image pipeline 인접 영역에서 1회 추가 commit을 허용한다. 단 조건은:
- 잔존 hot path가 같은 image pipeline 인접 영역.
- 잔존 hot path가 측정 가능한 비중.
- 변경 범위 작고 risk 명시 가능.

After-trace 결과 잔존 hot path는 **image pipeline 영역이 아니라 framework keyboard 영역**이다. plan §S "ProofPhoto trace evidence 없이 GoalDetail/Stats/Home으로 확장" 금지는 여기서 확장 trigger가 없음을 의미한다.

→ Pass 4 extension rule 미발동. **Pass 4 ProofPhoto track 종결.**

---

## 7. SwiftUI Template — final status

Pass 4 진행 중 SwiftUI Template 검증을 ProofPhoto P4-2/P4-3/P4-4의 entry gate처럼 다뤘는데 이는 잘못된 분류였다. SwiftUI Template은 ProofPhoto-specific optimization step이 아니라 **App-wide candidate-discovery layer**다.

**Final outcome** (Pass 4-S / S2 / S3 종합):
- **Launch-mode validated** (Pass 4-S retry, commit `d35efec`): `xcrun xctrace --template SwiftUI --launch -- <bundle-id>` + UITest args가 self-loading 시나리오에 대해 `swiftui-updates` / `swiftui-causes` / `swiftui-changes` / `swiftui-update-groups`를 실제로 채운다. 2/2 reps reproducible. Target attribution은 launched feature app process.
- **Self-run path validated** (Pass 4-S2, S3): launch-mode 내부에서 reducer action 또는 public SwiftUI API (`ScrollViewProxy.scrollTo`)로 self-run interaction을 실행하면 interactive scroll/typing의 SwiftUI rows를 capture할 수 있다. 이는 XCUITest attach-mode가 0 rows를 반환하는 한계의 우회로다.
- **Attach-mode 0-row limitation re-confirmed** (Pass 4-S audit, Pass 4-S retry, current device/OS): XCUITest driver가 app을 띄운 뒤 `xctrace --attach`하면 SwiftUI tables의 schema는 보이나 rows는 모두 0. Pass 3 finding을 Xcode 26.0 / iOS 26.4.2에서 재현. Driver-required interaction은 SwiftUI Template attribution 대상이 아니다.
- **Authoritative evidence remains Time Profiler + Animation Hitches.** SwiftUI Template counts alone never justify a production change. 본 Pass에서 양방향으로 검증됨:
  - **Positive (Pass 4-S2 H-C2-a, KEPT)**: SwiftUI 신호 -41%, TP `GoalCardView.body.getter` 2/3 reps에서 top-10 제거, Hitches `0/2/4 → 0/0/0`. 모든 layer corroborated → production-valid.
  - **Negative (Pass 4-S3 H-C5-a, REVERTED)**: SwiftUI `LazySubviewPlacements<LazyVGridLayout>` events `0`까지 떨어졌으나 (mechanism worked), Hitches count는 오히려 `2.3 → 3.67` 상승 (+60%) AND "Potentially expensive app update(s)" narrative reproducibility는 `3/3` 그대로 유지. 즉 **moved counts but not real cost** → revert.

이 contract — "SwiftUI Template counts → candidate discovery only; TP + Animation Hitches → authoritative" — 는 Pass 4-S2 closeout (`d015879`)에 명시되어 있고, Pass 4-S3가 negative example로 검증했다.

§8에서 sub-track별 상세 결과 기재.

---

## 8. Pass 4 sub-tracks (completed)

### 8.1 Pass 4-S — App-wide SwiftUI Template Audit (CLOSED, inventory-only)

**Outcome**: launch-mode tooling validated; attach-mode 0-row limitation confirmed; 21 launch-mode idle traces collected across 7 scenarios; 8-candidate inventory produced. Idle gates: C3 (TXCalendarDateCell) and C4 (GoalDetailView) **SKIPPED** at TP+Hitches gate — both below noise floor on idle scenarios.

Key commits:
- `e6274bd docs(perf): record Pass 4-S SwiftUI Template app-wide audit`
- `e1ee57b docs(perf): record Pass 4-S C3 TXCalendarDateCell gate and skip`
- `c488fe3 docs(perf): record Pass 4-S C4 GoalDetailView gate, skip, and closeout`

Self-run feasibility extension:
- `d35efec perf(infra): validate SwiftUI Template self-run interaction capture` — Pass 4-S retry, ProofPhoto state-driven self-run via reducer actions. Validated the methodology that Pass 4-S2 / S3 then used.

Result doc: `pass4-s-swiftui-template-audit.md`, `pass4-s-c3-txcalendardatecell.md`, `pass4-s-c4-goaldetailview.md`, `pass4-s-closeout.md`, `pass4-s-selfrun-swiftui-template-feasibility.md`.

### 8.2 Pass 4-S2 — Home self-running scroll (KEPT, production fix)

**Outcome**: H-C2-a (GoalCardView outside-border render duplication) KEPT. The first Pass 4-S candidate to survive **all three** gate layers — SwiftUI Template + Time Profiler + Animation Hitches — simultaneously.

Headline numbers (3 reps mean, before vs after):

| metric | before | after | delta |
|---|---:|---:|---:|
| `swiftui-updates` | 204,598 | 121,310 | **-40.7 %** |
| `View Body Updates` | 6,892 | 2,245 | -67.4 % |
| `GoalCardView.body` events | 2,642 | 166 | **-93.7 %** |
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` events | 1,709 | 918 | -46 % |
| Animation Hitches rows | 0 / 2 / 4 | **0 / 0 / 0** | **-100 %** |
| `GoalCardView.body.getter` in TP top-10 | 2 / 3 | 0 / 3 | eliminated |
| 133.34 ms severe hitch | 1 / 3 | 0 / 3 | eliminated |
| "37 offscreen passes" narrative | 1 / 3 | 0 / 3 | eliminated |
| `FeatureHomeExampleUITests` | — | 8 / 8 pass | clean |

Root-cause fix (single file): replaced shared `outsideBorder(...)` modifier usage in GoalCardView with local `.background { RoundedRectangle.stroke(lineWidth * 2) }`. The shared modifier's `overlay(shape.stroke.overlay(self))` re-renders the entire subtree under the stroke layer; the local replacement avoids the duplicated composition while preserving identical visible outside border.

Key commits: `b325943` (harness + before-gate), `d3f66be` (production fix), `68e2cb9` (after-gate KEEP), `d015879` (closeout).
Result doc: `pass4-s2-home-selfrun-scroll-result.md`, `pass4-s2-h-c2-a-comparison.md`, `pass4-s2-closeout.md`.

### 8.3 Pass 4-S3 — Stats self-running scroll (gate-and-revert)

**Outcome**: H-C5-a (LazyVGrid → eager VStack of HStack rows) **REVERTED**. The methodology contract working in reverse — SwiftUI Template signal moved but TP + Animation Hitches did NOT corroborate.

Investigation steps:
- C5 baseline gate: 3-AND failed on TP criterion #2 (no Stats user-code in TP top-10; cumulative scroll framework < 1 % of trace). SwiftUI signal ~641 K updates/rep, 3/3 reproducible within 0.2 %.
- Ablation A (ABLATE_STAMP_GRID): -69 % swiftui-updates, "Potentially expensive app update(s)" narrative `3/3 → 0/3`. Confirmed cost SOURCE is the stamp grid, but over-removal (hides UI).
- Ablation B (ABLATE_TXVECTOR): -10 % swiftui-updates only. Ruled out TXVector content as primary cost. **Root cause = LazyVGrid container / ForEach placement work**, not TXVector content.
- H-C5-a after-gate (3 SwiftUI + 3 TP + 3 Hitches reps):
  - `swiftui-updates`: 641,276 → 545,597 (**-15 %**, KEEP target ≥ 30 % MISS).
  - `LazySubviewPlacements<LazyVGridLayout>` events → **0** (mechanism worked).
  - Animation Hitches count: `4/1/2 → 3/4/4` (+60 % per rep mean, REVERT criterion triggered).
  - "Potentially expensive app update(s)" narrative reproducibility unchanged at 3/3.
  - TP framework self-time ~unchanged; cost moved from `LazyVGridLayout` (SwiftUI-visible) to `Layout.makeDynamicView` + `_VStackLayout` / `_HStackLayout` (TP-framework-visible).
- Production commit `405dc38` reverted by `73f4a00`. Post-revert smoke `FeatureStatsExampleUITests` TEST EXECUTE SUCCEEDED.

**Interpretation**: The "single inner container swap" hypothesis class is exhausted. The real cost concentration is at the cell-composition level (every visible cell re-composes its full subtree on materialization), not at the inner-container level. C5 status: **deferred with gate-and-revert outcome** — not permanently closed; larger-scope hypothesis classes (Equatable on StatsCardView / cell-content reduction / cell-pool / cell-snapshot caching) remain available but require fresh plan + explicit user approval.

Key commits: `55047c2` (plan), `a4a14c5` (harness, kept), `28adce3` (ablation attribution + DEFER), `c842d7e` (H-C5-a plan), `405dc38` (H-C5-a production attempt, **reverted**), `9a0351d` (after-gate REVERT verdict), `73f4a00` (revert), `88ae481` (revert + smoke confirmation), `d3e1bf9` (closeout).
Result doc: `pass4-s3-stats-selfrun-scroll-plan.md`, `pass4-s3-stats-selfrun-scroll-result.md`, `pass4-s3-h-c5-a-plan.md`, `pass4-s3-h-c5-a-after-gate.md`, `pass4-s3-closeout.md`.

### 8.4 Keyboard / focus UX investigation (image pipeline 범위 밖)

Pass 4 P4-2 after-trace의 잔여 stall은 framework keyboard 영역. 다음 stack이 typing scenario의 main thread를 점유:
- `UIAssistantBarButtonItemProvider`
- `UIInputWindowController` / `_UIKeyboardStateManager`
- `UIKeyboardCache displayImagesForView:fromLayout:imageFlags:`
- `UISystemKeyboardDockController`
- `UIView _accessibilityViewIsVisibleIgnoringAXOverrides`

이것은 image pipeline 문제가 아니라 keyboard / accessibility framework 문제이며 production 코드 단에서 직접 최적화하기 어려움. 후보 조사로만 기록.

### 8.5 Secondary candidates — status updates from Pass 4-S / S2 / S3

- **GoalDetail rapid-fire / initial**: Pass 4-S audit C4 (GoalDetailView initial-reactionbar idle scenario) was gated and SKIPPED at TP+Hitches noise floor. Interactive scenarios remain attributable only via TP + Animation Hitches (the SwiftUI Template attach-mode 0-row limitation prevents idle-style discovery here). No production action.
- **Stats heavy scroll**: Pass 4-S3 fully investigated. Ablation isolated LazyVGrid container/ForEach placement as root cause; H-C5-a (one-file inner-container swap) failed its gate and was reverted. C5 deferred with gate-and-revert outcome. See §8.3 and Pass 5 handoff for what classes of hypothesis remain.
- **Settings nickname**: loading-delay / probe-only 분류 유지. UI Rendering 결론에 인용 금지.

### 8.6 Pass 3 deferred items (변화 없음)

- Home / GoalCardView input stability: trace evidence 없으면 revive 금지. Pass 4-S2 H-C2-a addressed a *different* surface (render-side `outsideBorder` duplication, not input stability); the Pass 3 Commit 6 SKIP decision was not revived.
- ProofPhoto real Photos picker / camera capture flow: out of scope.
- StatsDetailView `dateCellBackground` cleanup: Phase 2 cleanup 분류 유지.

---

## 9. Honest caveats

1. **Configuration drift (Pass 3 Profile → Pass 4 PerfProfile)** — Pass 3 official traces는 `Profile`, Pass 4는 `PerfProfile` (PERF_TESTING flag). 이는 `5d507fa`가 marker infra를 분리한 결과. Pass 4 개선 수치는 Pass 4 baseline vs Pass 4 after 비교에만 한정. 두 Pass의 동일-workload 직접 비교 금지.

2. **Workload drift (1024 procedural → 4032×3024 bundled)** — Pass 4 large fixture는 Pass 3 fixture의 +1063% pixel workload. "Pass 3 ProofPhoto ms → Pass 4 ms 개선" 같은 framing 금지.

3. **Analyzer windowing limitation** — xctrace analyzer의 "Duration" 값은 활성 CPU sample window이며 30s trace의 idle 구간은 제외됨 (5.4–7.6s). Pass 3 dryrun 문서가 동일 한계 기록함. 본 보고서의 모든 hot-frame 수치는 이 활성 window 내 attribution이며 절대 wall time 아님.

4. **ImageIO sampling granularity** — TP top-frame에 ImageIO가 1/3 reps에만 보이는 것은 decode가 sampling 주기보다 짧기 때문일 가능성. Hitches의 interaction delay는 더 안정적인 신호 — 그것이 primary discriminator.

5. **P4-2 keep 근거의 1차 지표** — 본 보고서의 "-35% stall / -51% longest hang"은 typing-large 시나리오 Hitches 측정에 한정. preview / reselect 시나리오는 baseline에서 이미 stall이 작아 비교적 변화가 작음. P4-2의 가치는 typing 시나리오에 집중.

6. **Brief Unresponsiveness 169ms 잔존 (1/3 reps after)** — `commentCircle.tap()` 직후의 focus + keyboard reveal moment에서 잔존. P4-2가 incidence를 3/3 → 1/3으로 줄였으나 완전 제거하지는 못함. image pipeline 문제는 아니며 framework keyboard reveal 영역.

7. **reselect after-trace의 hang count 증가 (1+1 → 0+1+2)** — 절대값은 여전히 작음(38-47ms). noise floor 안. regression 신호 아님 (longest hang 거의 동일).

8. **Pre-existing Profile-build smoke failure** — `ProofPhotoExampleSmokeTests`가 Profile에서 `feature.proof-photo.ready` 마커 timeout으로 실패. `5d507fa`가 marker를 PerfProfile-gated로 옮긴 결과이며 P4-2 commit에서 새로 발생한 regression 아님. `git stash` 후 재현 검증 완료.

9. **SwiftUI Template은 Pass 4 ProofPhoto 트랙의 evidence가 아니다** — §7 정정.

---

## 10. Workspace document inventory

| 문서 | 역할 |
|---|---|
| `docs/perf-infra/reports/_workspace/pass4-baseline-analysis.md` | Pass 4 baseline 24-trace 분석, P4-2/P4-3 entry condition 평가, noise floor 산출 |
| `docs/perf-infra/reports/_workspace/pass4-p4-2-comparison.md` | P4-2 before/after 24-trace 비교, keep/revert 평가, P4-3/P4-4 skip 사유 |
| `Scripts/generate-proof-photo-large-fixture.swift` | Pass 4 large fixture 결정론적 생성 스크립트 |
| `/tmp/twix-perf-traces/pass4-before/proof-photo/` | Pass 4 official baseline 24 traces + summary.tsv + logs |
| `/tmp/twix-perf-traces/pass4-after/p4-2-preview-decode-out-of-body/proof-photo/` | P4-2 official after 24 traces + summary.tsv + logs |
| `/tmp/twix-perf-traces/pass4-dryrun/proof-photo/timeprofiler/` | Pass 4 dry-run 4 traces (plan §K gate) |

---

## 11. Pass 4 commit log (all sub-tracks)

### 11.1 Pass 4 ProofPhoto image pipeline

| commit | role |
|---|---|
| `6fe027c` perf(proof-photo): add 4032×3024 bundled fixture + reselect/typing-large rendering scenarios for Pass 4 | P4-0 infra (large fixture + scenarios + markers + Tuist Example resource path fix). `pass4-rendering-before` tag. |
| `bb33235` perf(proof-photo): P4-2 — preview decode out of body | **KEEP** — production code change, decoded preview representation in State. |
| `76fadf6` docs(perf): Pass 4 final report — ProofPhoto image pipeline (P4-2 KEEP) | ProofPhoto sub-track closeout. |

### 11.2 Pass 4-S App-wide SwiftUI Template audit (no production change)

| commit | role |
|---|---|
| `e6274bd` docs(perf): record Pass 4-S SwiftUI Template app-wide audit | launch-mode validation + attach-mode 0-row limit + 8-candidate inventory. |
| `e1ee57b` docs(perf): record Pass 4-S C3 TXCalendarDateCell gate and skip | C3 SKIPPED on idle TP+Hitches gate. |
| `c488fe3` docs(perf): record Pass 4-S C4 GoalDetailView gate, skip, and closeout | C4 SKIPPED on idle TP+Hitches gate. Pass 4-S closed as inventory-only. |
| `d35efec` perf(infra): validate SwiftUI Template self-run interaction capture | Pass 4-S retry — self-run feasibility (ProofPhoto state-driven typing). Validated the methodology Pass 4-S2 / S3 then used. |

### 11.3 Pass 4-S2 Home self-running scroll (production change KEPT)

| commit | role |
|---|---|
| `10dc39b` docs(perf): draft Pass 4-S2 Home self-running scroll plan | plan. |
| `b325943` perf(infra): add Home self-run scroll harness and record C2 gate result | harness + before-gate result (3-AND passed). |
| `d3f66be` perf(home): reduce GoalCardView outside-border render duplication | **KEEP** — production code change in `GoalCardView.swift` only. |
| `68e2cb9` docs(perf): record Pass 4-S2 H-C2-a after-gate keep verdict | after-gate KEEP decision. |
| `d015879` docs(perf): close Pass 4-S2 Home self-run scroll optimization | closeout. |

### 11.4 Pass 4-S3 Stats self-running scroll (production change REVERTED)

| commit | role |
|---|---|
| `55047c2` docs(perf): draft Pass 4-S3 Stats self-running scroll plan | plan. |
| `a4a14c5` perf(infra): add Stats self-run scroll harness for Pass 4-S3 | harness (kept as perf infrastructure). |
| `28adce3` docs(perf): record Pass 4-S3 C5 ablation attribution and defer production fix | C5 baseline gate + ablation experiments A/B + DEFER verdict. |
| `c842d7e` docs(perf): draft Pass 4-S3 H-C5-a stamp grid explicit rows plan | H-C5-a hypothesis plan. |
| `405dc38` perf(stats): replace stamp grid LazyVGrid with eager VStack rows | H-C5-a production attempt — **REVERTED**. |
| `9a0351d` docs(perf): record Pass 4-S3 H-C5-a after-gate REVERT verdict | after-gate evidence; KEEP target missed, REVERT criterion triggered. |
| `73f4a00` Revert "perf(stats): replace stamp grid LazyVGrid with eager VStack rows" | revert of `405dc38`. `StatsCardCompletionCell.swift` restored to baseline. |
| `88ae481` docs(perf): record Pass 4-S3 H-C5-a revert + smoke confirmation | post-revert smoke test pass. |
| `d3e1bf9` docs(perf): close Pass 4-S3 Stats self-run scroll investigation | closeout. |

---

## Pass 4 종결 한 줄

Pass 4는 두 production optimization을 keep (ProofPhoto P4-2 — typing total stall -35%, longest hang -51%; Home H-C2-a — Animation Hitches `0/2/4 → 0/0/0`, 133.34 ms severe hitch + "37 offscreen passes" narrative eliminated, 8/8 UITests pass), 한 production hypothesis는 gate-and-revert (Stats H-C5-a — SwiftUI mechanism은 작동했지만 TP+Hitches가 corroborate하지 않아 revert; C5는 root cause partially identified, larger-scope hypothesis classes deferred), SwiftUI Template launch-mode + self-run methodology를 양방향 example로 검증 (Pass 4-S2 positive, Pass 4-S3 negative)했다. SwiftUI Template counts alone never justify a production change — TP + Animation Hitches가 authoritative이다. Pass 5 후보는 별도 handoff 문서로 이관.
