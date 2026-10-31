import XCTest

/// Search: the field must be reachable above the custom tab bar, and typing in it finds an entry.
/// Spec: tests/budget/search/search-expenses.feature.
final class SearchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTypingInTheSearchFieldFindsAnExpense() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        addExpense(app, amount: "1250", description: "Weekly groceries")

        let tab = app.buttons["tab-Search"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        tab.tap()

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20), "no search field")
        XCTAssertLessThan(field.frame.maxY, tab.frame.minY, "the search field sits behind the tab bar")
        field.tap()
        field.typeText("grocer")

        XCTAssertTrue(app.descendants(matching: .any)["searchResultRow"].waitForExistence(timeout: 20))
    }

    @MainActor
    private func addExpense(_ app: XCUIApplication, amount: String, description: String) {
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
}
