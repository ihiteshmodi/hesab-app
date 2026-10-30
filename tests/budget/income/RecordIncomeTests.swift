import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/income/record-income.feature (borrowing and the
/// amount to repay come in a later slice)
struct RecordIncomeTests {
    @Test func aSalaryRaisesLeftToSpendAndShowsInThatMonthsIncome() throws {
        let app = try makeApp(today: "2026-10-30")

        try app.addIncome(NewIncome(date: day("2026-10-30"), kind: .salary, amount: .rupees(150_000)))

        let october = try app.monthBudget()
        #expect(october.leftToSpend == .rupees(150_000))
        #expect(october.incomeThisMonth == .rupees(150_000))
        #expect(october.incomeEntries.map(\.kind) == [.salary])
    }

    @Test func movingMoneyToSavingsLowersLeftToSpendButIsNotIncome() throws {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(150_000)))

        try app.addIncome(NewIncome(kind: .savings, amount: .rupees(100_000)))

        let october = try app.monthBudget()
        #expect(october.leftToSpend == .rupees(50_000))
        #expect(october.incomeThisMonth == .rupees(150_000))
    }

    @Test func investmentPayoutsAndMoneyReceivedRaiseLeftToSpendAndCountAsIncome() throws {
        let app = try makeApp()

        try app.addIncome(NewIncome(kind: .investmentIncome, amount: .rupees(800), note: "Bond A"))
        try app.addIncome(NewIncome(kind: .moneyReceived, amount: .rupees(1_125), note: "Ben paid his share"))

        let october = try app.monthBudget()
        #expect(october.leftToSpend == .rupees(1_925))
        #expect(october.incomeThisMonth == .rupees(1_925))
        #expect(october.incomeEntries.map(\.note) == ["Ben paid his share", "Bond A"])
    }

    @Test func borrowedMoneyRaisesLeftToSpendButIsNotIncome() throws {
        let app = try makeApp()

        try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(10_000), note: "Savings"))

        let october = try app.monthBudget()
        #expect(october.leftToSpend == .rupees(10_000))
        #expect(october.incomeThisMonth == .zero)
    }

    @Test(arguments: [
        (nil, IncomeKind.salary, "Enter an amount above 0"),
        (Money.zero, IncomeKind.salary, "Enter an amount above 0"),
        (Money.rupees(5_000), nil, "Choose a type"),
    ] as [(Money?, IncomeKind?, String)])
    func incompleteIncomeIsRefusedWithAHelpfulMessageAndNothingIsSaved(
        amount: Money?, kind: IncomeKind?, message: String
    ) throws {
        let app = try makeApp()

        let error = #expect(throws: IncomeValidationError.self) {
            try app.addIncome(NewIncome(kind: kind, amount: amount))
        }

        #expect(error?.message == message)
        #expect(try app.monthBudget().incomeEntries.isEmpty)
    }

    @Test func deletingAnIncomeEntryTakesItBackOutOfLeftToSpend() throws {
        let app = try makeApp()
        let salary = try app.addIncome(NewIncome(kind: .salary, amount: .rupees(150_000)))

        try app.deleteIncome(salary.id)

        #expect(try app.monthBudget().leftToSpend == .zero)
        #expect(try app.monthBudget().incomeEntries.isEmpty)
    }
}
