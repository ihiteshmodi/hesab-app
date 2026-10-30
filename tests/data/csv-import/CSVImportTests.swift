import Foundation
import Testing
import HisaabCore
@testable import HisaabImport

/// Scenarios from tests/data/csv-import/csv-import.feature, with made-up rows only.
struct CSVImportTests {
    private static let header =
        "date,description,new_description,amount,payment,category,sub_category,entity,spent_for,tags,route,my_note"

    private static let rows = [
        "2026-10-01,milk,Milk,50.50,UPI,Groceries,Milk,Dairy Co,,,expense,",
        "2026-10-02,Fibre bill,,\"1,060\",Visa Card,Home & Utilities,Internet,Netco,,,expense,monthly",
        "2026-10-03,Cab for mom,,300,UPI,Transport,Ride share,,Mom,a;b,expense,",
        "2026-10-04,Friend share,,-1125,UPI,Miscellaneous,,,,,expense,",
        "2026-10-05,Old salary,,150000,UPI,Miscellaneous,,,,,income,",
        "2026-10-06,Free sample,,0,UPI,Groceries,,,,,expense,",
    ]

    private var csv: String { ([Self.header] + Self.rows).joined(separator: "\n") + "\n" }
    private let options = ImportOptions(cards: ["Visa Card"], entityAliases: ["Netco": "Net Company"])
    private let october = CalendarDate.YearMonth(year: 2026, month: 10)

    private func outputURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString).sqlite")
    }

    private func open(_ file: URL) throws -> BudgetApp {
        BudgetApp(database: try AppDatabase.file(at: file), clock: FixedDayClock(date: day("2026-10-30")))
    }

    private func expense(_ app: BudgetApp, _ description: String) throws -> Expense {
        try #require(try app.monthBudget(for: october).expenses.first { $0.description == description })
    }

    @Test func aDryRunReportsEverythingAndWritesNothing() throws {
        let report = try CSVImporter.run(csv: csv, options: options, output: nil)

        #expect(report.expenses == 3)
        #expect(report.moneyReceived == 2)
        #expect(report.skipped.count == 1)
        #expect(report.expenseTotal == .rupees(1_410, paise: 50))
        #expect(report.leftToSpend == .rupees(149_714, paise: 50))
    }

    @Test func rowsBecomeExpensesWithEveryDetailKept() throws {
        let file = outputURL()
        _ = try CSVImporter.run(csv: csv, options: options, output: file)
        let app = try open(file)

        let milk = try expense(app, "Milk")
        #expect(milk.amount == .rupees(50, paise: 50))
        #expect(milk.entity == "Dairy Co")
        #expect(milk.subCategory == "Milk")
        #expect(milk.category == "Groceries")
        #expect(milk.date == day("2026-10-01"))
        let cab = try expense(app, "Cab for mom")
        #expect(cab.spentFor == "Mom")
        #expect(cab.tags == ["a", "b"])
        #expect(try expense(app, "Fibre bill").notes == "monthly")
    }

    @Test func theOldDescriptionIsUsedWhenThereIsNoNewOne() throws {
        let file = outputURL()
        _ = try CSVImporter.run(csv: csv, options: options, output: file)

        #expect(try expense(try open(file), "Fibre bill").description == "Fibre bill")
    }

    @Test func cardsUpiAndOtherPaymentsAreMapped() throws {
        let file = outputURL()
        _ = try CSVImporter.run(csv: csv, options: options, output: file)
        let app = try open(file)

        #expect(try expense(app, "Fibre bill").paymentMethod == .bank("Visa Card"))
        #expect(try expense(app, "Milk").paymentMethod == .upi)
        let visa = try #require(try app.cardBills(for: october).lines.first { $0.card.name == "Visa Card" })
        #expect(visa.bill == .rupees(1_060))
    }

    @Test func aPaymentThatIsNeitherUpiNorANamedCardStaysABankPayment() throws {
        let transfer = Self.header + "\n2026-10-01,Rent,,500,NEFT (SBI),Home & Utilities,,,,,expense,\n"
        let file = outputURL()
        _ = try CSVImporter.run(csv: transfer, options: options, output: file)
        let app = try open(file)

        #expect(try expense(app, "Rent").paymentMethod == .bank("NEFT (SBI)"))
        #expect(try app.cards().map(\.name).contains("NEFT (SBI)") == false)
    }

    @Test func aCardAlreadyOfferedByTheAppIsNotAddedTwice() throws {
        let sheet = Self.header + "\n2026-10-01,Fuel,,500,Credit Card,Fuel,,,,,expense,\n"
        let file = outputURL()

        _ = try CSVImporter.run(csv: sheet, options: ImportOptions(cards: ["Credit Card"]), output: file)

        #expect(try open(file).cards().filter { $0.name == "Credit Card" }.count == 1)
    }

    @Test func theAliasesFileRenamesEntities() throws {
        let file = outputURL()
        _ = try CSVImporter.run(csv: csv, options: options, output: file)

        #expect(try expense(try open(file), "Fibre bill").entity == "Net Company")
    }

    @Test func aliasesAreReadFromTheirOwnCSV() {
        let aliases = CSVImporter.aliases(from: "old_name,new_name\nNetco,Net Company\n\"Smith, J\",Smith\n")

        #expect(aliases == ["Netco": "Net Company", "Smith, J": "Smith"])
    }

    @Test func negativeAmountsAndIncomeRowsBecomeMoneyReceived() throws {
        let file = outputURL()
        _ = try CSVImporter.run(csv: csv, options: options, output: file)
        let budget = try open(file).monthBudget(for: october)

        let received = budget.incomeEntries.filter { $0.kind == .moneyReceived }
        #expect(Set(received.map(\.amount)) == [.rupees(1_125), .rupees(150_000)])
        #expect(!budget.expenses.contains { $0.amount < .zero })
    }

    @Test func aZeroAmountRowIsSkippedAndNamed() throws {
        let file = outputURL()
        let report = try CSVImporter.run(csv: csv, options: options, output: file)

        #expect(try open(file).monthBudget(for: october).expenses.contains { $0.description == "Free sample" } == false)
        #expect(report.skipped == ["Line 7: Free sample has an amount of 0"])
    }

    @Test func theToolRefusesToOverwriteAnExistingDatabase() throws {
        let file = outputURL()
        try Data("keep me".utf8).write(to: file)

        #expect(throws: ImportError.outputExists) { try CSVImporter.run(csv: csv, options: options, output: file) }
        #expect(try String(contentsOf: file, encoding: .utf8) == "keep me")
    }

    @Test func aRowThatCannotBeReadStopsTheImportAndIsNamed() throws {
        let broken = Self.header + "\n2026-10-01,Milk,,50,UPI,Groceries,,,,,expense,\n2026-13-45,Bad,,50,UPI,Groceries,,,,,expense,\n"
        let file = outputURL()

        #expect(throws: ImportError.badRow(line: 3, reason: "2026-13-45 is not a valid date")) {
            try CSVImporter.run(csv: broken, options: options, output: file)
        }
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func rowsBrokenInOtherWaysAreNamedToo() {
        let cases: [(String, String)] = [
            ("2026-10-01,Milk,,abc,UPI,Groceries,,,,,expense,", "abc is not an amount"),
            ("2026-10-01,Milk,,50,UPI,,,,,,expense,", "the category is missing"),
            ("2026-10-01,,,50,UPI,Groceries,,,,,expense,", "the description is missing"),
        ]
        for (row, reason) in cases {
            #expect(throws: ImportError.badRow(line: 2, reason: reason)) {
                try CSVImporter.run(csv: Self.header + "\n" + row + "\n", options: options, output: nil)
            }
        }
    }

    @Test func cashPaymentsKeepTheirMeaning() throws {
        let sheet = Self.header + "\n2026-10-01,ATM,,500,Cash Withdrawal,Miscellaneous,,,,,expense,\n"
            + "2026-10-02,Chai,,20,Cash,Food & Dining,,,,,expense,\n"
        let file = outputURL()
        _ = try CSVImporter.run(csv: sheet, options: options, output: file)
        let app = try open(file)

        #expect(try expense(app, "ATM").paymentMethod == .cashWithdrawal)
        #expect(try expense(app, "Chai").paymentMethod == .cash)
    }

    @Test func windowsLineEndingsBlankLinesAndNoFinalNewlineAreAccepted() throws {
        let sheet = Self.header + "\r\n\r\n2026-10-01,Milk,,50,UPI,Groceries,,,,,expense,\r\n\r\n2026-10-02,Bread,,30,UPI,Groceries,,,,,expense,"

        let report = try CSVImporter.run(csv: sheet, options: options, output: nil)

        #expect(report.expenses == 2)
    }

    @Test func spreadsheetFloatingPointNoiseIsRoundedToPaise() throws {
        let sheet = Self.header + "\n2026-10-01,Fuel,,16984.059999999998,UPI,Fuel,,,,,expense,\n"
            + "2026-10-02,Tea,,12.345,UPI,Food & Dining,,,,,expense,\n"
        let file = outputURL()
        _ = try CSVImporter.run(csv: sheet, options: options, output: file)
        let app = try open(file)

        #expect(try expense(app, "Fuel").amount == .rupees(16_984, paise: 6))
        #expect(try expense(app, "Tea").amount == .rupees(12, paise: 35))
    }

    @Test func aMissingRequiredColumnIsReported() {
        #expect(throws: ImportError.missingColumn("amount")) {
            try CSVImporter.run(csv: "date,description,payment,category\n", options: options, output: nil)
        }
    }

    @Test func quotedFieldsMayHoldCommasQuotesAndLineBreaks() throws {
        let sheet = Self.header + "\n2026-10-01,\"Tea, \"\"special\"\"\nround two\",,50,UPI,Groceries,,,,,expense,\n"
        let file = outputURL()

        _ = try CSVImporter.run(csv: sheet, options: options, output: file)

        let saved = try open(file).monthBudget(for: october).expenses
        #expect(saved.map(\.description) == ["Tea, \"special\"\nround two"])
    }

    @Test func errorsReadInPlainWords() {
        #expect(ImportError.outputExists.message == "Output file already exists. Choose a new name or remove it.")
        #expect(ImportError.badRow(line: 3, reason: "x").message == "Line 3: x.")
        #expect(ImportError.missingColumn("amount").message == "The CSV has no \"amount\" column.")
    }
}
