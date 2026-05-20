# Pass 4-S — App-wide SwiftUI Template Audit (candidate inventory)
**Status**: candidate discovery, not optimization. No production code change.
Source data: `/tmp/twix-perf-traces/pass4-s/analysis/*.json` (regenerable from `.../swiftui-launch/**/*.trace`).

## 1. CLI validation
Working launch-mode command:
```bash
xcrun xctrace record \
  --device 00008110-00096DC42632801E \
  --template 'SwiftUI' \
  --time-limit 20s \
  --output <path>.trace \
  --launch -- org.yapp.twix.example.<slug> \
  -UITEST -UITEST_RENDERING_SCENARIO -UITEST_SEED <seed> -UITEST_WAIT_READY
```
- `--launch` accepts the on-device bundle id directly.
- `-UITEST*` process arguments are forwarded; the example app self-loads via `UITestMode.configureApplication()` and `ProofPhotoFixture.forSeed(...)` (or equivalent).
- Capture target = the launched feature app (e.g. `FeatureProofPhotoExample`), not an XCTest runner.

## 2. Trace inventory
| scenario | reps | bundle MB (median) | swiftui-updates rows (per rep, mean) | view-body updates (per rep, mean) | rep range |
|---|---:|---:|---:|---:|---|
| ProofPhoto preview-1024 | 3 | ~62 | 2521 | 284 | 2440–2562 |
| ProofPhoto preview-large | 3 | ~62 | 2518 | 280 | 2442–2636 |
| GoalDetail initial-reactionbar | 3 | ~62 | 3750 | 295 | 3670–3886 |
| Home scroll-50 idle | 3 | ~62 | 11387 | 573 | 11387–11387 |
| Home home-heavy idle | 3 | ~62 | 11022 | 570 | 10291–11387 |
| Stats scroll-50 idle | 3 | ~62 | 10145 | 227 | 9628–11161 |
| Stats heavy idle | 3 | ~62 | 9621 | 223 | 9619–9624 |

All 21 traces: clean `exit(0)` termination, target pid = launched example app (not XCTest runner). Zero SpringBoard / banner contamination.

## 3. Attach-mode trial result
Driver-required scenarios (typing, reselect, interactive scroll) cannot be captured via `--launch` (xctrace and XCUITest cannot both launch the same iOS app instance). One short attach-mode trial was run:

- Scenario: `testRendering_proofPhotoCommentTypingWithLargeFixtureImage` driver, xctrace attach after `image-ingested.fixture-large` marker.
- Reps: 2 (rep1 + rep2).
- Trace bundle: 63 MB each, clean `exit(0)`.
- TOC contains `swiftui-updates`, `swiftui-causes`, `swiftui-changes`, `swiftui-update-groups` table **schemas**.
- Row counts in those tables: **0 / 0 / 0 / 0** in both reps.

**Conclusion**: SwiftUI Template attach mode collects the table schema but no actual data on this device (iPhone 13 Pro Max, iOS 26.4.2) under Xcode 26.0. This reproduces the Pass 3 finding. Driver-required scenarios cannot be measured with SwiftUI Template via the xctrace CLI on this configuration.
Recorded as a tooling limit, not a bug to fix in this track. A manual GUI attach (Instruments.app) was not attempted in this track.

## 4. Per-scenario candidate views
Columns:

- **mean count / rep** — average number of update events for this description across reps.
- **mean µs / rep** — average summed duration (microseconds) for this description across reps.
- **reps** — `present/total` reps where this description appeared in the per-trace top-40.
- **type** — `View Body Updates` (body re-eval, user-visible cost), `Representable Updates` (UIViewRepresentable bridge), or `Other Updates` (SwiftUI internal: layout, geometry, display-list build, etc.).

Only descriptions attributed to user code modules are highlighted. SwiftUI-internal entries (`module = SwiftUI`) are listed below each scenario in a secondary table since they represent system work, not direct optimization targets — but they are kept because patterns there often correlate with user-code shape.

### ProofPhoto preview-1024
- total rows / rep: [2440, 2562, 2562]
- update-type breakdown per rep: [{'Other Updates': 2158, 'View Body Updates': 280, 'Representable Updates': 2}, {'Other Updates': 2273, 'View Body Updates': 286, 'Representable Updates': 3}, {'Other Updates': 2273, 'View Body Updates': 286, 'Representable Updates': 3}]

**User-code views (candidates):**
| description | module | type | mean count / rep | mean µs / rep | reps |
|---|---|---|---:|---:|---|
| `ProofPhotoView.body` | FeatureProofPhotoExample | View Body Updates | 4.0 | 6189.9 | 3/3 |
| `TXRoundButton.body` | FeatureProofPhotoExample | View Body Updates | 3.0 | 1652.9 | 3/3 |
| `TXCommentCircle.body` | FeatureProofPhotoExample | View Body Updates | 4.0 | 374.5 | 3/3 |
| `ExampleHost.body` | FeatureProofPhotoExample | View Body Updates | 2.0 | 351.1 | 3/3 |
| `TXToastModifier.body` | FeatureProofPhotoExample | View Body Updates | 4.0 | 120.7 | 3/3 |

**SwiftUI internal (secondary signal):**
| description | type | mean count / rep | mean µs / rep | reps |
|---|---|---:|---:|---|
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | Other Updates | 18.0 | 6613.8 | 3/3 |
| `PlatformViewChild<PlatformViewRepresentableAdaptor<PlatformTextFieldAdaptor>>` | Other Updates | 1.0 | 3096.7 | 3/3 |
| `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` | Other Updates | 14.0 | 2603.6 | 3/3 |
| `DynamicViewContainer<AnyView>` | Other Updates | 1.0 | 2213.3 | 3/3 |
| `ResolvedTextFilter` | Other Updates | 8.0 | 1681.0 | 3/3 |
| `SecondaryLayerGeometryQuery` | Other Updates | 14.7 | 1131.9 | 3/3 |
| `ShapeStyleResolver<AnyShapeStyle>` | Other Updates | 34.7 | 992.2 | 3/3 |
| `PlatformViewRepresentableAdaptor.update` | Representable Updates | 1.7 | 548.7 | 3/3 |
| `DynamicViewList<_ConditionalContent<ModifiedContent, EmptyView>>` | Other Updates | 3.0 | 415.6 | 3/3 |
| `ButtonBehavior.body` | View Body Updates | 16.0 | 357.8 | 3/3 |

### ProofPhoto preview-large
- total rows / rep: [2442, 2475, 2636]
- update-type breakdown per rep: [{'Other Updates': 2167, 'View Body Updates': 274, 'Representable Updates': 1}, {'Other Updates': 2193, 'View Body Updates': 280, 'Representable Updates': 2}, {'Other Updates': 2347, 'View Body Updates': 286, 'Representable Updates': 3}]

**User-code views (candidates):**
| description | module | type | mean count / rep | mean µs / rep | reps |
|---|---|---|---:|---:|---|
| `ProofPhotoView.body` | FeatureProofPhotoExample | View Body Updates | 4.0 | 5841.2 | 3/3 |
| `TXRoundButton.body` | FeatureProofPhotoExample | View Body Updates | 3.0 | 1462.0 | 3/3 |
| `TXCommentCircle.body` | FeatureProofPhotoExample | View Body Updates | 4.0 | 380.5 | 3/3 |
| `ExampleHost.body` | FeatureProofPhotoExample | View Body Updates | 2.0 | 308.3 | 3/3 |
| `TXToastModifier.body` | FeatureProofPhotoExample | View Body Updates | 4.0 | 133.9 | 3/3 |

**SwiftUI internal (secondary signal):**
| description | type | mean count / rep | mean µs / rep | reps |
|---|---|---:|---:|---|
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | Other Updates | 18.0 | 6614.0 | 3/3 |
| `InsetChildGeometry` | Other Updates | 4.0 | 3920.1 | 3/3 |
| `PlatformViewChild<PlatformViewRepresentableAdaptor<PlatformTextFieldAdaptor>>` | Other Updates | 1.0 | 2856.7 | 3/3 |
| `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` | Other Updates | 13.0 | 2211.0 | 3/3 |
| `DynamicViewContainer<AnyView>` | Other Updates | 1.0 | 1873.3 | 3/3 |
| `ResolvedTextFilter` | Other Updates | 8.0 | 1582.2 | 3/3 |
| `SecondaryLayerGeometryQuery` | Other Updates | 15.3 | 1053.7 | 3/3 |
| `ShapeStyleResolver<AnyShapeStyle>` | Other Updates | 31.3 | 992.5 | 3/3 |
| `PlatformViewRepresentableAdaptor.update` | Representable Updates | 1.3 | 560.7 | 3/3 |
| `Button.body` | View Body Updates | 81.0 | 523.6 | 3/3 |

### GoalDetail initial-reactionbar
- total rows / rep: [3670, 3694, 3886]
- update-type breakdown per rep: [{'Other Updates': 3379, 'View Body Updates': 288, 'Representable Updates': 3}, {'Other Updates': 3400, 'View Body Updates': 290, 'Representable Updates': 4}, {'Other Updates': 3574, 'View Body Updates': 306, 'Representable Updates': 6}]

**User-code views (candidates):**
| description | module | type | mean count / rep | mean µs / rep | reps |
|---|---|---|---:|---:|---|
| `GoalDetailView.body` | FeatureGoalDetailExample | View Body Updates | 4.0 | 10392.5 | 3/3 |
| `TXNavigationBar.body` | FeatureGoalDetailExample | View Body Updates | 3.0 | 4414.8 | 3/3 |
| `GoalDetailExampleView.body` | FeatureGoalDetailExample | View Body Updates | 1.0 | 2843.3 | 3/3 |
| `TXCommentCircle.body` | FeatureGoalDetailExample | View Body Updates | 6.7 | 355.5 | 3/3 |
| `TXToastModifier.body` | FeatureGoalDetailExample | View Body Updates | 3.0 | 101.7 | 3/3 |

**SwiftUI internal (secondary signal):**
| description | type | mean count / rep | mean µs / rep | reps |
|---|---|---:|---:|---|
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | Other Updates | 29.0 | 9014.1 | 3/3 |
| `DynamicViewContainer<AnyView>` | Other Updates | 1.0 | 5386.7 | 3/3 |
| `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` | Other Updates | 20.0 | 3880.8 | 3/3 |
| `SecondaryLayerGeometryQuery` | Other Updates | 26.0 | 3676.4 | 3/3 |
| `PlatformViewChild<PlatformViewRepresentableAdaptor<PlatformTextFieldAdaptor>>` | Other Updates | 2.0 | 3364.3 | 3/3 |
| `ResolvedTextFilter` | Other Updates | 14.0 | 1626.2 | 3/3 |
| `PlatformViewRepresentableAdaptor.update` | Representable Updates | 2.0 | 829.1 | 3/3 |
| `ShapeStyleResolver<AnyShapeStyle>` | Other Updates | 52.0 | 729.9 | 3/3 |
| `ForEachChild<Range<Int>, Int, ModifiedContent<ModifiedContent, _FrameLayout>>` | Other Updates | 31.7 | 394.1 | 3/3 |
| `ResolvedButtonStyle.body` | View Body Updates | 61.0 | 371.5 | 3/3 |

### Home scroll-50 idle
- total rows / rep: [11387, 11387, 11387]
- update-type breakdown per rep: [{'Other Updates': 10812, 'View Body Updates': 573, 'Representable Updates': 2}, {'Other Updates': 10812, 'View Body Updates': 573, 'Representable Updates': 2}, {'Other Updates': 10812, 'View Body Updates': 573, 'Representable Updates': 2}]

**User-code views (candidates):**
| description | module | type | mean count / rep | mean µs / rep | reps |
|---|---|---|---:|---:|---|
| `TXNavigationBar.body` | FeatureHomeExample | View Body Updates | 2.0 | 3286.8 | 3/3 |
| `TXCalendarDateCell.body` | FeatureHomeExample | View Body Updates | 21.0 | 1552.5 | 3/3 |
| `HomeCoordinatorView.body` | FeatureHomeExample | View Body Updates | 1.0 | 815.5 | 3/3 |
| `GoalCardView.body` | FeatureHomeExample | View Body Updates | 6.0 | 654.3 | 3/3 |
| `CardHeaderView.body` | FeatureHomeExample | View Body Updates | 11.0 | 440.1 | 3/3 |
| `TXRoundButton.body` | FeatureHomeExample | View Body Updates | 5.0 | 291.6 | 3/3 |
| `HomeView.body` | FeatureHomeExample | View Body Updates | 0.7 | 193.1 | 1/3 |
| `HomePresentationLayer.body` | FeatureHomeExample | View Body Updates | 1.3 | 156.1 | 2/3 |

**SwiftUI internal (secondary signal):**
| description | type | mean count / rep | mean µs / rep | reps |
|---|---|---:|---:|---|
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | Other Updates | 101.0 | 21959.6 | 3/3 |
| `PlatformViewChild<PlatformViewControllerRepresentableAdaptor<NavigationStackRepresentable>>` | Other Updates | 1.0 | 8553.3 | 3/3 |
| `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` | Other Updates | 214.0 | 5845.1 | 3/3 |
| `LazyView.body` | View Body Updates | 1.0 | 4640.0 | 3/3 |
| `ResolvedTextFilter` | Other Updates | 72.0 | 3154.0 | 3/3 |
| `LazySubviewPlacements<LazyVStackLayout>` | Other Updates | 4.0 | 2314.2 | 3/3 |
| `DynamicViewContainer<AnyView>` | Other Updates | 3.0 | 2121.6 | 3/3 |
| `SecondaryLayerGeometryQuery` | Other Updates | 34.0 | 1542.4 | 3/3 |
| `Text Content` | Other Updates | 234.0 | 1445.7 | 3/3 |
| `PlaceholderInfo` | Other Updates | 1.0 | 1353.3 | 3/3 |

### Home home-heavy idle
- total rows / rep: [11387, 11387, 10291]
- update-type breakdown per rep: [{'Other Updates': 10812, 'View Body Updates': 573, 'Representable Updates': 2}, {'Other Updates': 10812, 'View Body Updates': 573, 'Representable Updates': 2}, {'Other Updates': 9725, 'View Body Updates': 563, 'Representable Updates': 3}]

**User-code views (candidates):**
| description | module | type | mean count / rep | mean µs / rep | reps |
|---|---|---|---:|---:|---|
| `TXNavigationBar.body` | FeatureHomeExample | View Body Updates | 2.0 | 3021.9 | 3/3 |
| `TXCalendarDateCell.body` | FeatureHomeExample | View Body Updates | 21.0 | 1419.1 | 3/3 |
| `GoalCardView.body` | FeatureHomeExample | View Body Updates | 6.0 | 659.9 | 3/3 |
| `HomeCoordinatorView.body` | FeatureHomeExample | View Body Updates | 1.0 | 490.9 | 3/3 |
| `CardHeaderView.body` | FeatureHomeExample | View Body Updates | 11.0 | 454.7 | 3/3 |
| `TXRoundButton.body` | FeatureHomeExample | View Body Updates | 5.0 | 295.2 | 3/3 |
| `HomePresentationLayer.body` | FeatureHomeExample | View Body Updates | 2.0 | 234.0 | 3/3 |

**SwiftUI internal (secondary signal):**
| description | type | mean count / rep | mean µs / rep | reps |
|---|---|---:|---:|---|
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | Other Updates | 101.0 | 21923.8 | 3/3 |
| `RendererEffectDisplayList<_ClipEffect<UnevenRoundedRectangle>>` | Other Updates | 2.7 | 7578.6 | 1/3 |
| `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` | Other Updates | 173.3 | 5340.4 | 3/3 |
| `PlatformViewChild<PlatformViewControllerRepresentableAdaptor<NavigationStackRepresentable>>` | Other Updates | 1.0 | 5326.7 | 3/3 |
| `LazyView.body` | View Body Updates | 1.0 | 3723.3 | 3/3 |
| `ResolvedTextFilter` | Other Updates | 72.0 | 3233.0 | 3/3 |
| `LazySubviewPlacements<LazyVStackLayout>` | Other Updates | 4.0 | 2374.5 | 3/3 |
| `DynamicViewContainer<AnyView>` | Other Updates | 3.0 | 1721.5 | 3/3 |
| `SecondaryLayerGeometryQuery` | Other Updates | 34.0 | 1585.5 | 3/3 |
| `Text Content` | Other Updates | 224.3 | 1183.9 | 3/3 |

### Stats scroll-50 idle
- total rows / rep: [11161, 9645, 9628]
- update-type breakdown per rep: [{'Other Updates': 10926, 'View Body Updates': 232, 'Representable Updates': 3}, {'Other Updates': 9419, 'View Body Updates': 224, 'Representable Updates': 2}, {'Other Updates': 9402, 'View Body Updates': 224, 'Representable Updates': 2}]

**User-code views (candidates):**
| description | module | type | mean count / rep | mean µs / rep | reps |
|---|---|---|---:|---:|---|
| `TXNavigationBar.body` | FeatureStatsExample | View Body Updates | 1.0 | 3450.0 | 3/3 |
| `TXCalendarMonthNavigation.body` | FeatureStatsExample | View Body Updates | 2.0 | 1255.9 | 3/3 |
| `StatsView.body` | FeatureStatsExample | View Body Updates | 2.0 | 1023.4 | 3/3 |
| `StatsCardCompletionCell.body` | FeatureStatsExample | View Body Updates | 20.0 | 719.4 | 3/3 |
| `StatsCoordinatorView.body` | FeatureStatsExample | View Body Updates | 1.0 | 650.2 | 3/3 |
| `CardHeaderView.body` | FeatureStatsExample | View Body Updates | 10.0 | 365.9 | 3/3 |
| `StatsCardView.body` | FeatureStatsExample | View Body Updates | 5.0 | 250.4 | 3/3 |

**SwiftUI internal (secondary signal):**
| description | type | mean count / rep | mean µs / rep | reps |
|---|---|---:|---:|---|
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | Other Updates | 60.0 | 14084.0 | 3/3 |
| `SecondaryLayerGeometryQuery` | Other Updates | 74.0 | 9219.3 | 3/3 |
| `LazySubviewPlacements<LazyVStackLayout>` | Other Updates | 4.3 | 6644.2 | 3/3 |
| `PlatformViewChild<PlatformViewControllerRepresentableAdaptor<NavigationStackRepresentable>>` | Other Updates | 1.0 | 5383.3 | 3/3 |
| `ResolvedTextFilter` | Other Updates | 64.0 | 5092.6 | 3/3 |
| `LazyView.body` | View Body Updates | 1.0 | 3790.0 | 3/3 |
| `PlaceholderInfo` | Other Updates | 1.0 | 2190.0 | 3/3 |
| `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` | Other Updates | 46.0 | 2074.3 | 3/3 |
| `Layout: ScrollViewChildContainerSize` | Other Updates | 249.0 | 2028.2 | 3/3 |
| `DynamicViewContainer<AnyView>` | Other Updates | 3.0 | 1727.3 | 3/3 |

### Stats heavy idle
- total rows / rep: [9621, 9619, 9624]
- update-type breakdown per rep: [{'Other Updates': 9395, 'View Body Updates': 224, 'Representable Updates': 2}, {'Other Updates': 9395, 'View Body Updates': 222, 'Representable Updates': 2}, {'Other Updates': 9400, 'View Body Updates': 222, 'Representable Updates': 2}]

**User-code views (candidates):**
| description | module | type | mean count / rep | mean µs / rep | reps |
|---|---|---|---:|---:|---|
| `TXNavigationBar.body` | FeatureStatsExample | View Body Updates | 1.0 | 3023.3 | 3/3 |
| `TXCalendarMonthNavigation.body` | FeatureStatsExample | View Body Updates | 2.0 | 1373.4 | 3/3 |
| `StatsView.body` | FeatureStatsExample | View Body Updates | 2.0 | 862.3 | 3/3 |
| `StatsCardCompletionCell.body` | FeatureStatsExample | View Body Updates | 20.0 | 798.3 | 3/3 |
| `StatsCoordinatorView.body` | FeatureStatsExample | View Body Updates | 1.0 | 404.3 | 3/3 |
| `CardHeaderView.body` | FeatureStatsExample | View Body Updates | 10.0 | 375.2 | 3/3 |
| `StatsCardView.body` | FeatureStatsExample | View Body Updates | 5.0 | 267.1 | 3/3 |

**SwiftUI internal (secondary signal):**
| description | type | mean count / rep | mean µs / rep | reps |
|---|---|---:|---:|---|
| `DynamicContainerInfo<DynamicLayoutViewAdaptor>` | Other Updates | 60.0 | 14370.4 | 3/3 |
| `SecondaryLayerGeometryQuery` | Other Updates | 74.0 | 9328.4 | 3/3 |
| `LazySubviewPlacements<LazyVStackLayout>` | Other Updates | 4.0 | 6680.1 | 3/3 |
| `ResolvedTextFilter` | Other Updates | 64.0 | 5479.8 | 3/3 |
| `PlatformViewChild<PlatformViewControllerRepresentableAdaptor<NavigationStackRepresentable>>` | Other Updates | 1.0 | 5296.7 | 3/3 |
| `LazyView.body` | View Body Updates | 1.0 | 3703.3 | 3/3 |
| `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` | Other Updates | 42.0 | 2426.0 | 3/3 |
| `PlaceholderInfo` | Other Updates | 1.0 | 2006.7 | 3/3 |
| `Layout: ScrollViewChildContainerSize` | Other Updates | 249.0 | 1994.4 | 3/3 |
| `DynamicViewContainer<AnyView>` | Other Updates | 3.0 | 1574.2 | 3/3 |

## 5. Cross-scenario candidate shortlist
Candidates worth a follow-up Time Profiler + Animation Hitches before/after gate (NOT a production change yet — these are hypothesis seeds). Each candidate names the SwiftUI Template signal that motivated it, the user-code surface to investigate, and what would need to be true at Time Profiler / Hitches before any commit.

Classification per Step 3 rubric:
- **Candidate** — strong SwiftUI Template signal, plausible user-code cause, follow-up Time Profiler + Hitches required.
- **Weak signal** — visible but small or ambiguous; tracked, not actionable.
- **Out of scope** — non-rendering or already-resolved.
- **Already resolved** — covered by Pass 3 or Pass 4 commits.

### C1. TXNavigationBar idle re-evaluation (cross-feature)
- **Signal**: `TXNavigationBar.body` is the heaviest user-code body update in Home idle (~3.3ms × 2 evals/rep), Stats idle (~3.0–3.5ms × 1–2 evals/rep), and GoalDetail initial (~4.4ms × 3 evals/rep). Appears in 3/3 reps across all 7 launch-mode scenarios.
- **Hypothesis**: TXNavigationBar reads state (e.g. environment value, focus state, theme-related observable) that invalidates 1–3× during a 20s idle window even though no visible state has changed.
- **User-code surface to investigate**: `SharedDesignSystem` `TXNavigationBar` body + any `@Environment` / `@FocusState` / `@Observable` dependency it reads, and any modifier (`.toolbar` / `.safeAreaInset`) the consuming features attach.
- **Why this is a candidate, not a fix**: SwiftUI Template event count and µs do not prove user-visible cost. Before any change, capture a Time Profiler + Animation Hitches before/after on Home scroll-50 idle and Stats scroll-50 idle to confirm a main-thread cost reduction.
- **Classification**: Candidate.

### C2. Home LazyVStack adaptor revalidation
- **Signal**: `DynamicContainerInfo<DynamicLayoutViewAdaptor>` is the heaviest single SwiftUI-internal update in Home (`101 events × ~22ms / rep` on idle), with `LazySubviewPlacements<LazyVStackLayout>` and `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` (214 events) showing related cost.
- **Hypothesis**: LazyVStack item content is being re-validated each refresh tick. Common causes: non-stable `id:` keys, conditional content that toggles `_ConditionalContent` branches, or environment-driven invalidation propagating into every cell.
- **User-code surface to investigate**: the LazyVStack(s) inside `HomeView` / `HomePresentationLayer` and its `GoalCardView` rows; `id:` / `Identifiable` conformance on goal items; whether `Image` views in goal cards are constructed inline vs via stable `Image(systemName:)`.
- **Pass 3 cross-reference**: Pass 3 Commit 6 (GoalCardView input stability) was investigated and SKIPPED because Time Profiler did not show GoalCardView frames in the top-20. This Pass 4-S finding does NOT revive Commit 6 — it points at a *different* layer (lazy container revalidation under SwiftUI, not user-code input recomposition) and any follow-up must come with its own Time Profiler + Hitches gate per the Pass 4-S rules.
- **Classification**: Candidate.

### C3. TXCalendarDateCell idle invalidation in Home
- **Signal**: `TXCalendarDateCell.body` shows 21 updates × 1.5ms / rep across all 3 Home idle reps. ~1 invalidation/sec on a static weekly calendar.
- **Hypothesis**: Date cell body reads a time-driven value (`Date()`, `TimelineView`, or a calendar-now observable) that re-emits during idle.
- **User-code surface to investigate**: `TXCalendarDateCell` body and its `@Environment`/`@State`/closure inputs. Cross-check with `TXCalendarMonthNavigation.body` (2 updates / rep on Stats) for the same root cause.
- **Pass 3 cross-reference**: Same family of pattern as the Pass 3 Commit 7 KEEP (`FlyingReactionOverlay` idle TimelineView). If a similar guard pattern fits, it would be a small, well-scoped follow-up.
- **Classification**: Candidate.

### C4. GoalDetail initial body cost
- **Signal**: `GoalDetailView.body` is the single heaviest user-code body update across all 7 scenarios (10.4ms total per rep, 4 evals). The view also drives `GoalDetailExampleView.body` 2.8ms per rep.
- **Hypothesis**: Initial render of GoalDetail with the reaction bar visible (`.you` owner branch) triggers more body evaluations than expected during the post-ready idle. Possible causes: reaction-bar / overlay subscriptions re-emit during initial layout, or modifier chains attached at the GoalDetailView root re-derive on every owner check.
- **User-code surface to investigate**: `GoalDetailView` body composition, `GoalDetailReducer` state observation surface used by the view, `FlyingReactionOverlay` (already optimized in Pass 3 Commit 7 — verify that this is not regressing).
- **Pass 3 cross-reference**: Pass 3 Commit 7 KEEP reduced rapid-fire interactive cost but did not target initial-idle body cost. This is a distinct entry condition.
- **Classification**: Candidate.

### C5. Stats scroll-view container size re-query
- **Signal**: `Layout: ScrollViewChildContainerSize` shows 249 updates × ~2ms / rep across both Stats idle scenarios, plus `LazySubviewPlacements<LazyVStackLayout>` at ~6.7ms (heavier than Home).
- **Hypothesis**: Something in Stats causes the ScrollView's content size to be re-measured ~12×/sec on idle. Likely a `GeometryReader`-coupled cell, a TXCalendar component, or a `LazyVStack` with cells whose size depends on a frequently-invalidated state.
- **User-code surface to investigate**: `StatsView` ScrollView root, `StatsCardCompletionCell` (20 evals / rep), `TXCalendarMonthNavigation`. Same-pattern audit as C3.
- **Classification**: Candidate.

### C6. Image accessibility provider churn (Home)
- **Signal**: `Image.ImageViewChild<SwiftUIImageAccessibilityProvider>` 214 updates × 5.8ms in Home idle, ~46 updates × 2.1ms in Stats idle. Each event is sub-100µs but the volume is high.
- **Hypothesis**: Goal-card icon images and stat-card icon images are getting accessibility re-evaluation per layout pass. Could be inline `Image(systemName:)` reconstructions or modifier chains forcing re-providing accessibility hints.
- **User-code surface to investigate**: `GoalCardView` icon, `StatsCardView` icon, any `Image` constructor that takes a non-static argument.
- **Classification**: Weak signal — high event count, low per-event cost. Tracked, not actionable until Time Profiler shows main-thread cost.

### C7. ProofPhoto preview-1024 vs preview-large differential
- **Signal**: `ProofPhotoView.body` event count, duration, and update-type breakdown are statistically identical between preview-1024 and preview-large (4 body evals, ~6ms total, in 3/3 reps each). No size-dependent SwiftUI Template signal remains after Pass 4 P4-2.
- **Implication**: This re-confirms Pass 4 P4-2 (decode-out-of-body) at the SwiftUI Template layer — large fixture does not amplify preview-side update cost on idle. **Already resolved**.
- **Caveat**: SwiftUI Template attach mode failure means typing/reselect time cost is NOT covered by this scenario. Pass 4 final report already concluded those scenarios via Time Profiler + Animation Hitches.
- **Classification**: Already resolved.

### C8. Driver-required SwiftUI Template attribution
- **Signal**: §3 — SwiftUI tables are empty in attach mode on this device/OS. Driver-required scenarios (Home feed scroll, Stats heavy scroll, GoalDetail rapid-fire, ProofPhoto typing/reselect) cannot be measured with SwiftUI Template via xctrace CLI here.
- **Classification**: Tooling limit. Follow-up options if needed later: (a) Instruments.app manual launch + driver via Accessibility Inspector or simulated touches, (b) replace driver-required scenarios with launch-mode equivalents that auto-perform the interaction via `onAppear` async tasks, (c) accept Time Profiler + Animation Hitches as the only attribution layer for interactive scenarios (current state).

### Out-of-scope / explicitly NOT candidates
- **Pass 3 SKIP/HOLD Commits 4/5/6**: not revived. Pass 4-S findings (C2/C6) point at adjacent SwiftUI-internal patterns rather than the user-code input-stability hypotheses Commits 4/5/6 originally tested. Any follow-up enters as a fresh hypothesis with its own Time Profiler + Hitches gate.
- **ProofPhoto P4-3 / P4-4**: Pass 4 final report SKIP decisions stand. SwiftUI Template idle scenarios provide no new evidence to revive them.
- **Settings nickname**: loading-delay category; not a SwiftUI rendering candidate.
- **Auth / Onboarding**: out of scope per plan.


## 6. Honest caveats
- **Per-trace top-40 horizon**: aggregator currently sums only top-40 rows per trace; descriptions that appear with `<1 sample` in any single rep but are large in aggregate may be under-counted. Acceptable for candidate discovery; raise top-N before any optimization gate.
- **Idle scenarios only**: launch-mode scenarios capture the post-ready idle window. They do not represent feed-scroll, typing, reselect, or rapid-fire interaction cost. Interaction-time SwiftUI Template attribution is not available on this configuration.
- **Update count ≠ wall-clock cost**: `swiftui-updates` row count is an event count, not a CPU-time measurement. Use the `mean µs / rep` column (event-recorded duration) for cost; cross-check with Time Profiler before any commit.
- **PerfProfile only**: Pass 4 baseline configuration (drift from Pass 3 `Profile` documented in pass-4 final report §2.1).
- **`<unknown>` module entries**: typically views created before tracing started or framework-internal nodes; not actionable from this trace alone.
- **No optimization claim**: nothing in this report is evidence of a regression or improvement. It is a candidate-discovery inventory.

