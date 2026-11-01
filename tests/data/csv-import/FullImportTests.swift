import Foundation
import Testing
import HisaabCore
@testable import HisaabImport

/// The "everything the spreadsheet holds" scenarios from tests/data/csv-import/csv-import.feature, with made-up rows only.
struct FullImportTests {
    private static let expenseHeader =
        "date,description,amount,payment,category,route,refundable,reimbursed"
    private let october = CalendarDate.YearMonth(year: 2026, month: 10)
    private let options = ImportOptions(cards: [])

    private func bundle(
        expenses: [String] = [], income: [String]? = nil, bills: [String]? = nil, planned: [String]? = nil,
        ledgers: [String]? = nil, entries: [String]? = nil, portfolio: [String]? = nil
    ) -> ImportBundle {
        func file(_ header: String, _ rows: [String]?) -> String? {
            rows.map { ([header] + $0).joined(separator: "\n") + "\n" }
        }
        return ImportBundle(
            expenses: ([Self.expenseHeader] + expenses).joined(separator: "\n") + "\n",
            income: file("date,amount,kind,note", income),
            bills: file("name,amount,category,sub_category,entity,payment,next_due,repeat,ends,automatic,alert,notes,auto_debit", bills),
            planned: file("description,amount", planned),
            ledgers: file("name,counts_towards_net_worth", ledgers),
            ledgerEntries: file("ledger,date,description,amount", entries),
            portfolio: file("kind,name,amount,currency,rate,date,payout,payout_day,maturity,closed", portfolio)
        )
    }

    private func imported(_ bundle: ImportBundle) throws -> (ImportReport, BudgetApp) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("full-\(UUID().uuidString).sqlite")
        let report = try CSVImporter.run(bundle: bundle, options: options, output: file)
        let app = BudgetApp(database: try AppDatabase.file(at: file), clock: FixedDayClock(date: day("2026-10-30")))
        return (report, app)
    }

    private func expense(_ app: BudgetApp, _ description: String) throws -> Expense {
        try #require(try app.monthBudget(for: october).expenses.first { $0.description == description })
    }

    @Test func refundFlagsBecomeRefundStates() throws {
        let (report, app) = try imported(bundle(expenses: [
            "2026-10-01,Train ticket,1200,UPI,Transport,expense,Yes,Yes",
            "2026-10-02,Online order,600,UPI,Shopping - Needs,expense,Yes,No",
            "2026-10-03,Milk,50,UPI,Groceries,expense,No,No",
        ]))

        #expect(try expense(app, "Train ticket").refund == .settled(received: .rupees(1_200)))
        #expect(try expense(app, "Online order").refund == .pending)
        #expect(try expense(app, "Milk").refund == .notRefundable)
        #expect(report.refundsSettled == 1)
        #expect(report.refundsPending == 1)
    }

    @Test func refundFlagsOnAMoneyReceivedRowAreIgnored() throws {
        let (report, _) = try imported(bundle(expenses: ["2026-10-01,Friend share,-300,UPI,Miscellaneous,expense,Yes,Yes"]))

        #expect(report.moneyReceived == 1)
        #expect(report.refundsSettled == 0)
    }

    @Test func incomeRowsKeepTheirKindAndNote() throws {
        let (report, app) = try imported(bundle(
            expenses: ["2026-10-02,Milk,500,UPI,Groceries,expense,No,No"],
            income: [
                "2026-10-01,10000,salary,",
                "2026-10-05,800,investment_income,Bond A",
                "2026-10-06,3000,savings,moved to savings",
            ]
        ))
        let entries = try app.monthBudget(for: october).incomeEntries

        #expect(Set(entries.map(\.kind)) == [.salary, .investmentIncome, .savings])
        #expect(entries.first { $0.kind == .investmentIncome }?.note == "Bond A")
        #expect(report.incomeEntries == 3)
        #expect(report.leftToSpend == .rupees(7_300))
    }

    @Test func zeroIncomeRowsAreSkippedAndReportedWithTheirNote() throws {
        let (report, _) = try imported(bundle(
            expenses: [], income: ["2026-10-06,0,savings,no investment this month"]
        ))

        #expect(report.incomeEntries == 0)
        #expect(report.skipped == ["income line 2: no investment this month has an amount of 0"])
    }

    @Test func anIncomeKindThatIsNotKnownStopsTheImport() {
        #expect(throws: ImportError.badRow(line: 2, reason: "income: lottery is not an income kind")) {
            try imported(bundle(income: ["2026-10-06,100,lottery,"]))
        }
    }

    @Test func aBillIsPaidByHandUnlessTheFileSaysItDebitsByItself() throws {
        let (_, app) = try imported(bundle(bills: [
            "Premium,3000,Monthly Fixed Expenses,,,Bank,2026-11-05,monthly,,no,none,,yes",
            "Light,900,Monthly Fixed Expenses,,,Bank,2026-11-06,monthly,,no,none,,",
        ]))
        let bills = try app.bills().map(\.bill)

        #expect(bills.first { $0.name == "Premium" }?.autoDebit == true)
        #expect(bills.first { $0.name == "Light" }?.autoDebit == false)
    }

    @Test func billsStartOnTheGivenDateAndAnAutomaticOneAddsNothingOnTheFirstLaunch() throws {
        let (report, app) = try imported(bundle(bills: [
            "Home cash,5000,Monthly Fixed Expenses,,,Cash Withdrawal,2026-11-01,monthly,,yes,none,,",
            "Society,7000,Monthly Fixed Expenses,,,NEFT (SBI),2026-08-12,every3Months,,no,dayBefore,quarterly,",
        ]))
        let bills = try app.bills()

        #expect(report.bills == 2)
        #expect(bills.map(\.bill.name) == ["Home cash", "Society"])
        #expect(bills[0].nextDue == day("2026-11-01"))
        #expect(bills[0].bill.addAutomatically)
        #expect(bills[1].bill.repeats == .every3Months)
        #expect(bills[1].bill.alert == .dayBefore)
        #expect(bills[1].bill.notes == "quarterly")
        #expect(try app.runAutomaticBills().isEmpty)
        #expect(try app.monthBudget(for: october).expenses.isEmpty)
    }

    @Test func aBillWithAnUnknownRepeatStopsTheImportAndIsNamed() {
        #expect(throws: ImportError.badRow(line: 2, reason: "bills: fortnightly is not a repeat")) {
            try imported(bundle(bills: ["Gym,500,Health & Medical,,,UPI,2026-11-01,fortnightly,,no,none,"]))
        }
    }

    @Test func plannedItemsKeepTheirTotal() throws {
        let (report, app) = try imported(bundle(planned: ["Helmet,2000", "Vials,600"]))

        #expect(try app.plannedItems().total == .rupees(2_600))
        #expect(report.plannedTotal == .rupees(2_600))
    }

    @Test func ledgersComeWithTheirEntriesAndNetWorthFlag() throws {
        let (report, app) = try imported(bundle(
            ledgers: ["Aunty,yes", "Friend,no"],
            entries: ["Aunty,2026-09-01,Carry over,5000", "Aunty,2026-09-10,Sent,-1200", "Friend,2026-09-02,Held,100"]
        ))
        let ledgers = try app.ledgers().ledgers

        let aunty = try #require(ledgers.first { $0.ledger.name == "Aunty" })
        #expect(aunty.balance == .rupees(3_800))
        #expect(aunty.ledger.countsTowardsNetWorth)
        #expect(try #require(ledgers.first { $0.ledger.name == "Friend" }).ledger.countsTowardsNetWorth == false)
        #expect(report.ledgerBalances == ["Aunty": .rupees(3_800), "Friend": .rupees(100)])
    }

    @Test func aLedgerEntryForAnUnknownLedgerStopsTheImport() {
        #expect(throws: ImportError.badRow(line: 2, reason: "ledger entries: Nobody is not a ledger in ledgers.csv")) {
            try imported(bundle(ledgers: ["Aunty,no"], entries: ["Nobody,2026-09-01,Carry over,5000"]))
        }
    }

    @Test func thePortfolioIsRebuiltAndNetWorthFollowsTheAppsRule() throws {
        let (report, app) = try imported(bundle(
            ledgers: ["Aunty,yes", "Friend,no"],
            entries: ["Aunty,2026-09-01,Carry over,5000", "Friend,2026-09-02,Held,2000"],
            portfolio: [
                "bank_balance,,100000,,,2026-10-29,,,,",
                "holding,Shares,10000,,,,,,,",
                "holding,Cash reserve,10,USD,80,2026-06-22,,,,",
                "allocation,Trip fund,4000,,,,,,,",
                "scheme,Bond A,100000,,,,800,24,2028-01-30,no",
                "scheme,Bond B,50000,,,,0,5,,yes",
            ]
        ))
        let portfolio = try app.portfolio()
        let schemes = try app.payoutSchemes().schemes.map(\.scheme)

        #expect(portfolio.bankBalance == .rupees(100_000))
        #expect(portfolio.bankBalanceAsOf == day("2026-10-29"))
        #expect(portfolio.holdings.map(\.holding.name).sorted() == ["Cash reserve", "Shares"])
        #expect(portfolio.allocatedFunds.map(\.name) == ["Trip fund"])
        #expect(portfolio.availableForAllocation == .rupees(89_000))
        #expect(schemes.map(\.name) == ["Bond A", "Bond B"])
        #expect(schemes[0].payoutDay == 24)
        #expect(schemes[0].maturity == day("2028-01-30"))
        #expect(schemes[0].monthlyPayout == .rupees(800))
        #expect(schemes[1].isClosed)
        #expect(report.bankBalance == .rupees(100_000))
        #expect(report.investments == portfolio.investments)
        #expect(report.netWorth == portfolio.netWorth)
        #expect(portfolio.netWorth == portfolio.availableForAllocation + portfolio.investments + .rupees(5_000))
    }

    @Test func zeroAllocationsAreSkippedAndReported() throws {
        let (report, app) = try imported(bundle(portfolio: ["allocation,Empty goal,0,,,,,,,"]))

        #expect(try app.portfolio().allocatedFunds.isEmpty)
        #expect(report.skipped == ["portfolio line 2: Empty goal has an amount of 0"])
    }

    @Test func aBundleWithOnlyExpensesStillWorks() throws {
        let (report, _) = try imported(bundle(expenses: ["2026-10-01,Milk,50,UPI,Groceries,expense,No,No"]))

        #expect(report.expenses == 1)
        #expect(report.bills == 0)
        #expect(report.plannedTotal == .zero)
    }
}
