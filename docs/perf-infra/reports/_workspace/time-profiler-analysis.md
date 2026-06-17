# Phase 7 — Time Profiler 분석

git: `e786fc9` (post-Pass 1)
device: Jiyong의 iPhone (iOS 26.4.2, UDID `00008110-00096DC42632801E`)
recorded: 2026-05-17

## Trace 파일

| Feature | Trace | 총 실행 시간 | 스레드 수 |
|---|---|---|---|
| Home | `org.yapp.twix.example.home-cpu-2026-05-17T06-38-41-872Z.trace` | 6.6 s | 14 |
| Stats | `org.yapp.twix.example.stats-cpu-2026-05-17T06-39-32-774Z.trace` | 6.4 s | 10 |
| GoalDetail | `org.yapp.twix.example.goal-detail-cpu-2026-05-17T06-40-02-822Z.trace` | 7.1 s | 11 |

trace root: `/Users/<redacted>/Library/Application Support/xctrace-analyzer/traces/`

캡처 방법: `mcp__xctrace-analyzer__profile_running_app` (preset=`cpu`, 즉 Time Profiler 단독). launch arguments `-UITEST -UITEST_SEED default -UITEST_DISABLE_ANIMATIONS -UITEST_WAIT_READY`. 6초 윈도우.

## 핵심 결론 — 시스템 한계

3개 trace 모두에서 **user-code top frame 이 모두 1–7 ms (전체 sample 의 0.0–0.1%)**. 코드에서 cold launch wall clock 의 ≥15% 를 줄일 여지가 없음.

| Feature | Top user-code frame | 시간 | 비중 |
|---|---|---|---|
| Home | `HomeView.body.getter` | 3 ms | 0.0% |
| Stats | `NavigationStackRepresentable.makeUIViewController(context:)` | 2 ms | 0.0% |
| GoalDetail | `TimelineView.UpdateFilter.updateValue()` | 7 ms | 0.1% |

전체 user-code top 10 frame 의 합산은 각 Feature 당 ~10–20 ms. 3.5 s wall clock 의 <1%.

### Top 10 — Home

```
Layout.makeLayoutView(root:inputs:body:)          3ms (system: SwiftUI)
HomeView.body.getter                              3ms (user)
DisplayList.ViewUpdater.updateInheritedView       2ms (system: SwiftUI)
AppleJPEGReadPlugin::copyIOSurfaceImp             2ms (system: ImageIO / launch screen 디코드)
+[_UISceneUserActivityManager _deleteSavedScene…] 2ms (system: UIKit scene)
type metadata accessor for HomeCoordinatorView    1ms (system: Swift runtime)
-[UISApplicationSupportClient applicationInit…]   1ms (system: UIKit)
-[FBSWorkspaceScenesClient initWithEndpoint…]     1ms (system: FrontBoard)
+[UIKeyboardSceneDelegate automaticKeyboard…]     1ms (system: UIKit)
-[FBSWorkspaceScenesClient _callOutQueue…]        1ms (system: FrontBoard)
```

### Top 10 — Stats

```
NavigationStackRepresentable.makeUIViewController 2ms (user: TCA wrapper)
Layout.makeLayoutView(root:inputs:body:)          2ms (system: SwiftUI)
specialized ColorProvider._apply(color:to:)       2ms (system: SwiftUI)
UIHostingController.preferencesDidChange(_:)      2ms (system: UIKit)
DisplayList.ViewUpdater.updateInheritedView       2ms (system: SwiftUI)
+[_UISceneUserActivityManager _deleteSavedScene…] 2ms (system)
dyld4::FileRecord::FileRecord                     1ms (system: dyld)
+[UIView initialize]                              1ms (system: UIKit)
type metadata accessor for StatsCoordinatorView   1ms (system: Swift runtime)
-[UISApplicationSupportClient applicationInit…]   1ms (system)
```

### Top 10 — GoalDetail

```
TimelineView<>.UpdateFilter.updateValue()         7ms (user: FlyingReactionOverlay TimelineView)
closure #1 in GoalDetailView.body.getter          2ms (user)
closure #1 in GoalDetailView.cardView.getter      2ms (user)
-[UIView(Internal) _addSubview:positioned:…]      2ms (system: UIKit)
+[_UISceneUserActivityManager _deleteSavedScene…] 2ms (system)
-[UISApplicationSupportClient applicationInit…]   1ms (system)
-[LockdownModeManager enabled]                    1ms (system)
-[FBSWorkspaceScenesClient initWithEndpoint…]     1ms (system)
+[UIKeyboardSceneDelegate automaticKeyboard…]     1ms (system)
-[FBSWorkspaceScenesClient _callOutQueue…]        1ms (system)
```

## Wall clock 의 실제 구성 (추정)

XCTest cold launch wall clock 3.5 s ≈ 다음 합:

- **0–1.5 s**: dyld + dylib load + ObjC runtime init (system, 코드에서 손 못 댐)
- **1.5–3.0 s**: SwiftUI App init + DisplayList 첫 빌드 + accessibility tree 구축 + UIScene 초기화 (system 위주)
- **3.0–3.5 s**: ready marker 노출 + XCTest accessibility polling 도달 (harness)

user code 비중은 **<30 ms (~1%)**. SwiftUI framework + UIKit + dyld 이 95%+.

## 의미 있는 발견 (cold launch ≠ idle CPU)

GoalDetail 의 `TimelineView.UpdateFilter.updateValue` 가 7 ms (0.1%) — `FlyingReactionOverlay` 의 `TimelineView(.animation(minimumInterval: 1.0/60.0))` 가 cold launch 도중에도 60 Hz 로 update 호출을 트리거. 6 s 윈도우에서 7 ms 면 **continuous idle 1.2 ms/sec ≈ 0.12% CPU 상시 점유**.

영향:
- Cold launch wall clock 영향: 무시 가능 (7 ms / 3500 ms ≈ 0.2%)
- 그러나 앱이 계속 떠 있는 동안 0.12% CPU 상시 사용 → 배터리/스로틀에서는 따져볼 만함

이건 cold launch 목표와 별개. follow-up 항목으로 분류.

## Phase 7 게이트 판정

Plan 의 게이트:
> Hot frame 이 명확하면 Phase 8 진입. 시스템 비중이 압도적이면 즉시 honest 보고로 분기.

**판정: 시스템 비중이 압도적 → honest 보고로 분기**.

### 이유
1. user-code top frame 이 모두 ≤7 ms, 합산 <30 ms
2. 3.5 s wall clock 의 95%+ 가 SwiftUI / UIKit / FBS / dyld
3. View body 분해, computed property → stored 등을 다 적용해도 절약 가능한 user CPU 가 <30 ms ≈ <1% wall clock
4. ≥15% (≈525 ms) 절약은 user code 에서 물리적으로 불가능

### 권장 follow-up (Pass 2 비범위였던 작업)
- **TimelineView 항상 돌리는 문제 해결**: `FlyingReactionOverlay` 를 `reactions.isEmpty` 일 때 `TimelineView` 자체를 안 만들도록 conditional. idle CPU 0.12% → 0%
- **launch image 최적화**: Home top frame 의 `AppleJPEGReadPlugin::copyIOSurfaceImp` 는 launch screen JPEG 디코드. PNG 또는 단색으로 바꾸면 0–10 ms 절약 가능 (전체 ≤0.3% 영향)
- **Pre-warm**: AppDelegate 에서 view 일부 미리 instantiate 해 첫 body 평가를 fan-out 시킴. 효과 검증 어렵고 복잡도 증가
- **iOS 추가 최적화**: `UIApplication.shared.applicationState != .inactive` 분기, scene 단순화 — 본질적으로 system overhead 라 무의미

위 follow-up 들 중 wall clock 영향이 ≥15% 인 것은 없음. **사용자가 체감한 "느린 cold start" 는 system overhead (dyld + SwiftUI + UIScene + accessibility tree) 가 본질이며 이번 작업 범위 내 user code 수정으로는 해결 불가**.
