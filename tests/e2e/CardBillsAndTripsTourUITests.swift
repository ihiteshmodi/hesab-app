import XCTest

/// Walks the updated Upcoming Expenses, Trips list, Menu badge and Card Bills screens on a scratch copy of real data.
/// Skipped unless /tmp/hisaab-tour-enabled and /tmp/hisaab-real.sqlite exist.
/// Run with: TOUR=1 scripts/run-ui-tests.sh CardBillsAndTripsTourUITests
final class CardBillsAndTripsTourUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/tmp/hisaab-tour-enabled"), "screen tour is off")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/tmp/hisaab-real.sqlite"), "no database copy to tour")
    }

    @MainActor
    private func attach(_ name: String) {
        Thread.sleep(forTimeInterval: 0.9)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func launchReal() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-database", "/tmp/hisaab-real.sqlite"]
        app.launch()
        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 60))
        return app
    }

    @MainActor
    func testUpcomingExpensesAndMenuBadge() {
        let app = launchReal()
        attach("01-activity-profile-badge")

        app.buttons["Upcoming Expenses"].tap()
        attach("02-upcoming-expenses-no-chart")

        app.buttons["Spending"].tap()
        app.buttons["profileButton"].tap()
        attach("03-left-menu-card-bills-badge")
    }

    @MainActor
    func testTripsListPlannedCost() {
        let app = launchReal()
        let tripsTab = app.buttons["tab-Trips"]
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 20))
        tripsTab.tap()
        attach("04-trips-list-planned-cost")
    }

    @MainActor
    func testCardBillsCyclesAndCutoff() {
        let app = launchReal()
        app.buttons["profileButton"].tap()
        let cardLink = app.buttons["cardBillsLink"]
        XCTAssertTrue(cardLink.waitForExistence(timeout: 20))
        cardLink.tap()
        attach("05-card-bills-november-unpaid")

        let payButtons = app.buttons.matching(identifier: "cardPaidButton")
        let targetPay = payButtons.count > 2 ? payButtons.element(boundBy: 2) : payButtons.firstMatch
        if targetPay.waitForExistence(timeout: 10) {
            targetPay.tap()
            attach("06-pay-card-cutoff-sheet")
            let confirm = app.buttons["confirmCardPaidButton"]
            if confirm.waitForExistence(timeout: 10) { confirm.tap() }
            attach("07-card-bills-after-paying-with-blue-new-spend")
        }

        let nextMonth = app.buttons["nextCardMonth"]
        if nextMonth.waitForExistence(timeout: 10) {
            nextMonth.tap()
            attach("08-card-bills-december-carryover-and-new-spend")
        }

        let firstCardEdit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'editCard-'")).firstMatch
        if firstCardEdit.waitForExistence(timeout: 10) {
            firstCardEdit.tap()
            attach("09-edit-card-due-day-sheet")
        }
    }
}
