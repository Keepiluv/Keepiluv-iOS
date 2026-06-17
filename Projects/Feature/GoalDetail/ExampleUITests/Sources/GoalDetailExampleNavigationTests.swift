import SharedPerfTestingSupportUITests
import XCTest

final class GoalDetailExampleNavigationTests: XCTestCase {
    func testPrimaryCtaPresentsProofPhoto() {
        let app = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("goal-detail")

        let primaryCta = app.descendants(matching: .any)["feature.goal-detail.primary-cta"]
        XCTAssertTrue(primaryCta.waitForExistence(timeout: 5), "primary-cta not found")
        primaryCta.tap()

        let destinationReady = app.descendants(matching: .any)["feature.goal-detail-to-proof-photo.ready"]
        XCTAssertTrue(
            destinationReady.waitForExistence(timeout: 10),
            "goal-detail-to-proof-photo ready marker did not appear"
        )
    }
}
