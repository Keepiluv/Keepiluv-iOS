import SharedPerfTestingSupportUITests
import XCTest

final class StatsExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("stats")
    }
}
