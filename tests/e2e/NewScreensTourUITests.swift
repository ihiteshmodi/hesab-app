import XCTest

/// Walks the newer screens on a copy of the owner's real data (plus made-up investments, trips and history) and saves a
/// screenshot of each to /tmp/hisaab-shots2. Skipped unless /tmp/hisaab-tour-enabled and /tmp/hisaab-real.sqlite exist.
/// Run it with: TOUR=1 scripts/run-ui-tests.sh NewScreensTourUITests
final class NewScreensTourUITests: XCTestCase {
    private var number = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/tmp/hisaab-tour-enabled"), "screen tour is off")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/tmp/hisaab-real.sqlite"), "no database copy to tour")
        try? FileManager.default.createDirectory(atPath: "/tmp/hisaab-shots2", withIntermediateDirectories: true)
    }

    @MainActor
    private func shot(_ name: String) {
        number += 1
        Thread.sleep(forTimeInterval: 1.0)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: String(format: "/tmp/hisaab-shots2/%@-%02d-%@.png", String(name.filter(\.isLetter).suffix(10)), number, name)))
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-database", "/tmp/hisaab-real.sqlite", "-ui-extras"]
        app.launch()
        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 60))
        return app
    }

    @MainActor
    private func tab(_ app: XCUIApplication, _ name: String) {
        let button = app.buttons["tab-\(name)"]
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        button.tap()
    }

    @MainActor
    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons.firstMatch
        if button.waitForExistence(timeout: 5) { button.tap() }
    }

    @MainActor
    private func close(_ app: XCUIApplication) {
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 3) { cancel.tap() } else if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        Thread.sleep(forTimeInterval: 0.5)
    }

    // MARK: reports

    @MainActor
    func testReports() {
        let app = launch()
        tab(app, "Reports")
        shot("breakdown")
        app.swipeUp(); shot("breakdown-lower"); app.swipeDown()
        app.buttons["Trends"].tap()
        shot("trends")
        app.swipeUp(); shot("trends-lower"); app.swipeDown()
        app.buttons["previousTrendMonth"].tap(); shot("trends-previous-month")
        app.buttons["nextTrendMonth"].tap()
        app.buttons["Breakdown"].tap()
        let row = app.descendants(matching: .any)["reportRow"].firstMatch
        if row.waitForExistence(timeout: 10) {
            row.tap(); shot("category-open")
            let split = app.descendants(matching: .any)["groupSplitRow"].firstMatch
            if split.waitForExistence(timeout: 10) { split.tap(); shot("category-filtered-one-subcategory") }
            app.swipeUp(); shot("category-expenses")
        }
    }

    // MARK: activity

    @MainActor
    func testActivity() {
        let app = launch()
        shot("activity-spending")
        app.buttons["Upcoming Expenses"].tap(); shot("upcoming-forecast")
        app.swipeUp(); shot("upcoming-forecast-lower"); app.swipeDown()
        app.buttons["Spending"].tap()
        let search = app.textFields["activitySearchField"]
        if search.waitForExistence(timeout: 10) {
            search.tap(); search.typeText("light")
            Thread.sleep(forTimeInterval: 2); shot("activity-search-results")
            app.swipeUp(); shot("activity-search-results-lower")
        }
    }

    // MARK: trips

    @MainActor
    func testTrips() {
        let app = launch()
        tab(app, "Trips")
        shot("trips-list")
        let rows = app.descendants(matching: .any).matching(identifier: "tripRow")
        let bali = rows.matching(NSPredicate(format: "label CONTAINS 'Bali'")).firstMatch
        if bali.waitForExistence(timeout: 10) {
            bali.tap()
            app.buttons["Plan"].tap()
            shot("bali-plan")
            app.swipeUp(); shot("bali-plan-lower"); app.swipeDown()
            app.buttons["Expenses"].tap(); shot("bali-expenses")
            let insights = app.buttons["tripInsightsButton"]
            if insights.exists { insights.tap(); shot("bali-insights"); back(app) }
            app.buttons["Plan"].tap()
            app.buttons["addPlanItemButton"].tap(); shot("plan-item-form"); close(app)
            let tick = app.buttons.matching(identifier: "planPaidToggle").element(boundBy: 2)
            if tick.exists { tick.tap(); shot("mark-as-paid-form"); close(app) }
            back(app)
        }
        let goa = rows.matching(NSPredicate(format: "label CONTAINS 'Goa'")).firstMatch
        if goa.waitForExistence(timeout: 10) { goa.tap(); shot("goa-planning"); back(app) }
    }

    // MARK: portfolio

    @MainActor
    func testPortfolio() {
        let app = launch()
        tab(app, "Portfolio")
        shot("portfolio-top")
        app.swipeUp(); shot("portfolio-investments")
        let stock = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Demo stock'")).firstMatch
        if stock.waitForExistence(timeout: 10) {
            stock.tap(); shot("stock-page")
            app.swipeUp(); shot("stock-page-lower"); app.swipeDown()
            app.buttons["holdingUpdateWorthButton"].tap(); shot("update-worth-form"); close(app)
            app.buttons["holdingEditButton"].tap(); shot("edit-investment-form"); close(app)
            back(app)
        }
        let sip = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Demo index SIP'")).firstMatch
        if sip.waitForExistence(timeout: 10) {
            sip.tap(); shot("sip-page")
            app.swipeUp(); shot("sip-page-lower"); app.swipeDown()
            let add = app.buttons["holdingAddMoneyButton"]
            if add.exists { add.tap(); shot("add-instalment-form"); close(app) }
            back(app)
        }
        app.buttons["addHoldingButton"].tap(); app.buttons["SIP"].tap(); shot("add-investment-sip-form"); close(app)
    }

    // MARK: forms

    @MainActor
    func testForms() {
        let app = launch()
        app.buttons["addMenu"].tap(); app.buttons["addExpenseButton"].tap()
        app.buttons["categoryPicker"].tap(); app.buttons["Home & Utilities"].tap()
        app.buttons["subCategoryPicker"].tap(); app.buttons["New sub-category…"].tap()
        shot("expense-new-subcategory"); close(app)
        app.buttons["addMenu"].tap(); app.buttons["addIncomeButton"].tap()
        app.buttons["incomeTypePicker"].tap(); app.buttons["Investment Income"].tap()
        shot("income-add-to-savings"); close(app)
        app.buttons["profileButton"].tap()
        let backup = app.buttons["backupLink"]
        if backup.waitForExistence(timeout: 10) {
            backup.tap()
            app.buttons["exportDataButton"].tap()
            _ = app.otherElements["ActivityListView"].waitForExistence(timeout: 15)
            Thread.sleep(forTimeInterval: 2)
            shot("export-share-sheet")
        }
    }
}
