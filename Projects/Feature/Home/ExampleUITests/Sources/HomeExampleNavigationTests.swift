import SharedPerfTestingSupportUITests
import XCTest

final class HomeExampleNavigationTests: XCTestCase {
    func testTappingCellPushesDestination() {
        let app = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("home")

        let firstCell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'feature.home.cell.'"))
            .firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "no Home cell found")
        firstCell.tap()

        let destinationReady = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'feature.home-to-'"))
            .firstMatch
        XCTAssertTrue(
            destinationReady.waitForExistence(timeout: 10),
            "no destination ready marker (home-to-goal-detail or home-to-stats-detail) appeared"
        )
    }
}
