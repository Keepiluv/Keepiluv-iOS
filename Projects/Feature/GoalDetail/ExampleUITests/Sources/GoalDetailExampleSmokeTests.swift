import SharedPerfTestingSupportUITests
import XCTest

final class GoalDetailExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("goal-detail")
    }
}
