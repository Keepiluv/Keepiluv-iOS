import SharedPerfTestingSupportUITests
import XCTest

final class HomeExampleScrollTests: XCTestCase {
    func testScrollFiftyCells() {
        let app = XCUIApplication.launchForPerf(seed: "scroll-50")
        waitForFeatureReady("home", timeout: 30)

        let feed = app.descendants(matching: .any)["feature.home.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 5), "feature.home.feed not found")

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
