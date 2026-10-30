import Foundation
import GRDB
import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/currencies/foreign-currency-spending.feature
struct ForeignCurrencyTests {
    private let perThousandIDR = Decimal(string: "0.0053")!

    private func idr(_ amount: Int, rate: Decimal? = nil, paid: Money? = nil) -> ForeignSpend {
        ForeignSpend(currency: "IDR", amount: .rupees(amount), rate: rate, paidInHome: paid)
    }

    @discardableResult
    private func spend(_ app: BudgetApp, foreign: ForeignSpend, date: String = "2026-10-12") throws -> Expense {
        try app.addExpense(NewExpense(
            date: day(date), description: "Dinner", amount: nil, category: "Food & Dining", foreign: foreign
        ))
    }

    @Test func anExpenseInRupiahStoresBothAmountsAndLowersLeftToSpendInTheHomeCurrency() throws {
        let app = try makeApp()

        let saved = try spend(app, foreign: idr(150_000, rate: perThousandIDR))

        #expect(saved.amount == .rupees(795))
        #expect(saved.foreign?.currency == "IDR")
        #expect(saved.foreign?.amount == .rupees(150_000))
        #expect(saved.foreign?.rate == perThousandIDR)
        #expect(try app.monthBudget().leftToSpend == .rupees(-795))
    }

    @Test func whatTheCardActuallyChargedBecomesTheHomeAmountAndSetsTheRate() throws {
        let app = try makeApp()

        let saved = try spend(app, foreign: idr(150_000, paid: .rupees(812, paise: 40)))

        #expect(saved.amount == .rupees(812, paise: 40))
        #expect(saved.foreign?.rate == Decimal(string: "0.005416")!)
    }

    @Test func theLastRateForACurrencyIsOfferedNextTime() throws {
        let app = try makeApp()
        try spend(app, foreign: idr(150_000, rate: Decimal(string: "0.0054")!), date: "2026-10-01")
        try spend(app, foreign: idr(100_000, rate: perThousandIDR), date: "2026-10-09")

        #expect(try app.lastRate(for: "IDR") == perThousandIDR)
        #expect(try app.lastRate(for: "USD") == nil)
    }

    @Test func theFirstTimeACurrencyIsUsedARateIsRequired() throws {
        let app = try makeApp()

        let error = #expect(throws: ExpenseValidationError.self) { try spend(app, foreign: idr(150_000)) }

        #expect(error?.message == "Enter the exchange rate")
    }

    @Test(arguments: [
        (0, Decimal(string: "0.0053")!, "Enter an amount above 0"),
        (150_000, Decimal(0), "Enter an exchange rate above 0"),
        (150_000, Decimal(-1), "Enter an exchange rate above 0"),
    ])
    func invalidForeignAmountsAreRefused(amount: Int, rate: Decimal, message: String) throws {
        let app = try makeApp()

        let error = #expect(throws: ExpenseValidationError.self) { try spend(app, foreign: idr(amount, rate: rate)) }

        #expect(error?.message == message)
        #expect(try app.monthBudget().expenses.isEmpty)
    }

    @Test func aHomeCurrencyExpenseNeedsNoRate() throws {
        let app = try makeApp()

        let saved = try app.addExpense(NewExpense(description: "Tea", amount: .rupees(1_000), category: "Food & Dining"))

        #expect(saved.foreign == nil)
        #expect(saved.amount == .rupees(1_000))
    }

    @Test func totalsStayInTheHomeCurrency() throws {
        let app = try makeApp()
        try spend(app, foreign: idr(150_000, rate: perThousandIDR))
        try app.addExpense(NewExpense(
            date: day("2026-10-12"), description: "Tea", amount: .rupees(1_000), category: "Food & Dining"
        ))

        #expect(try app.monthBudget().spentThisMonth == .rupees(1_795))
    }

    @Test func correctingTheRateChangesTheHomeAmountOfThatExpense() throws {
        let app = try makeApp()
        let saved = try spend(app, foreign: idr(150_000, rate: perThousandIDR))

        let updated = try app.updateExpense(saved.id!, NewExpense(
            date: saved.date, description: "Dinner", amount: nil, category: "Food & Dining",
            foreign: idr(150_000, rate: Decimal(string: "0.0054")!)
        ))

        #expect(updated.amount == .rupees(810))
        #expect(try app.monthBudget().leftToSpend == .rupees(-810))
    }

    @Test func aRefundIsReceivedInTheHomeCurrencyAndCannotExceedIt() throws {
        let app = try makeApp()
        let saved = try spend(app, foreign: idr(150_000, rate: perThousandIDR))
        try app.markRefundable(saved.id!)

        let error = #expect(throws: RefundError.self) { try app.recordReceived(saved.id!, .rupees(900)) }
        #expect(error?.message == "Received can't be more than 795")

        try app.recordReceived(saved.id!, .rupees(795))
        #expect(try app.monthBudget().expenses.first?.netAmount == .zero)
    }

    @Test func aRateIsRoundedToWholePaiseInTheHomeAmount() throws {
        let app = try makeApp()

        let saved = try spend(app, foreign: ForeignSpend(currency: "USD", amount: .rupees(1), rate: Decimal(string: "83.456")!))

        #expect(saved.amount == .rupees(83, paise: 46))
    }

    // MARK: currencies and formatting

    @Test func commonCurrenciesAreOfferedAndMoreCanBeAdded() throws {
        let app = try makeApp()
        #expect(try app.currencies().map(\.code).contains("IDR"))
        #expect(try app.currencies().map(\.code).contains("USD"))

        try app.addCurrency(Currency(code: "VND", name: "Vietnamese Dong", symbol: "₫", decimals: 0))

        let vnd = try #require(try app.currencies().first { $0.code == "VND" })
        #expect(vnd.name == "Vietnamese Dong")
        #expect(CurrencyFormat.string(.rupees(150_000), in: vnd) == "₫150,000")
    }

    @Test func aCurrencyCodeCannotBeAddedTwice() throws {
        let app = try makeApp()

        #expect(throws: CurrencyError.codeTaken("IDR")) {
            try app.addCurrency(Currency(code: "idr", name: "Rupiah", symbol: nil, decimals: 0))
        }
        #expect(throws: CurrencyError.codeMissing) {
            try app.addCurrency(Currency(code: " ", name: "Nothing", symbol: nil, decimals: 2))
        }
        #expect(CurrencyError.codeTaken("IDR").message == "A currency called IDR already exists")
        #expect(CurrencyError.codeMissing.message == "Enter a currency code")
    }

    @Test(arguments: [
        (123_456_789, "INR", "₹12,34,567.89"),
        (123_456_789, "USD", "$1,234,567.89"),
        (15_000_000, "IDR", "IDR 150,000"),
        (-5_050, "USD", "−$50.50"),
    ])
    func amountsAreShownInEachCurrencysOwnStyle(paise: Int, code: String, text: String) throws {
        let app = try makeApp()
        let currency = try #require(try app.currencies().first { $0.code == code })

        #expect(CurrencyFormat.string(Money(paise: paise), in: currency) == text)
    }

    // MARK: home currency and travel mode

    @Test func theHomeCurrencyCanChangeOnlyBeforeAnyRecordsExist() throws {
        let app = try makeApp()
        try app.setHomeCurrency("USD")
        #expect(try app.preferences().homeCurrency == "USD")

        try app.addExpense(NewExpense(description: "Tea", amount: .rupees(10), category: "Food & Dining"))

        let error = #expect(throws: CurrencyError.self) { try app.setHomeCurrency("INR") }
        #expect(error?.message == "Your records are in USD. Export a backup and start a new file to use another home currency.")
        #expect(try app.preferences().homeCurrency == "USD")
    }

    @Test func recordsIncludeIncomeWhenLockingTheHomeCurrency() throws {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(100)))

        #expect(throws: CurrencyError.homeLocked("INR")) { try app.setHomeCurrency("USD") }
    }

    @Test func travelModeRemembersTheCurrencyNewExpensesStartIn() throws {
        let app = try makeApp()
        #expect(try app.preferences().spendingIn == nil)

        try app.updatePreferences { $0.spendingIn = "IDR" }
        #expect(try app.preferences().spendingIn == "IDR")

        try app.updatePreferences { $0.spendingIn = nil }
        #expect(try app.preferences().spendingIn == nil)
    }

    @Test func expensesFromAnOlderVersionHaveNoForeignAmount() throws {
        let queue = try DatabaseQueue()
        try AppDatabase.migrator.migrate(queue, upTo: "v12-bills")
        try queue.write {
            try $0.execute(sql: """
                INSERT INTO expense (date, description, amount_paise, category) VALUES ('2026-10-12', 'Old', 100, 'Groceries')
                """)
        }
        try AppDatabase.migrator.migrate(queue)

        let app = BudgetApp(database: try AppDatabase.file(at: try copy(queue)), clock: FixedDayClock(date: day("2026-10-30")))

        #expect(try app.monthBudget().expenses.first?.foreign == nil)
    }

    private func copy(_ queue: DatabaseQueue) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
        try queue.backup(to: try DatabaseQueue(path: url.path))
        return url
    }
}
