import XCTest

/// The menu drawer (mockup 42), Activity > Upcoming and the month calendar (mockups 1-2),
/// and the Bills calendar with its filter menu (mockups 6-12).
/// Spec: tests/budget/bills/bills.feature, tests/budget/month-budget/month-budget.feature.
final class ActivityAndBillsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private var today: Int { Calendar.current.component(.day, from: Date()) }

    @MainActor
    func testTheMenuDrawerListsEveryScreenAndOpensSettings() {
        let app = launchApp()
        app.buttons["profileButton"].tap()
        for id in ["categoriesLink", "entitiesLink", "ledgersLink", "cardBillsLink", "cashInHandLink", "amountToRepayLink",
                   "pendingRefundsLink", "backupLink", "importLink", "settingsLink"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 20), "the menu has no \(id)")
        }
        app.buttons["settingsLink"].tap()
        XCTAssertTrue(app.buttons["currencyLink"].waitForExistence(timeout: 20))
        goBack(app)

        app.buttons["profileButton"].tap()
        let close = app.descendants(matching: .any)["closeMenuButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 20))
        close.tap()
        XCTAssertTrue(waitForAbsence(app.buttons["settingsLink"]), "the menu stayed open")
    }

    @MainActor
    func testTheMonthCalendarShowsWhatWasSpentToday() {
        let app = launchApp()
        addExpense(app, "1250", "Groceries")
        app.buttons["Calendar"].tap()

        let day = app.descendants(matching: .any)["spentDay-\(today)"]
        XCTAssertTrue(day.waitForExistence(timeout: 20))
        XCTAssertTrue(day.label.contains("₹1.2k"), "day reads \(day.label)")
    }

    @MainActor
    func testABillYouAddYourselfWaitsInUpcomingAndIsAddedFromThere() {
        let app = launchApp()
        app.buttons["Upcoming"].tap()
        XCTAssertTrue(app.staticTexts["upcomingEmpty"].waitForExistence(timeout: 20))

        app.buttons["createBillButton"].tap()
        fillBill(app, "Rent", "20000")

        XCTAssertTrue(app.descendants(matching: .any)["upcomingRow"].waitForExistence(timeout: 20))
        app.buttons["addUpcomingBillButton"].tap()
        let save = app.buttons["saveExpenseButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        save.tap()

        app.buttons["Spending"].tap()
        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.label.contains("Rent"))
    }

    @MainActor
    func testABillIsEditedInAllBillsAndNotFromUpcoming() {
        let app = launchApp()
        app.buttons["Upcoming"].tap()
        app.buttons["createBillButton"].tap()
        fillBill(app, "Internet", "800")

        let row = app.descendants(matching: .any)["upcomingRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.staticTexts["Internet"].tap()
        XCTAssertFalse(app.textFields["billNameField"].waitForExistence(timeout: 3), "Upcoming opened the editor")

        selectTab(app, "Bills")
        let bill = app.buttons["billRow"]
        XCTAssertTrue(bill.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["addBillRowButton"].exists, "All bills has no Add button")
        bill.tap()
        XCTAssertTrue(app.textFields["billNameField"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.switches["billAutoDebitToggle"].exists)
    }

    @MainActor
    func testABillYouPayYourselfStaysPendingToSendUntilTickedSentWithADate() {
        let app = launchApp()
        app.buttons["Upcoming"].tap()
        app.buttons["createBillButton"].tap()
        fillBill(app, "Rent", "20000")
        XCTAssertTrue(app.descendants(matching: .any)["upcomingRow"].waitForExistence(timeout: 20))
        app.buttons["addUpcomingBillButton"].tap()
        let save = app.buttons["saveExpenseButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        save.tap()

        app.buttons["Spending"].tap()
        let tile = app.buttons["pendingToSendTile"]
        XCTAssertTrue(tile.waitForExistence(timeout: 20))
        XCTAssertTrue(tile.label.contains("Pending to send"), "tile reads \(tile.label)")
        tile.tap()
        XCTAssertTrue(app.staticTexts["stillToSend"].waitForExistence(timeout: 20))
        app.buttons["toSendRow"].tap()
        let saveSent = app.buttons["saveSentButton"]
        XCTAssertTrue(saveSent.waitForExistence(timeout: 20))
        saveSent.tap()

        XCTAssertTrue(app.staticTexts["Nothing to send. Bills you pay yourself appear here after you add them."].waitForExistence(timeout: 20))
    }

    @MainActor
    func testUpcomingShowsACountAndAnIncomeSideWithTheExpectedPayouts() {
        let app = launchApp()
        selectTab(app, "Portfolio")
        app.buttons["payoutSchemesLink"].tap()
        app.buttons["addSchemeButton"].tap()
        type(app.textFields["schemeNameField"], "Bond A")
        type(app.textFields["schemeInvestedField"], "500000")
        type(app.textFields["schemePayoutField"], "4100")
        app.switches.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["saveSchemeButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["schemeRow"].waitForExistence(timeout: 20))

        selectTab(app, "Activity")
        let upcoming = app.buttons["Upcoming"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 20))
        XCTAssertFalse((upcoming.value as? String ?? "").isEmpty, "the Upcoming tab shows no count")
        upcoming.tap()
        app.buttons["Income"].tap()
        XCTAssertTrue(app.staticTexts["Matures today"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Bond A"].exists)
        XCTAssertTrue(app.buttons["createIncomeButton"].exists)
        XCTAssertTrue(app.buttons["addSeveralIncomeButton"].exists)
        XCTAssertTrue(app.buttons["editUpcomingFiltersButton"].exists)
    }

    @MainActor
    func testUpcomingBillAmountsStayVisibleWithHideBalancesOn() {
        let app = launchApp(["-ui-hide-balances"])
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹0.00")
        app.buttons["Upcoming"].tap()
        app.buttons["createBillButton"].tap()
        fillBill(app, "Internet", "800")

        let row = app.descendants(matching: .any)["upcomingRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.staticTexts["₹800.00"].exists, "the amount is hidden: \(row.debugDescription)")
    }

    @MainActor
    func testANewBillWaitsToBeAddedAndNeverAddsItself() {
        let app = launchApp()
        app.buttons["Upcoming"].tap()
        app.buttons["createBillButton"].tap()
        fillBill(app, "Internet", "800")

        let row = app.descendants(matching: .any)["upcomingRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.staticTexts["Internet"].exists)
        app.buttons["Spending"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["expenseRow"].exists)
    }

    @MainActor
    func testTheBillsCalendarShowsABillOnItsDayAndAddsIt() {
        let app = launchApp()
        selectTab(app, "Bills")
        app.buttons["billsAddMenu"].tap()
        app.buttons["newBillButton"].tap()
        fillBill(app, "Rent", "20000")

        let day = app.buttons["billDay-\(today)"]
        XCTAssertTrue(day.waitForExistence(timeout: 20))
        XCTAssertTrue(day.label.contains("1 due"), "day reads \(day.label)")
        app.buttons["billsViewSwitch"].tap()
        let add = app.buttons["addCalendarBillButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.tap()
        let save = app.buttons["saveExpenseButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        save.tap()

        chooseFilter(app, "added")
        XCTAssertTrue(app.descendants(matching: .any)["billCalendarRow"].waitForExistence(timeout: 20), "Rent is not shown as added")
        XCTAssertTrue(app.staticTexts["Rent"].exists)
        chooseFilter(app, "notAdded")
        XCTAssertTrue(app.staticTexts["Nothing this month."].waitForExistence(timeout: 20))
    }

    @MainActor
    func testAnExpectedPayoutIsRecordedFromTheBillsTab() {
        let app = launchApp()
        selectTab(app, "Portfolio")
        app.buttons["payoutSchemesLink"].tap()
        app.buttons["addSchemeButton"].tap()
        type(app.textFields["schemeNameField"], "Bond A")
        type(app.textFields["schemeInvestedField"], "500000")
        type(app.textFields["schemePayoutField"], "4100")
        app.buttons["saveSchemeButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["schemeRow"].waitForExistence(timeout: 20))

        selectTab(app, "Bills")
        chooseFilter(app, "upcomingIncome")
        app.buttons["billsViewSwitch"].tap()
        let record = app.buttons["recordPayoutButton"]
        if !record.waitForExistence(timeout: 5) { app.buttons["billsNextMonth"].tap() }
        XCTAssertTrue(record.waitForExistence(timeout: 20), "no payout expected this month or next")
        record.tap()
        let save = app.buttons["savePayoutButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        save.tap()
        XCTAssertTrue(waitForAbsence(save))

        selectTab(app, "Activity")
        app.buttons["Income"].tap()
        let income = app.descendants(matching: .any)["incomeRow"]
        XCTAssertTrue(income.waitForExistence(timeout: 20))
        XCTAssertTrue(income.label.contains("Investment Income"))
        XCTAssertTrue(income.label.contains("₹4,100.00"))
    }

    @MainActor
    func testThePlannedFilterListsWhatIsComingWithItsTotal() {
        let app = launchApp()
        selectTab(app, "Bills")
        app.buttons["billsAddMenu"].tap()
        app.buttons["newPlannedButton"].tap()
        type(app.textFields["plannedDescriptionField"], "Sofa")
        type(app.textFields["plannedAmountField"], "25000")
        app.buttons["savePlannedButton"].tap()

        chooseFilter(app, "planned")
        let total = app.staticTexts["plannedTotal"]
        XCTAssertTrue(total.waitForExistence(timeout: 20))
        XCTAssertEqual(total.label, "₹25,000.00")
    }

    // MARK: helpers

    @MainActor
    private func fillBill(_ app: XCUIApplication, _ name: String, _ amount: String) {
        type(app.textFields["billNameField"], name)
        type(app.textFields["billAmountField"], amount)
        app.buttons["billCategoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        let done = app.buttons["keyboardDoneButton"]
        if done.waitForExistence(timeout: 3) { done.tap() }
        app.buttons["saveBillButton"].tap()
        XCTAssertTrue(waitForAbsence(app.buttons["saveBillButton"]), "the bill was not saved")
    }

    @MainActor
    private func addExpense(_ app: XCUIApplication, _ amount: String, _ description: String) {
        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        type(app.textFields["amountField"], amount)
        type(app.textFields["descriptionField"], description)
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["saveExpenseButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["expenseRow"].waitForExistence(timeout: 20))
    }

    @MainActor
    private func chooseFilter(_ app: XCUIApplication, _ filter: String) {
        app.buttons["billsFilterButton"].tap()
        let option = app.buttons["filter-\(filter)"]
        XCTAssertTrue(option.waitForExistence(timeout: 20))
        option.tap()
    }

    @MainActor
    private func waitForAbsence(_ element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: 10) == .completed
    }

    @MainActor
    private func type(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func goBack(_ app: XCUIApplication) {
        let back = app.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 20), "no back button")
        back.tap()
    }

    @MainActor
    private func selectTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.buttons["tab-\(name)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "no tab called \(name)")
        tab.tap()
    }

    @MainActor
    private func launchApp(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extra
        app.launch()
        return app
    }
}
