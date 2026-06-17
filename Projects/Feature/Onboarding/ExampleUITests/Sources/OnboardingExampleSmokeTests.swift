import SharedPerfTestingSupportUITests
import XCTest

final class OnboardingExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("onboarding")
    }
}
