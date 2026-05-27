# Pass 3 — Commit 6 (재정의) 사전 조사 보고서

원래 Commit 6 = `HomeGoalItem equality 비용 감소` 의 범위를 사용자 지시로
넓혀 **Home card rendering / GoalCardView input stability optimization**
로 재정의. 구현 전 read-only 조사로 구체적 + 측정 가능한 candidate 가
있는지 검증.

## Home card rendering investigation

### Files inspected

- `Projects/Feature/Home/Sources/Home/HomeView.swift`
  - `HomeContentSection` (155–198)
  - `cardList` (173–182)
  - `goalCard(for:)` (184–197)
- `Projects/Feature/Home/Interface/Sources/Home/HomeGoalItem.swift` (전체)
- `Projects/Feature/Home/Interface/Sources/Home/HomeReducer.swift` (`items`
  declaration at line 40, derived `hasCards` / `isEmptyVisible` 52–53)
- `Projects/Feature/Home/Sources/Home/HomeReducer+Impl.swift`
  - `state.items` mutation sites (305, 319–320, 360–362, 387, 439, 472,
    fetch path)
- `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardView.swift` (전체)
- `Projects/Shared/DesignSystem/Sources/Components/Card/Goal/GoalCardItem.swift` (전체)
- `Projects/Shared/PerfTestingSupport/Sources/View+PerfAccessibility.swift`
  (`perfCell` / `perfFeed` 21–27)

추가 trace 검증:
- baseline Home feed-scroll TP rep1
  (`/tmp/twix-perf-traces/pass3-official-before/home/feed-scroll/tp/rep1.trace`)
- after-Commit 3 Home feed-scroll TP rep1
  (`/tmp/twix-perf-traces/pass3-after/commit3-home-readset/home/feed-scroll/tp/rep1.trace`)

### Current rendering path

```
HomeView.body
└── if store.hasCards
    └── HomeContentSection (private, owns the card list read-set)
        └── ScrollView
            └── cardList
                └── LazyVStack(spacing: 16)
                    └── ForEach(store.items) { item in           // ID = item.id (Int64)
                          goalCard(for: item)
                            .perfCell(slug: "home", stableId: item.id)  // accessibilityIdentifier만
                        }

goalCard(for:) → GoalCardView(
    item: item.card,                              // GoalCardItem (Equatable)
    onHeaderTapped:     { store.send(.headerTapped(item.card)) },
    onCheckButtonTapped:{ store.send(.goalCheckButtonTapped(id: item.id, isChecked: …)) },
    actionLeft:         { store.send(.myCardTapped(item.card)) },
    actionRight:        { store.send(.yourCardTapped(item.card)) }
)

GoalCardView.body
├── VStack
│   ├── CardHeaderView(title: item.goalName, iconImage: item.goalEmoji, isBordered: !my && !your, onTap: …) { TXCheckButton(...) }
│   └── if myCard.isSelected || yourCard.isSelected
│       └── HStack { myContent | borderLine | yourContent }.background(...)
├── .clipShape(RoundedRectangle)
└── .outsideBorder(...)

myContent / yourContent
└── contentCell(item:, placeholder:, …)
    ├── if let imageURL { KFImage(imageURL).resizable().placeholder{}.scaledToFill().frame(...).clipped() }
    │  else            { unCompletedView(...).frame(...) }
    ├── .clipShape(UnevenRoundedRectangle(...))
    ├── .contentShape(Rectangle())
    └── .overlay(alignment: .bottomTrailing) { if let emoji { emojiImage(emoji:) } }
```

#### `store.items` mutation pattern

```text
state.items = …              fetchGoalsCompleted (305–320), fetchGoals cache hit (360–362)
state.items[i].updateGoal(_) goalCheckResponse 류 (439, 472)
updatePokeButtonDisabled(in: &state.items, …)  poke side-effect (387)
```

스크롤 자체는 어떤 action 도 dispatch 하지 않음
(`HomeExampleFeedScrollRenderingTests` 의 driver 는 `swipeUp` × N 만 함).
따라서 **60s feed-scroll 측정 윈도우 동안 `state.items` 는 mutate 되지 않으며,
`HomeContentSection.body` 도 re-evaluate 되지 않는다**. LazyVStack 이 새
cell 을 viewport 안으로 materialize 할 때만 `goalCard(for:)` 가 호출됨.

### Trace evidence (key)

#### Home feed-scroll TP rep1 — top 10 user-attributed frames

| baseline (`pass3-rendering-before`) | after-Commit 3 (`d6482c9`) |
|---|---|
| `layoutSublayersOfLayer:` 66ms (0.1%) | `layoutSublayersOfLayer:` 71ms (0.1%) |
| `DisplayList.ViewUpdater.Platform.updateItemView` 20ms | `__updateContentOverlayInsetsWithOurRect:` 21ms |
| `__updateContentOverlayInsetsWithOurRect:` 20ms | `DisplayList.ViewUpdater.Platform.updateItemView` 21ms |
| `DisplayList.ViewUpdater.updateInheritedView` 19ms | `DisplayList.ViewUpdater.updateInheritedView` 20ms |
| `HostingScrollView.updateContext` 17ms | `_contentScrollViewHeuristic` 19ms |
| `setContentOffset:` 15ms | `setContentOffset:` 18ms |
| `_contentScrollViewHeuristic` 13ms | `HostingScrollView.updateContext` 17ms |
| `_updateContentOverlayInsetsFromParentIfNecessary` 13ms | `setFrame:` 14ms |
| `UpdatedHostingScrollView.updateValue` 12ms | `_updateContentOverlayInsetsFromParentIfNecessary` 12ms |
| `_updatePanGesture` 12ms | `_updatePanGesture` 11ms |

**GoalCardView / GoalCardItem / HomeGoalItem / HomeContentSection / cardList /
goalCard 어느 user-code frame 도 top 10 에 등장하지 않음** (top 20 까지
확장해도 동일). before/after 두 trace 모두 동일 패턴 — 100% UIKit + SwiftUI
framework 가 점유.

baseline doc 의 sum-of-top-10 ≈ 200ms / 50s ≈ **0.4 % of trace** — 측정
가능한 user-code 절감 여지가 ~0.4% 의 일부에 불과. noise floor ±10.4% 와
비교 불가능한 크기.

### Potential optimization candidates

| candidate | expected benefit | risk | measurable scenario | proceed / skip |
|---|---|---|---|---|
| **A. `GoalCardView: Equatable` + `EquatableView`** (parent body 재평가 시 동일 input 의 card subtree diff 생략) | scroll 중에는 parent body 재평가가 없어 효과 없음. fetch/update 후 첫 cascade 때만 부분적 효과 가능 | 4개 closure (`onHeaderTapped` 외) 는 Equatable 불가 → custom `==` 필요 (closures 무시), 향후 closure 변경 누락 시 stale UI 발생 위험 | 측정 가능한 시나리오 없음 (baseline 에 GoalCardView body 없음) | **skip** |
| **B. `HomeGoalItem` 에서 `goal: Goal` 제거** (id + card 만 남기고 Goal 은 별도 dictionary 로) | `state.items != items` 비교 비용 감소. fetch path 에서만 효과 | 큰 리팩터링 — `state.items[index].goal` 읽는 reducer 모든 사이트 (line 421, 454 등) 변경. State shape 영향. closure 캡처 hashmap 동기화 필요 | feed-scroll 시나리오 측정 윈도우에 `==` 자체가 등장 안 함 | **skip** (시나리오 mismatch) |
| **C. closure 캡처 줄이기** (per-cell context 객체 1개로 통합) | closure 4개 → 1개 reference. 마이크로 절약 | 코드 복잡도 증가. View prop 변경. SwiftUI diff 거동 변화 위험 | 측정 불가 (capture 자체가 top frame 아님) | **skip** |
| **D. `unEvenRoundedRect` / `placeholder` 캐싱** | 트리비얼한 struct init 제거 | 거의 없음 | 측정 불가 | **skip** |
| **E. `HomeGoalItem.makeCard(from:)` 의 `URL(string:)` 캐싱** | imageURL 재계산 비용 감소 | fetch path 에서만 호출되고 body path 와 무관 | feed-scroll 측정 윈도우에 호출 안 됨 | **skip** |
| **F. KFImage 설정 / placeholder 정리** | image pipeline 절약 가능 | 본 phase 에서 ProofPhoto image pipeline 최적화 금지 제약과 충돌 | 별도 측정 필요 | **skip** (constraint 위반) |
| **G. `goalEmoji: Image` 자산 캐싱** | 이미 `HomeGoalItem.makeCard(from:)` 시점에 한 번만 매핑됨 (body path 아님) | 없음 | 이미 최적 | **skip** |

추가로 검토한 가설:
- "GoalCardView body 가 selection 변화 시 무거운 derived work 한다" → 검사
  결과 `myCard.isSelected || yourCard.isSelected` 분기 정도. expensive
  derivation 없음.
- "Image asset / icon mapping 이 body 마다 반복" → `GoalIcon(from:).image`
  는 `HomeGoalItem.makeCard(from:)` 에서 한 번만 매핑되어 `goalEmoji` 로
  stored. body 에서 재계산 안 함.
- "ForEach identity 불안정" → `HomeGoalItem: Identifiable, id: Int64 =
  goal.id`. 안정.
- "LazyVStack materialization 자체 비용" → SwiftUI framework 영역
  (`DisplayList.ViewUpdater.Platform.updateItemView`). user-code 가
  아니라 framework 비용. 다음 단계 candidate 가 아님 (Pass 3 에서 우리가
  손댈 영역 아님).

### Recommendation

**2. skip Commit 6 because no concrete measurable candidate exists.**

근거:
1. baseline + Commit 3 after 양쪽 trace 의 top-20 user-code 에 GoalCardView /
   HomeGoalItem / GoalCardItem / HomeContentSection / cardList / goalCard
   관련 frame 이 **0건**. Pass 2 부터 누적된 패턴 (cold launch top frame 의
   95%+ 는 framework, Home feed-scroll top user-code sum ≈ 0.4 %) 의 연장.
2. feed-scroll 측정 윈도우 동안 `state.items` 는 mutate 되지 않아 parent
   body re-evaluation 이 일어나지 않는다. 따라서 `EquatableView` 형태의
   diff-skip 최적화도 적용될 트리거 자체가 측정 윈도우에 없음. 효과를
   재현하려면 새 시나리오 (예: fetch 직후 60s 스크롤) 가 필요한데 본
   Phase 의 scope 변경 금지 제약과 충돌.
3. closure 4개 input 으로 인해 `EquatableView` 는 custom `==` (closure 무시)
   가 필수. 향후 closure semantic 변경을 누락하면 stale UI 가 발생할 수
   있어 **structural risk** 가 분명한 반면, **measurable upside 는 없음**.
4. `HomeGoalItem.goal` 제거 같은 더 큰 리팩터링은 fetch path 에만 영향
   주는데 그 path 는 측정 시나리오에 포함되지 않음. attribution 만 더
   어려워짐.
5. baseline 의 top-10 user-code sum 이 trace 의 ~0.4 % 라는 사실이 결정적.
   이 한도 안에서 GoalCardView 만 절감해도 noise floor ±10.4% 와 비교
   불가능.

### 별도 결정 — Pass 3 final report 에 어떻게 기록할지

- Commit 6 은 plan 의 우선순위 #2 였으나 **본 조사 결과에 따라 skip**.
  Plan amendment C 의 "별도 조사 후 진행 여부 결정" 조건을 충족해 close.
- Final report (`docs/perf-infra/reports/<YYYY-MM-DD>-render-pass-3.md`)
  의 "considered but skipped" 섹션에 다음을 기록:
  - 후보: GoalCardView Equatable / HomeGoalItem.goal 분리 / closure 캡처
    축소 / image URL 캐싱.
  - 사유: baseline + Commit 3 after trace 양쪽에서 user-code 가 top-20 에
    등장하지 않음. measurable upside 없음. 일부 후보는 structural risk
    (stale UI / 리팩터링 surface) 가 명확.
- Pass 3 plan 의 우선순위 표는 본 결정을 반영해 Commit 6 을 "조사 후
  skip" 으로 close, Commit 4 / Commit 5 는 기존대로 hold/stand-by.

### What this investigation does NOT cover (정직히)

- **Production HomeView 의 모든 실 사용 경로**: 본 조사는 dedicated
  rendering scenario (home-heavy feed scroll) 에 한정. 실제 사용 환경의
  intermittent fetch + scroll mix 패턴은 별도 시나리오로만 검증 가능.
  이번 Pass 의 scope 가 아니므로 본 결론을 "Home 카드는 어떤 환경에서도
  최적이다" 로 일반화하지 말 것.
- **SwiftUI template 의 view-tree-internal cost**: Time Profiler 는
  framework 함수 단위까지만 attribution. SwiftUI 내부의 view-tree diff /
  attribute update 비용은 SwiftUI template recording 으로만 분리 가능
  (현 Pass 의 Phase 2 follow-up).
- **device thermal / 다른 cold start condition**: 본 데이터는 안정된 device
  상태 + Profile build + 정해진 driver 시나리오 기준.
