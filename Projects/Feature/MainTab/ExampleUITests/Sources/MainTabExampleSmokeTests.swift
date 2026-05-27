import SharedPerfTestingSupportUITests
import XCTest

final class MainTabExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("main-tab")
    }
}
