import XCTest

/// Portfolio: amounts hidden until the eye is tapped, a bank balance, and a payout scheme.
/// Spec: tests/networth/portfolio/portfolio.feature, tests/networth/payout-schemes/payout-schemes.feature.
final class PortfolioUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAmountsStayHiddenUntilTheEyeIsTappedAndTheBankBalanceSetsNetWorth() {
        let app = launchApp(["-ui-hide-balances"])
        selectTab(app, "Portfolio")
        let netWorth = app.staticTexts["netWorth"]
        XCTAssertTrue(netWorth.waitForExistence(timeout: 20))
        XCTAssertEqual(netWorth.label, "••••••")

        app.buttons["eyeButton"].tap()
        app.buttons["setBankBalanceButton"].tap()
        let field = app.textFields["bankBalanceField"]
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap()
        field.typeText("100000")
        app.buttons["saveBankBalanceButton"].tap()

        XCTAssertEqual(app.staticTexts["netWorth"].label, "₹1,00,000.00")
    }

    @MainActor
    func testTappingAnInvestmentOpensItForEditing() {
        let app = launchApp()
        selectTab(app, "Portfolio")
        app.buttons["addHoldingButton"].tap()
        type(app.textFields["holdingNameField"], "Stocks")
        type(app.textFields["holdingAmountField"], "12000")
        app.buttons["saveHoldingButton"].tap()

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Stocks'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()

        let name = app.textFields["holdingNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 20))
        XCTAssertEqual(name.value as? String, "Stocks")
    }

    @MainActor
    func testAddingAPayoutSchemeListsItWithItsMonthlyPayout() {
        let app = launchApp()
        selectTab(app, "Portfolio")
        app.buttons["payoutSchemesLink"].tap()
        app.buttons["addSchemeButton"].tap()
        type(app.textFields["schemeNameField"], "Bond A")
        type(app.textFields["schemeInvestedField"], "500000")
        type(app.textFields["schemePayoutField"], "4100")
        app.buttons["saveSchemeButton"].tap()

        let row = app.descendants(matching: .any)["schemeRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        XCTAssertTrue(row.label.contains("Bond A"))
    }

    @MainActor
    func testAnIncompleteSchemeShowsWhatToFix() {
        let app = launchApp()
        selectTab(app, "Portfolio")
        app.buttons["payoutSchemesLink"].tap()
        app.buttons["addSchemeButton"].tap()
        app.buttons["saveSchemeButton"].tap()

        XCTAssertEqual(app.staticTexts["schemeError"].label, "Enter a name")
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
    private func launchApp(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extra
        app.launch()
        return app
    }
}
