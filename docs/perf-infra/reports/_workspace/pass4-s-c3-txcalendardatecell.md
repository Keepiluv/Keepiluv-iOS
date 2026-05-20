# Pass 4-S C3 — TXCalendarDateCell idle invalidation

**Status**: read-only investigation + Time Profiler / Animation Hitches before-gate. **Verdict: SKIP per gate.**

## 1. Signal recap (from Pass 4-S audit §C3)

SwiftUI Template, Home idle scenarios (launch mode, `-UITEST_SEED scroll-50` and `home-heavy`), 3/3 reps each:

| field | value |
|---|---|
| description | `TXCalendarDateCell.body` |
| module | `FeatureHomeExample` |
| update-type | `View Body Updates` |
| mean count / rep | 21.0 |
| mean µs / rep | ~1,500 (≈ 1.5 ms summed across all events) |
| reps | 3/3 |
| scenario coverage | Home scroll-50 idle, Home heavy idle |

Magnitude pattern: 21 events / 20s window ≈ 1 event/sec. Decomposable as either (a) 7 visible weekly cells × 3 parent re-evals, or (b) 7 cells × 3 weekly pages with cascading re-eval. Both decompositions are consistent with one TXCalendar parent body re-evaluation per ~7s on idle.

## 2. Read-only code findings

### 2.1 TXCalendarDateCell.swift (DesignSystem)

`SharedDesignSystem/Sources/Components/Calendar/Core/TXCalendarDateCell.swift:10-22`

```swift
struct TXCalendarDateCell: View {
    let item: TXCalendarDateItem
    let style: TXCalendarDateStyle
    let customBackground: AnyView?

    var body: some View {
        Text(item.text)
            .typography(style.typography)
            .foregroundStyle(textColor)
            .frame(width: style.size, height: style.size)
            .background { backgroundView }
    }
}
```

- Body is small: `Text` + `.typography` + `.foregroundStyle` + `.frame` + `.background`.
- No `TimelineView`, `Date()`, `@Environment`, `@State`, `@StateObject`, `@ObservedObject`, `GeometryReader`, `PreferenceKey`, animation modifier, or timer.
- Stored properties are all `let`. View struct does NOT conform to `Equatable` explicitly.
- The cell does not own a self-initiated invalidation source. Re-evaluation must be driven by the parent re-eval and/or input identity churn.

### 2.2 TXCalendar.swift parent

`SharedDesignSystem/Sources/Components/Calendar/Core/TXCalendar.swift:143-201`

`body` is wrapped in `GeometryReader`. Weekly mode renders three horizontal pages up-front (lines 187–193):

```swift
weeklyPage(items: weeklyPageItems(weekOffset: -1), spacing: spacing).frame(width: width)
weeklyPage(items: weeklyPageItems(weekOffset:  0), spacing: spacing).frame(width: width)
weeklyPage(items: weeklyPageItems(weekOffset:  1), spacing: spacing).frame(width: width)
```

`weeklyPageItems(weekOffset:)` for non-zero offsets (lines 422–446) calls:

```swift
let items = TXCalendarDataGenerator.generateWeekData(
    for: referenceDate,
    weekOffset: weekOffset
).first ?? []
```

…and returns a `.map { item in ... }` chain that produces NEW `TXCalendarDateItem` instances on every call.

### 2.3 TXCalendarDataGenerator.swift

`SharedDesignSystem/Sources/Components/Calendar/Utilities/TXCalendarDataGenerator.swift:183-205`

`buildWeekItems` returns items via `.init(text:status:dateComponents:)` (line 199), which falls back to the default initializer:

```swift
public init(
    id: UUID = UUID(),  // ← fresh UUID per call
    text: String,
    status: TXCalendarDateStatus = .default,
    dateComponents: DateComponents? = nil
)
```

(from `TXCalendarModels.swift:36-46`)

**Identity drift**: every call to `generateWeekData` produces items with fresh UUIDs. Since `TXCalendarDateItem: Equatable` derives from synthesized conformance over all stored properties including `id`, two items with the same text/status/dateComponents but generated separately compare as `!=`.

This means the ±1 weekly page TXCalendarDateCell instances receive a different `item.id` on every TXCalendar.body re-evaluation, even when the underlying date data has not changed.

### 2.4 HomeView consumption

`Projects/Feature/Home/Sources/Home/HomeView.swift:116-147` (`HomeCalendarSection`)

```swift
TXCalendar(
    mode: .weekly,
    currentDate: $store.calendarDate,
    weeks: store.calendarWeeks,
    ...
    onSelect: { item in store.send(.calendarDateSelected(item)) },
    onSwipe:  { swipe in store.send(.weekCalendarSwipe(swipe)) }
)
```

- Pass 3 Commit 3 already isolated `HomeCalendarSection` so its observation of `$store.calendarDate` and `store.calendarWeeks` does NOT leak into the parent `HomeView`. Intact and confirmed by `HomeView.body` showing only 0.7 evals/rep in Pass 4-S inventory.
- On idle, `store.calendarDate` and `store.calendarWeeks` do not change (no timer/auto-emit in `HomeReducer`).
- Closures (`onSelect`, `onSwipe`) are constructed fresh on every body call of `HomeCalendarSection`, but that drives `HomeCalendarSection`'s child re-eval only when `HomeCalendarSection.body` itself fires.

### 2.5 HomeReducer time/timer dependencies

`grep` confirms no `Timer`, `TimelineView`, `.timer`, `.repeat`, or `scheduledTimer` in `Projects/Feature/Home/Sources/` or `Interface/`. The only `Date()` call is in `HomeReducer+Impl.swift:42,68` (poke timestamp helpers, action-driven only).

### 2.6 swiftui-causes signal (Home heavy idle rep1)

The `swiftui-causes` table in Home idle SwiftUI traces shows source-node labels including:

- "Creation of App" (initial setup, one-shot)
- "External: Time" (system-level time source — likely vsync / animation-phase tick)
- "External Environment"
- "External: _GraphInputs.Phase"

These are SwiftUI-internal external drivers, not user-code state. The 21 cell body events appear to be cascade fan-out from one TXCalendar parent re-evaluation per several seconds, driven by `_GraphInputs.Phase` / `External: Time` updates which are part of SwiftUI's normal idle phase advancement.

## 3. Hypothesis (if a fix were attempted)

The most localized hypothesis: stabilize the ±1 weekly page generation so that input identity is invariant when `currentDate` hasn't changed. Two viable shapes:

- **H1** — Cache `weeklyPageItems(±1)` results in `@State` keyed by `currentDate`. The central page already uses stable props.
- **H2** — Conditionally include ±1 pages only when `isWeeklyPaging || weeklyDragTranslation != 0`. Reduces idle cell count from 21 to 7.
- **H3** — Change `TXCalendarDataGenerator` initializers so id is deterministic from `(year, month, day)`. Widely-touched public-API change with unknown blast radius (tests, selection logic, sheet/bottom-sheet identity).

H1 is least invasive but requires `@State` inside `TXCalendar` and care around `currentDate` change detection.
H3 has the largest correctness risk.
H2 is the cleanest reduction in idle work but changes drag behavior on first frame after drag-start.

**None of H1–H3 are implemented in this investigation.** Each would need its own ProjectRules / DesignSystem review.

## 4. Before-gate evidence (Time Profiler + Animation Hitches)

### 4.1 Method

| field | value |
|---|---|
| device | iPhone 13 Pro Max, iOS 26.4.2 (`00008110-00096DC42632801E`) |
| configuration | PerfProfile (matches Pass 4-S launch-mode SwiftUI sweep) |
| scenario | Home home-heavy idle, launch mode, args `-UITEST -UITEST_RENDERING_SCENARIO -UITEST_SEED home-heavy -UITEST_WAIT_READY` |
| templates | Time Profiler × 3 reps + Animation Hitches × 3 reps |
| window | 20s per trace |
| trace root | `/tmp/twix-perf-traces/pass4-s/c3-before/home-heavy-idle/` |

### 4.2 Animation Hitches (3 reps)

| metric | rep1 | rep2 | rep3 |
|---|---:|---:|---:|
| potential-hangs rows | 0 | 0 | 0 |
| hitches rows | 0 | 0 | 0 |
| termination | exit(0) | exit(0) | exit(0) |
| bundle MB | 85.1 | 78.3 | 75.1 |
| contamination | none | none | none |

**0 hangs, 0 hitches across 3/3 reps.** Idle Home shows no Animation Hitches detector activity at all.

### 4.3 Time Profiler (3 reps)

| metric | rep1 | rep2 | rep3 |
|---|---:|---:|---:|
| slow functions (≥100ms) | 0 | 0 (analyzer race) | 0 |
| max single-function ms | 7 | (analyzer race) | 8 |
| max user-code self-time ms | 2 | (analyzer race) | 2 |
| top user-code frame | `-[UIView _performPreLayoutUpdateOfLayer:]` (2ms / 2 samples) | — | `CardHeaderView.body.getter` (2ms / 2 samples) |
| TXCalendarDateCell.body in top-30? | NO | (analyzer race) | NO |
| TXCalendar.body in top-30? | NO | (analyzer race) | NO |
| TXNavigationBar.body in top-30? | NO | (analyzer race) | NO |
| termination | exit(0) | exit(0) | exit(0) |

rep2 hit a TOC export race (`xctrace export --xpath` returned no usable rows when analyzer called it), but the trace bundle is valid (`exit(0)`, 5MB). Re-export of `potential-hangs` rows succeeded with 0 rows. rep1/rep3 give consistent picture: no calendar-related user-code frame appears in the Time Profiler top-N at all.

### 4.4 Verdict against the gate

The user-supplied measurement gate for C3 (verbatim):

> Keep only if:
> - TXCalendarDateCell-related SwiftUI update signal is reduced, and
> - Time Profiler or Animation Hitches shows no regression, and
> - no new hot path appears, and
> - Home rendering/smoke tests pass.
> Revert or skip if the change is speculative or only improves SwiftUI Template counts without Time Profiler/Hitches support.

**Result**: the before-gate already shows 0 hangs / 0 hitches / no user-code frames involving `TXCalendar*` in Time Profiler top-N. There is no measurable main-thread cost on idle Home for TXCalendarDateCell. The SwiftUI Template signal of 21 events × ~1.5ms accounts for SwiftUI's own internal update events at sub-ms granularity, which sits below the Time Profiler sampling resolution and far below the 100ms Animation Hitches threshold.

Any hypothesis (H1/H2/H3) implemented now would *only* reduce SwiftUI Template counts and would not be supported by Time Profiler / Animation Hitches. That is exactly the "revert or skip" condition.

→ **C3: SKIP per gate.** No production code change.

## 5. Honest caveats

- The SwiftUI Template signal is real but its magnitude is below the noise floor of Time Profiler at this sampling configuration. SwiftUI Template internal accounting (sub-ms event records) is more sensitive than Time Profiler (1ms-bucket statistical samples).
- The gate is **idle Home** specifically. This does not say TXCalendar is cheap during weekly swipe / month toggle / calendar bottom-sheet open. Those are interactive scenarios the Pass 4-S attach-mode trial could not measure, and Pass 3 did not isolate either.
- The UUID-on-init identity drift in `TXCalendarDateItem` is a real shape issue and may matter for *interactive* scenarios where TXCalendar.body re-evals at higher frequency (drag, animation). It is documented here for future follow-up but is NOT escalated to a Pass 4-S commit.
- rep2 Time Profiler trace bundle is valid but had an analyzer export race; the conclusion does not depend on rep2 since rep1 + rep3 agree with each other and with all 3 Animation Hitches reps.
- Pass 4-S audit rule reaffirmed: "do not optimize from SwiftUI Template numbers alone." Honored.

## 6. Implication for adjacent candidates

C1 (TXNavigationBar idle re-eval), which showed 3.3ms / 1–3 evals per rep on the same Home idle traces, is in the same magnitude class as C3 and similarly does not appear in the Time Profiler top-N of these before-gate traces (verified rep1/rep3). C1 is also unlikely to pass its own gate under idle Home. Re-collecting before-gate for C1 separately would be redundant under the current scenario.

C5 (Stats `ScrollViewChildContainerSize` re-query) and C2 (Home `LazyVStack` adaptor) are SwiftUI-internal signals attributed to system code, so the gate would need to detect *user-code* improvement after any change — also weak unless an interactive scenario is captured.

## 7. Recommendation

- Close C3 as **SKIP per gate**.
- Do not re-collect before-gate for C1 under the same idle scenario — the existing TP traces already show no TXNavigationBar frames.
- For Pass 4-S to produce any actionable optimization, the gate would need to move to an **interactive** scenario (e.g., Home feed-scroll, Stats heavy-scroll, calendar swipe). Those are XCUITest driver-required, and SwiftUI Template attach mode produced 0 rows. A separate plan would be needed to either (a) make the driver scenarios self-running in launch mode, or (b) accept Time Profiler + Animation Hitches as the only attribution surface for interactive scenarios (the current Pass 3/4 default).
- Update Pass 4-S audit with these gate outcomes.

## 8. Workspace artifacts

- `/tmp/twix-perf-traces/pass4-s/c3-before/home-heavy-idle/timeprofiler/*.trace` (3 reps)
- `/tmp/twix-perf-traces/pass4-s/c3-before/home-heavy-idle/hitches/*.trace` (3 reps)
- `/tmp/twix-perf-traces/pass4-s/c3-before/home-heavy-idle/summary.tsv`
- `/tmp/twix-perf-traces/pass4-s/c3-before/home-heavy-idle/collection.log`
- `/tmp/pass4-s-c3-before.sh` (collection script)
