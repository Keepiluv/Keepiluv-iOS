import SharedPerfTestingSupportUITests
import XCTest

/// Pass 3 **probe-only** UITests for FeatureHomeExample.
///
/// IMPORTANT — these tests are NOT UI Rendering benchmarks.
///
/// - The XCTest `Clock Monotonic Time` / `CPU Instructions Retired` numbers
///   reported by `measureActionLatency` include XCUI tap synthesis, marker
///   polling, accessibility-tree synchronization, and app/test process IPC.
///   They do not isolate SwiftUI rendering cost.
/// - The authoritative UI Rendering metric is an Xcode Instruments / xctrace
///   `Time Profiler` (or `SwiftUI`) trace recorded on a real device. The
///   UITest is only the deterministic driver that drives the app through the
///   same UI steps during recording.
/// - `PerfRebuildProxyPing` is a proxy signal for view rebuild frequency
///   (View struct init). It is not an exact SwiftUI body-evaluation counter.
/// - The `PerfToastPresentationHarness` modifier conditionally adds
///   `store.toast` observation to HomeView **only when UITestMode.isEnabled**.
///   Production HomeView does not observe `toast`. The probe scenario is
///   therefore an artificial path used to exercise observation scoping
///   experiments; it is NOT representative of the user's real rendering path.
/// - The PERF action harness sits as the first VStack child in HomeView and
///   shifts the production layout by ~44pt **only when the probe scenario is
///   active** (`-UITEST_PROBE_SCENARIO`). Plain UITest launches and
///   `-UITEST_RENDERING_SCENARIO` launches do not activate the harness, so
///   production layout / scroll geometry is preserved for those modes. Even
///   inside the probe scenario, residual effects of the harness on SwiftUI
///   layout pass, accessibility tree, scroll geometry, and LazyVStack
///   materialization cannot be fully ruled out — probe DELTAs should be
///   interpreted cautiously and any authoritative claim must be verified
///   with an Instruments trace from a rendering-scenario launch.
///
/// Treat the numbers below as **driver/probe sanity metrics**. Do not cite
/// them as UI Rendering improvement evidence.
///
/// ## Reading the measured metric
///
/// `measureActionLatency(repetitions: 5)` reports the time for the **bundle**
/// of 5 repetitions per `measure` iteration. To derive per-state-change
/// latency: `bundle / repetitions / (state changes per repetition)`. For
/// these probes each repetition performs 2 state changes (show+dismiss or
/// next+prev), so per-action latency = `bundle / 5 / 2`.
final class HomeExampleRenderingProbeTests: XCTestCase {

    /// Probe: toggle `store.toast` via PERF-only buttons and confirm the
    /// `PerfToastPresentationHarness` marker + `home.view.rebuild.proxy`
    /// counter respond. Not an authoritative rendering metric.
    func testProbe_toastShowDismiss_markerAndCounter() {
        let app = XCUIApplication.launchForPerf(seed: "default", scenario: .probe)
        waitForFeatureReady("home", timeout: 30)

        let showButton = app.descendants(matching: .any)["feature.home.perf.toast-show"]
        let dismissButton = app.descendants(matching: .any)["feature.home.perf.toast-dismiss"]
        XCTAssertTrue(showButton.waitForExistence(timeout: 5), "PERF toast-show button missing")
        XCTAssertTrue(dismissButton.exists, "PERF toast-dismiss button missing")
        awaitPerfMarker(slug: "home", key: "toast", value: "hidden", timeout: 5)

        // Probe-only driver metric. See class doc-comment.
        measureActionLatency(repetitions: 5) {
            showButton.tap()
            awaitPerfMarker(slug: "home", key: "toast", value: "visible")
            dismissButton.tap()
            awaitPerfMarker(slug: "home", key: "toast", value: "hidden")
        }

        let rebuildProxy = readPerfCounter(slug: "home", key: "home.view.rebuild.proxy")
        XCTAssertGreaterThan(
            rebuildProxy,
            0,
            "home.view.rebuild.proxy counter never incremented (proxy signal, not exact body count)"
        )
        print("[perf-probe-counters] home.view.rebuild.proxy=\(rebuildProxy)")
    }

    /// Probe: toggle `calendarDate` via PERF-only buttons and confirm the
    /// calendar sub-view `perfStateMarker` responds. Triggers a real
    /// production cascade (calendarWeeks / items refetch), so this probe
    /// includes more than a pure presentation-only state change. Not an
    /// authoritative rendering metric.
    func testProbe_calendarMonthToggle_markerAndCounter() {
        let app = XCUIApplication.launchForPerf(seed: "default", scenario: .probe)
        waitForFeatureReady("home", timeout: 30)

        let nextButton = app.descendants(matching: .any)["feature.home.perf.calendar-next"]
        let prevButton = app.descendants(matching: .any)["feature.home.perf.calendar-prev"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5), "PERF calendar-next button missing")
        XCTAssertTrue(prevButton.exists, "PERF calendar-prev button missing")

        let baseMarker = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'feature.home.marker.calendar-month.'"))
            .firstMatch
        XCTAssertTrue(baseMarker.waitForExistence(timeout: 5), "initial calendar-month marker missing")
        let baseIdentifier = baseMarker.identifier
        let baseValue = baseIdentifier.replacingOccurrences(
            of: "feature.home.marker.calendar-month.",
            with: ""
        )
        let baseParts = baseValue.split(separator: "-").compactMap { Int($0) }
        guard baseParts.count == 2 else {
            XCTFail("unexpected base marker identifier: \(baseIdentifier)")
            return
        }
        let baseYear = baseParts[0]
        let baseMonth = baseParts[1]
        let nextYear = baseMonth == 12 ? baseYear + 1 : baseYear
        let nextMonth = baseMonth == 12 ? 1 : baseMonth + 1
        let nextValue = "\(nextYear)-\(nextMonth)"

        // Probe-only driver metric. See class doc-comment.
        measureActionLatency(repetitions: 5) {
            nextButton.tap()
            awaitPerfMarker(slug: "home", key: "calendar-month", value: nextValue)
            prevButton.tap()
            awaitPerfMarker(slug: "home", key: "calendar-month", value: baseValue)
        }

        let rebuildProxy = readPerfCounter(slug: "home", key: "home.view.rebuild.proxy")
        XCTAssertGreaterThan(
            rebuildProxy,
            0,
            "home.view.rebuild.proxy counter never incremented (proxy signal, not exact body count)"
        )
        print("[perf-probe-counters] home.view.rebuild.proxy=\(rebuildProxy)")
    }
}
