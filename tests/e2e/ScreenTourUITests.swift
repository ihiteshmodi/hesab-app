import XCTest

/// Walks the main screens with made-up data and saves a screenshot of each to /tmp/hisaab-shots for a visual check.
/// Skipped unless the file /tmp/hisaab-tour-enabled exists, so the normal suite does not run it.
final class ScreenTourUITests: XCTestCase {
    private var number = 0

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(FileManager.default.fileExists(atPath: "/tmp/hisaab-tour-enabled"), "screen tour is off")
        try? FileManager.default.createDirectory(atPath: "/tmp/hisaab-shots", withIntermediateDirectories: true)
    }

    @MainActor
    private func shot(_ name: String) {
        number += 1
        Thread.sleep(forTimeInterval: 0.8)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: String(format: "/tmp/hisaab-shots/%02d-%@.png", number, name)))
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

    @MainActor
    func testTour() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-demo-data"]
        app.launch()
        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 30))

        // Activity
        shot("activity-spending")
        app.swipeUp(); shot("activity-spending-lower"); app.swipeDown()
        app.buttons["Income"].tap(); shot("activity-income-list")
        app.buttons["Calendar"].tap(); shot("activity-calendar")
        app.buttons["Expenses"].tap()
        app.buttons["Upcoming Expenses"].tap(); shot("upcoming-expenses")
        app.buttons["Upcoming Income"].tap(); shot("upcoming-income")
        app.buttons["editUpcomingIncomeFiltersButton"].tap(); shot("upcoming-income-filters"); close(app)
        app.buttons["Spending"].tap()

        // Tiles
        for (id, name) in [("pendingRefundsTile", "pending-refunds"), ("pendingToSendTile", "pending-to-send"),
                           ("cashInHandTile", "cash-in-hand"), ("amountToRepayTile", "amount-to-repay")] {
            let tile = app.buttons[id]
            if tile.waitForExistence(timeout: 5) { tile.tap(); shot(name); back(app) }
        }
        app.buttons["amountToRepayTile"].tap()
        app.buttons["Repaid"].tap(); shot("amount-to-repay-repaid")
        app.buttons["addBorrowingButton"].exists ? () : app.buttons["Active"].tap()
        app.buttons["addBorrowingButton"].tap(); shot("add-borrowing"); close(app)
        back(app)

        // Forms
        app.buttons["addMenu"].tap(); app.buttons["addExpenseButton"].tap()
        app.buttons["categoryPicker"].tap(); app.buttons["Monthly Fixed Expenses"].tap()
        app.buttons["paymentPicker"].tap(); app.buttons["Cash Withdrawal"].tap()
        shot("add-expense-long-names"); close(app)
        app.buttons["addMenu"].tap(); app.buttons["addIncomeButton"].tap()
        app.buttons["incomeTypePicker"].tap(); app.buttons["Borrowed"].tap()
        shot("add-income-borrowed"); close(app)
        app.buttons["Upcoming Expenses"].tap()
        app.buttons["addUpcomingBillButton"].firstMatch.tap(); shot("add-to-budget"); close(app)
        app.buttons["Spending"].tap()
        app.buttons["profileButton"].tap(); shot("menu")
        app.buttons["settingsLink"].tap(); shot("settings"); back(app)

        // Bills
        app.buttons["tab-Bills"].tap(); shot("bills")
        app.swipeUp(); shot("bills-lower"); app.swipeDown()
        app.buttons["billRow"].firstMatch.tap(); shot("edit-bill"); close(app)
        app.buttons["billsFilterButton"].tap(); shot("bills-filter-menu")
        app.buttons["billsFilterButton"].tap()

        // Portfolio
        app.buttons["tab-Portfolio"].tap(); shot("portfolio")
        app.swipeUp(); shot("portfolio-lower"); app.swipeUp(); shot("portfolio-bottom"); app.swipeDown(); app.swipeDown()
        app.buttons["ledgerRow-Mom"].tap(); shot("ledger-detail")
        app.buttons["ledgerEntryRow"].firstMatch.tap(); shot("edit-ledger-entry"); close(app)
        back(app)
        app.buttons["setBankBalanceButton"].tap(); shot("bank-balance"); close(app)
        app.swipeUp()
        app.buttons["payoutSchemesLink"].tap(); shot("payout-schemes")
        app.buttons["addSchemeButton"].tap(); shot("new-scheme"); close(app)
        back(app)

        // Other tabs
        app.buttons["tab-Reports"].tap(); shot("reports")
        app.buttons["tab-Trips"].tap(); shot("trips")
        app.buttons["tab-Search"].tap(); shot("search")
    }

    @MainActor
    func testTourWithHiddenBalancesAndExpenseDetail() {
        number = 50
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-demo-data", "-ui-hide-balances"]
        app.launch()
        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 30))
        shot("hidden-activity")
        app.buttons["expenseRow"].firstMatch.tap(); shot("expense-detail"); close(app)
        app.buttons["tab-Portfolio"].tap(); shot("hidden-portfolio")
        app.buttons["ledgerRow-Mom"].tap(); shot("hidden-ledger-detail")
    }
}
