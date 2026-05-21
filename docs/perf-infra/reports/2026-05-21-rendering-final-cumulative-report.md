# Rendering Optimization — Final Cumulative Report (Pass 1 → Pass 5)

- **작성일**: 2026-05-21
- **상태**: 시리즈 종결. 추가 production rendering hypothesis는 새 시리즈로 시작해야 한다.
- **Anchor baseline**: tag `baseline-render-pass-1` = commit `56b5b63` (Sun 2026-05-17 14:46 KST), configuration **Profile**, device "Jiyong의 iPhone" (UDID `00008110-00096DC42632801E`, iOS 26.4.2).
- **Final HEAD reference**: Pass 5 closure 시점 (Pass 5 final report commit `10881a7` 직후).
- **Authoritative metric**: Xcode Instruments / xctrace (Time Profiler + Animation Hitches).
- **Probe metric (보조)**: XCTest driver / marker — sanity 신호로만 사용, 공식 개선 evidence 아님.

이 리포트는 Pass 1 → Pass 5 전체의 production impact, KEEP / REVERT / SKIP / CLOSED inventory, 누적 정량 비교 (가능한 범위에서), 시리즈 종료 근거를 정리한다.

---

## 1. Series 종합 outcome

### 1.1 Production impact summary (KEEP 목록 only)

실제 production code로 ship된 변경만 포함. Reverted 변경, infra-only commit, docs-only commit은 production impact에서 제외 (각각 §2.2, §2.3, §2.4).

| pass | sub-track | commit | scenario | 핵심 수치 |
|---|---|---|---|---|
| Pass 3 | Commit 3 — Home read-set split (`HomePresentationLayer`) | `d6482c9` | Home idle / Home scroll | 측정 수치는 noise floor 내. **structural cleanup** 으로 KEEP — rendering 개선 evidence 로 인용하지 않음 |
| Pass 3 | Commit 7 — GoalDetail TimelineView idle guard | `aae16d3` | GoalDetail initial | TimelineView UpdateFilter user-code top-1 frame **9-12 ms 3/3 reps 제거**. idle CPU / 배터리 카테고리 |
| Pass 4 | P4-2 — ProofPhoto image pipeline (preview decode-out-of-body + decoded preview representation) | `4cfabd0` | ProofPhoto comment typing (large fixture) | typing total stall `0.82 s → 0.53 s` (**-35 %**), longest hang `233 ms → 114 ms` (**-51 %**), TP ImageIO / JPEG decode top-frame **3/3 reps 제거** |
| Pass 4 | Pass 4-S2 H-C2-a — Home GoalCardView outsideBorder render duplication removal | `0c0da63` | Home self-run scroll | Animation Hitches `0/2/4 → 0/0/0` (**-100 %**), 133.34 ms severe hitch eliminated, "37 offscreen passes" narrative eliminated, swiftui-updates **-40.7 %**, GoalCardView.body events **-94 %**, Image accessibility events **-50 %** (side effect) |
| Pass 5 | H-C5-b — Stats StatsCardView outsideBorder render duplication removal | `5085d27` | Stats self-run scroll | Animation Hitches `4/1/2 → 2/0/0` (**-71 %**), hangs `1 (35.89 ms severe) → 0` (**-100 %**), "Potentially expensive app update(s)" narrative `3/3 → 0/3` (**eliminated**), swiftui-updates **-47.6 %** |

**Production-valid 개선 5건** (3 rendering + 1 idle CPU + 1 structural cleanup). 모두 강제 reverted 되지 않고 현재 main branch에 남아 있다.

### 1.2 Pass-by-pass scope

| pass | 기간 | focus | 결과 요약 |
|---|---|---|---|
| Pass 1 | 2026-05-17 이전 | perf 측정 인프라 구축 (XCTest metrics, `PERF_TESTING` flag, marker infra, fixture 시드, baseline-render-pass-1 tag) | infra-only — production rendering 변경 0건 |
| Pass 2 | 2026-05-17 ~ 18 | app launch / 초기 인스트루먼트 dryrun, baseline 측정 체계 검증 | infra-only — production rendering 변경 0건 (별도 final report 없음; Pass 3 baseline 문서에 흡수) |
| Pass 3 | 2026-05-18 | rendering candidate 1차 (Home read-set split, GoalDetail TimelineView, Commit 4 / 5 / 6 후보 검토) | KEEP 2건 (Commit 3, Commit 7), SKIP 3건 (Commit 4 / 5 / 6) |
| Pass 4 | 2026-05-20 | ProofPhoto image pipeline + Pass 4-S app-wide audit + Pass 4-S2 Home self-run scroll + Pass 4-S3 Stats self-run scroll | KEEP 2건 (P4-2, H-C2-a), REVERT 1건 (H-C5-a), SKIP / CLOSED inventory-only (Pass 4-S audit C3 / C4, P4-3 / P4-4) |
| Pass 5 | 2026-05-21 | Stats C5 H-C5-b primary track + C1 / C6 / keyboard residual closure | KEEP 1건 (H-C5-b), CLOSED-as-deferred 1건 (C1), CLOSED-resolved-as-side-effect 1건 (C6), CLOSED-out-of-scope 1건 (keyboard residual) |

---

## 2. Full inventory (KEEP / REVERT / SKIP / CLOSED)

### 2.1 KEEP (production change ships)

(§1.1 표와 동일.)

### 2.2 REVERT (production attempt rolled back)

| pass | sub-track | commit (reverted) | revert commit | 사유 |
|---|---|---|---|---|
| Pass 4-S3 | H-C5-a — Stats LazyVGrid → eager VStack/HStack rows | `da2278e` | `aa4a160` | SwiftUI count -15 %만 움직였고 Animation Hitches count +60 % (REVERT criterion #4). "Potentially expensive app update(s)" narrative 3/3 unchanged. 단일-inner-container swap hypothesis class exhausted (Pass 5 H-C5-b가 다른 hypothesis class로 같은 후보에서 KEEP 달성) |

**Reverted commits는 production impact summary에 포함되지 않는다.**

### 2.3 SKIP (investigated, no production change)

| pass | sub-track | 사유 |
|---|---|---|
| Pass 3 | Commit 4 (destination / presentation scoping) | Commit 3의 `HomePresentationLayer`가 흡수, attribution 악화 우려 |
| Pass 3 | Commit 5 (`goalSectionTitle` / `nowDate` stored derivation) | baseline top-frame 미등장 |
| Pass 3 | Commit 6 (Home card rendering / GoalCardView input stability) | measurable candidate 없음; stale-closure risk 동반 |
| Pass 4 | P4-3 (ProofPhoto downsample) | P4-2 적용 후 ImageIO frame typing TP에서 0/3로 사라짐 → 진입 조건 미충족 |
| Pass 4 | P4-4 (ProofPhoto subtree isolation) | image subtree re-render 문제가 P4-2로 이미 해결 |
| Pass 4-S | C3 (TXCalendarDateCell) | idle gate에서 TP top-30 부재 → 진입 조건 미충족 |
| Pass 4-S | C4 (GoalDetailView) | idle gate에서 진입 조건 미충족 |

### 2.4 CLOSED (Pass 5 final closure, no further action in series)

| pass | sub-track | 분류 | 사유 |
|---|---|---|---|
| Pass 5 | C1 — TXNavigationBar idle re-eval | CLOSED-as-deferred | C3 magnitude class와 동일 (SKIPPED 선례). 신규 interaction-time harness + cross-feature scope (≥ 3 features) 필요 → §4.8 one-file rule + Pass 5 closing 취지에 충돌. 향후 새 시리즈에서만 재오픈 가능 |
| Pass 5 | C6 — Image accessibility | CLOSED-resolved-as-side-effect | Pass 4-S2 H-C2-a (Home, -50 % events) + Pass 5 H-C5-b (Stats, -47.6 % SwiftUI total)의 cell-subtree composition 감소의 side effect로 noise floor 아래로 collapse. TP top-30 부재, Hitches narrative 부재 |
| Pass 5 | ProofPhoto keyboard residual | CLOSED-out-of-scope | UIKit framework keyboard / focus stack. SwiftUI / view layer로 직접 최적화 불가. UX latency / input handling 별도 카테고리로만 추적 |

---

## 3. 정량 비교

### 3.1 정량 비교의 제약

- **Configuration drift**: Pass 3는 `Profile` configuration으로 수집, Pass 4 / Pass 5는 `PerfProfile` configuration으로 수집. `5d507fa` (2026-05-19) commit이 `PERF_TESTING` gating을 `PerfProfile`로 분리 → Pass 3 `Profile` traces vs Pass 4+ `PerfProfile` traces는 동일 workload 직접 비교 불가. Pass 4 final report §2.4의 caveat 그대로 적용.
- **Workload drift**: Pass 4 ProofPhoto는 large fixture (4032×3024, 7.46 MiB JPEG)로 workload 변경. Pass 3 ProofPhoto baseline (1024×1024 procedural)과 직접 비교 불가. Pass 4 final report §2.5의 caveat 그대로 적용.
- **Window drift**: Pass 5 H-C5-b after-gate는 `--time-limit 35s`, Pass 4-S3 C5 before-gate는 30s. Active-scroll-window 기반 event metric (Hitches, narrative)은 window-insensitive. Total swiftui-updates는 raw -47.6 % → window-normalized 보수 추정 ≥ -40 %.
- **초기 baseline-render-pass-1 (Pass 1) 대비 현재 HEAD 직접 비교는 같은 이유로 불가**. Pass 1 baseline (`56b5b63`, `Profile`)의 `home-scroll` CPU time `0.803 s` 같은 수치는 같은 configuration / harness / device로 다시 측정해야 비교 가능한데, 그 사이에 PerfProfile 분리 + 새 harness (ProofPhoto-large, Home self-run, Stats self-run) 추가 + 측정 metric 자체의 변화 (XCTClockMetric → Time Profiler authoritative metric 전환)가 일어남.

### 3.2 같은-workload 누적 개선 (pass별 before/after only)

각 pass의 same-configuration, same-workload before/after만 인용:

#### Pass 3 (configuration: `Profile`)

| commit | scenario | metric | before | after | delta |
|---|---|---|---:|---:|---:|
| Commit 7 | GoalDetail initial | TP TimelineView UpdateFilter top-1 user-code frame | 9-12 ms (3/3 reps) | absent (3/3 reps) | **eliminated** |
| Commit 3 | Home scroll | TP user-code top-N | noise-floor 내 변동 | noise-floor 내 변동 | structural cleanup; not a rendering improvement |

#### Pass 4 (configuration: `PerfProfile`)

| commit | scenario | metric | before (pass4-rendering-before = `cd989de`) | after | delta |
|---|---|---|---:|---:|---:|
| P4-2 (`4cfabd0`) | ProofPhoto typing-large | total stall (ms) | 820 | 530 | **-35 %** |
| P4-2 (`4cfabd0`) | ProofPhoto typing-large | longest hang (ms) | 233 | 114 | **-51 %** |
| P4-2 (`4cfabd0`) | ProofPhoto typing-large | TP ImageIO decode top frame | present (3/3 reps) | absent (3/3 reps) | **eliminated** |
| H-C2-a (`0c0da63`) | Home self-run scroll | Animation Hitches per-rep | 0 / 2 / 4 (mean 2.0, total 6) | **0 / 0 / 0** | **-100 %** |
| H-C2-a (`0c0da63`) | Home self-run scroll | 133.34 ms severe hitch | present rep 2 | eliminated | **eliminated** |
| H-C2-a (`0c0da63`) | Home self-run scroll | "37 offscreen passes" narrative | present | eliminated | **eliminated** |
| H-C2-a (`0c0da63`) | Home self-run scroll | swiftui-updates total | 204,598 | 121,310 | **-40.7 %** |
| H-C2-a (`0c0da63`) | Home self-run scroll | GoalCardView.body events | 2,642 | 166 | **-93.7 %** |
| H-C2-a (`0c0da63`) | Home self-run scroll | Image.ImageViewChild events | 2,563 | 1,270 | **-50 %** (side effect) |

#### Pass 5 (configuration: `PerfProfile`)

| commit | scenario | metric | before (pass4-s3 c5-before, identical to Pass 5 H-C5-b baseline state) | after | delta |
|---|---|---|---:|---:|---:|
| H-C5-b (`5085d27`) | Stats self-run scroll | Animation Hitches per-rep | 4 / 1 / 2 (mean 2.33, total 7) | **2 / 0 / 0** (mean 0.67, total 2) | **-71 %** |
| H-C5-b (`5085d27`) | Stats self-run scroll | hangs ≥ 33 ms | 1 (35.89 ms severe) | **0** | **-100 %** |
| H-C5-b (`5085d27`) | Stats self-run scroll | "Potentially expensive app update(s)" narrative reproducibility | **3 / 3 reps** | **0 / 3 reps** | **eliminated** |
| H-C5-b (`5085d27`) | Stats self-run scroll | swiftui-updates total | 641,276 | 336,120 | **-47.6 %** (raw; window-normalized ≥ -40 %) |
| H-C5-b (`5085d27`) | Stats self-run scroll | TP user-code Stats frame in top-10 | absent (0/3) | absent (0/3) | unchanged (PASS, no regression) |

### 3.3 trace contamination

| pass | scenario | template | total reps | contaminated | retain rate |
|---|---|---|---:|---:|---:|
| Pass 3 | rendering 시리즈 (8 scenarios × {TP, Hitches} × 3) | TP + Hitches | 48 | 0 | 48 / 48 |
| Pass 4 | ProofPhoto (4 scenarios × {TP, Hitches} × 3) | TP + Hitches | 24 | 0 | 24 / 24 |
| Pass 4-S | app-wide audit (7 scenarios × 3) | SwiftUI | 21 | 0 | 21 / 21 |
| Pass 4-S2 | Home self-run scroll (before + after) | SwiftUI + TP + Hitches | 18 | 0 | 18 / 18 |
| Pass 4-S3 | Stats self-run scroll (before + after) | SwiftUI + TP + Hitches | 18 | 0 | 18 / 18 |
| Pass 5 | Stats self-run scroll H-C5-b after-gate | SwiftUI + TP + Hitches | 9 | 0 | 9 / 9 |

**Cumulative contamination rate: 0 / 138 official traces** across Pass 3 / 4 / 5. (Pass 1 / Pass 2 infra dryrun은 별도; 본 표는 production-decision-relevant trace만.)

---

## 4. 최종 production impact

§1.1의 5건 (Pass 3 Commit 3 + Pass 3 Commit 7 + Pass 4 P4-2 + Pass 4-S2 H-C2-a + Pass 5 H-C5-b)이 현재 main에 남아 있는 production-valid 개선의 전부. Reverted commit (H-C5-a), SKIPPED commits (Pass 3 Commit 4 / 5 / 6, Pass 4 P4-3 / P4-4, Pass 4-S C3 / C4), CLOSED candidates (Pass 5 C1 / C6 / keyboard residual)는 production impact에 포함되지 않는다.

Infra-only commits (perf harness, fixture 시드, marker infra, self-run scroll harness 등)도 production behavior 변경이 없으므로 production impact에 포함되지 않는다. 단, 측정 인프라로서의 가치는 future series에서 reusable assets로 유지된다 — §6.1 참조.

Docs-only commits (각 pass의 workspace docs, plan, after-gate 검증 doc, final report)도 production impact 외. 단, 의사결정 재현성 / methodology 검증 / 향후 시리즈 진입 시 reference로서의 가치는 유지.

---

## 5. 회귀 방지 근거

### 5.1 UITest / smoke 결과

- Pass 3 / Pass 4 / Pass 5의 모든 production-KEEP 변경은 commit 직후 smoke / scenario UITest 통과 확인.
- Pass 4 P4-2: `FeatureProofPhotoExampleUITests` 전체 통과 (Pass 4 final report §11.1).
- Pass 4-S2 H-C2-a: `FeatureHomeExampleUITests` 8/8 통과 (Pass 4 final report §11.3).
- Pass 4-S3 H-C5-a 후 revert: 반환된 baseline state에서 `FeatureStatsExampleUITests` 통과 (revert verification commit `21c734d`).
- Pass 5 H-C5-b: `StatsExampleSmokeTests/testExampleRendersReadyState` 통과 (7.32 s).

### 5.2 Visual sanity

- Pass 4 P4-2: ProofPhoto preview / typing / reselect visual identical 확인 (Pass 4 final report §9).
- Pass 4-S2 H-C2-a: Home GoalCardView border / corner / color identical 확인 (Pass 4-S2 H-C2-a 검증 시 simulator 비교).
- Pass 5 H-C5-b: Stats StatsCardView border / corner / color identical 확인 (`/tmp/stats-h-c5-b-after.png`).

### 5.3 No new TP hot path (rendering KEEP 후보 모두)

- Pass 4 P4-2 after-gate: ImageIO decode frame eliminated, new top-20 user-code 없음.
- Pass 4-S2 H-C2-a after-gate: GoalCardView.body.getter eliminated, CardHeaderView 상승은 절대 event count는 감소했으나 상대 ranking 상승 (Pass 4-S2 H-C2-a comparison §3 — not a regression).
- Pass 5 H-C5-b after-gate: 모든 rep에서 Stats user-code TP top-10 부재 유지. rep3의 `StatsView.scrollCardList.getter` closure는 `#if PERF_TESTING` self-run harness driver (production code 아님).

### 5.4 Reverted hypothesis가 정상 revert되었는지

- Pass 4-S3 H-C5-a: `git revert da2278e` → `aa4a160 refactor: Stats 스탬프 그리드 행 레이아웃 되돌림`. revert 후 `StatsCardCompletionCell.swift`가 H-C5-a 이전 baseline LazyVGrid form으로 복원됨 확인 (Pass 4-S3 closeout commit `7873646` §1). 이 reverted state가 Pass 5 H-C5-b의 baseline이며, H-C5-b는 `StatsCardCompletionCell.swift`를 touch하지 않으므로 두 변경은 orthogonal — H-C5-a revert는 영구적으로 유효.

---

## 6. 시리즈 종료 근거

### 6.1 무엇이 빨라졌는가

- **Home scroll**: Animation Hitches 0/2/4 → 0/0/0 (133 ms severe hitch 포함 -100 %), "37 offscreen passes" narrative 제거.
- **Stats scroll**: Animation Hitches 4/1/2 → 2/0/0 (-71 %), 35.89 ms severe hang 제거, "Potentially expensive app update(s)" narrative reproducibility 3/3 → 0/3 제거.
- **ProofPhoto typing (large 4032×3024 photo)**: total stall -35 % (820 → 530 ms), longest hang -51 % (233 → 114 ms), TP ImageIO decode top-frame 3/3 reps 제거.
- **GoalDetail initial cold**: TimelineView UpdateFilter user-code top-1 frame 9-12 ms 3/3 reps 제거 (idle CPU 카테고리).

### 6.2 어떤 종류의 병목을 제거했는가

| category | mechanism | 사례 |
|---|---|---|
| **Render-side composition duplication** | shared `outsideBorder` modifier가 `overlay { stroke.overlay(self) }`로 cell subtree를 두 번 composition. local `.background { stroke }`로 대체해서 중복 제거 | Pass 4-S2 H-C2-a (Home GoalCardView), Pass 5 H-C5-b (Stats StatsCardView) |
| **Main-thread image decode-in-body** | `UIImage(data:)`가 SwiftUI body 안에서 매 invalidation마다 재실행. ingestion 시점 한 번 decode + decoded representation을 state로 저장 | Pass 4 P4-2 (ProofPhoto preview / typing) |
| **Idle TimelineView re-evaluation** | `TimelineView` schedule이 idle 상태에서도 frame-tick 마다 user-code update 호출. idle guard 추가로 GoalDetail initial 시나리오에서 user-code top-1 frame 제거 | Pass 3 Commit 7 (GoalDetail) |
| **Read-set / observation surface 정리** | `HomePresentationLayer`로 Home의 read-set을 분리해 향후 attribution을 단순화 (직접적 rendering 개선은 noise floor 내) | Pass 3 Commit 3 (Home structural cleanup) |

### 6.3 무엇은 의도적으로 최적화하지 않았는가

| 후보 | 사유 |
|---|---|
| Pass 3 Commit 4 / 5 / 6 | TP top-frame 부재 또는 stale-closure risk. SKIP. |
| Pass 4 P4-3 (ProofPhoto downsample) / P4-4 (subtree isolation) | P4-2 적용 후 진입 조건 미충족. |
| Pass 4-S C3 (TXCalendarDateCell) / C4 (GoalDetailView) | idle gate에서 TP top-30 부재. SKIP. |
| Pass 4-S3 H-C5-a (Stats LazyVGrid swap) | gated-and-reverted — counts moved, real cost did not. Single-inner-container swap class exhausted. |
| Pass 5 C5 잔여 hypothesis classes (Equatable on StatsCardView, cell-content reduction, cell-pool, cell-snapshot caching) | Pass 5 one-pass-one-hypothesis budget for C5는 H-C5-b로 충족. 잔여 class는 각각 multi-file rewrite 또는 visual-behavior change 또는 stale-closure risk 동반. 새 시리즈의 새 plan + approval로만 진입. |
| Pass 5 C1 (TXNavigationBar idle re-eval) | cross-feature scope (≥ 3 features) + interaction-time harness 신설 필요. §4.8 one-file rule 및 Pass 5 closing 취지 충돌. CLOSED-as-deferred. |
| Pass 5 C6 (Image accessibility) | Pass 4-S2 H-C2-a + Pass 5 H-C5-b의 side effect로 noise floor 아래로 collapse. CLOSED-resolved-as-side-effect. |
| Pass 5 ProofPhoto keyboard residual | UIKit framework cost — SwiftUI / view layer 최적화 불가. CLOSED-out-of-scope. |

### 6.4 Pass 5 이후 rendering optimization series를 종료해도 되는 이유

1. **VoC 우선 후보 모두 closure**: ProofPhoto (image pipeline + typing) 개선, Home scroll 개선, Stats scroll 개선 — 사용자 VoC가 지목한 세 영역 모두 production-valid 개선 달성.
2. **남은 후보는 cost / risk가 benefit을 초과**: C1 (cross-feature scope), C5 잔여 (multi-file rewrite / visual change / closure risk), C6 (이미 해결), keyboard residual (out of category). 추가 작업의 marginal benefit이 진입 cost (새 harness, 새 plan, 새 gate, multi-file diff)를 정당화하지 않는다.
3. **Methodology contract가 안정적으로 작동함을 3번 입증**: H-C2-a KEEP, H-C5-a REVERT, H-C5-b KEEP. "SwiftUI Template counts alone never justify; TP + Animation Hitches가 authoritative" 룰은 양방향 + 같은 메커니즘 cross-feature 재현으로 확립.
4. **Trace 신뢰도 0 contamination**: 138 production-decision-relevant traces 중 0건 contaminated. 추가 시리즈가 진입할 때 baseline 신뢰도는 매우 높음.
5. **Reusable infrastructure intact**: ProofPhoto self-run typing harness (`79b6393`), Home self-run scroll harness (`fde7d41`), Stats self-run scroll harness (`caa26be`), large fixture infrastructure (`cd989de` 시점 Pass 4 baseline tag), PerfProfile configuration + PERF_TESTING gating. 새 시리즈가 시작될 때 이 infra를 그대로 활용 가능.
6. **Future risk / known unresolved area는 명시적으로 문서화됨**: §6.3 표 + 본 cumulative report 자체가 inventory. 새 pass는 새 plan으로 진입할 때 본 리포트의 §6.3 표를 참조해 hypothesis class를 정한다.

---

## 7. Future risk / known unresolved area

- **Stats C5 — larger-scope hypothesis classes**: Pass 5에서 의도적으로 열지 않음. Equatable on StatsCardView (closure-identity risk), cell-content reduction (visual change), cell-pool (architectural rewrite), cell-snapshot caching (first-paint cost + lifecycle complexity). 잔여 cost는 H-C5-b 후 baseline 대비 Animation Hitches `2/0/0` (mean 0.67) 수준 — practical impact 매우 낮음.
- **C1 — TXNavigationBar idle re-eval**: cross-feature scope. 재오픈 조건은 §2.4 참조.
- **ProofPhoto keyboard / focus framework residual**: UIKit framework cost. UX latency / input handling 별도 카테고리로만 추적. SwiftUI rendering 시리즈 밖.
- **Configuration drift**: `Profile` vs `PerfProfile` configuration 차이가 직접 비교를 가로막음. 향후 시리즈는 처음부터 `PerfProfile` baseline tag로 시작해서 본 caveat을 피할 수 있음.
- **Animation Hitches metric의 count vs severity tension**: Pass 4-S3 H-C5-a가 보여준 것처럼 count는 +60 %, severity (hangs)는 -100 %로 갈 수 있음. 본 시리즈는 plan의 명시적 KEEP/REVERT criteria가 count-based였기 때문에 그 게이트를 따랐음. 향후 시리즈는 severity-weighted metric을 별도 KEEP criterion에 추가하는 것을 고려할 수 있음.
- **SwiftUI Template attach-mode 0-row 제한**: iOS 26.4.2 / Xcode 26.0에서 재확인된 tooling limit. Driver-required scenario (XCUITest typing / reselect / interactive scroll)는 self-run harness 우회로만 SwiftUI Template attribution 가능. 향후 OS / Xcode 업데이트가 이 제한을 풀 수 있음.

---

## 8. Commit log summary

| pass | production commits (kept) | revert commits | infra commits | docs commits |
|---|---|---|---|---|
| Pass 1 | — | — | `5594c1f`, `78215b4`, etc (baseline infra) | `e7c4423` (baseline-render-pass-1 시점 docs) |
| Pass 2 | — | — | `0fbd8f8` (Instruments dryrun) | (Pass 3 baseline 문서에 흡수) |
| Pass 3 | `d6482c9` (Commit 3), `aae16d3` (Commit 7) | — | `5d507fa` (PerfProfile 분리) | `e9b6e45` (Pass 3 final), `766a6c3` (Commit 6 investigation), etc |
| Pass 4 | `4cfabd0` (P4-2), `0c0da63` (H-C2-a) | `aa4a160` (revert of `da2278e` H-C5-a) | `cd989de` (P4-0 large fixture + scenarios), `79b6393` (ProofPhoto self-run typing harness), `fde7d41` (Home self-run scroll harness), `caa26be` (Stats self-run scroll harness), `d35efec` (SwiftUI Template self-run validation) | `76fadf6` / `a9eea07` / `78b592c` (Pass 4 final), `e6274bd` / `fb83216` (Pass 4-S audit), 등 다수 |
| Pass 5 | `5085d27` (H-C5-b) | — | — (재사용) | `e2523f8` (handoff), `cb99884` (plan), `ec2b8f2` (after-gate), `10881a7` (Pass 5 final), (this commit) |

**Total production-kept rendering commits: 5** (Pass 3 × 2 + Pass 4 × 2 + Pass 5 × 1).
**Total reverts: 1** (Pass 4-S3 H-C5-a).
**Total docs / infra commits: 다수** (재현성 / methodology 검증 자산).

---

## 9. Closing

Rendering optimization 시리즈 (Pass 1 → Pass 5) 종료.

향후 rendering 관련 production 변경이 필요한 경우, 본 cumulative report의 §6.3 (의도적으로 최적화하지 않은 후보 inventory) 및 §7 (future risk / known unresolved area)을 starting point로 사용해서 새 시리즈로 진입한다. Pass 5의 H-C5-b가 입증한 "render-side duplication removal" 패턴이 또 다른 cross-feature 후보 (`CardHeaderView`, `GoalEditCardView` 등 `outsideBorder` consumer)에서 재현 가능한지는 본 시리즈가 명시적으로 다루지 않은 영역이므로, 그 자체로 다음 시리즈의 candidate가 될 수 있다 (단, handoff §4.5 룰 — 각 cross-feature 적용은 independent gate evidence 필수 — 그대로 적용).

본 시리즈는 이로써 결론을 내고 closed.
