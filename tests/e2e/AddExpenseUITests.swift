import XCTest

/// The walking-skeleton smoke test: the built app, a real (in-memory) database, one user journey.
/// Spec: tests/budget/expenses/record-expense.feature, "Priya adds an expense".
final class AddExpenseUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddingAnExpenseListsItAndLowersLeftToSpend() {
        let app = launchApp()
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹0.00")

        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        amount.tap()
        amount.typeText("1250")
        let description = app.textFields["descriptionField"]
        description.tap()
        description.typeText("Weekly groceries")
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["saveExpenseButton"].tap()

        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.label.contains("Weekly groceries"))
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "−₹1,250.00")
    }

    @MainActor
    func testAnIncompleteExpenseShowsWhatToFixAndKeepsTheSheetOpen() {
        let app = launchApp()

        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        app.buttons["saveExpenseButton"].tap()

        let message = app.staticTexts["errorMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 20))
        XCTAssertEqual(message.label, "Enter an amount above 0")
    }

    @MainActor
    func testRecordingASalaryRaisesLeftToSpend() {
        let app = launchApp()

        app.buttons["addMenu"].tap()
        app.buttons["addIncomeButton"].tap()
        let amount = app.textFields["incomeAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        amount.tap()
        amount.typeText("150000")
        app.buttons["incomeTypePicker"].tap()
        app.buttons["Salary"].tap()
        app.buttons["saveIncomeButton"].tap()

        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹1,50,000.00")
        XCTAssertEqual(app.staticTexts["incomeThisMonth"].label, "₹1,50,000.00")
    }

    @MainActor
    func testAPartialRefundLowersWhatTheExpenseCostAndGivesBackLeftToSpend() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        amount.tap()
        amount.typeText("1200")
        let description = app.textFields["descriptionField"]
        description.tap()
        description.typeText("Train ticket")
        app.buttons["categoryPicker"].tap()
        app.buttons["Transport"].tap()
        app.buttons["saveExpenseButton"].tap()

        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        let markRefundable = app.buttons["markRefundableButton"]
        XCTAssertTrue(markRefundable.waitForExistence(timeout: 20), app.debugDescription)
        markRefundable.tap()
        let received = app.textFields["receivedField"]
        XCTAssertTrue(received.waitForExistence(timeout: 20))
        received.tap()
        received.typeText("900")
        app.buttons["recordReceivedButton"].tap()

        XCTAssertTrue(app.staticTexts["₹300.00"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "−₹300.00")
    }

    @MainActor
    func testAddingALedgerListsItWithAZeroBalance() {
        let app = launchApp()

        app.buttons["ledgersLink"].tap()
        app.buttons["addLedgerButton"].tap()
        let name = app.textFields["ledgerNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 20))
        name.tap()
        name.typeText("Mom")
        app.buttons["saveLedgerButton"].tap()

        let row = app.descendants(matching: .any)["ledgerRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.label.contains("Mom"))
        XCTAssertTrue(row.label.contains("₹0.00"))
    }

    @MainActor
    func testKeepingACashWithdrawalFillsCashInHand() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        amount.tap()
        amount.typeText("5000")
        let description = app.textFields["descriptionField"]
        description.tap()
        description.typeText("ATM")
        app.keyboards.buttons["Return"].tap()
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["paymentPicker"].tap()
        app.buttons["Cash Withdrawal"].tap()
        let keep = app.switches["keepAsCashToggle"]
        XCTAssertTrue(keep.waitForExistence(timeout: 20))
        XCTAssertTrue(keep.isHittable)
        keep.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let isOn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: keep)
        XCTAssertEqual(XCTWaiter().wait(for: [isOn], timeout: 5), .completed, "toggle stayed off")
        app.buttons["saveExpenseButton"].tap()

        let link = app.buttons["cashInHandLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 20))
        link.tap()
        let balance = app.staticTexts["cashBalance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 20))
        XCTAssertEqual(balance.label, "₹5,000.00")
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }
}
