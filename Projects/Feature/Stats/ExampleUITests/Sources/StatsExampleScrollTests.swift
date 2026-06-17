import SharedPerfTestingSupportUITests
import XCTest

final class StatsExampleScrollTests: XCTestCase {
    func testScrollFiftyCells() {
        let app = XCUIApplication.launchForPerf(seed: "scroll-50")
        waitForFeatureReady("stats", timeout: 30)

        let feed = app.descendants(matching: .any)["feature.stats.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 5), "feature.stats.feed not found")

        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric(),
            XCTCPUMetric()
        ]) {
            for _ in 0..<5 {
                feed.swipeUp()
            }
        }
    }
}
