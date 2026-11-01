import XCTest

/// Hide Balances, the Face ID eye on Savings and Portfolio, and App Lock.
/// Spec: tests/settings/preferences/preferences.feature, "Privacy" and "App Lock".
/// The tests answer for the phone: `-ui-testing` lets Face ID succeed, `-ui-auth-fail` makes it fail.
final class PrivacyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHidingBalancesMasksLeftToSpendUntilTheEyeIsTapped() {
        let app = launchApp()
        openSettings(app)
        flip(app.switches["hideBalancesToggle"])
        goBack(app)

        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹ ••••")
        app.buttons["activityEyeButton"].tap()
        XCTAssertEqual(app.staticTexts["leftToSpend"].label, "₹0.00")
    }

    @MainActor
    func testTheSavingsBankBalanceStaysHiddenUntilTheEyeIsTapped() {
        let app = launchApp()
        app.buttons["Savings"].tap()

        let balance = app.staticTexts["savingsBalance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 20))
        XCTAssertEqual(balance.label, "₹ ••••••")
        XCTAssertEqual(app.staticTexts["savingsIncome"].label, "₹ ••••")
        XCTAssertEqual(app.staticTexts["savingsCashFlow"].label, "₹ ••••")
        XCTAssertFalse(app.buttons["Ledgers"].exists, "ledgers can be opened while the pane is locked")
        app.buttons["savingsEyeButton"].tap()
        XCTAssertTrue(app.staticTexts["₹0.00"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["savingsIncome"].label, "₹0.00")
        XCTAssertTrue(app.buttons["Ledgers"].exists)
    }

    @MainActor
    func testPortfolioHidesAgainAfterSwitchingTabs() {
        let app = launchApp()
        selectTab(app, "Portfolio")
        app.buttons["eyeButton"].tap()
        XCTAssertEqual(app.staticTexts["netWorth"].label, "₹0.00")

        selectTab(app, "Activity")
        selectTab(app, "Portfolio")

        XCTAssertEqual(app.staticTexts["netWorth"].label, "••••••")
    }

    @MainActor
    func testAFailedFaceIDKeepsPortfolioHiddenAndSaysTryAgain() {
        let app = launchApp(["-ui-auth-fail"])
        selectTab(app, "Portfolio")
        app.buttons["eyeButton"].tap()

        XCTAssertTrue(app.staticTexts["portfolioAuthMessage"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["portfolioAuthMessage"].label, "Try Again")
        XCTAssertEqual(app.staticTexts["netWorth"].label, "••••••")
    }

    @MainActor
    func testAppLockAsksToUnlockWhenTheAppOpensAndUnlocksWithFaceID() {
        let app = launchApp(["-ui-app-lock"])

        XCTAssertTrue(app.buttons["unlockButton"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["leftToSpend"].exists)
        app.buttons["unlockButton"].tap()
        XCTAssertTrue(app.staticTexts["leftToSpend"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["unlockButton"].exists)
    }

    @MainActor
    func testAFailedFaceIDKeepsTheAppLockedAndSaysTryAgain() {
        let app = launchApp(["-ui-app-lock", "-ui-auth-fail"])

        XCTAssertTrue(app.buttons["unlockButton"].waitForExistence(timeout: 20))
        app.buttons["unlockButton"].tap()

        XCTAssertTrue(app.staticTexts["lockMessage"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["lockMessage"].label, "Try Again")
        XCTAssertTrue(app.buttons["unlockButton"].exists)
        XCTAssertFalse(app.staticTexts["leftToSpend"].exists)
    }

    @MainActor
    func testAppLockCannotBeTurnedOnWhenFaceIDFails() {
        let app = launchApp(["-ui-auth-fail"])
        openSettings(app)
        flip(app.switches["appLockToggle"])

        XCTAssertTrue(app.staticTexts["appLockMessage"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["appLockMessage"].label, "Try Again")
        XCTAssertEqual(app.switches["appLockToggle"].value as? String, "0")
    }

    // MARK: helpers

    /// A switch row toggles from its switch, not from the label in the middle of the row.
    @MainActor
    private func flip(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 20))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        app.buttons["profileButton"].tap()
        let settings = app.buttons["settingsLink"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.tap()
        XCTAssertTrue(app.switches["hideBalancesToggle"].waitForExistence(timeout: 20))
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
