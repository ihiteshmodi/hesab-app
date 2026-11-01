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
        dismissKeyboard(app)
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
        dismissKeyboard(app)
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
        dismissKeyboard(app)
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
    func testANoteIsAddedShownAndChangedOnAnExpense() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        amount.tap()
        amount.typeText("549")
        let description = app.textFields["descriptionField"]
        description.tap()
        description.typeText("Gadget")
        dismissKeyboard(app)
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        let note = app.textFields["notesField"]
        focus(note, in: app)
        note.typeText("used coupon THANKYOU")
        dismissKeyboard(app)
        app.buttons["saveExpenseButton"].tap()

        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        XCTAssertEqual(app.staticTexts["expenseNote"].label, "used coupon THANKYOU")

        app.buttons["editExpenseButton"].tap()
        let edited = app.textFields["notesField"]
        XCTAssertTrue(edited.waitForExistence(timeout: 20))
        XCTAssertEqual(edited.value as? String, "used coupon THANKYOU")
        focus(edited, in: app)
        edited.typeText("twice")
        dismissKeyboard(app)
        app.buttons["saveExpenseButton"].tap()
        XCTAssertTrue(app.staticTexts["expenseNote"].waitForExistence(timeout: 20))
        let changed = app.staticTexts["expenseNote"].label
        XCTAssertTrue(changed.contains("twice") && changed.contains("coupon"), "the edited note was not shown: \(changed)")
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
        dismissKeyboard(app)
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
        dismissKeyboard(app)
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

        app.buttons["Income"].tap()
        let row = app.descendants(matching: .any)["incomeRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.press(forDuration: 1.2)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 20))
        delete.tap()

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: row)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "income row is still there")
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹0.00")
    }

    @MainActor
    func testTappingAnIncomeEntryChangesIt() {
        let app = launchApp()
        app.buttons["addMenu"].tap()
        app.buttons["addIncomeButton"].tap()
        let amount = app.textFields["incomeAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        focus(amount, in: app)
        amount.typeText("5000")
        app.buttons["incomeTypePicker"].tap()
        app.buttons["Salary"].tap()
        app.buttons["saveIncomeButton"].tap()

        app.buttons["Income"].tap()
        let row = app.descendants(matching: .any)["incomeRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        let note = app.textFields["incomeNoteField"]
        XCTAssertTrue(note.waitForExistence(timeout: 20))
        focus(note, in: app)
        note.typeText("bonus")
        app.buttons["saveIncomeButton"].tap()

        let changed = app.descendants(matching: .any)["incomeRow"]
        XCTAssertTrue(changed.waitForExistence(timeout: 20))
        XCTAssertTrue(changed.label.contains("bonus"), "the changed note is not shown: \(changed.label)")
    }

    @MainActor
    func testTheCashTileOpensTheCashListAndAddsCashWithATitle() {
        let app = launchApp()
        let tile = app.buttons["cashInHandTile"]
        XCTAssertTrue(tile.waitForExistence(timeout: 20))
        tile.tap()
        app.buttons["addCashButton"].tap()
        let amount = app.textFields["addCashAmountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 20))
        focus(amount, in: app)
        amount.typeText("2000")
        let title = app.textFields["addCashTitleField"]
        title.tap()
        title.typeText("Gift from Dad")
        app.buttons["saveAddCashButton"].tap()

        XCTAssertTrue(app.staticTexts["Gift from Dad"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["cashBalance"].label, "₹2,000.00")
    }

    @MainActor
    func testABorrowingInCashRaisesCashAndMovesToRepaidOnceSettled() {
        let app = launchApp()
        let tile = app.buttons["amountToRepayTile"]
        XCTAssertTrue(tile.waitForExistence(timeout: 20))
        tile.tap()
        app.buttons["addBorrowingButton"].tap()
        let lender = app.textFields["borrowingLenderField"]
        XCTAssertTrue(lender.waitForExistence(timeout: 20))
        lender.tap()
        lender.typeText("Ben")
        let amount = app.textFields["borrowingAmountField"]
        amount.tap()
        amount.typeText("3000")
        app.buttons["Cash"].tap()
        app.buttons["saveBorrowingButton"].tap()

        XCTAssertEqual(app.staticTexts["repayTotal"].label, "₹3,000.00")
        app.buttons["borrowingRow"].tap()
        let repay = app.textFields["repaymentAmountField"]
        XCTAssertTrue(repay.waitForExistence(timeout: 20))
        repay.tap()
        repay.typeText("3000")
        app.buttons["saveRepaymentButton"].tap()
        XCTAssertEqual(app.staticTexts["repayTotal"].label, "₹0.00")
        XCTAssertTrue(app.staticTexts["nothingOwed"].waitForExistence(timeout: 20))

        app.buttons["Repaid"].tap()
        XCTAssertTrue(app.buttons["borrowingRow"].waitForExistence(timeout: 20))
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
        let done = app.buttons["keyboardDoneButton"]
        if done.waitForExistence(timeout: 3) { done.tap() }
        app.buttons["saveBillButton"].tap()

        app.buttons["billsViewSwitch"].tap()
        let add = app.buttons["addCalendarBillButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.tap()
        let save = app.buttons["saveExpenseButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        save.tap()

        selectTab(app, "Activity")
        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.label.contains("Rent"))
    }

    /// Taps Return when the on-screen keyboard offers it; a connected hardware keyboard shows none.
    @MainActor
    private func dismissKeyboard(_ app: XCUIApplication) {
        let key = app.keyboards.buttons["Return"]
        if key.exists, key.isHittable { key.tap() }
    }

    /// Taps a field until the keyboard is up.
    @MainActor
    private func focus(_ field: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<3 {
            field.tap()
            if app.keyboards.firstMatch.waitForExistence(timeout: 3) { return }
        }
        XCTFail("the keyboard never came up for \(field.identifier)")
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
