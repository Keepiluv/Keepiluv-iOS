import SharedPerfTestingSupportUITests
import XCTest

final class AuthExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("auth")
    }
}
