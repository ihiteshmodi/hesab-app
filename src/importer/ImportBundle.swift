import Foundation
import HisaabCore

/// The files of one full import; only the expenses are required.
public struct ImportBundle: Sendable {
    public var expenses: String
    public var income: String?
    public var bills: String?
    public var planned: String?
    public var ledgers: String?
    public var ledgerEntries: String?
    public var portfolio: String?

    public init(
        expenses: String, income: String? = nil, bills: String? = nil, planned: String? = nil,
        ledgers: String? = nil, ledgerEntries: String? = nil, portfolio: String? = nil
    ) {
        self.expenses = expenses
        self.income = income
        self.bills = bills
        self.planned = planned
        self.ledgers = ledgers
        self.ledgerEntries = ledgerEntries
        self.portfolio = portfolio
    }
}

/// One CSV file read into rows you can ask for fields by column name.
private struct Table {
    let columns: [String: Int]
    let rows: [(line: Int, record: [String])]

    init?(_ text: String?, required: [String], file: String) throws {
        guard let text else { return nil }
        let records = CSV.parse(text)
        guard let header = records.first else { return nil }
        columns = Dictionary(header.enumerated().map { ($1.trimmed.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        for name in required where columns[name] == nil { throw ImportError.missingColumn("\(file): \(name)") }
        rows = records.enumerated().dropFirst().map { (line: $0 + 1, record: $1) }
    }

    func field(_ name: String, _ record: [String]) -> String {
        guard let position = columns[name], position < record.count else { return "" }
        return record[position].trimmed
    }
}

/// Everything besides the expenses, checked row by row before anything is written.
struct ExtraPlan {
    var income: [NewIncome] = []
    var bills: [NewBill] = []
    var planned: [NewPlannedItem] = []
    var ledgers: [NewLedger] = []
    var ledgerEntries: [(ledger: String, entry: NewLedgerEntry)] = []
    var bank: (balance: Money, asOf: CalendarDate?)?
    var holdings: [NewHolding] = []
    var allocations: [(name: String, amount: Money)] = []
    var schemes: [(scheme: NewPayoutScheme, closed: Bool)] = []
    var skipped: [String] = []

    init(_ bundle: ImportBundle) throws {
        try readIncome(bundle.income)
        try readBills(bundle.bills)
        try readPlanned(bundle.planned)
        try readLedgers(bundle.ledgers, bundle.ledgerEntries)
        try readPortfolio(bundle.portfolio)
    }

    private static func bad(_ line: Int, _ file: String, _ reason: String) -> ImportError {
        .badRow(line: line, reason: "\(file): \(reason)")
    }

    private static func date(_ text: String, line: Int, file: String) throws -> CalendarDate {
        guard let date = try? CalendarDate(isoString: text) else { throw bad(line, file, "\(text) is not a valid date") }
        return date
    }

    private static func money(_ text: String, line: Int, file: String) throws -> Money {
        guard let amount = Plan.amount(text) else { throw bad(line, file, "\(text) is not an amount") }
        return amount
    }

    private mutating func readIncome(_ text: String?) throws {
        guard let table = try Table(text, required: ["date", "amount", "kind"], file: "income") else { return }
        for (line, record) in table.rows {
            let kindName = table.field("kind", record)
            guard let kind = IncomeKind(rawValue: kindName) else { throw Self.bad(line, "income", "\(kindName) is not an income kind") }
            let amount = try Self.money(table.field("amount", record), line: line, file: "income")
            let note = table.field("note", record)
            if amount == .zero {
                skipped.append("income line \(line): \(note.isEmpty ? "a row" : note) has an amount of 0")
                continue
            }
            income.append(NewIncome(
                date: try Self.date(table.field("date", record), line: line, file: "income"), kind: kind, amount: amount, note: note
            ))
        }
    }

    private mutating func readBills(_ text: String?) throws {
        let required = ["name", "amount", "category", "next_due", "repeat"]
        guard let table = try Table(text, required: required, file: "bills") else { return }
        for (line, record) in table.rows {
            func field(_ name: String) -> String { table.field(name, record) }
            guard let repeats = BillRepeat(rawValue: field("repeat")) else {
                throw Self.bad(line, "bills", "\(field("repeat")) is not a repeat")
            }
            let alert = BillAlert(rawValue: field("alert")) ?? .none
            bills.append(NewBill(
                name: field("name"), amount: try Self.money(field("amount"), line: line, file: "bills"),
                category: field("category"), subCategory: field("sub_category"), entity: field("entity"),
                paymentMethod: Plan.payment(field("payment")),
                dueDate: try Self.date(field("next_due"), line: line, file: "bills"), repeats: repeats,
                endsOn: field("ends").isEmpty ? nil : try Self.date(field("ends"), line: line, file: "bills"),
                addAutomatically: field("automatic").lowercased() == "yes", alert: alert, notes: field("notes")
            ))
        }
    }

    private mutating func readPlanned(_ text: String?) throws {
        guard let table = try Table(text, required: ["description", "amount"], file: "planned") else { return }
        for (line, record) in table.rows {
            planned.append(NewPlannedItem(
                description: table.field("description", record),
                amount: try Self.money(table.field("amount", record), line: line, file: "planned")
            ))
        }
    }

    private mutating func readLedgers(_ ledgerText: String?, _ entryText: String?) throws {
        if let table = try Table(ledgerText, required: ["name"], file: "ledgers") {
            for (_, record) in table.rows {
                ledgers.append(NewLedger(
                    name: table.field("name", record),
                    countsTowardsNetWorth: table.field("counts_towards_net_worth", record).lowercased() == "yes"
                ))
            }
        }
        guard let table = try Table(entryText, required: ["ledger", "date", "amount"], file: "ledger entries") else { return }
        for (line, record) in table.rows {
            let name = table.field("ledger", record)
            guard ledgers.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
                throw Self.bad(line, "ledger entries", "\(name) is not a ledger in ledgers.csv")
            }
            ledgerEntries.append((name, NewLedgerEntry(
                date: try Self.date(table.field("date", record), line: line, file: "ledger entries"),
                description: table.field("description", record),
                value: try Self.money(table.field("amount", record), line: line, file: "ledger entries")
            )))
        }
    }

    private mutating func readPortfolio(_ text: String?) throws {
        guard let table = try Table(text, required: ["kind", "name", "amount"], file: "portfolio") else { return }
        for (line, record) in table.rows {
            func field(_ name: String) -> String { table.field(name, record) }
            let amount = try Self.money(field("amount"), line: line, file: "portfolio")
            switch field("kind") {
            case "bank_balance":
                bank = (amount, field("date").isEmpty ? nil : try Self.date(field("date"), line: line, file: "portfolio"))
            case "holding":
                holdings.append(NewHolding(
                    name: field("name"), amount: amount, currency: field("currency").isEmpty ? nil : field("currency"),
                    rate: Decimal(string: field("rate"))
                ))
            case "allocation":
                if amount == .zero { skipped.append("portfolio line \(line): \(field("name")) has an amount of 0") }
                else { allocations.append((field("name"), amount)) }
            case "scheme":
                guard let day = Int(field("payout_day")) else { throw Self.bad(line, "portfolio", "\(field("payout_day")) is not a payout day") }
                schemes.append((NewPayoutScheme(
                    name: field("name"), invested: amount,
                    monthlyPayout: try Self.money(field("payout"), line: line, file: "portfolio"), payoutDay: day,
                    maturity: field("maturity").isEmpty ? nil : try Self.date(field("maturity"), line: line, file: "portfolio")
                ), field("closed").lowercased() == "yes"))
            default:
                throw Self.bad(line, "portfolio", "\(field("kind")) is not a kind")
            }
        }
    }

    func write(to app: BudgetApp) throws {
        for new in income { try app.addIncome(new) }
        var ledgerIDs: [String: Int64] = [:]
        for new in ledgers { ledgerIDs[new.name.lowercased()] = try app.addLedger(new).id }
        for item in ledgerEntries {
            if let id = ledgerIDs[item.ledger.lowercased()] { try app.addLedgerEntry(id, item.entry) }
        }
        for new in bills { try app.addBill(new) }
        for new in planned { try app.addPlannedItem(new) }
        if let bank { try app.setBankBalance(bank.balance, asOf: bank.asOf) }
        for new in holdings { try app.addHolding(new) }
        for fund in allocations { try app.addAllocatedFund(name: fund.name, amount: fund.amount) }
        for item in schemes {
            let saved = try app.addScheme(item.scheme)
            if item.closed { try app.closeScheme(saved.id) }
        }
    }
}
