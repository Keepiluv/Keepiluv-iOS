import SharedPerfTestingSupportUITests
import XCTest

final class NotificationExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("notification")
    }
}
