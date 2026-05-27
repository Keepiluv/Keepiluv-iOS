import SharedPerfTestingSupportUITests
import XCTest

final class GoalDetailExampleColdLaunchTests: XCTestCase {
    func testColdLaunch() {
        measure(metrics: [
            XCTClockMetric(),
            XCTMemoryMetric(),
            XCTCPUMetric()
        ]) {
            _ = XCUIApplication.launchForPerf(seed: "default")
            waitForFeatureReady("goal-detail", timeout: 30)
        }
    }
}
