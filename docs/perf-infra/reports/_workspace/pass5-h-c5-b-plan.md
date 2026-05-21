# H-C5-b — StatsCardView outsideBorder render-duplication removal

**Hypothesis class**: render-side duplicated-subtree elimination on `StatsCardView`. **NOT** composition-skip / input-stability.

**Scope**: 1 file — `Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardView.swift`.

**Status**: plan, awaiting user approval before implementation.

---

## 1. Why this hypothesis

### 1.1 Mechanism (same as H-C2-a)

`outsideBorder` is implemented as `overlay { shape.stroke(...).overlay(self) }` (see `Projects/Shared/DesignSystem/Sources/Modifiers/View+BorderInOutSide.swift:42-56`). The inner `.overlay(self)` composes the receiver view **twice** into the rendered output: once for its own content, once for the border overlay. During scroll-time materialization, this doubles the per-cell render-side composition cost.

H-C2-a on `GoalCardView` (commit `0c0da63`, Pass 4-S2) replaced this modifier with a local `.background { RoundedRectangle.stroke }` form. Result on `home-selfrun-scroll` after-gate (3 SwiftUI + 3 TP + 3 Hitches reps each, before vs after):

| metric | before | after | delta |
|---|---:|---:|---:|
| `swiftui-updates` total | 204,598 | 121,310 | -40.7 % |
| `GoalCardView.body` events | 2,642 | 166 | -93.7 % |
| `Image.ImageViewChild<…AccessibilityProvider>` events | 2,563 | 1,270 | -50 % (side effect) |
| Animation Hitches per rep | 0 / 2 / 4 | 0 / 0 / 0 | -100 % |
| 133.34 ms severe hitch | present rep 2 | eliminated | — |
| "37 offscreen passes" narrative | present | eliminated | — |

### 1.2 Why `StatsCardView` is a valid analog

- **Same modifier**: `StatsCardView.swift:55-59` uses `.outsideBorder(...)` with identical shape/lineWidth structure.
- **Same `.clipShape` → `.outsideBorder` ordering**: matches `GoalCardView` exactly (`.clipShape(RoundedRectangle)` immediately followed by `.outsideBorder(...)`).
- **Same narrative class on baseline**: Pass 4-S3 baseline gate showed "Potentially expensive app update(s)" narrative reproducibility 3/3 reps on Stats self-run scroll — same narrative that H-C2-a eliminated on Home.
- **Render-side mechanism does NOT require body re-eval to occur**: even if Stats user-code never appears in TP top-10 (which it doesn't on baseline), render-side composition duplication can still cost framework time. This is consistent with H-C5-a's failure to move TP — H-C5-a addressed inner-container layout, not render-side composition.

### 1.3 Why this is NOT a blind cross-transfer

Handoff §4.5 prohibits cross-transferring H-C2-a's fix to other features **without independent gate evidence**. This plan satisfies §4.5 by:

- collecting independent before-gate on Stats self-run scroll (reuse `/tmp/twix-perf-traces/pass4-s3/c5-before/` if intact; re-collect otherwise);
- collecting independent after-gate on the same scenario with the same template × reps;
- applying the same KEEP/REVERT criteria locally, judged on the Stats scenario alone — Home's H-C2-a result is not cited as evidence of Stats success.

### 1.4 Why other hypothesis classes are out of scope for H-C5-b

- **Equatable / input-stability**: SKIP — baseline TP shows no Stats user-code in top-10, predictably will not move TP/Hitches.
- **`StatsCardView` Equatable + closure stripping**: FORBIDDEN — Pass 3 Commit 6 stale-closure risk.
- **TXVector caching**: FORBIDDEN per handoff §4.3 (Experiment B ruled it out as primary cost source).
- **`LazyVGrid` → other container (eager VStack/HStack)**: FORBIDDEN — exhausted by H-C5-a.
- **Canvas / ImageRenderer rasterization**: FORBIDDEN — out of single-commit scope.
- **Cell-pool / cell architecture rewrite**: FORBIDDEN — multi-file rewrite.
- **Cap / hide stamp grid**: FORBIDDEN — visual behavior change.
- **Shared `outsideBorder` modifier modification**: FORBIDDEN — would affect every other call site (`GoalEditCardView`, `CardHeaderView`, etc.); §4.8 one-file violation.

---

## 2. Diff sketch (1 file)

**File**: `Projects/Shared/DesignSystem/Sources/Components/Card/Stats/View/StatsCardView.swift`

**Current** (lines 48-61):

```swift
public var body: some View {
    VStack(spacing: 0) {
        header
        verticalDivider
        completionSection
    }
    .clipShape(RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
    .outsideBorder(
        Color.Gray.gray500,
        shape: RoundedRectangle(cornerRadius: Constants.cardCornerRadius),
        lineWidth: Constants.borderLineWidth
    )
    .onTapGesture { onTap(item.goalId) }
}
```

**Proposed** (replace `.outsideBorder(...)` modifier; everything else unchanged):

```swift
public var body: some View {
    VStack(spacing: 0) {
        header
        verticalDivider
        completionSection
    }
    .clipShape(RoundedRectangle(cornerRadius: Constants.cardCornerRadius))
    // Pass 5 H-C5-b: render-side duplication removal — same mechanism as
    // Pass 4-S2 H-C2-a (`GoalCardView.swift`). The shared `outsideBorder`
    // modifier implements as `overlay { shape.stroke().overlay(self) }`,
    // which composes the card subtree twice per render. Local
    // `.background { stroke }` replicates the visual (stroke drawn at the
    // view's bounds, inside half hidden by the clipped content above, outside
    // half visible) with one fewer subtree composition. Shared
    // `outsideBorder` modifier is intentionally unchanged.
    .background {
        RoundedRectangle(cornerRadius: Constants.cardCornerRadius)
            .stroke(Color.Gray.gray500, lineWidth: Constants.borderLineWidth * 2)
    }
    .onTapGesture { onTap(item.goalId) }
}
```

**Net change**: 5-line modifier swap, ~10 lines of explanatory comment. No imports added. No constants added. No other file modified.

**Why `lineWidth * 2`**: the stroke is drawn centered on the path. Half-width is inside the bounds (hidden by `clipShape` above), half-width is outside (visible). Original `outsideBorder` uses `shape.stroke(content, lineWidth: lineWidth * 2)` for the same reason. Visible width = `Constants.borderLineWidth` = 1 pt, matching baseline.

---

## 3. Visual risk

| risk | mitigation |
|---|---|
| stroke geometry / outside-edge alignment differs from `outsideBorder` | identical math used in H-C2-a; visual sanity passed on `GoalCardView` (simulator screenshot before/after identical) |
| corner radius mismatch | both modifiers use `RoundedRectangle(cornerRadius: Constants.cardCornerRadius)` — identical shape |
| stroke color mismatch | both use `Color.Gray.gray500` — unchanged |
| stroke width mismatch | both produce visible 1 pt outside-the-bounds line — unchanged |
| `onTapGesture` ordering — currently after `.outsideBorder`; preserve placement after `.background { stroke }` | preserved in proposed diff (last modifier on the chain) |
| `clipShape` interaction — content clipped to corner radius; stroke half-inside is also clipped | identical behavior in H-C2-a; verified visually on Home |

**Mitigation step before commit**: build + run simulator with `proof-photo-prefilled` analog seed (Stats has its own seed flow); compare before/after card border rendering visually. Discrepancy on any of: corner radius, color, width, outside-edge alignment, tap-area → REVERT before commit.

---

## 4. Gate plan

### 4.1 Scenario & configuration

- **Scenario**: Stats self-run scroll under `-UITEST_SWIFTUI_SELF_RUN_STATS_SCROLL` (existing harness, committed at `caa26be`).
- **Scheme**: `FeatureStatsExample`.
- **Configuration**: `PerfProfile` (PERF_TESTING gating active).
- **Device**: Jiyong의 iPhone, UDID `00008110-00096DC42632801E`, iOS 26.4.2.
- **Seed**: same `stats-heavy` seed Pass 4-S3 used for C5 baseline.
- **Templates × reps**: SwiftUI × 3 + Time Profiler × 3 + Animation Hitches × 3 = **9 traces** per (before / after).

### 4.2 Before-gate sourcing

- **Primary**: reuse `/tmp/twix-perf-traces/pass4-s3/c5-before/`. Verify all 9 trace bundles exist and are non-empty (`xcrun xctrace export ... | head` produces row data).
- **Fallback**: if `/tmp` was cleared since Pass 4-S3 (host /tmp is transient), re-collect fresh before-gate using the unchanged baseline (`pass4-rendering-before` tag still HEAD-adjacent since H-C5-a was reverted to baseline) with the same harness/seed/templates/reps/device/config. Document re-collection in the after-gate result doc.

### 4.3 After-gate collection

- Output: `/tmp/twix-perf-traces/pass5-after/h-c5-b/{swiftui,time-profiler,animation-hitches}/rep<1,2,3>.trace`.
- Contamination policy: same as Pass 3 / Pass 4 — SpringBoard activation, banner notification, driver wall ±50 %, malformed bundle, marker miss → discard + re-collect that rep.
- DND on, charging cable connected, Low Power Mode off, screen unlocked, no external displays/audio, device not hot.

### 4.4 KEEP criteria (all must hold)

1. **Animation Hitches count**: per-rep count reduced or unchanged vs baseline (`4 / 1 / 2`, mean 2.33). No rep with severe hang ≥ 33 ms reproduced 2/3 reps.
2. **Narrative reproducibility**: "Potentially expensive app update(s)" narrative reproducibility **< 3/3 reps** (any reduction is positive). Other narratives (e.g. "Potentially expensive render, N offscreen passes") count as positive evidence if eliminated.
3. **TP top-20**: no new user-code hot path appears in TP top-20 in any after rep that was not already present in before. (`destroy for StatsCardView`-style cell-deinit transients are not regressions; same exception as H-C2-a §3 comparison.)
4. **SwiftUI Template count**: reduction is **secondary / corroborating evidence only**. Not required to hit a specific threshold. If SwiftUI count moves without TP/Hitches improvement → REVERT (per §4.4 in handoff).
5. **`FeatureStatsExampleUITests`**: full suite passes.
6. **Visual regression**: none. Manual screenshot check before commit + smoke-test of `StatsExampleSmokeTests` post-commit.

### 4.5 REVERT criteria (any one triggers revert)

1. Animation Hitches per-rep count or stall-ms increases vs baseline.
2. "Potentially expensive app update(s)" narrative reproducibility unchanged at 3/3 reps **or** worse.
3. SwiftUI Template count moves but TP top-20 and Animation Hitches show no corroborating improvement → counts-only failure mode, same as H-C5-a.
4. New TP top-20 user-code hot path appears.
5. Visual regression (border geometry / color / width / corner / tap area).
6. Any `FeatureStatsExampleUITests` failure attributable to the change.
7. Diff scope grew beyond 1 file or beyond the local modifier swap.

### 4.6 Decision matrix

| outcome | hitches | narrative | TP | swiftui | verdict |
|---|---|---|---|---|---|
| Hitches ↓ + narrative ↓ + no new TP top-20 | ↓ or = | < 3/3 | clean | ↓ or = (corroborating) | **KEEP** |
| Hitches ↑ at any rep | ↑ | any | any | any | **REVERT** |
| Narrative 3/3 unchanged + SwiftUI count ↓ | = | 3/3 | clean | ↓ | **REVERT** (counts-only) |
| New TP top-20 user-code frame | any | any | new frame | any | **REVERT** |
| Visual regression | any | any | any | any | **REVERT** |
| Test regression attributable | any | any | any | any | **REVERT** |

---

## 5. Implementation sequence (after approval)

1. **Re-verify baseline trace bundles** at `/tmp/twix-perf-traces/pass4-s3/c5-before/`. If missing → re-collect fresh before-gate first (9 traces). Document.
2. **Apply diff** to `StatsCardView.swift` (the 5-line modifier swap + comment).
3. **Build**: `tuist generate --no-open` + `xcodebuild -workspace Twix.xcworkspace -scheme FeatureStatsExample -configuration PerfProfile -destination 'platform=iOS,id=00008110-00096DC42632801E' build-for-testing`.
4. **Visual sanity (simulator)**: launch `FeatureStatsExample` simulator, compare card border rendering with a baseline screenshot (before applying diff or from git stash). Any geometry mismatch → revert diff before commit.
5. **Smoke test**: `FeatureStatsExampleSmokeTests` + `FeatureStatsExampleRenderingTests` (non-perf parts) pass on simulator.
6. **Commit production change** as a single commit:
   - message: `perf(stats): StatsCardView outsideBorder render duplication removal - #310`
   - paired with no other change.
7. **After-gate trace collection** (9 traces) on device per §4.3.
8. **Analyze**:
   - SwiftUI Template counts + per-view event/µs breakdown (compare against §4.4 / §4.5).
   - TP top-20 per rep (any new user-code frame).
   - Animation Hitches narrative + count + stall ms.
9. **Verdict**:
   - **KEEP** → document in `pass5-h-c5-b-after-gate.md` with headline table; commit doc; proceed to C1/C6/keyboard closure + Pass 5 final/cumulative reports.
   - **REVERT** → `git revert` the production commit; commit revert doc; document in `pass5-h-c5-b-after-gate.md`; proceed as if C5 SKIP — Pass 5 still closes C5 (verdict = REVERT, hypothesis exhausted), then proceed to Pass 5 final/cumulative reports.
10. **Either way**: C5 is closed by Pass 5. No further hypothesis attempted in Pass 5 (one-hypothesis-per-pass-candidate after H-C5-a + H-C5-b).

---

## 6. Out-of-scope (explicit)

The following are explicitly OUT of H-C5-b scope and must not be touched by this commit:

- `Projects/Shared/DesignSystem/Sources/Modifiers/View+BorderInOutSide.swift` (shared modifier — unchanged).
- `StatsCardCompletionCell.swift` (cell-internal layout — unchanged).
- `StatsView.swift` / `StatsReducer*` (parent view + reducer — unchanged).
- `CardHeaderView.swift` / `GoalEditCardView.swift` (other `outsideBorder` consumers — unchanged in this commit; each is its own future hypothesis if ever opened).
- `TXVector` / SVG path / icon rendering — unchanged.
- `LazyVGrid` / `LazyVStack` — unchanged.
- `Equatable` / `EquatableView` / closure-stripping — not done.
- Canvas / ImageRenderer / rasterization — not done.
- Stamp count cap / visibility — not done.

---

## 7. Approval gate

Before implementation, please confirm:

1. **Diff sketch in §2** is acceptable (1 file, modifier swap + comment, identical visual intent).
2. **KEEP/REVERT criteria in §4.4 / §4.5** are correct as the final gate definition.
3. **Trace reuse plan in §4.2** is acceptable (reuse `/tmp/twix-perf-traces/pass4-s3/c5-before/` if intact, else re-collect).
4. **Commit message and structure in §5.6** is acceptable.

On approval, I will execute steps §5.1 through §5.4 (trace verify + diff + build + visual sanity), report results, then pause again before §5.5 (smoke test) and §5.6 (production commit) for a final commit-time confirmation.
