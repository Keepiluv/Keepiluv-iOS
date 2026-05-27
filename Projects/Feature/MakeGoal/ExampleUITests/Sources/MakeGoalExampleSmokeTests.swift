import SharedPerfTestingSupportUITests
import XCTest

final class MakeGoalExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("make-goal")
    }
}
