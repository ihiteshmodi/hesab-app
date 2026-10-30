import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/search/search-expenses.feature
struct SearchTests {
    private func appWithExpenses() throws -> BudgetApp {
        let app = try makeApp()
        let rows: [(String, String, String, String, Int, String)] = [
            ("Weekly groceries", "Metro Dairy", "Home & Utilities", "", 1_250, "2026-10-29"),
            ("Sev bhaji", "Highway Dhaba", "Food & Dining", "", 116, "2026-10-24"),
            ("Fuel additive", "Amazon", "Shopping - Needs", "for the scooter", 145, "2026-10-27"),
            ("Water tax", "", "Annual Fixed Expenses", "", 3_120, "2026-04-19"),
        ]
        for (description, entity, category, notes, rupees, date) in rows {
            try app.addExpense(NewExpense(
                date: day(date), description: description, amount: .rupees(rupees), category: category, entity: entity, notes: notes
            ))
        }
        return app
    }

    private func found(_ app: BudgetApp, _ text: String) throws -> [String] {
        try app.searchExpenses(text).groups.flatMap(\.expenses).map(\.description)
    }

    @Test(arguments: [
        ("sev", ["Sev bhaji"]),
        ("HIGHWAY", ["Sev bhaji"]),
        ("scooter", ["Fuel additive"]),
        ("food", ["Sev bhaji"]),
        ("1250", ["Weekly groceries"]),
        ("1,250", ["Weekly groceries"]),
        ("tax", ["Water tax"]),
    ])
    func textMatchesDescriptionEntityCategoryNotesOrAmount(text: String, results: [String]) throws {
        #expect(try found(try appWithExpenses(), text) == results)
    }

    @Test func resultsAreGroupedByMonthNewestFirstWithATotal() throws {
        let app = try appWithExpenses()

        let results = try app.searchExpenses("a")

        #expect(results.groups.map(\.month) == [.init(year: 2026, month: 10), .init(year: 2026, month: 4)])
        #expect(results.groups[0].expenses.map(\.description) == ["Weekly groceries", "Fuel additive", "Sev bhaji"])
        #expect(results.total == .rupees(1_250 + 145 + 116 + 3_120))
    }

    @Test func aRefundLowersTheTotalOfTheResults() throws {
        let app = try appWithExpenses()
        let sev = try #require(try app.searchExpenses("sev").groups.first?.expenses.first)
        try app.markRefundable(sev.id!)
        try app.recordReceived(sev.id!, .rupees(100))

        #expect(try app.searchExpenses("sev").total == .rupees(16))
    }

    @Test func nothingMatchingGivesNoGroups() throws {
        let results = try appWithExpenses().searchExpenses("xyz")

        #expect(results.groups.isEmpty)
        #expect(results.total == .zero)
    }

    @Test func aBlankSearchFindsNothing() throws {
        #expect(try appWithExpenses().searchExpenses("   ").groups.isEmpty)
    }
}
