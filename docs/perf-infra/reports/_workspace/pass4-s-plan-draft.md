# Pass 4-S — App-wide SwiftUI Template Audit (plan draft)

**Status**: DRAFT — not yet executed. Pass 4 ProofPhoto track closed; this is the proposed next track.

## Context

Pass 3 + Pass 4 trace 결과 user-code top-frame은 UIKit + SwiftUI framework 가 압도적으로 점유 (95%+). Time Profiler / Animation Hitches 는 SwiftUI 자체의 body evaluation / view update / transaction / invalidation 비용을 user-code attribution 으로 분리하지 못한다. SwiftUI Template 은 이 분리를 제공할 가능성이 있다.

이 트랙의 목적은 **production optimization commit 이 아니라 candidate discovery**. Pass 4 P4-2 처럼 명확한 image-pipeline 신호가 없는 시나리오 (Home feed scroll, Stats heavy scroll 등) 에서 SwiftUI body/update/invalidation 비용이 attribution 되면 후속 최적화 트랙의 출발점이 된다.

## Goal

1. Pass 3 의 8 개 rendering scenario + Pass 4 의 4 개 (총 9 개; 일부 중복 통합) 에 대해 SwiftUI Template 데이터를 수집한다.
2. body evaluation count, view update transaction, invalidation 범위를 발굴한다.
3. 발견된 후보는 **Time Profiler + Animation Hitches before/after** 로 재검증한 뒤에만 production commit 한다. SwiftUI Template 수치만으로 commit 하지 않는다.

## Scope

### In scope

- 9 rendering scenarios (Pass 3 + Pass 4 union):
  - Home feed scroll
  - Home calendar sweep
  - GoalDetail initial render
  - GoalDetail reaction rapid-fire
  - ProofPhoto preview-large
  - ProofPhoto comment-typing-large
  - ProofPhoto reselect-large
  - Stats heavy initial
  - Stats heavy scroll
- SwiftUI Template trace 수집 (가능한 경우)
- candidate discovery + Time Profiler / Hitches 재검증

### Out of scope

- ProofPhoto P4-2 추가 보강 (이미 KEEP, 종결).
- Pass 3 commit 재검토 (Commit 3/7 KEEP, 4/5/6 SKIP).
- SwiftUI Template 수치만으로 production optimization commit.
- ProofPhoto P4-3/P4-4 부활 (Pass 4 final report 에서 SKIP 사유 명시).
- production app 빌드 (PerfProfile 만 사용).
- Auth / Onboarding 시나리오.
- Settings nickname (loading-delay / probe-only 로 분리).

## Phase plan

### Phase S1 — Tooling validation (max 2 hours)

**Goal**: SwiftUI Template 이 자동화 가능한지 결정.

Steps:

1. `xcrun xctrace help record` 출력으로 `--launch` syntax, `--env` 지원, `--target-stdin/stdout` 등 확인.
2. `xcrun xctrace list templates` 로 `SwiftUI` template 존재 재확인.
3. 1~2 개 짧은 시나리오로 trial recording:
   - **First trial**: ProofPhoto preview-large (driver 없이 launch + ready marker 도달, 단순).
     ```bash
     # 가설 명령 — 실제 syntax 는 xctrace help 출력으로 검증 후 사용
     xcrun xctrace record \
       --device <UDID> \
       --template 'SwiftUI' \
       --time-limit 30s \
       --launch -- <FeatureProofPhotoExample.app path> \
       -UITEST -UITEST_SEED proof-photo-prefilled-large -UITEST_RENDERING_SCENARIO \
       --output /tmp/twix-perf-traces/pass4-s-trial/preview-large-launch.trace
     ```
   - **Second trial (if first works)**: GoalDetail initial render (1.7s wall time, 짧음).
4. 성공 기준:
   - trace bundle 에 SwiftUI 관련 table (`view-update`, `body-evaluation`, `transaction` 등) 존재.
   - `mcp__xctrace-analyzer__analyze_trace` 가 SwiftUI 카테고리 데이터 반환.
   - 동일 절차로 2회 이상 재현.
5. 실패 시 fallback path 로 이동 (Phase S4).

**Stop**: 누적 2시간 초과 또는 명확한 unavailable 신호 → Phase S4 로 이동.

### Phase S2 — Full sweep (S1 성공 시)

**Goal**: 9 시나리오 × SwiftUI Template × 3 reps = 27 traces 수집.

Conditions:

- Configuration: PerfProfile (Pass 4 baseline 과 동일).
- Window: 30s (Pass 4 패턴).
- Device: 동일 (`00008110-00096DC42632801E`).
- Driver: 각 시나리오의 기존 UITest 재사용 (수정 없음).
- Contamination policy: Pass 4 §2.4 동일.

Trace output: `/tmp/twix-perf-traces/pass4-s/swiftui/{home,goal-detail,proof-photo,stats}/<scenario>-rep<N>.trace`

### Phase S3 — Candidate analysis (S2 성공 시)

각 시나리오 × rep 에서 다음을 추출:

- view body evaluation count (per view type).
- view update transaction count.
- invalidation 범위 (which views invalidate when state changes).
- excessive re-render 의심 view.
- Pass 3 / Pass 4 의 Time Profiler 에서 framework-only 였던 구간의 SwiftUI attribution.

Output: `docs/perf-infra/reports/_workspace/pass4-s-candidates.md`

Format per candidate:

| field | value |
|---|---|
| scenario | e.g. Home feed scroll |
| view | e.g. `HomeContentSection`, `GoalCardView` |
| metric | body evals per scroll cycle |
| baseline | before/expected count |
| observed | actual count |
| hypothesis | proposed cause |
| proposed change | small commit scope |
| measurable benefit | expected Time Profiler / Hitches delta |
| risk | stale UI / API change / observation churn |

### Phase S4 — Fallback (S1 실패 시)

SwiftUI Template automatic collection 이 불가능할 경우:

- **Targeted body / update counters**: `PerfCounters` 패턴으로 view body 호출 횟수 +1. 시나리오 시작/끝에 counter 차이로 body re-eval count 추출. probe-only.
- **os_signpost based markers**: body / reducer / preview phase 에 `os_signpost` 삽입, Instruments 의 Signposts instrument 으로 수집.
- **Suspicious view audit (read-only)**: 다음 view 패턴을 grep + 코드 검토로 수집 — 후보 발굴은 정량 데이터 없이 hypothesis 만 제공:
  - `GeometryReader`
  - `TimelineView`
  - `PreferenceKey` 관련
  - `overlay` 다중 중첩
  - `LazyVGrid` / `LazyVStack` per-cell cost
  - `KFImage` cache miss
  - `FocusState` / keyboard 관련 view
- 발견 후보는 동일하게 **Time Profiler + Animation Hitches before/after** 로 검증.

Phase S4 의 결과는 SwiftUI Template 만큼 정량적이지 않지만 후속 trace evidence 로 보강할 수 있다.

### Phase S5 — Evidence-gated per-candidate commit

각 후보에 대해:

1. hypothesis + entry condition 명시.
2. small commit (one hypothesis = one commit).
3. Time Profiler + Animation Hitches before/after 24 traces.
4. keep/revert per Pass 4 §P style gate.
5. user approval before commit (per Pass 4 §U style protocol).
6. result 를 `docs/perf-infra/reports/<YYYY-MM-DD>-render-pass-4-s.md` 에 기록.

## Constraints (Pass 4 와 동일)

- Authoritative metric = Time Profiler + Animation Hitches trace. SwiftUI Template = candidate discovery only.
- XCTest timing = probe-only.
- Noise floor 는 Pass 4-S baseline (있다면) 또는 Pass 4 reference 사용.
- 1 commit = 1 hypothesis. attribution 보존.
- Contamination policy 동일.

## Stop conditions

- S1 2시간 한도 → S4 로 이동.
- S2 trace 수집 실패율 > 25% → 환경 / driver 점검.
- candidate 발굴 후 Time Profiler / Hitches 에서 evidence 미확인 → skip 후 다음 후보.
- visual regression → revert.
- 다른 카테고리 (idle CPU / loading delay) 분기 필요 → 별도 트랙.

## Do NOT

- SwiftUI Template 수치만 인용해서 production commit.
- SwiftUI Template 을 ProofPhoto P4-2 의 추가 검증으로 사용 (이미 KEEP).
- Pass 3 / Pass 4 에서 SKIP 된 commit 을 SwiftUI Template 수치만으로 revive.
- production app build 또는 Auth / Onboarding 시나리오로 확장.
- XCTest wall time 을 SwiftUI optimization evidence 로 인용.

## Recommended first task (when this track starts)

1. `xcrun xctrace help record 2>&1 | less` — actual syntax 확인.
2. `xcrun xctrace list templates` — `SwiftUI` template 존재 재확인.
3. ProofPhoto preview-large 1회 trial recording (driver 없이 launch + ready marker).
4. trace bundle 에 SwiftUI table 있는지 `mcp__xctrace-analyzer__analyze_trace` 로 검증.
5. 성공 시 사용자에게 보고 후 Phase S2 진입 승인 요청.

Pass 4-S 진입 시점은 사용자 결정.
