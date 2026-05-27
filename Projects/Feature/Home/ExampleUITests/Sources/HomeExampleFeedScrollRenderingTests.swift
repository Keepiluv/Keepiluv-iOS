import SharedPerfTestingSupportUITests
import XCTest

/// Pass 3 **rendering driver** UITest for FeatureHomeExample.
///
/// This is a deterministic UI driver, **not a benchmark**. The XCTest
/// pass/fail status and any timing the XCTest harness happens to print are
/// not the rendering metric — they only indicate whether the deterministic
/// UI script completed. The authoritative rendering metric is a real-device
/// xctrace / Instruments trace recorded while this driver runs.
///
/// ## Intended use
///
/// 1. Launch this test against a real device. It launches with
///    `-UITEST` + `-UITEST_RENDERING_SCENARIO` + `-UITEST_SEED home-heavy`
///    and `disableAnimations: false`, so the PERF probe harness stays gated
///    off and animations behave like production.
/// 2. Attach `xcrun xctrace record --attach FeatureHomeExample` (Time
///    Profiler or SwiftUI template) once the driver enters the scroll
///    phase (UITest log shows `Synthesize event`).
/// 3. Stop the trace when the test reports completion.
/// 4. Compare before/after traces in Instruments. That comparison is the
///    authoritative rendering metric.
///
/// ## Determinism
///
/// - Single seed: `home-heavy` → 200 deterministic cells (`HomeApp.swift`).
/// - Fixed coordinate-based drag pattern (25 up + 25 down = 50
///   interactions). Coordinate-based drag is denser and produces less
///   accessibility idle wait between gestures than `swipeUp()`, so a
///   higher fraction of the recording window is actual scroll work.
/// - `disableAnimations: false` so SwiftUI animation timing reflects
///   production. (Smoke / probe scenarios use the default `true` for
///   stability; rendering scenarios must NOT inherit that setting.)
/// - No XCTest `measure(metrics:)`. The driver runs once per launch.
///
/// ## Guardrails
///
/// - Asserts that probe harness identifiers are absent, to catch the bug
///   where someone accidentally activates `-UITEST_PROBE_SCENARIO` and
///   pollutes a rendering trace with the 44pt layout shift.
final class HomeExampleFeedScrollRenderingTests: XCTestCase {

    /// Drives a same-screen state-change rendering scenario. Each calendar
    /// swipe dispatches the production `weekCalendarSwipe` action, which
    /// cascades through `.setCalendarDate` → `calendarWeeks` rebuild +
    /// `.fetchGoals` → 200-cell list reload + LazyVStack re-render. No
    /// navigation, no scroll-position change, no PERF harness. The
    /// authoritative metric is the Instruments / xctrace trace recorded
    /// while this driver runs. Not a benchmark.
    func testRendering_homeHeavyCalendarWeekSweep() {
        let app = XCUIApplication.launchForPerf(
            seed: "home-heavy",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("home", timeout: 30)

        let probeToastShow = app.descendants(matching: .any)["feature.home.perf.toast-show"]
        XCTAssertFalse(
            probeToastShow.exists,
            "PERF probe harness is active under a rendering scenario launch. The trace would be polluted by the 44pt layout shift. Re-check launchForPerf(scenario:) arguments."
        )

        // `feature.home.calendar` may be present on multiple descendants
        // because the TXCalendar composite propagates the accessibility
        // identifier to its internal cells. The first match in document
        // order is the calendar container — that's the swipe target.
        let calendar = app.descendants(matching: .any)
            .matching(identifier: "feature.home.calendar")
            .firstMatch
        XCTAssertTrue(calendar.waitForExistence(timeout: 10), "feature.home.calendar not found")

        // Horizontal drag on the calendar bar fires onSwipe -> reducer
        // `weekCalendarSwipe` -> `setCalendarDate(...)`. Each tick triggers
        // calendarWeeks regeneration + items refetch + cardList re-render.
        // 20 left + 20 right = 40 deterministic same-screen state changes.
        let left = calendar.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let right = calendar.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        for _ in 0..<20 {
            right.press(forDuration: 0.01, thenDragTo: left)
            left.press(forDuration: 0.01, thenDragTo: right)
        }
    }

    /// Drives the home-heavy feed scroll. Not a benchmark — use Instruments
    /// for the rendering metric. See class doc.
    func testRendering_homeHeavyFeedScroll() {
        let app = XCUIApplication.launchForPerf(
            seed: "home-heavy",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("home", timeout: 30)

        // Guardrail: rendering scenarios must NOT activate the PERF probe
        // harness, otherwise the 44pt layout shift would change scroll
        // geometry / LazyVStack materialization range and contaminate the
        // trace. If these identifiers exist, someone passed
        // `-UITEST_PROBE_SCENARIO` by accident.
        let probeToastShow = app.descendants(matching: .any)["feature.home.perf.toast-show"]
        XCTAssertFalse(
            probeToastShow.exists,
            "PERF probe harness is active under a rendering scenario launch. The trace this driver produces would be polluted by the 44pt layout shift. Re-check launchForPerf(scenario:) arguments."
        )

        let feed = app.descendants(matching: .any)["feature.home.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 10), "feature.home.feed not found")

        // Coordinate-based dense drag drive.
        //
        // IMPORTANT: normalize coordinates against the *window*, NOT the
        // `feed` element. `feed` is the LazyVStack inside a ScrollView and
        // its accessibility frame reports the *content* size (200 cells
        // ≈ 16,000pt tall on this fixture). Drag origins normalized to
        // that frame land far below the visible viewport and the OS
        // delivers them to Springboard, which backgrounds the app between
        // every drag and contaminates the recording with system activity.
        //
        // Window-normalized coordinates with safe dy values stay inside
        // the visible feed area (navbar + calendar bar live above dy 0.30,
        // home indicator lives below dy 0.85).
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "no window")
        let top = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let bottom = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80))
        for _ in 0..<25 {
            bottom.press(forDuration: 0.01, thenDragTo: top)
        }
        for _ in 0..<25 {
            top.press(forDuration: 0.01, thenDragTo: bottom)
        }
    }
}
