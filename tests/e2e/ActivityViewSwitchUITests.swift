import XCTest

/// Activity's view switch (Expenses, Income, Calendar) and the hidden income figure in the summary card.
/// Spec: tests/budget/month-budget/month-budget.feature.
final class ActivityViewSwitchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTheSwitchShowsOneListAtATime() {
        let app = launchApp()
        addExpense(app, "1250", "Weekly groceries")
        addSalary(app, "5000")

        XCTAssertTrue(app.buttons["Expenses"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["expenseRow"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.descendants(matching: .any)["incomeRow"].exists)

        app.buttons["Income"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["incomeRow"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.descendants(matching: .any)["expenseRow"].exists)

        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["spentDay-\(today)"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.descendants(matching: .any)["expenseRow"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["incomeRow"].exists)
    }

    @MainActor
    func testIncomeIsHiddenWithHideBalancesOnAndComesBackAfterLeaving() {
        let app = launchApp(["-ui-hide-balances"])
        addSalary(app, "150000")

        XCTAssertEqual(app.staticTexts["incomeThisMonth"].label, "₹ ••••")
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹1,50,000.00")

        app.buttons["activityEyeButton"].tap()
        XCTAssertEqual(app.staticTexts["incomeThisMonth"].label, "₹1,50,000.00")

        app.buttons["tab-Bills"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["incomeThisMonth"])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "Activity is still on screen after choosing Bills")
        app.buttons["tab-Activity"].tap()
        XCTAssertTrue(app.staticTexts["incomeThisMonth"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["incomeThisMonth"].label, "₹ ••••")
    }

    @MainActor
    func testAFailedFaceIDKeepsIncomeHiddenAndSaysTryAgain() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-auth-fail", "-ui-hide-balances"]
        app.launch()
        addSalary(app, "150000")

        app.buttons["activityEyeButton"].tap()

        XCTAssertTrue(app.staticTexts["activityAuthMessage"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["activityAuthMessage"].label, "Try Again")
        XCTAssertEqual(app.staticTexts["incomeThisMonth"].label, "₹ ••••")
    }

    private var today: Int { Calendar.current.component(.day, from: Date()) }

    @MainActor
    private func launchApp(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func addExpense(_ app: XCUIApplication, _ amount: String, _ description: String) {
        app.buttons["addMenu"].tap()
        app.buttons["addExpenseButton"].tap()
        let amountField = app.textFields["amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 20))
        amountField.tap()
        amountField.typeText(amount)
        let descriptionField = app.textFields["descriptionField"]
        descriptionField.tap()
        descriptionField.typeText(description)
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["saveExpenseButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["expenseRow"].waitForExistence(timeout: 20))
    }

    @MainActor
    private func addSalary(_ app: XCUIApplication, _ amount: String) {
        app.buttons["addMenu"].tap()
        app.buttons["addIncomeButton"].tap()
        let amountField = app.textFields["incomeAmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 20))
        amountField.tap()
        amountField.typeText(amount)
        app.buttons["incomeTypePicker"].tap()
        app.buttons["Salary"].tap()
        app.buttons["saveIncomeButton"].tap()
        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 20))
    }
}
