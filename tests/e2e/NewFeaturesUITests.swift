import XCTest

/// One or two real journeys for each of the newer features, on an empty app.
/// Specs: tests/budget/income/record-income.feature, tests/budget/categories/categories.feature,
/// tests/budget/search/search-expenses.feature, tests/insights/spending-trends/spending-trends.feature,
/// tests/trips/trips/trip-planner.feature, tests/networth/portfolio/investment-performance.feature.
final class NewFeaturesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: income and expenses

    @MainActor
    func testIncomeAddedToSavingsCountsAsIncomeButDoesNotRaiseLeftToSpend() {
        let app = launchApp()

        app.buttons["addMenu"].tap()
        app.buttons["addIncomeButton"].tap()
        type(app.textFields["incomeAmountField"], "800")
        app.buttons["incomeTypePicker"].tap()
        app.buttons["Investment Income"].tap()
        let toggle = app.switches["incomeToSavingsToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 20), "no Add to savings switch")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["saveIncomeButton"].tap()

        XCTAssertTrue(app.staticTexts["incomeThisMonth"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["incomeThisMonth"].label, "₹800.00")
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹0.00")
    }

    @MainActor
    func testASubCategoryTypedInTheExpenseFormIsSavedWithTheExpense() {
        let app = launchApp()

        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        type(app.textFields["amountField"], "500")
        type(app.textFields["descriptionField"], "Pressure cooker")
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["subCategoryPicker"].tap()
        app.buttons["New sub-category…"].tap()
        type(app.textFields["newSubCategoryField"], "Kitchenware")
        app.buttons["saveExpenseButton"].tap()

        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        XCTAssertTrue(app.staticTexts["Home & Utilities › Kitchenware"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testSettlingARefundFromPendingRefundsKeepsTheExpenseOnScreen() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        type(app.textFields["amountField"], "900")
        type(app.textFields["descriptionField"], "Jacket")
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["saveExpenseButton"].tap()
        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        app.buttons["markRefundableButton"].tap()
        app.buttons["doneButton"].tap()

        app.buttons["pendingRefundsTile"].tap()
        let pending = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Jacket'")).firstMatch
        XCTAssertTrue(pending.waitForExistence(timeout: 20))
        pending.tap()
        type(app.textFields["receivedField"], "900")
        app.buttons["recordReceivedButton"].tap()

        XCTAssertTrue(app.buttons["undoSettlementButton"].waitForExistence(timeout: 20), "the expense went blank after the refund")
    }

    @MainActor
    func testExportOpensTheShareSheetAtOnce() {
        let app = launchApp()
        app.buttons["profileButton"].tap()
        let backup = app.buttons["backupLink"]
        XCTAssertTrue(backup.waitForExistence(timeout: 20))
        backup.tap()

        app.buttons["exportDataButton"].tap()

        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 30), "the share sheet never opened")
    }

    // MARK: search

    @MainActor
    func testTheSearchFieldFollowsTheTabAndIsAbsentOnTheCalendar() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        type(app.textFields["amountField"], "120")
        type(app.textFields["descriptionField"], "Beans")
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["saveExpenseButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["expenseRow"].waitForExistence(timeout: 20))
        app.buttons["addMenu"].tap()
        app.buttons["addIncomeButton"].tap()
        type(app.textFields["incomeAmountField"], "300")
        app.buttons["incomeTypePicker"].tap()
        app.buttons["Money Received"].tap()
        type(app.textFields["incomeNoteField"], "Beans refund")
        app.buttons["saveIncomeButton"].tap()
        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 20))

        type(app.textFields["activitySearchField"], "bean")
        XCTAssertTrue(app.descendants(matching: .any)["searchResultRow"].waitForExistence(timeout: 20), "no expense result")
        XCTAssertFalse(app.descendants(matching: .any)["searchIncomeRow"].exists, "income showed up under the Expenses tab")

        app.buttons["Income"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["searchIncomeRow"].waitForExistence(timeout: 20), "no income result")
        XCTAssertFalse(app.descendants(matching: .any)["searchResultRow"].exists, "an expense showed up under the Income tab")

        app.buttons["Calendar"].tap()
        XCTAssertFalse(app.textFields["activitySearchField"].exists, "the Calendar tab should have no search field")
        app.buttons["Expenses"].tap()
        XCTAssertEqual(app.textFields["activitySearchField"].value as? String, "Search expenses", "the field should come back empty")
    }

    // MARK: reports

    @MainActor
    func testTheTrendsTabShowsTheChartsAndSaysWhenThereIsNotEnoughHistory() {
        let app = launchApp()
        selectTab(app, "Reports")

        app.buttons["Trends"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["paceChart"].waitForExistence(timeout: 20), "no this-month-vs-last chart")
        XCTAssertTrue(app.descendants(matching: .any)["incomeSpentChart"].exists, "no income vs spent chart")
        XCTAssertTrue(app.descendants(matching: .any)["normalNoHistory"].exists, "no not-enough-history note")
    }

    // MARK: trips

    @MainActor
    func testAPlannedTripIsStartedAndAnItemIsTickedAsPaid() {
        let app = launchApp()
        selectTab(app, "Trips")
        app.buttons["newTripButton"].tap()
        XCTAssertTrue(app.textFields["tripNameField"].waitForExistence(timeout: 20))
        let picker = app.buttons["tripCategoryPicker"]
        if picker.label.hasSuffix("Choose") {
            picker.tap()
            app.buttons["Home & Utilities"].tap()
        }
        type(app.textFields["tripNameField"], "Bali plan")
        app.switches["tripPlanOnlyToggle"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["saveTripButton"].tap()
        app.descendants(matching: .any)["tripRow"].firstMatch.tap()

        let add = app.buttons["addPlanItemButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 20), "a planned trip should open on its plan")
        add.tap()
        type(app.textFields["planItemNameField"], "Flights")
        type(app.textFields["planItemAmountField"], "6000")
        app.buttons["savePlanItemButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["planItemRow"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["tripPlannedTotal"].label, "₹6,000.00")

        app.buttons["startTripButton"].tap()
        let tick = app.buttons["planPaidToggle"]
        XCTAssertTrue(tick.waitForExistence(timeout: 20), "no tick mark once the trip has started")
        tick.tap()
        app.buttons["confirmPlanPaidButton"].tap()

        XCTAssertTrue(app.staticTexts["tripPendingTotal"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["tripPendingTotal"].label, "₹0.00")
        app.buttons["Expenses"].tap()
        XCTAssertEqual(app.staticTexts["tripLedgerAmount"].label, "₹6,000.00")
    }

    @MainActor
    func testAnItemPaidInPartsRemindsWhenAPartIsDueAndEachPartIsTickedOnItsOwn() {
        let app = launchApp()
        openNewTrip(app, name: "Himalaya trek", planOnly: false)
        app.buttons["Plan"].tap()
        app.buttons["addPlanItemButton"].tap()
        type(app.textFields["planItemNameField"], "Group tour")
        type(app.textFields["planItemAmountField"], "80000")
        type(app.textFields["planItemNoteField"], "Advance holds the seats")
        app.buttons["saveAndAddDetailsButton"].tap()

        app.buttons["addPartButton"].tap()
        type(app.textFields["partLabelField"], "Advance")
        type(app.textFields["partAmountField"], "20000")
        app.switches["partDueToggle"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["savePartButton"].tap()
        app.buttons["addPartButton"].tap()
        type(app.textFields["partLabelField"], "Balance")
        type(app.textFields["partAmountField"], "60000")
        app.buttons["savePartButton"].tap()
        XCTAssertEqual(app.staticTexts["planItemTotal"].label, "₹80,000.00")
        app.buttons["savePlanItemButton"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["tripDueHeading"].waitForExistence(timeout: 20), "no due-soon reminder")
        XCTAssertTrue(app.buttons["tab-Trips"].label.contains("1"), "no red 1 on the Trips tab: \(app.buttons["tab-Trips"].label)")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "planPartRow").count, 2)
        XCTAssertTrue(app.staticTexts["Advance holds the seats"].exists, "the note is not shown on the item")

        app.buttons["payDueButton"].tap()
        app.buttons["confirmPlanPaidButton"].tap()
        XCTAssertTrue(app.staticTexts["tripPendingTotal"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["tripPendingTotal"].label, "₹60,000.00")
        XCTAssertFalse(app.descendants(matching: .any)["tripDueHeading"].exists, "the reminder stays after the part was paid")
    }

    @MainActor
    func testAFlightLegKeepsItsRouteNumberAndTimesAndListsInTheTravelSection() {
        let app = launchApp()
        openNewTrip(app, name: "Bali plan", planOnly: true)
        app.buttons["addPlanItemButton"].tap()
        type(app.textFields["planItemNameField"], "Flights")
        type(app.textFields["planItemAmountField"], "9000")
        app.buttons["saveAndAddDetailsButton"].tap()

        app.buttons["addLegButton"].tap()
        type(app.textFields["legFromField"], "Delhi")
        type(app.textFields["legToField"], "Denpasar")
        type(app.textFields["legCarrierField"], "IndiGo")
        type(app.textFields["legNumberField"], "6E1175")
        app.switches["legDepartureToggle"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.switches["legDepartureTimeToggle"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["saveLegButton"].tap()
        app.buttons["savePlanItemButton"].tap()

        let leg = app.descendants(matching: .any)["itineraryLeg"]
        XCTAssertTrue(leg.waitForExistence(timeout: 20), "no leg in the Travel section")
        XCTAssertTrue(leg.label.contains("Delhi → Denpasar"), "leg reads \(leg.label)")
        XCTAssertTrue(leg.label.contains("IndiGo 6E1175"), "leg reads \(leg.label)")
        XCTAssertTrue(leg.label.contains("Planned"), "leg reads \(leg.label)")
    }

    @MainActor
    func testATripShowsItsStartAndEndDatesInTheList() {
        let app = launchApp()
        selectTab(app, "Trips")
        app.buttons["newTripButton"].tap()
        XCTAssertTrue(app.textFields["tripNameField"].waitForExistence(timeout: 20))
        let picker = app.buttons["tripCategoryPicker"]
        if picker.label.hasSuffix("Choose") { picker.tap(); app.buttons["Home & Utilities"].tap() }
        type(app.textFields["tripNameField"], "Goa weekend")
        app.switches["tripStartToggle"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["saveTripButton"].tap()

        let dates = app.staticTexts["tripDates"]
        XCTAssertTrue(dates.waitForExistence(timeout: 20), "no dates on the trip row")
        XCTAssertTrue(dates.label.hasPrefix("From "), "dates read \(dates.label)")
    }

    @MainActor
    private func openNewTrip(_ app: XCUIApplication, name: String, planOnly: Bool) {
        selectTab(app, "Trips")
        app.buttons["newTripButton"].tap()
        XCTAssertTrue(app.textFields["tripNameField"].waitForExistence(timeout: 20))
        let picker = app.buttons["tripCategoryPicker"]
        if picker.label.hasSuffix("Choose") { picker.tap(); app.buttons["Home & Utilities"].tap() }
        type(app.textFields["tripNameField"], name)
        if planOnly { app.switches["tripPlanOnlyToggle"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap() }
        app.buttons["saveTripButton"].tap()
        app.descendants(matching: .any)["tripRow"].firstMatch.tap()
    }

    // MARK: investments

    @MainActor
    func testAStockShowsUpInGreenWithItsGainOnItsPage() {
        let app = launchApp()
        selectTab(app, "Portfolio")
        app.buttons["addHoldingButton"].tap()
        type(app.textFields["holdingNameField"], "Groww Stocks")
        app.buttons["Stock"].tap()
        type(app.textFields["holdingAmountField"], "12000")
        type(app.textFields["holdingInvestedField"], "10000")
        app.buttons["saveHoldingButton"].tap()

        let row = app.buttons["holdingRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()

        let pill = app.descendants(matching: .any)["holdingGainPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 20), "no up or down pill")
        XCTAssertTrue(pill.label.contains("Up"), "pill reads \(pill.label)")
        XCTAssertTrue(pill.label.contains("20.0%"), "pill reads \(pill.label)")
        XCTAssertTrue(app.descendants(matching: .any)["holdingHistoryChart"].exists, "no worth-over-time chart")
    }

    @MainActor
    func testASIPOffersThisMonthsInstalmentAndOneTapAddsIt() {
        let app = launchApp()
        selectTab(app, "Portfolio")
        app.buttons["addHoldingButton"].tap()
        type(app.textFields["holdingNameField"], "Index fund")
        app.buttons["SIP"].tap()
        type(app.textFields["holdingAmountField"], "10000")
        type(app.textFields["holdingInvestedField"], "10000")
        type(app.textFields["holdingSipAmountField"], "2000")
        app.buttons["saveHoldingButton"].tap()
        let row = app.buttons["holdingRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()

        let add = app.buttons["addInstalmentButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 20), "no instalment due, though its day (the 1st) has passed")
        add.tap()

        XCTAssertTrue(app.staticTexts["holdingWorth"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["holdingWorth"].label, "₹12,000.00")
        XCTAssertFalse(app.buttons["addInstalmentButton"].exists, "the instalment is still offered after it was added")
    }

    // MARK: helpers

    @MainActor
    private func type(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 20), "field never appeared")
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func selectTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.buttons["tab-\(name)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "no tab called \(name)")
        tab.tap()
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }
}
