# Smell Inventory — Home / Stats / GoalDetail

작성일: 2026-05-17
범위: `Projects/Feature/{Home,Stats,GoalDetail}/{Sources,Interface/Sources}`
출처: 정적 스캔 only (Phase 1). **측정 데이터로 검증되지 않은 휴리스틱 후보** — Phase 3 baseline trace 와 cross-check 후 최종 fix 대상 확정.

## 기준 (Phase 0 확정 8개)

1. **거대 body**: `var body` 30+ statements 또는 파일 200+ lines
2. **AnyView** inline 사용 (Factory 패턴 제외)
3. **IfLetStore** (TCA 1.7+ deprecated)
4. **ForEach** stable id 누락
5. **광범위 WithViewStore / Store observation**
6. **body 안 `store.scope` 또는 expensive computed property**
7. **`@StateObject`/`@ObservedObject` ObservableObject** (TCA 환경 anti-pattern)
8. **body 경로 무거운 computed property** (날짜 포맷/정렬/필터)

`✓` = smell 확인, `–` = 해당 없음, `?` = 검증 필요(Phase 3 데이터 의존).

## View / Coordinator 인벤토리

| File | 1. body | 2. AnyView | 3. IfLetStore | 4. ForEach key | 5. WithViewStore | 6. body scope/heavy | 7. ObservableObject | 8. heavy computed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Home/Sources/Root/HomeCoordinatorView.swift | ✓ (body 92 lines, ~50+ stmt, 9 case switch) | – | ✓ (lines 54, 60, 66, 72) | – | – | ✓ (body 안 `store.scope` 12회. settings scope 5번 중복 호출) | – | – |
| Home/Sources/Home/HomeView.swift | ✓ (body 61 lines, 10+ modifier chain) | – | ✓ (line 93, proofPhoto fullScreenCover) | – (ForEach store.items: Identifiable) | – | – (scope 1회만, fullScreenCover content) | – | – |
| Home/Sources/Goal/EditGoalListView.swift | ✓ borderline (body 46, 10+ modifier chain) | – | – | – (ForEach store.cards: Identifiable) | – | – | – | – |
| Home/Sources/Goal/AddGoalListView.swift | – (body 7) | – | – | – (`\.self` on `GoalCategory` enum — stable) | – | – | – | – |
| Stats/Sources/Coordinator/StatsCoordinatorView.swift | – (body 26) | – | ✓ (lines 46, 52, 58) | – | – | ✓ (body 안 `store.scope` 4회) | – | – |
| Stats/Sources/Stats/StatsView.swift | – (body 26) | – | – | – (`id: \.self.goalId` — explicit stable) | – | – | – | – |
| Stats/Sources/Detail/StatsDetailView.swift | ✓ (body 49 + 273 lines, 10+ modifier chain) | ✓ (line 117 — inline `AnyView(dateImageBackground(...))` in calendar `dateCellBackground:` closure, 셀당 1회) | – | – (`id: \.title` — 안정적이라 가정) | – | ✓ (body 경로 `completedDate(for:)` → `formattedAPIDateString()` + dict lookup, 캘린더 셀당 1회) | – | ✓ (`completedDate(for:)` Phase 6 의 일부, 셀 N개 × 매 render) |
| GoalDetail/Sources/Detail/GoalDetailView.swift | ✓ (body 55 + 579 lines, 12+ modifier chain) | – | ✓ (line 103, proofPhoto fullScreenCover) | – | – | – (scope 1회만) | ✓ (`@StateObject myEmojiFlyingReactionEmitter`, line 38) | – borderline (`isSEDevice` reads `UIScreen.main.bounds.height` — 저렴하지만 modifier 인자에서 호출됨) |
| GoalDetail/Sources/Detail/ReactionBarView.swift | – (body 17) | – | – | – (`\.self` on `ReactionEmoji` enum — stable) | – | – | ✓ (`@StateObject flyingReactionEmitter`, line 16) | – |
| GoalDetail/Sources/Detail/FlyingReactionSupport.swift | – (FlyingReactionOverlay body 14) | – | – | – | – | – | – (`FlyingReactionEmitter` 정의 자체. ObservableObject 클래스이지만 selection criterion 7 은 "deep hierarchy 에 퍼진 사용처" 기준) | – |

## 확정 fix 후보 (smell 확실 + 영향 큼)

A. **HomeCoordinatorView IfLetStore × 4 + 중복 scope**
   - `IfLetStore` 4건은 `@Bindable store` 기반 `if let store = store.scope(...)` 패턴으로 치환 (이미 settings/notification case 들이 같은 패턴 사용)
   - settings scope 5번 중복 호출은 switch 바깥에서 한 번 unwrapping 후 sub-case 처리로 정리 가능. 단 case 별 destination 이 달라 코드 가독성과 trade-off 가 있으므로 baseline 후 영향 확인 후 결정

B. **HomeView IfLetStore × 1 (line 93)**
   - 단일 IfLetStore → `if let scopedStore = store.scope(...)` 치환. 기계적 작업

C. **GoalDetailView IfLetStore × 1 (line 103)**
   - 동일 패턴

D. **StatsCoordinatorView IfLetStore × 3**
   - 동일 패턴

E. **StatsDetailView inline AnyView (line 117) + body 경로 heavy method**
   - `dateCellBackground:` 가 캘린더 셀당 호출. 현재 closure 가 `AnyView` 로 type-erase 하고 `completedDate(for:)` 가 매번 dict 조회 + String 포맷팅
   - 개선 1: `dateCellBackground:` 의 closure signature 자체가 `AnyView` 를 요구한다면 (TXCalendar API), 그건 디자인시스템 쪽이라 이번 범위 밖. 디자인시스템 API 가 generic 받으면 AnyView 제거 가능 — 확인 필요
   - 개선 2: `store.completedDateByKey` 가 이미 dict 라면 `formattedAPIDateString()` 캐싱 또는 `[Components: ImageBackground]` precompute 로 셀당 비용 절감
   - **이건 측정으로 우선 확인** (Phase 3 trace 에서 hot 으로 나오면 fix)

F. **`@StateObject FlyingReactionEmitter` × 2 (GoalDetailView, ReactionBarView)**
   - `FlyingReactionEmitter` 는 `@Published reactions: [...]` 를 가진 ObservableObject. 사용처는 overlay 의 `FlyingReactionOverlay(reactions: emitter.reactions, ...)` 형태로 단일 child 에 전달
   - SwiftUI 가 `@StateObject` change 를 owner View body 전체로 전파 → ReactionBarView/GoalDetailView body 가 reactions 배열 갱신마다 재계산
   - 개선: `FlyingReactionEmitter` 를 `@Observable` (Swift 5.9+, iOS 17) 로 전환하면 unused property 변경은 body 재계산을 일으키지 않음. 단 본 클래스가 `@Published reactions` 하나만 노출하므로 효과는 제한적
   - 대안: `reactions` 를 `@State` 로 분리 + emit 함수를 free function/struct 로 — 큰 변경
   - **측정 우선** (Phase 3 의 `_printChanges()` 로 body 재계산 횟수 확인 후 결정)

## 잠재 후보 (측정 의존, 회색 영역)

- **HomeView body 의 modifier 체인 10+**: cold launch / scroll 둘 다에서 보일 가능성. 측정에서 SwiftUI body slot 비중이 높으면 일부 modifier 를 sub-view 로 분리해볼 만함
- **GoalDetailView 의 modifier 체인 12+ 및 다수 `@State`**: 6개 `@State` + 1개 `@StateObject`. cold launch 비용 확인 대상
- **`isSEDevice` (UIScreen.main 접근)**: body 안 두 곳 사용. 매번 main thread bound. 측정에서 보이면 init 시 1회 캐싱

## Smell 아닌 것 확인됨

- **WithViewStore**: 0건. 프로젝트는 `@ObservableState` + `@Bindable store` 모던 패턴. State observation 광범위 smell 없음
- **ForEach key 누락**: 모든 ForEach 가 Identifiable 또는 stable id 사용. enum `\.self` 사용분도 Hashable enum 이라 안정
- **Factory 패턴 AnyView (GoalDetailFactory, StatsDetailFactory, *Factory+Live)**: 아키텍처 결정. 이번 범위 밖
- **`FlyingReactionEmitter` 클래스 정의 자체**: ObservableObject 이지만 사용처 fan-out 이 좁아 criterion 7 의 "deep hierarchy 광범위 구독" 에 해당 안 됨. (단 owner View body 재계산은 criterion 6/7 의 그레이 영역으로 위 F 에 다시 잡혔음)

## 다음 단계 의존성

- A, B, C, D (IfLetStore deprecation 4 파일 9 건) — Phase 3 baseline 후 fix 진입. trace 없이도 기계적이라 안전한 1차 후보.
- E, F — Phase 3 baseline 의 Top User-Code Frame 및 `_printChanges()` 결과를 본 뒤 진입.
- 잠재 후보 — 측정 결과 hot 으로 나올 때만 진입.
