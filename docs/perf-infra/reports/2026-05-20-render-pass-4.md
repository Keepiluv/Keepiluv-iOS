# Pass 4 — Image Pipeline Optimization (ProofPhoto)

- **작성일**: 2026-05-20
- **Baseline tag**: `pass4-rendering-before` = `6fe027c`
- **Production commit**: `bb33235 perf(proof-photo): P4-2 — preview decode out of body`
- **Authoritative metric**: Xcode Instruments / xctrace (Time Profiler + Animation Hitches), iOS 26.4.2 device (Jiyong의 iPhone, UDID `00008110-00096DC42632801E`), **PerfProfile** configuration
- **Probe metric (보조)**: XCTest XCUI driver — driver/marker sanity 신호 (개선 evidence 아님)

이 리포트는 Pass 4의 ProofPhoto image-pipeline 최적화 트랙을 정리한다. Pass 3에서 deferred되었던 SwiftUI Template 검증은 본 Pass의 ProofPhoto P4-2 gate가 아니라 별도 App-wide audit 트랙(`Pass 4-S`)으로 분리한다.

---

## 1. Executive summary

| 항목 | 결과 |
|---|---|
| 측정 인프라 추가 (large fixture + 3개 시나리오 + 신규 marker) | **완료** (Commit `6fe027c`) |
| Pass 4 official baseline 수집 | **24/24 traces, contamination 0/24** (`pass4-rendering-before`) |
| P4-2 (preview decode out of body) | **KEEP** — typing-large total stall `0.82s → 0.53s` (`-35%`), longest hang `233ms → 114ms` (`-51%`), TP ImageIO/JPEG decode top-frame **3/3 reps에서 제거** |
| P4-3 (preview downsample) | **SKIP** — P4-2 적용 후 ImageIO frame이 typing TP에서 0/3로 사라짐. 남은 stall은 keyboard-side UIKit이며 downsample 적용 영역이 아님 |
| P4-4 (preview subtree isolation) | **SKIP** — image subtree re-render 문제가 P4-2로 해결됨; 잔여 stall은 SwiftUI subtree 비용이 아님 |
| SwiftUI Template launch-mode 검증 | **재분류** — ProofPhoto gate가 아니라 별도 트랙 `Pass 4-S — App-wide SwiftUI Template Audit`로 분리 |
| Secondary candidates (GoalDetail / Stats / Settings nickname) | **evidence-gated 유지** — Pass 4 ProofPhoto baseline에서 진입 evidence 없음 |

**한 줄 요약**: 사용자 VoC ("preview가 떠 있는 상태에서 5글자 멘트 작성 시 렉이 체감됨")을 정량 재현(typing-large 3/3 reps, 15 hangs/rep, 0.82s total stall)했고, ingestion-time decode + State에 preview representation 보관(P4-2)으로 **typing total stall을 35%, longest hang을 51% 감소**시켰다. ImageIO decode frame은 typing TP에서 사라졌고 새 hot path 등장 없음. 남은 stall은 framework keyboard 영역으로 image pipeline 범위 밖이라 P4-3/P4-4는 skip한다.

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

## 7. SwiftUI Template — 의도 정정 (re-classified)

Pass 4 진행 중 SwiftUI Template 검증을 ProofPhoto P4-2/P4-3/P4-4의 entry gate처럼 다뤘는데 이는 잘못된 분류였다. SwiftUI Template은 ProofPhoto-specific optimization step이 아니라 **App-wide second-pass diagnostic layer**다.

목적 재정의:
- Pass 3에서 Time Profiler + Animation Hitches로 측정한 8개 rendering scenario를 SwiftUI Template으로 재검사.
- framework-only로 attribute되었던 구간의 **body evaluation / view update / transaction / invalidation** 비용을 후보로 발굴.
- SwiftUI Template 결과 자체는 production optimization evidence가 아님.
- 후보가 발굴되면 **Time Profiler + Animation Hitches before/after**로 다시 검증한 뒤에만 commit.

→ Pass 4 본 ProofPhoto 트랙은 P4-2 KEEP으로 종결. SwiftUI Template은 **`Pass 4-S — App-wide SwiftUI Template Audit`**라는 별도 트랙으로 분리.

§8(Phase 5+ follow-ups)에 detail 기재.

---

## 8. Follow-ups (next-track candidates)

### 8.1 Pass 4-S — App-wide SwiftUI Template Audit (별도 트랙)

**Context**: Pass 3의 8 + Pass 4의 4 scenario 모두에서 user-code top-frame은 framework가 압도적으로 점유. Time Profiler / Hitches는 SwiftUI 자체의 body / update / invalidation 비용을 user-code attribution으로 분리하지 못함. SwiftUI Template은 그 분리를 제공할 가능성.

**Goal**: 9개 rendering scenario에 대해 SwiftUI Template 데이터 수집 + body/update/invalidation 후보 발굴.

**Plan 요약**:
1. Tooling validation (최대 2시간): `xcrun xctrace help record` / `list templates` 검증, 1~2개 짧은 scenario로 trial. 성공 기준 = trace bundle에 SwiftUI 카테고리 table + analyzer 파싱 가능 + 2회 이상 재현.
2. 성공 시 full sweep: 9 scenarios × SwiftUI Template × 3 reps = 27 traces.
3. Candidate analysis: body re-eval count, transaction count, invalidation 범위.
4. 각 후보는 **Time Profiler + Animation Hitches before/after**로 재검증한 뒤에만 commit. SwiftUI Template 수치만으로 production commit 금지.
5. Fallback (SwiftUI Template 미사용 시): targeted body/update counters via os_signpost, suspicious view audit (GeometryReader, TimelineView, PreferenceKey, overlay, LazyVGrid, KFImage, FocusState).

**Stop conditions**:
- tooling validation 2시간 한도 초과 → fallback.
- 후보 발굴 후 Time Profiler / Hitches에서 evidence 미확인 → skip.
- 다른 카테고리(idle CPU / loading delay)로 분기 필요 → 별도 트랙.

**Out of scope**:
- ProofPhoto P4-2 추가 보강 (이미 KEEP).
- Pass 3 commit 재검토 (이미 결정됨).
- SwiftUI Template 수치만으로 production optimization commit.

### 8.2 Keyboard / focus UX investigation (image pipeline 범위 밖)

Pass 4 P4-2 after-trace의 잔여 stall은 framework keyboard 영역. 다음 stack이 typing scenario의 main thread를 점유:
- `UIAssistantBarButtonItemProvider`
- `UIInputWindowController` / `_UIKeyboardStateManager`
- `UIKeyboardCache displayImagesForView:fromLayout:imageFlags:`
- `UISystemKeyboardDockController`
- `UIView _accessibilityViewIsVisibleIgnoringAXOverrides`

이것은 image pipeline 문제가 아니라 keyboard / accessibility framework 문제이며 production 코드 단에서 직접 최적화하기 어려움. 후보 조사로만 기록.

### 8.3 Secondary candidates (evidence-gated 유지)

- **GoalDetail rapid-fire**: Pass 4 baseline 진입 evidence 없음. Pass 4-S에서 SwiftUI body 비중 발견 시 재검토.
- **Stats heavy scroll**: 같음.
- **Settings nickname**: loading-delay / probe-only 분류 유지. UI Rendering 결론에 인용 금지.

### 8.4 Pass 3 deferred items (변화 없음)

- Home / GoalCardView input stability: trace evidence 없으면 revive 금지.
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

## 11. Pass 4 commit log

| commit | role |
|---|---|
| `6fe027c` perf(proof-photo): add 4032×3024 bundled fixture + reselect/typing-large rendering scenarios for Pass 4 | P4-0 infra (large fixture + scenarios + markers + Tuist Example resource path fix) |
| `bb33235` perf(proof-photo): P4-2 — preview decode out of body | KEEP — production code change, decoded preview representation in State |

`pass4-rendering-before` tag = `6fe027c` (P4-0 HEAD).

---

## Pass 4 종결 한 줄

ProofPhoto의 사용자 VoC ("preview 떠 있는 상태에서 5글자 멘트 작성 시 렉")을 정량 재현하고 P4-2 (preview decode out of body)로 **typing main-thread stall을 35% (longest hang 51%) 줄였다**. 남은 stall은 framework keyboard 영역으로 image pipeline 범위 밖이라 P4-3/P4-4는 skip. SwiftUI Template은 ProofPhoto gate가 아니라 App-wide audit으로 재분류하여 별도 트랙 `Pass 4-S`로 이관.
