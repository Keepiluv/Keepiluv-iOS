import SharedPerfTestingSupportUITests
import XCTest

final class MainTabExampleSmokeTests: XCTestCase {
    func testExampleRendersReadyState() {
        _ = XCUIApplication.launchForPerf(seed: "default")
        waitForFeatureReady("main-tab")
    }

    func testCalendarBottomSheetCoversCustomTabBarAndCompletes() {
        let app = launchDesignSystemBottomSheetScenario()
        waitForFeatureReady("main-tab")

        let homeTab = app.buttons[DesignSystemBottomSheetScenarioID.homeTab]
        let statisticsTab = app.buttons[DesignSystemBottomSheetScenarioID.statisticsTab]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        XCTAssertTrue(statisticsTab.waitForExistence(timeout: 5))
        let tabBarFrame = homeTab.frame.union(statisticsTab.frame)
        attachScreenshot(named: "01-tabbar-baseline")

        app.buttons[DesignSystemBottomSheetScenarioID.presentButton].tap()

        let sheet = app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.sheetContent]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.calendarSheet].exists)
        XCTAssertTrue(app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.dragArea].exists)
        XCTAssertTrue(app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.calendarMonth("2026-05")].exists)
        XCTAssertLessThan(sheet.frame.minY, tabBarFrame.maxY)
        XCTAssertGreaterThanOrEqual(sheet.frame.maxY, tabBarFrame.maxY - 1)
        attachScreenshot(named: "02-sheet-over-tabbar")

        app.buttons[DesignSystemBottomSheetScenarioID.calendarNextButton].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.calendarMonth("2026-06")]
                .waitForExistence(timeout: 2)
        )
        attachScreenshot(named: "03-calendar-next-month")

        app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.completeButton].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 3))
        XCTAssertTrue(homeTab.waitForExistence(timeout: 3))
        XCTAssertTrue(statisticsTab.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.completedCount(1)].exists)
        attachScreenshot(named: "04-dismissed-tabbar-restored")
    }

    func testBottomSheetBackdropDismissesAndCanPresentRepeatedly() {
        let app = launchDesignSystemBottomSheetScenario()
        waitForFeatureReady("main-tab")

        let presentButton = app.buttons[DesignSystemBottomSheetScenarioID.presentButton]
        XCTAssertTrue(presentButton.waitForExistence(timeout: 5))

        presentButton.tap()
        let firstSheet = app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.sheetContent]
        XCTAssertTrue(firstSheet.waitForExistence(timeout: 5))
        attachScreenshot(named: "01-first-presentation")

        let backdrop = app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.backdrop]
        XCTAssertTrue(backdrop.waitForExistence(timeout: 2))
        backdrop.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(firstSheet.waitForNonExistence(timeout: 3))
        attachScreenshot(named: "02-backdrop-dismissed")

        presentButton.tap()
        let secondSheet = app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.sheetContent]
        XCTAssertTrue(secondSheet.waitForExistence(timeout: 5))
        attachScreenshot(named: "03-second-presentation")

        app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.completeButton].tap()
        XCTAssertTrue(secondSheet.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.completedCount(1)].exists)
        attachScreenshot(named: "04-second-dismissed")
    }

    func testBottomSheetQuickRepresentDuringDismissKeepsSheetVisible() {
        let app = launchDesignSystemBottomSheetScenario()
        waitForFeatureReady("main-tab")

        let quickRepresentButton = app.buttons[DesignSystemBottomSheetScenarioID.quickRepresentButton]
        XCTAssertTrue(quickRepresentButton.waitForExistence(timeout: 5))

        quickRepresentButton.tap()
        let sheet = app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.sheetContent]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.calendarSheet].exists)
        attachScreenshot(named: "01-quick-represent-sheet-visible")

        app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.completeButton].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)[DesignSystemBottomSheetScenarioID.completedCount(1)].exists)
        attachScreenshot(named: "02-quick-represent-dismissed")
    }

    private func launchDesignSystemBottomSheetScenario() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            "-UITEST",
            "-UITEST_SEED", "default",
            "-UITEST_WAIT_READY",
            "-UITEST_DISABLE_ANIMATIONS",
            "-UITEST_DESIGN_SYSTEM_BOTTOM_SHEET_SCENARIO"
        ])
        app.launch()
        return app
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private enum DesignSystemBottomSheetScenarioID {
    static let presentButton = "example.bottom-sheet.present-button"
    static let quickRepresentButton = "example.bottom-sheet.quick-represent-button"
    static let completedCountPrefix = "example.bottom-sheet.completed-count"
    static let calendarMonthPrefix = "example.bottom-sheet.calendar-month"
    static let sheetContent = "tx.bottom-sheet.content"
    static let backdrop = "tx.bottom-sheet.backdrop"
    static let dragArea = "tx.bottom-sheet.drag-area"
    static let calendarSheet = "tx.calendar-bottom-sheet"
    static let completeButton = "tx.calendar-bottom-sheet.complete-button"
    static let calendarNextButton = "tx.calendar.month-navigation.next-button"
    static let homeTab = "tx.tab-bar.item.home"
    static let statisticsTab = "tx.tab-bar.item.statistics"

    static func completedCount(_ count: Int) -> String {
        "\(completedCountPrefix).\(count)"
    }

    static func calendarMonth(_ yearDashMonth: String) -> String {
        "\(calendarMonthPrefix).\(yearDashMonth)"
    }
}
