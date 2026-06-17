import SharedPerfTestingSupportUITests
import XCTest

final class HomeExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("home")
    }
}
