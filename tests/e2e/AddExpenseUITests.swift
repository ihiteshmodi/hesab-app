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

        app.buttons["addExpenseButton"].tap()
        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("1250")
        let description = app.textFields["descriptionField"]
        description.tap()
        description.typeText("Weekly groceries")
        app.buttons["categoryPicker"].tap()
        app.buttons["Home & Utilities"].tap()
        app.buttons["saveExpenseButton"].tap()

        let row = app.descendants(matching: .any)["expenseRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Weekly groceries"))
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "−₹1,250.00")
    }

    @MainActor
    func testAnIncompleteExpenseShowsWhatToFixAndKeepsTheSheetOpen() {
        let app = launchApp()

        app.buttons["addExpenseButton"].tap()
        app.buttons["saveExpenseButton"].tap()

        let message = app.staticTexts["errorMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(message.label, "Enter an amount above 0")
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }
}
