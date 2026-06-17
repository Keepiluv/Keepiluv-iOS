import SharedPerfTestingSupportUITests
import XCTest

final class StatsExampleNavigationTests: XCTestCase {
    func testTappingCellPushesStatsDetail() {
        let app = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("stats")

        let firstCell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'feature.stats.cell.'"))
            .firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "no Stats cell found")
        firstCell.tap()

        let destinationReady = app.descendants(matching: .any)["feature.stats-to-stats-detail.ready"]
        XCTAssertTrue(
            destinationReady.waitForExistence(timeout: 10),
            "stats-to-stats-detail ready marker did not appear"
        )
    }
}
