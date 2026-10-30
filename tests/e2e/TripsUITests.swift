import XCTest

/// Trips: one journey in the home currency (split, settle in full) and one in a foreign currency (cash stays out of the ledger).
/// Spec: tests/trips/trips/trips.feature.
final class TripsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSplittingAVillaAndSettlingInFullForOneRupeeLess() {
        let app = launchApp()
        selectTab(app, "Trips")
        newTrip(app, name: "Goa weekend")
        app.descendants(matching: .any)["tripRow"].firstMatch.tap()
        addPerson(app, "Ana")

        let add = app.buttons["addTripEntryButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.tap()
        type(app.textFields["tripExpenseTitleField"], "Villa")
        type(app.textFields["tripExpenseAmountField"], "5622")
        app.buttons["saveTripExpenseButton"].tap()

        XCTAssertTrue(app.staticTexts["tripMyExpenses"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["tripMyExpenses"].label, "₹2,811.00")
        XCTAssertEqual(app.staticTexts["tripLedgerAmount"].label, "₹5,622.00")

        app.buttons["Balances"].tap()
        app.buttons["settleUpButton"].tap()
        app.switches["settleInFullToggle"].tap()
        type(app.textFields["transferAmountField"], "2810")
        XCTAssertTrue(app.descendants(matching: .any)["transferEffect"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["transferDatePicker"].exists)
        saveTransfer(app)

        XCTAssertTrue(app.staticTexts["tripWrittenOff"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["tripWrittenOff"].label, "₹1.00")
        app.buttons["Expenses"].tap()
        XCTAssertEqual(app.staticTexts["tripLedgerAmount"].label, "₹2,812.00")
    }

    @MainActor
    func testCashFromAFriendInTheTripCurrencyStaysOutOfTheLedger() {
        let app = launchApp()
        selectTab(app, "Trips")
        app.buttons["newTripButton"].tap()
        type(app.textFields["tripNameField"], "Bali trip")
        app.buttons["tripCurrencyPicker"].tap()
        app.buttons["IDR"].tap()
        type(app.textFields["tripRateField"], "0.0053")
        app.buttons["tripCategoryPicker"].tap()
        app.buttons["Transport"].tap()
        app.buttons["saveTripButton"].tap()
        app.descendants(matching: .any)["tripRow"].firstMatch.tap()
        addPerson(app, "Raj")

        let add = app.buttons["addTripEntryButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.tap()
        type(app.textFields["tripExpenseTitleField"], "Dinner")
        type(app.textFields["tripExpenseAmountField"], "400000")
        type(app.textFields["tripExpenseCardField"], "2150")
        app.buttons["saveTripExpenseButton"].tap()
        XCTAssertTrue(app.staticTexts["tripLedgerAmount"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["tripLedgerAmount"].label, "₹2,150.00")

        app.buttons["Balances"].tap()
        app.buttons["settleUpButton"].tap()
        app.buttons["Cash IDR"].tap()
        type(app.textFields["transferAmountField"], "150000")
        saveTransfer(app)

        XCTAssertTrue(app.staticTexts["tripCashBalance"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["tripCashBalance"].label, "IDR 150,000")
        app.buttons["Expenses"].tap()
        XCTAssertEqual(app.staticTexts["tripLedgerAmount"].label, "₹2,150.00")
    }

    @MainActor
    func testAGroupSelectsItsPeopleInTheSplit() {
        let app = launchApp()
        selectTab(app, "Trips")
        newTrip(app, name: "Goa weekend")
        app.descendants(matching: .any)["tripRow"].firstMatch.tap()
        openPeople(app)
        addPersonOnScreen(app, "Ana")
        addPersonOnScreen(app, "Raj")
        app.buttons["newGroupButton"].tap()
        type(app.textFields["groupNameField"], "Daily people")
        app.buttons["groupMember-Me"].tap()
        app.buttons["groupMember-Ana"].tap()
        app.buttons["saveGroupButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["groupRow"].waitForExistence(timeout: 20))
        goBack(app)

        let add = app.buttons["addTripEntryButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.tap()
        type(app.textFields["tripExpenseTitleField"], "Lunch")
        type(app.textFields["tripExpenseAmountField"], "900")
        app.buttons["groupChip-Daily people"].tap()
        app.buttons["saveTripExpenseButton"].tap()

        XCTAssertTrue(app.staticTexts["tripMyExpenses"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["tripMyExpenses"].label, "₹450.00")
    }

    @MainActor
    func testTheTripsTabSitsFifthAndSearchSixth() {
        let app = launchApp()

        let labels = ["Activity", "Bills", "Portfolio", "Reports", "Trips", "Search"]
        let frames = labels.map { app.buttons["tab-\($0)"].frame.minX }
        XCTAssertEqual(frames, frames.sorted())
        XCTAssertTrue(app.buttons["tab-Trips"].waitForExistence(timeout: 20))
    }

    // MARK: helpers

    @MainActor
    private func saveTransfer(_ app: XCUIApplication) {
        let save = app.buttons["saveTransferButton"]
        if !save.waitForExistence(timeout: 5) { print("SAVE-MISSING-HIERARCHY", app.debugDescription) }
        XCTAssertTrue(save.waitForExistence(timeout: 20), "the Save button never appeared")
        save.tap()
    }

    @MainActor
    private func newTrip(_ app: XCUIApplication, name: String) {
        app.buttons["newTripButton"].tap()
        type(app.textFields["tripNameField"], name)
        app.buttons["tripCategoryPicker"].tap()
        app.buttons["Transport"].tap()
        app.buttons["saveTripButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["tripRow"].waitForExistence(timeout: 20))
    }

    @MainActor
    private func addPerson(_ app: XCUIApplication, _ name: String) {
        openPeople(app)
        addPersonOnScreen(app, name)
        goBack(app)
    }

    @MainActor
    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 3) {
            back.tap()
            return
        }
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
    }

    @MainActor
    private func openPeople(_ app: XCUIApplication) {
        let people = app.buttons["tripPeopleButton"]
        XCTAssertTrue(people.waitForExistence(timeout: 20))
        people.tap()
    }

    @MainActor
    private func addPersonOnScreen(_ app: XCUIApplication, _ name: String) {
        app.buttons["addPersonButton"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap()
        field.typeText(name)
        app.alerts.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch.waitForExistence(timeout: 20))
    }

    @MainActor
    private func type(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 20))
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
