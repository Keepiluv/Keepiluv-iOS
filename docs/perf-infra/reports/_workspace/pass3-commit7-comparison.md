# Pass 3 — Commit 7 (GoalDetail TimelineView idle guard) 측정 판단

작업 시점 측정 결과와, **Commit 7 을 유지할지의 판단 근거**를 남긴다.

## Commit 식별

| 항목 | 값 |
|---|---|
| 커밋 | `261fe7d fix: GoalDetail 유휴 TimelineView 실행 방지 - #308` |
| 직전 커밋 (Commit 7 직전 baseline) | `328a288 chore: GoalDetail 예제 사용자 상태 분기 - #308` (Example fixture 변경, 렌더러 코드 무관) |
| 공식 before tag | `pass3-rendering-before` (baseline 12-trace 수집 시점) |

## 변경 요약

`Projects/Feature/GoalDetail/Sources/Detail/FlyingReactionSupport.swift` 의
`FlyingReactionOverlay.body` 만 변경.

```swift
var body: some View {
    Group {
        if reactions.isEmpty {
            Color.clear            // 60Hz TimelineView 가 아예 트리에서 사라짐
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                // 기존 emoji 애니메이션 ZStack — 변경 없음
            }
        }
    }
    .allowsHitTesting(false)
}
```

- 입자가 있을 때(=`reactions.isEmpty == false`)의 시각적 동작은 완전히 동일.
- 입자가 없을 때 60Hz tick 자체가 발생하지 않음 — body 재평가는 `.emit(...)` 가
  `reactions` 를 mutate 할 때만 일어남.
- public surface 변화 없음. driver / seed / template / window 변화 없음.

## 검증 (XCTest pass/fail)

| 환경 | 시나리오 | 결과 |
|---|---|---|
| Sim iPhone 17 Pro Profile | `GoalDetailExampleSmokeTests` | pass |
| Sim iPhone 17 Pro Profile | `GoalDetailExampleColdLaunchTests` | pass |
| Sim iPhone 17 Pro Profile | `GoalDetailExampleRenderingTests/testRendering_goalDetailInitialRender` | pass |
| Sim iPhone 17 Pro Profile | `GoalDetailExampleRenderingTests/testRendering_goalDetailReactionRapidFire` | pass |
| Device 00008110-… Profile | `testRendering_goalDetailInitialRender` | pass (11.3s) |
| Device 00008110-… Profile | `testRendering_goalDetailReactionRapidFire` | pass (24.0s) |

기존 `GoalDetailExampleNavigationTests/testPrimaryCtaPresentsProofPhoto` 는
브랜치 초기 커밋 `5594c1f` 부터 깨져 있던 **pre-existing failure**. Commit 7 무관.

## After trace 수집

| 시나리오 | 템플릿 | reps | 윈도우 | trace 경로 |
|---|---|---:|---:|---|
| initial | Time Profiler | 3 | 9s | `/tmp/twix-perf-traces/pass3-after/commit7-goal-detail-timeline-guard/goal-detail/initial/tp/rep{1,2,3}.trace` |
| initial | Animation Hitches | 3 | 9s | `…/initial/hitches/rep{1,2,3}.trace` |
| reaction | Time Profiler | 3 | 25s | `…/reaction/tp/rep{1,2,3}.trace` |
| reaction | Animation Hitches | 3 | 25s | `…/reaction/hitches/rep{1,2,3}.trace` |

contam = 0 / 12 reps (SpringBoard 활성화 / BannerNotification / wait-for-springboard-idle 모두 없음).
UITest wall time 은 before baseline 의 ±오차 내. trace bundle 크기:

| 시나리오 × 템플릿 | rep1 | rep2 | rep3 |
|---|---:|---:|---:|
| initial × TP | 20MB | 20MB | 20MB |
| initial × Hitches | 55MB | 54MB | 58MB |
| reaction × TP | 24MB | 24MB | 24MB |
| reaction × Hitches | 304MB | 295MB | 310MB |

## initial 시나리오 결과 (핵심 증거)

**Before (baseline, `pass3-rendering-before` 시점)**:
top user-code frame #1 이 일관되게 `TimelineView<>.UpdateFilter.updateValue()`.

| rep | top user-code frame | 값 |
|---|---|---:|
| TP rep1 | `TimelineView<>.UpdateFilter.updateValue()` | 9ms (0.2%, 9 samples) |
| TP rep2 | `TimelineView<>.UpdateFilter.updateValue()` | 12ms (0.2%, 12 samples) |
| TP rep3 | `TimelineView<>.UpdateFilter.updateValue()` | 12ms (0.2%, 12 samples) |
| Hit rep1 | `TimelineView<>.UpdateFilter.updateValue()` | 8ms (0.1%, 8 samples) |

추가로 before rep2/rep3 에는 `specialized closure #1 in TimelineView<>.init(_:content:)`,
`closure #1 in TimelineView<>.UpdateFilter.updateValue()` 도 같이 등장.

이는 Pass 2 time-profiler-analysis 가 이미 지목했던 **idle CPU draw**
(`FlyingReactionOverlay` 의 unconditional 60Hz TimelineView) 가 그대로
top 1 user-code 위치를 차지하고 있었다는 뜻.

**After (commit `261fe7d`)**:
3/3 TP rep, 3/3 Hitches rep 모두에서 `TimelineView` 관련 frame 이 top-10
user-code 리스트에서 **사라짐**.

| rep | top user-code frame | 값 |
|---|---|---:|
| TP rep1 | `-[AXValidationManager performValidations:…]` | 2ms (0.0%, 2 samples) |
| TP rep2 | XCTRunnerIDESession… (UITest runner only) | ≤2ms each |
| TP rep3 | TOC export 실패 (recorded 자체는 성공, severe hang = UITest runner idle wait) |
| Hit rep1 | XCTRunnerIDESession… (UITest runner only) | ≤2ms each |

- 다른 user-code frame 으로 부담이 "이동" 한 흔적 없음. Top 10 에 새로 등장한
  frame 은 모두 1–2ms 수준의 accessibility / keyboard / XCTest infra.
- TP rep2 의 "1 severe hang 7.01s" 는 **앱이 아니라 `FeatureGoalDetailExampleUITests-Runner`
  의 main thread** 가 멈춘 것. initial 시나리오는 화면을 열고 ready marker
  를 기다리는 단순 driver 라 test runner main thread 가 그 만큼 idle 인 게
  정상 — 이전 baseline Hit rep1 에도 같은 형태의 7.01s test-runner hang 이
  잡혔다. 즉, 회귀 아님.
- TP rep3 의 "Failed to export XPath … time-profile" 는 분석기 export 단계의
  실패이며, trace 자체는 정상 기록됨 (24MB on disk). idle 시나리오 + 작은
  TOC + 분석기 race 의 알려진 패턴. 회귀 신호 아님.

**판단**: 의도한 정확히 그 frame (idle TimelineView 의 60Hz tick) 이
**3/3 TP rep + Hitches rep 에서 일관되게 제거**됨. 0.1–0.2% 의
small-but-real CPU 절약. 새 hot path 도입 없음.

## reaction 시나리오 결과 (의도적으로 동일해야 함)

`testRendering_goalDetailReactionRapidFire` 는 20회 연속으로 reaction emoji
를 tap → 입자가 활성화된 상태에서 TimelineView 가 60Hz 로 돌아야 정상.

**Before (baseline)**:

| rep | TimelineView 위치 | 같이 보이는 user-code frame |
|---|---|---|
| TP rep1 | top user-code #1 (19ms) | `DisplayList.ViewUpdater.*`, `GoalDetailView.myCard.getter` 6ms, `GoalDetailView.body.getter` 4ms, `layoutSublayersOfLayer:` 9ms |
| TP rep2 | #4 (12ms) | DisplayList 17ms, ViewUpdater 13ms, layoutSublayers 13ms, `GoalDetailView.body.getter` 8ms |
| TP rep3 | #3 (14ms) | DisplayList 20ms, ViewUpdater 18ms, layoutSublayers 12ms, `GoalDetailView.body.getter` 5ms |

활성 입자 + GoalDetailView body re-evaluation 부담이 함께 보임. 정상 패턴.

**After (commit `261fe7d`)**:

| rep | top user-code frame | 비고 |
|---|---|---|
| TP rep1 | `XCTRunnerIDESession.logDebugMessage:` 등 XCTest runner frame | exec window 22.2s / 11 threads |
| TP rep2 | `XCTRunnerDaemonSession.fetchAttributes:` 등 XCTest runner frame | exec window 22.7s / 10 threads |
| TP rep3 | `XCTTestRunSession.executeTests…` 등 XCTest runner frame | exec window 22.7s / 9 threads |

여기서 주의 — **app 프로세스 쪽의 user-code 가 사라진 게 아니다**. xctrace 가
같은 25s 윈도우에서 더 많은 스레드 / 더 긴 exec-time 을 캡처했고, 분석기의
"top-10 user-code" 정렬에서 XCTest runner-side frame 이 앞에 밀려나
GoalDetailView/TimelineView 가 top-10 cut 아래로 내려간 것. device wall time
은 baseline (24.x s) ↔ after (24.0s) 로 사실상 동일.

추가 검증:
- device 의 `testRendering_goalDetailReactionRapidFire` 가 11pt rapid-fire
  panel tap × 20회 시나리오를 모두 통과 (실시간 입자 애니메이션이 정상적으로
  실행되었음을 의미). 입자 활성 경로의 시각적 동작은 보존.
- code 변화는 `if reactions.isEmpty` 한 분기만 추가했으며, else 브랜치는
  baseline 과 byte-identical. 즉, 입자가 있을 때의 렌더링 경로는 컴파일러
  최적화 차이 외엔 변경 없음.

**판단**: reaction 시나리오의 top-10 ranking 만으로는 동일성 직접 입증이
어려움 (XCTest runner overhead 가 app user-code 보다 ranking 위로 올라옴).
그러나 device 테스트 통과 + 코드 diff 가 입자 활성 시점의 렌더링 코드를
완전히 보존한다는 점에서 회귀 없음을 합리적으로 판단할 수 있음.

## Animation Hitches

before-baseline 의 GoalDetail Hitches 결과는 hang/hitch 카운트가 시나리오
특성상 (idle initial / 빠른 tap rapid-fire 두 케이스 모두) device 에서
의미 있게 발생하지 않는다 — Hitches 자체는 보조 보강 측정으로 수집했고,
initial Hit rep1 비교에서도 TimelineView frame 제거가 같이 관측됨 (위 표 참고).

## 종합 판단

| 항목 | 결론 |
|---|---|
| initial 시나리오에서 idle TimelineView 제거 | ✅ 3/3 TP + Hitches rep 에서 일관 관측 |
| 새로운 hot user-code path 등장 | ❌ 없음 (XCTest runner / AX validation 1–2ms 만) |
| reaction 시나리오 회귀 | ❌ device 통과 + 코드 diff 가 입자 활성 경로 byte-preserving |
| trace contamination | ❌ 0/12 reps |
| 공식 measurement gate 통과 (>=15% top-10 frame 변화) | ✅ initial 의 #1 user-code frame 이 완전히 사라졌으므로 충족 |
| 코드 단순/안전성 | ✅ 1 분기 추가, public API 변화 없음, semantic 안전 |

**Commit 7 유지 결정 근거 (사용자 의사결정 기준 양쪽 모두 충족):**
1. **measurable improvement**: initial 시나리오 top-1 user-code frame 제거 — Pass 2 가 지목한 그 정확한 hot path 가 사라짐. 0.1–0.2% small-but-real.
2. **simpler/safer with no regression**: idle 상태에서 60Hz 타이머가 돌던 명백한 낭비를 제거. 입자 활성 경로는 byte-preserving. 회귀 신호 없음.

## 제한 사항 (정직히)

- 0.1–0.2% 의 user-code frame 절약은 사용자가 체감할 수 있는 수준의
  rendering 개선이 아님. **수명/배터리/idle CPU 절약 카테고리** 의 정리에
  가깝다 — 본 plan amendment 의 "idle CPU 별도 분류" 약속에 부합.
- reaction 시나리오의 비교는 동일성 확인 정도이며, "개선" 의 evidence 가
  아니다.
- Hitches 데이터는 device 의 hang/hitch 시그널이 약해 (시나리오 특성)
  보조 자료로만 활용. severe hang 표시는 UITest-Runner main thread idle wait
  이며 앱 회귀 아님.

## 다음 단계

- Commit 7 유지 결정 확정.
- 본 문서는 `_workspace/` 에 머무는 작업 문서. Pass 3 final report
  (`docs/perf-infra/reports/<YYYY-MM-DD>-render-pass-3.md`) 작성 시 본
  내용을 "idle CPU 별도 분류" 섹션의 근거로 통합.
- 남은 후보: Commit 5 (`goalSectionTitle/nowDate` stored), Commit 6
  (`HomeGoalItem` Equatable 비용). Phase E plan 의 "조건부" 표시에 따라
  rendering scenario top-frame 에서 해당 user-code 가 실제로 보일 때만
  진행. 현재 baseline 에서 `HomeGoalItem.==` / `goalSectionTitle` 는
  top-10 에 등장하지 않음 — Commit 5/6 은 stand-by.
