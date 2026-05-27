# UI Rendering Perf Infrastructure Inventory

작성일: 2026-05-17

| Feature | Example 존재 | 현재 Bundle ID | 측정 대상 | 비고 |
| --- | --- | --- | --- | --- |
| Auth | 있음 | `org.yapp.twix.example.auth` | 예 | 기존 `org.yapp.twix` 충돌을 고유 Bundle ID로 분리 |
| Common | 없음(의도) | N/A | 아니오 | 매니페스트에 Example target 없음 |
| GoalDetail | 있음 | `org.yapp.twix.example.goal-detail` | 예 | 기존 `org.yapp.twix` 충돌을 고유 Bundle ID로 분리 |
| Home | 있음 | `org.yapp.twix.example.home` | 예 | placeholder Example을 실제 `HomeCoordinatorView` wiring으로 교체 |
| MainTab | 있음 | `org.yapp.twix.example.main-tab` | 예 | 기존 `org.yapp.twix` 충돌을 고유 Bundle ID로 분리 |
| MakeGoal | 있음 | `org.yapp.twix.example.make-goal` | 예 | placeholder Example을 실제 `MakeGoalView` wiring으로 교체 |
| Notification | 있음 | `org.yapp.twix.example.notification` | 예 | `Date()` 기반 mock을 deterministic reference date로 교체 |
| Onboarding | 있음 | `org.yapp.twix.example.onboarding` | 예 | entitlements/provisioning 검증 필요 |
| ProofPhoto | 있음 | `org.yapp.twix.example.proof-photo` | 예 | placeholder Example을 실제 `ProofPhotoView` wiring으로 교체 |
| Settings | 있음 | `org.yapp.twix.example.settings` | 예 | 기존 `org.yapp.twix` 충돌을 고유 Bundle ID로 분리 |
| Stats | 있음 | `org.yapp.twix.example.stats` | 예 | 기존 `org.yapp.twix` 충돌을 고유 Bundle ID로 분리 |

