import SharedPerfTestingSupportUITests
import XCTest

final class ProofPhotoExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("proof-photo")
    }
}
