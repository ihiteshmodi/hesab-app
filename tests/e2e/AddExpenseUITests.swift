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

        app.buttons["profileButton"].tap()
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
        var switchedOn = false
        for _ in 0..<3 where !switchedOn {
            keep.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            let isOn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: keep)
            switchedOn = XCTWaiter().wait(for: [isOn], timeout: 3) == .completed
        }
        XCTAssertTrue(switchedOn, "toggle stayed off")
        app.buttons["saveExpenseButton"].tap()

        app.buttons["profileButton"].tap()
        let link = app.buttons["cashInHandLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 20))
        link.tap()
        let balance = app.staticTexts["cashBalance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 20))
        XCTAssertEqual(balance.label, "₹5,000.00")
    }

    @MainActor
    func testTickingACardBillAsPaidClearsWhatIsDue() {
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
        app.keyboards.buttons["Return"].tap()
        app.buttons["categoryPicker"].tap()
        app.buttons["Transport"].tap()
        app.buttons["paymentPicker"].tap()
        app.buttons["Credit Card"].tap()
        app.buttons["saveExpenseButton"].tap()

        app.buttons["profileButton"].tap()
        let link = app.buttons["cardBillsLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 20))
        link.tap()
        let row = app.descendants(matching: .any)["cardBillRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.label.contains("Credit Card, bill ₹1,200.00, due ₹1,200.00"))
        XCTAssertEqual(app.staticTexts["cardTotalDue"].label, "₹1,200.00")

        app.buttons["cardPaidButton"].tap()

        let paid = NSPredicate(format: "label == %@", "₹0.00")
        let cleared = XCTNSPredicateExpectation(predicate: paid, object: app.staticTexts["cardTotalDue"])
        XCTAssertEqual(XCTWaiter().wait(for: [cleared], timeout: 10), .completed, "due was not cleared")
    }

    @MainActor
    func testTheBackupScreenOffersExportAndImport() {
        let app = launchApp()

        app.buttons["profileButton"].tap()
        let link = app.buttons["backupLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 20))
        link.tap()

        XCTAssertTrue(app.buttons["exportDataButton"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["importDataButton"].exists)
    }

    @MainActor
    func testRepayingPartOfABorrowingLowersWhatIsOwed() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addIncomeButton"].tap()
        let amount = app.textFields["incomeAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        amount.tap()
        amount.typeText("10000")
        app.buttons["incomeTypePicker"].tap()
        app.buttons["Borrowed"].tap()
        let lender = app.textFields["incomeNoteField"]
        lender.tap()
        lender.typeText("Savings")
        app.keyboards.buttons["Return"].tap()
        app.buttons["saveIncomeButton"].tap()

        app.buttons["profileButton"].tap()
        let link = app.buttons["amountToRepayLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 20))
        link.tap()
        XCTAssertEqual(app.staticTexts["repayTotal"].label, "₹10,000.00")
        app.buttons["borrowingRow"].tap()
        let repaid = app.textFields["repaymentAmountField"]
        XCTAssertTrue(repaid.waitForExistence(timeout: 20))
        repaid.tap()
        repaid.typeText("4000")
        app.buttons["saveRepaymentButton"].tap()

        let owed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "₹6,000.00"), object: app.staticTexts["repayTotal"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [owed], timeout: 10), .completed, "repayment was not applied")
    }

    @MainActor
    func testEditingAnExpenseAndSwitchingMonths() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        amount.tap()
        amount.typeText("100")
        let description = app.textFields["descriptionField"]
        description.tap()
        description.typeText("Milk")
        app.keyboards.buttons["Return"].tap()
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["saveExpenseButton"].tap()

        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        app.buttons["editExpenseButton"].tap()
        let editedDescription = app.textFields["descriptionField"]
        XCTAssertTrue(editedDescription.waitForExistence(timeout: 20))
        editedDescription.tap()
        editedDescription.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "Oat milk")
        app.keyboards.buttons["Return"].tap()
        app.buttons["saveExpenseButton"].tap()
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["expenseRow"].label.contains("Oat milk"))

        app.buttons["previousMonthButton"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["expenseRow"].waitForExistence(timeout: 3))
        app.buttons["nextMonthButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["expenseRow"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testDeletingAnIncomeEntryTakesItBackOut() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addIncomeButton"].tap()
        let amount = app.textFields["incomeAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        amount.tap()
        amount.typeText("5000")
        app.buttons["incomeTypePicker"].tap()
        app.buttons["Salary"].tap()
        app.buttons["saveIncomeButton"].tap()

        let row = app.descendants(matching: .any)["incomeRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.swipeLeft()
        app.buttons["Delete"].tap()

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: row)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "income row is still there")
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹0.00")
    }

    @MainActor
    func testAddingABillAndPuttingItIntoTheBudget() {
        let app = launchApp()
        selectTab(app, "Bills")
        app.buttons["billsAddMenu"].tap()
        app.buttons["newBillButton"].tap()
        let name = app.textFields["billNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 20))
        name.tap()
        name.typeText("Rent")
        let amount = app.textFields["billAmountField"]
        amount.tap()
        amount.typeText("20000")
        app.buttons["billCategoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["saveBillButton"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["upcomingRow"].waitForExistence(timeout: 20))
        app.buttons["addUpcomingBillButton"].tap()
        let save = app.buttons["saveExpenseButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        save.tap()

        selectTab(app, "Activity")
        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.label.contains("Rent"))
    }

    @MainActor
    private func selectTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
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
