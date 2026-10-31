import Foundation
import HisaabCore

public struct ImportOptions: Sendable {
    /// Payment names that are cards; they get a bill in the app.
    public var cards: [String]
    /// Entity spellings to rename, old to new.
    public var entityAliases: [String: String]

    public init(cards: [String] = [], entityAliases: [String: String] = [:]) {
        self.cards = cards
        self.entityAliases = entityAliases
    }
}

public struct ImportReport: Equatable, Sendable {
    public let expenses: Int
    public let moneyReceived: Int
    public let skipped: [String]
    public let cards: [String]
    /// The sum of the imported expenses, to check against the spreadsheet.
    public let expenseTotal: Money
    public let leftToSpend: Money
    public internal(set) var incomeEntries = 0
    public internal(set) var bills = 0
    public internal(set) var refundsSettled = 0
    public internal(set) var refundsPending = 0
    public internal(set) var plannedTotal = Money.zero
    public internal(set) var ledgerBalances: [String: Money] = [:]
    public internal(set) var bankBalance = Money.zero
    public internal(set) var investments = Money.zero
    public internal(set) var netWorth = Money.zero
    /// The sum of the expenses after refunds, to check against the spreadsheet's Net Amount column.
    public internal(set) var netExpenseTotal = Money.zero
}

public enum ImportError: Error, Equatable, Sendable {
    case outputExists
    case missingColumn(String)
    case badRow(line: Int, reason: String)

    public var message: String {
        switch self {
        case .outputExists: "Output file already exists. Choose a new name or remove it."
        case .missingColumn(let name): "The CSV has no \"\(name)\" column."
        case .badRow(let line, let reason): "Line \(line): \(reason)."
        }
    }
}

public enum CSVImporter {
    /// Reads the CSV and writes a database file; with no `output` it only reports (a dry run).
    @discardableResult
    public static func run(csv: String, options: ImportOptions, output: URL?) throws -> ImportReport {
        try run(bundle: ImportBundle(expenses: csv), options: options, output: output)
    }

    @discardableResult
    public static func run(bundle: ImportBundle, options: ImportOptions, output: URL?) throws -> ImportReport {
        if let output, FileManager.default.fileExists(atPath: output.path) { throw ImportError.outputExists }
        let plan = try Plan(records: CSV.parse(bundle.expenses), options: options, extras: try ExtraPlan(bundle))

        guard let output else { return try plan.write(to: try AppDatabase.inMemory(), options: options) }

        let scratch = output.deletingLastPathComponent().appendingPathComponent(".import-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let report = try plan.write(to: try AppDatabase.file(at: scratch), options: options)
        try FileManager.default.moveItem(at: scratch, to: output)
        return report
    }

    /// Reads an "old_name,new_name" file.
    public static func aliases(from csv: String) -> [String: String] {
        var result: [String: String] = [:]
        for record in CSV.parse(csv).dropFirst() where record.count >= 2 {
            result[record[0].trimmed] = record[1].trimmed
        }
        return result
    }
}

/// Every row checked and turned into a use-case input before anything is written.
struct Plan {
    enum Item {
        case expense(NewExpense, refund: Refund)
        case received(NewIncome)
    }

    enum Refund { case none, pending, settled }

    var items: [Item] = []
    var skipped: [String] = []
    let extras: ExtraPlan

    init(records: [[String]], options: ImportOptions, extras: ExtraPlan) throws {
        self.extras = extras
        skipped = extras.skipped
        guard let header = records.first else { throw ImportError.missingColumn("date") }
        let columns = Dictionary(
            header.enumerated().map { ($1.trimmed.lowercased(), $0) }, uniquingKeysWith: { first, _ in first }
        )
        for required in ["date", "description", "amount", "payment", "category"] where columns[required] == nil {
            throw ImportError.missingColumn(required)
        }

        for (index, record) in records.enumerated().dropFirst() {
            let line = index + 1
            func field(_ name: String) -> String {
                guard let position = columns[name], position < record.count else { return "" }
                return record[position].trimmed
            }
            func bad(_ reason: String) -> ImportError { .badRow(line: line, reason: reason) }

            guard let date = try? CalendarDate(isoString: field("date")) else {
                throw bad("\(field("date")) is not a valid date")
            }
            guard let amount = Self.amount(field("amount")) else { throw bad("\(field("amount")) is not an amount") }
            let description = field("new_description").isEmpty ? field("description") : field("new_description")
            guard !description.isEmpty else { throw bad("the description is missing") }
            guard !field("category").isEmpty else { throw bad("the category is missing") }

            if amount == .zero {
                skipped.append("Line \(line): \(description) has an amount of 0")
            } else if amount < .zero || field("route").lowercased() == "income" {
                let magnitude = amount < .zero ? Money.zero - amount : amount
                items.append(.received(NewIncome(date: date, kind: .moneyReceived, amount: magnitude, note: description)))
            } else {
                let refundable = field("refundable").lowercased() == "yes"
                let reimbursed = field("reimbursed").lowercased() == "yes"
                items.append(.expense(NewExpense(
                    date: date, description: description, amount: amount, category: field("category"),
                    subCategory: field("sub_category"),
                    entity: options.entityAliases[field("entity")] ?? field("entity"),
                    spentFor: field("spent_for"),
                    tags: field("tags").split(whereSeparator: { ",;|".contains($0) }).map(String.init),
                    paymentMethod: Self.payment(field("payment")), notes: field("my_note")
                ), refund: refundable ? (reimbursed ? .settled : .pending) : .none))
            }
        }
    }

    func write(to database: AppDatabase, options: ImportOptions) throws -> ImportReport {
        let app = BudgetApp(database: database, clock: SystemDayClock())
        for name in options.cards where !(try app.cards()).contains(where: { $0.name.lowercased() == name.lowercased() }) {
            try app.addCard(NewCard(name: name))
        }
        var expenseTotal = Money.zero
        var expenses = 0
        var received = 0
        var settled = 0
        var pending = 0
        var netTotal = Money.zero
        for item in items {
            switch item {
            case .expense(let expense, let refund):
                let saved = try app.addExpense(expense)
                expenseTotal = expenseTotal + (expense.amount ?? .zero)
                expenses += 1
                netTotal = netTotal + (refund == .settled ? .zero : (expense.amount ?? .zero))
                if refund != .none, let id = saved.id {
                    try app.markRefundable(id)
                    if refund == .settled {
                        try app.recordReceived(id, expense.amount ?? .zero)
                        settled += 1
                    } else {
                        pending += 1
                    }
                }
            case .received(let income):
                try app.addIncome(income)
                received += 1
            }
        }
        try extras.write(to: app)
        var report = ImportReport(
            expenses: expenses, moneyReceived: received, skipped: skipped, cards: options.cards,
            expenseTotal: expenseTotal, leftToSpend: try app.monthBudget().leftToSpend
        )
        let portfolio = try app.portfolio()
        report.incomeEntries = extras.income.count
        report.bills = extras.bills.count
        report.refundsSettled = settled
        report.refundsPending = pending
        report.plannedTotal = try app.plannedItems().total
        report.ledgerBalances = Dictionary(
            uniqueKeysWithValues: try app.ledgers().ledgers.map { ($0.ledger.name, $0.balance) }
        )
        report.bankBalance = portfolio.bankBalance
        report.investments = portfolio.investments
        report.netWorth = portfolio.netWorth
        report.netExpenseTotal = netTotal
        return report
    }

    /// Exact amounts as typed; a long decimal such as 16984.059999999998 is spreadsheet noise and is rounded to paise.
    static func amount(_ text: String) -> Money? {
        if let exact = MoneyInput.parse(text) { return exact }
        guard text.wholeMatch(of: /-?[0-9]+\.[0-9]+/) != nil, var value = Decimal(string: text) else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return Money(paise: NSDecimalNumber(decimal: rounded * 100).intValue)
    }

    static func payment(_ name: String) -> PaymentMethod {
        switch name.lowercased() {
        case "upi", "": .upi
        case "cash withdrawal": .cashWithdrawal
        case "cash": .cash
        default: .bank(name)
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
