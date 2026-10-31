import Foundation
import GRDB

public struct Holding: Equatable, Sendable {
    public let id: Int64
    public let name: String
    /// In the holding's own currency.
    public let amount: Money
    /// Nil means the home currency.
    public let currency: String?
}

public struct HoldingLine: Equatable, Sendable {
    public let holding: Holding
    public let valueInHome: Money
}

public struct AllocatedFund: Equatable, Sendable {
    public let id: Int64
    public let name: String
    public let amount: Money
}

public struct ExchangeRateLine: Equatable, Sendable {
    public let currency: String
    public let rate: Decimal
    public let setOn: CalendarDate
}

public struct NewHolding: Sendable {
    public var name: String
    public var amount: Money?
    public var currency: String?
    public var rate: Decimal?

    public init(name: String, amount: Money?, currency: String? = nil, rate: Decimal? = nil) {
        self.name = name
        self.amount = amount
        self.currency = currency
        self.rate = rate
    }
}

public struct Portfolio: Equatable, Sendable {
    public let bankBalance: Money
    public let bankBalanceAsOf: CalendarDate?
    /// Bank balance minus every ledger balance and every allocated fund.
    public let availableForAllocation: Money
    /// Holdings (foreign ones at today's rate) plus open payout schemes.
    public let investments: Money
    public let netWorth: Money
    public let holdings: [HoldingLine]
    public let allocatedFunds: [AllocatedFund]
    public let rates: [ExchangeRateLine]
    public let warning: String?
}

public enum PortfolioError: Error, Equatable, Sendable {
    case nameMissing
    case amountInvalid
    case rateMissing
    case rateNotPositive
    case notFound(Int64)

    public var message: String {
        switch self {
        case .nameMissing: "Enter a name"
        case .amountInvalid: "Enter an amount of 0 or more"
        case .rateMissing: "Enter the exchange rate"
        case .rateNotPositive: "Enter an exchange rate above 0"
        case .notFound: "That item no longer exists."
        }
    }
}

final class PortfolioRepository: Sendable {
    private let database: AppDatabase
    private let settings: SettingsRepository

    init(database: AppDatabase, settings: SettingsRepository) {
        self.database = database
        self.settings = settings
    }

    func bank() throws -> (balance: Money, asOf: CalendarDate?) {
        let stored = try settings.all()
        return (
            Money(paise: stored["bank_balance_paise"].flatMap(Int.init) ?? 0),
            try stored["bank_balance_date"].map { try CalendarDate(isoString: $0) }
        )
    }

    func setBank(_ balance: Money, asOf date: CalendarDate) throws {
        try settings.save(["bank_balance_paise": String(balance.paise), "bank_balance_date": date.isoString])
    }

    func holdings() throws -> [Holding] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name, amount_paise, currency FROM holding ORDER BY id").map {
                Holding(id: $0["id"], name: $0["name"], amount: Money(paise: $0["amount_paise"]), currency: $0["currency"])
            }
        }
    }

    func addHolding(name: String, amount: Money, currency: String?) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO holding (name, amount_paise, currency) VALUES (?, ?, ?)",
                arguments: [name, amount.paise, currency]
            )
        }
    }

    func updateHolding(_ id: Int64, name: String, amount: Money, currency: String?) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE holding SET name = ?, amount_paise = ?, currency = ? WHERE id = ?",
                arguments: [name, amount.paise, currency, id]
            )
            guard db.changesCount > 0 else { throw PortfolioError.notFound(id) }
        }
    }

    func deleteHolding(_ id: Int64) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM holding WHERE id = ?", arguments: [id])
            guard db.changesCount > 0 else { throw PortfolioError.notFound(id) }
        }
    }

    func funds() throws -> [AllocatedFund] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name, amount_paise FROM allocated_fund ORDER BY id").map {
                AllocatedFund(id: $0["id"], name: $0["name"], amount: Money(paise: $0["amount_paise"]))
            }
        }
    }

    func addFund(name: String, amount: Money) throws {
        try database.writer.write { db in
            try db.execute(sql: "INSERT INTO allocated_fund (name, amount_paise) VALUES (?, ?)", arguments: [name, amount.paise])
        }
    }

    func updateFund(_ id: Int64, name: String, amount: Money) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE allocated_fund SET name = ?, amount_paise = ? WHERE id = ?", arguments: [name, amount.paise, id])
            guard db.changesCount > 0 else { throw PortfolioError.notFound(id) }
        }
    }

    func deleteFund(_ id: Int64) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM allocated_fund WHERE id = ?", arguments: [id])
            guard db.changesCount > 0 else { throw PortfolioError.notFound(id) }
        }
    }

    func rates() throws -> [ExchangeRateLine] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT currency, rate, set_on FROM exchange_rate ORDER BY currency").compactMap {
                guard let rate = Decimal(string: $0["rate"] as String) else { return nil }
                return ExchangeRateLine(currency: $0["currency"], rate: rate, setOn: try CalendarDate(isoString: $0["set_on"]))
            }
        }
    }

    func setRate(_ currency: String, _ rate: Decimal, on date: CalendarDate) throws {
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO exchange_rate (currency, rate, set_on) VALUES (?, ?, ?)
                ON CONFLICT(currency) DO UPDATE SET rate = excluded.rate, set_on = excluded.set_on
                """, arguments: [currency, "\(rate)", date.isoString])
        }
    }
}

public struct GetPortfolio: Sendable {
    let portfolio: PortfolioRepository
    let ledgers: LedgerRepository
    let expenses: ExpenseRepository
    let schemes: PayoutSchemeRepository

    public func callAsFunction() throws -> Portfolio {
        let bank = try portfolio.bank()
        let ledgerSummaries = LedgerBook.summaries(
            ledgers: try ledgers.allLedgers(), entries: try ledgers.allEntries(), expenses: try expenses.all()
        )
        let ledgerTotal = ledgerSummaries.reduce(Money.zero) { $0 + $1.balance }
        let counted = ledgerSummaries.filter(\.ledger.countsTowardsNetWorth).reduce(Money.zero) { $0 + $1.balance }
        let funds = try portfolio.funds()
        let rates = try portfolio.rates()
        let lines = try portfolio.holdings().map { holding -> HoldingLine in
            guard let code = holding.currency, let rate = rates.first(where: { $0.currency == code })?.rate else {
                return HoldingLine(holding: holding, valueInHome: holding.amount)
            }
            var exact = Decimal(holding.amount.paise) * rate
            var rounded = Decimal()
            NSDecimalRound(&rounded, &exact, 0, .plain)
            return HoldingLine(holding: holding, valueInHome: Money(paise: NSDecimalNumber(decimal: rounded).intValue))
        }
        let schemeTotal = try schemes.all().filter { !$0.isClosed }.reduce(Money.zero) { $0 + $1.invested }
        let investments = lines.reduce(Money.zero) { $0 + $1.valueInHome } + schemeTotal
        let available = bank.balance - ledgerTotal - funds.reduce(Money.zero) { $0 + $1.amount }
        return Portfolio(
            bankBalance: bank.balance, bankBalanceAsOf: bank.asOf, availableForAllocation: available,
            investments: investments, netWorth: available + investments + counted, holdings: lines,
            allocatedFunds: funds, rates: rates,
            warning: available < .zero ? "Allocations exceed the bank balance by \(IndianMoneyFormat.plain(.zero - available))" : nil
        )
    }
}

public struct SetBankBalance: Sendable {
    let portfolio: PortfolioRepository
    let clock: any DayClock

    public func callAsFunction(_ balance: Money, asOf date: CalendarDate? = nil) throws {
        try portfolio.setBank(balance, asOf: date ?? clock.today())
    }
}

public struct SetExchangeRate: Sendable {
    let portfolio: PortfolioRepository
    let clock: any DayClock

    public func callAsFunction(_ currency: String, _ rate: Decimal) throws {
        guard rate > 0 else { throw PortfolioError.rateNotPositive }
        try portfolio.setRate(currency, rate, on: clock.today())
    }
}

public struct AddHolding: Sendable {
    let portfolio: PortfolioRepository
    let setRate: SetExchangeRate

    public func callAsFunction(_ new: NewHolding) throws {
        let (name, amount) = try validatedHolding(new, portfolio: portfolio, setRate: setRate)
        try portfolio.addHolding(name: name, amount: amount, currency: new.currency)
    }
}

public struct UpdateHolding: Sendable {
    let portfolio: PortfolioRepository
    let setRate: SetExchangeRate

    public func callAsFunction(_ id: Int64, _ new: NewHolding) throws {
        let (name, amount) = try validatedHolding(new, portfolio: portfolio, setRate: setRate)
        try portfolio.updateHolding(id, name: name, amount: amount, currency: new.currency)
    }
}

private func validatedHolding(
    _ new: NewHolding, portfolio: PortfolioRepository, setRate: SetExchangeRate
) throws -> (name: String, amount: Money) {
    let name = new.name.trimmed
    guard !name.isEmpty else { throw PortfolioError.nameMissing }
    guard let amount = new.amount, amount >= .zero else { throw PortfolioError.amountInvalid }
    if let currency = new.currency {
        if let rate = new.rate {
            try setRate(currency, rate)
        } else if try !portfolio.rates().contains(where: { $0.currency == currency }) {
            throw PortfolioError.rateMissing
        }
    }
    return (name, amount)
}

public struct DeleteHolding: Sendable {
    let portfolio: PortfolioRepository

    public func callAsFunction(_ id: Int64) throws {
        try portfolio.deleteHolding(id)
    }
}

public struct AddAllocatedFund: Sendable {
    let portfolio: PortfolioRepository

    public func callAsFunction(name: String, amount: Money?) throws {
        guard !name.trimmed.isEmpty else { throw PortfolioError.nameMissing }
        guard let amount, amount >= .zero else { throw PortfolioError.amountInvalid }
        try portfolio.addFund(name: name.trimmed, amount: amount)
    }
}

public struct UpdateAllocatedFund: Sendable {
    let portfolio: PortfolioRepository

    public func callAsFunction(_ id: Int64, name: String, amount: Money?) throws {
        guard !name.trimmed.isEmpty else { throw PortfolioError.nameMissing }
        guard let amount, amount >= .zero else { throw PortfolioError.amountInvalid }
        try portfolio.updateFund(id, name: name.trimmed, amount: amount)
    }
}

public struct DeleteAllocatedFund: Sendable {
    let portfolio: PortfolioRepository

    public func callAsFunction(_ id: Int64) throws {
        try portfolio.deleteFund(id)
    }
}

public struct SetLedgerCountsTowardsNetWorth: Sendable {
    let ledgers: LedgerRepository

    public func callAsFunction(_ id: Int64, _ counts: Bool) throws {
        try ledgers.setCountsTowardsNetWorth(id, counts)
    }
}
