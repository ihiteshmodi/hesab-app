import Testing
@testable import HisaabCore

/// Scenarios from tests/insights/spending-breakdown/spending-breakdown.feature
struct SpendingBreakdownTests {
    private let october = CalendarDate.YearMonth(year: 2026, month: 10)

    @discardableResult
    private func spend(
        _ app: BudgetApp, _ category: String, _ rupees: Int, _ method: PaymentMethod = .upi, sub: String = "",
        date: String = "2026-10-12", entity: String = ""
    ) throws -> Expense {
        try app.addExpense(NewExpense(
            date: day(date), description: "Item", amount: .rupees(rupees), category: category, subCategory: sub,
            entity: entity, paymentMethod: method
        ))
    }

    private func background() throws -> BudgetApp {
        let app = try makeApp()
        try spend(app, "Food & Dining", 2_000, .upi)
        try spend(app, "Food & Dining", 1_000, .cash)
        try spend(app, "Home & Utilities", 5_000, .bank("Visa Card"))
        try spend(app, "Transport", 2_000, .upi)
        return app
    }

    @Test func spendingByCategoryIsListedLargestFirstWithShares() throws {
        let app = try background()

        let report = try app.spendingBreakdown(.month(october), by: .category)

        #expect(report.rows.map(\.name) == ["Home & Utilities", "Food & Dining", "Transport"])
        #expect(report.rows.map(\.amount) == [.rupees(5_000), .rupees(3_000), .rupees(2_000)])
        #expect(report.rows.map(\.sharePercent) == [50, 30, 20])
        #expect(report.total == .rupees(10_000))
    }

    @Test func spendingByPaymentMethodIncludesCashAndLedger() throws {
        let app = try background()

        let report = try app.spendingBreakdown(.month(october), by: .paymentMethod)

        #expect(report.rows.map(\.name) == ["Visa Card", "UPI", "Cash"])
        #expect(report.rows.map(\.amount) == [.rupees(5_000), .rupees(4_000), .rupees(1_000)])
    }

    @Test func spendingByEntityHasANoEntityRow() throws {
        let app = try makeApp()
        try spend(app, "Shopping - Needs", 300, entity: "Amazon")
        try spend(app, "Shopping - Needs", 200, entity: "Amazon")
        try spend(app, "Shopping - Needs", 300, entity: "Meesho")
        try spend(app, "Food & Dining", 150, entity: "Highway Dhaba")
        try spend(app, "Groceries", 50)

        let report = try app.spendingBreakdown(.month(october), by: .entity)

        #expect(report.rows.map(\.name) == ["Amazon", "Meesho", "Highway Dhaba", "No entity"])
        #expect(report.rows.map(\.sharePercent) == [50, 30, 15, 5])
        #expect(report.total == .rupees(1_000))
    }

    @Test func aRefundLowersTheFigures() throws {
        let app = try makeApp()
        let ticket = try spend(app, "Transport", 1_200)
        try app.markRefundable(ticket.id!)
        try app.recordReceived(ticket.id!, .rupees(900))

        #expect(try app.spendingBreakdown(.month(october), by: .category).rows.first?.amount == .rupees(300))
    }

    @Test func aMonthWithNoSpendingIsEmpty() throws {
        let app = try background()

        let report = try app.spendingBreakdown(.month(.init(year: 2026, month: 9)), by: .category)

        #expect(report.isEmpty)
        #expect(report.rows.isEmpty)
        #expect(report.total == .zero)
    }

    @Test func allTimeAddsUpEveryMonth() throws {
        let app = try background()
        try spend(app, "Transport", 500, date: "2026-09-02")

        let report = try app.spendingBreakdown(.allTime, by: .category)

        #expect(report.rows.first { $0.name == "Transport" }?.amount == .rupees(2_500))
        #expect(report.total == .rupees(10_500))
    }

    @Test func sharesAreRoundedToWholePercents() throws {
        let app = try makeApp()
        try spend(app, "Fuel", 1)
        try spend(app, "Personal", 2)

        let report = try app.spendingBreakdown(.month(october), by: .category)

        #expect(report.rows.map(\.sharePercent) == [67, 33])
    }

    @Test func aCategoryCanBeOpenedIntoItsSubCategoriesAndExpenses() throws {
        let app = try makeApp()
        try spend(app, "Food & Dining", 1_800, sub: "Food delivery")
        try spend(app, "Food & Dining", 1_200)
        try spend(app, "Transport", 999)

        let detail = try app.categoryBreakdown("Food & Dining", .month(october))

        #expect(detail.rows.map(\.name) == ["Food delivery", "No sub-category"])
        #expect(detail.rows.map(\.amount) == [.rupees(1_800), .rupees(1_200)])
        #expect(detail.expenses.count == 2)
        #expect(detail.total == .rupees(3_000))
    }

    // MARK: other groupings, any row opens, top share

    private func tagged(
        _ app: BudgetApp, _ rupees: Int, category: String = "Food & Dining", sub: String = "",
        spentFor: String = "", tags: [String] = [], entity: String = ""
    ) throws {
        try app.addExpense(NewExpense(
            date: day("2026-10-12"), description: "Item", amount: .rupees(rupees), category: category, subCategory: sub,
            entity: entity, spentFor: spentFor, tags: tags
        ))
    }

    @Test func spendingCanBeGroupedBySpentForSubCategoryAndTag() throws {
        let app = try makeApp()
        try tagged(app, 700, sub: "Restaurant", spentFor: "Mom", tags: ["Dubai trip"])
        try tagged(app, 300)

        #expect(try app.spendingBreakdown(.month(october), by: .spentFor).rows.map(\.name) == ["Mom", "Me"])
        #expect(try app.spendingBreakdown(.month(october), by: .subCategory).rows.map(\.name)
            == ["Restaurant (Food & Dining)", "Food & Dining (no sub-category)"])
        #expect(try app.spendingBreakdown(.month(october), by: .tag).rows.map(\.name) == ["Dubai trip", "No tag"])
    }

    @Test func anExpenseWithTwoTagsCountsUnderEachTagButOnceInTheTotal() throws {
        let app = try makeApp()
        try tagged(app, 1_000, tags: ["Avenger", "Dominar"])

        let report = try app.spendingBreakdown(.month(october), by: .tag)

        #expect(report.rows.map(\.amount) == [.rupees(1_000), .rupees(1_000)])
        #expect(report.total == .rupees(1_000))
    }

    @Test func anyRowOpensToItsExpensesAndTheirCategories() throws {
        let app = try makeApp()
        try tagged(app, 500, category: "Groceries")
        try tagged(app, 200, category: "Transport")
        try tagged(app, 900, category: "Transport", entity: "Uber")

        let detail = try app.groupBreakdown(.entity, "No entity", .month(october))

        #expect(detail.expenses.map(\.amount) == [.rupees(200), .rupees(500)])
        #expect(detail.rows.map(\.name) == ["Groceries", "Transport"])
        #expect(detail.total == .rupees(700))
    }

    @Test func aCategoryOpensToItsSubCategories() throws {
        let app = try makeApp()
        try tagged(app, 500, sub: "Restaurant")
        try tagged(app, 200)

        let detail = try app.groupBreakdown(.category, "Food & Dining", .month(october))

        #expect(detail.rows.map(\.name) == ["Restaurant", "No sub-category"])
    }

    @Test func theSliderKeepsTheRowsThatMakeUpTheChosenShare() throws {
        let app = try makeApp()
        for (category, rupees) in [("Home & Utilities", 5_000), ("Food & Dining", 3_000), ("Transport", 1_000), ("Fuel", 1_000)] {
            try tagged(app, rupees, category: category)
        }

        let top = try app.spendingBreakdown(.month(october), by: .category).top(percent: 80)

        #expect(top.rows.map(\.name) == ["Home & Utilities", "Food & Dining"])
        #expect(top.rest == .rupees(2_000))
        #expect(try app.spendingBreakdown(.month(october), by: .category).top(percent: 100).rest == .zero)
    }

    @Test func theSliderKeepsTheBiggestExpensesInsideARow() throws {
        let app = try makeApp()
        for rupees in [100, 600, 300] { try tagged(app, rupees) }

        let detail = try app.groupBreakdown(.category, "Food & Dining", .month(october))

        #expect(detail.topExpenses(percent: 80).map(\.amount) == [.rupees(600), .rupees(300)])
        #expect(detail.topExpenses(percent: 100).count == 3)
    }
}
