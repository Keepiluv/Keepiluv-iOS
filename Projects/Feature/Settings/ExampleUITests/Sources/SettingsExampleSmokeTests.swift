import SharedPerfTestingSupportUITests
import XCTest

final class SettingsExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("settings")
    }
}
