import SharedPerfTestingSupportUITests
import XCTest

/// Pass 3 **rendering driver** UITests for FeatureStatsExample.
///
/// These tests are NOT benchmarks. They drive deterministic UI activity so
/// that a real-device xctrace recording (Time Profiler + Animation Hitches)
/// captures the Stats rendering path. XCTest pass/fail is correctness only.
///
/// ## Intended use
///
/// 1. Launch on a real device with seed `stats-heavy` (200 deterministic
///    stats items). The driver launches with `-UITEST_RENDERING_SCENARIO`
///    + `disableAnimations: false` so animations behave like production.
/// 2. Attach `xcrun xctrace record --attach FeatureStatsExample` once
///    `feature.stats.ready` exists (initial render) or after the
///    `Synthesize event` log line (scroll).
/// 3. Stop the trace when the test reports completion.
///
/// ## Scenarios
///
/// - `testRendering_statsHeavyInitialRender` — launch + 7s idle window.
///   Captures the initial LazyVStack materialization + idle cost on a
///   200-cell list.
/// - `testRendering_statsHeavyScroll` — coordinate-based dense drag on
///   the visible viewport. Coordinates are anchored on the window
///   (NOT on `feature.stats.feed`, whose accessibility frame reports
///   LazyVStack content size and could land drags off-screen and bleed
///   to SpringBoard — same root cause as the Home feed-scroll fix).
///
/// ## Determinism
///
/// - Single seed (`stats-heavy` → 200 fixed-content cells via the new
///   `perfStatsClient(count:)` branch).
/// - Fixed coordinate-based drag pattern (25 down→up + 25 up→down = 50
///   interactions per recording window).
/// - `disableAnimations: false` to reflect production animation timing.
/// - No XCTest `measure(metrics:)`. The driver runs once per launch.
///
/// ## Separation from existing tests
///
/// `StatsExampleScrollTests.testScrollFiftyCells` uses `measure(metrics:)`
/// and the smaller `scroll-50` seed; it remains as a probe-style sanity
/// signal but is NOT the authoritative rendering metric. The tests in this
/// file are the authoritative driver paths for xctrace.
final class StatsExampleRenderingTests: XCTestCase {

    /// Drives heavy initial render + 7s idle window.
    func testRendering_statsHeavyInitialRender() {
        let app = XCUIApplication.launchForPerf(
            seed: "stats-heavy",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("stats", timeout: 30)

        let feed = app.descendants(matching: .any)["feature.stats.feed"]
        XCTAssertTrue(
            feed.waitForExistence(timeout: 10),
            "feature.stats.feed not found — stats-heavy seed probably not delivered"
        )

        Thread.sleep(forTimeInterval: 7.0)
    }

    /// Drives 50 coordinate-based drags on the visible viewport. Window-
    /// normalized so the drag stays inside the safe scroll area; never
    /// resolves to the LazyVStack content-size frame.
    func testRendering_statsHeavyScroll() {
        let app = XCUIApplication.launchForPerf(
            seed: "stats-heavy",
            scenario: .rendering,
            disableAnimations: false
        )
        waitForFeatureReady("stats", timeout: 30)

        let feed = app.descendants(matching: .any)["feature.stats.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 10), "feature.stats.feed not found")

        // IMPORTANT: anchor coordinates on `app.windows.firstMatch`, NOT on
        // `feed`. The feed's accessibility frame reports LazyVStack
        // content size (very tall with 200 cells) — feed-normalized dy
        // 0.20/0.85 would land far below the visible viewport and the OS
        // would deliver drags to SpringBoard. Window-normalized stays in
        // the visible scroll area.
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
