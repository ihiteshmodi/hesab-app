import Foundation
import GRDB

/// What kind of investment it is: a SIP keeps getting money added, a stock is bought and held.
public enum HoldingKind: String, CaseIterable, Sendable {
    case stock, sip, other

    public var title: String {
        switch self {
        case .stock: "Stock"
        case .sip: "SIP"
        case .other: "Other"
        }
    }
}

public struct Holding: Equatable, Sendable {
    public let id: Int64
    public let name: String
    /// In the holding's own currency.
    public let amount: Money
    /// Nil means the home currency.
    public let currency: String?
    /// What was paid for it, in the holding's own currency; nil when she does not track it.
    public let invested: Money?
    /// The day it was first bought; nil when she has not said.
    public let investedOn: CalendarDate?
    public let kind: HoldingKind
    /// A SIP's usual instalment and the day of the month it goes out.
    public let sipAmount: Money?
    public let sipDay: Int?

    /// Up or down against what was paid, in the holding's own currency.
    public var gain: Money? { invested.map { amount - $0 } }

    /// The gain as a share of what was paid, in tenths of a percent (125 is 12.5%).
    public var gainPercentTenths: Int? {
        guard let invested, invested > .zero else { return nil }
        return Self.tenths(of: amount - invested, over: invested)
    }

    static func tenths(of gain: Money, over base: Money) -> Int {
        // Half-up in whole paise, away from zero for losses.
        (gain.paise * 1_000 + gain.paise.signum() * base.paise / 2) / base.paise
    }
}

public struct HoldingLine: Equatable, Sendable {
    public let holding: Holding
    public let valueInHome: Money
    /// The gain converted at today's rate; nil when she does not track what was paid.
    public let gainInHome: Money?
}

/// Every holding that has an amount invested, added together in the home currency.
public struct InvestmentPerformance: Equatable, Sendable {
    public let invested: Money
    public let value: Money
    public var gain: Money { value - invested }
    public var gainPercentTenths: Int? { invested > .zero ? Holding.tenths(of: gain, over: invested) : nil }
}

/// Money added later, such as a SIP instalment.
public struct HoldingContribution: Equatable, Sendable {
    public let id: Int64
    public let date: CalendarDate
    public let amount: Money
}

/// Everything the page of one investment shows.
public struct HoldingDetail: Equatable, Sendable {
    public let line: HoldingLine
    /// Days since it was bought; nil when no date was given.
    public let daysHeld: Int?
    /// About how much it grows a year, in tenths of a percent: only for a lump sum held a year or more, because money added
    /// at different times cannot be averaged this simply.
    public let yearlyGrowthTenths: Int?
    /// Oldest first.
    public let contributions: [HoldingContribution]
    /// What the first purchase was: what she paid less everything added later; nil when she does not track what she paid.
    public let boughtAmount: Money?
    public let history: [HoldingPoint]
    /// A SIP's next instalment day, or the one that is due now; nil for anything else.
    public let nextInstalment: CalendarDate?
    /// A SIP whose instalment day has come and has nothing added this month.
    public let instalmentDue: Bool

    public var holding: Holding { line.holding }
}

public struct HoldingPoint: Equatable, Sendable {
    public let date: CalendarDate
    public let value: Money
    public let invested: Money?
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
    /// What was paid; leave out for a holding she does not track.
    public var invested: Money?
    /// The day it was bought.
    public var investedOn: CalendarDate?
    public var kind: HoldingKind
    /// Only kept for a SIP: the usual instalment and the day of the month it goes out.
    public var sipAmount: Money?
    public var sipDay: Int?

    public init(
        name: String, amount: Money?, currency: String? = nil, rate: Decimal? = nil, invested: Money? = nil,
        investedOn: CalendarDate? = nil, kind: HoldingKind = .other, sipAmount: Money? = nil, sipDay: Int? = nil
    ) {
        self.name = name
        self.amount = amount
        self.currency = currency
        self.rate = rate
        self.invested = invested
        self.investedOn = investedOn
        self.kind = kind
        self.sipAmount = sipAmount
        self.sipDay = sipDay
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
    /// Up or down across the holdings that have an amount invested; nil when none has.
    public let performance: InvestmentPerformance?
}

public enum PortfolioError: Error, Equatable, Sendable {
    case nameMissing
    case amountInvalid
    case rateMissing
    case rateNotPositive
    case notFound(Int64)
    case investedMissing
    case dateInFuture
    case sipDayMissing
    case sipAmountInvalid

    public var message: String {
        switch self {
        case .sipDayMissing: "Pick the day of the month the instalment goes out."
        case .sipAmountInvalid: "Enter an amount above 0"
        case .dateInFuture: "The date can't be in the future."
        case .investedMissing: "Enter what you paid for it first."
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
            try Row.fetchAll(db, sql: "SELECT * FROM holding ORDER BY id").map {
                Holding(
                    id: $0["id"], name: $0["name"], amount: Money(paise: $0["amount_paise"]), currency: $0["currency"],
                    invested: ($0["invested_paise"] as Int?).map { Money(paise: $0) },
                    investedOn: try ($0["invested_on"] as String?).map { try CalendarDate(isoString: $0) },
                    kind: HoldingKind(rawValue: $0["kind"]) ?? .other,
                    sipAmount: ($0["sip_amount_paise"] as Int?).map { Money(paise: $0) }, sipDay: $0["sip_day"]
                )
            }
        }
    }

    func addHolding(_ checked: CheckedHolding, currency: String?, invested: Money?, investedOn: CalendarDate?, on date: CalendarDate) throws {
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO holding (name, amount_paise, currency, invested_paise, invested_on, kind, sip_amount_paise, sip_day)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    checked.name, checked.amount.paise, currency, invested?.paise, investedOn?.isoString, checked.kind.rawValue,
                    checked.sipAmount?.paise, checked.sipDay,
                ])
            let amount = checked.amount
            try Self.remember(db, db.lastInsertedRowID, date, amount, invested)
        }
    }

    func updateHolding(
        _ id: Int64, _ checked: CheckedHolding, currency: String?, invested: Money?, investedOn: CalendarDate?, on date: CalendarDate
    ) throws {
        try database.writer.write { db in
            try db.execute(sql: """
                UPDATE holding SET name = ?, amount_paise = ?, currency = ?, invested_paise = ?, invested_on = ?, kind = ?,
                    sip_amount_paise = ?, sip_day = ? WHERE id = ?
                """, arguments: [
                    checked.name, checked.amount.paise, currency, invested?.paise, investedOn?.isoString, checked.kind.rawValue,
                    checked.sipAmount?.paise, checked.sipDay, id,
                ])
            let amount = checked.amount
            guard db.changesCount > 0 else { throw PortfolioError.notFound(id) }
            try Self.remember(db, id, date, amount, invested)
        }
    }

    /// One value per holding per day: the last one of the day wins.
    private static func remember(_ db: Database, _ id: Int64, _ date: CalendarDate, _ value: Money, _ invested: Money?) throws {
        try db.execute(sql: """
            INSERT OR REPLACE INTO holding_value (holding_id, date, value_paise, invested_paise) VALUES (?, ?, ?, ?)
            """, arguments: [id, date.isoString, value.paise, invested?.paise])
    }

    /// Adds money to a holding in one step: what was paid and what it is worth both rise, and the addition is listed.
    func contribute(_ holding: Holding, amount: Money, on date: CalendarDate, today: CalendarDate) throws {
        try database.writer.write { db in
            let invested = (holding.invested ?? .zero) + amount
            let value = holding.amount + amount
            try db.execute(
                sql: "UPDATE holding SET amount_paise = ?, invested_paise = ? WHERE id = ?", arguments: [value.paise, invested.paise, holding.id]
            )
            try db.execute(
                sql: "INSERT INTO holding_contribution (holding_id, date, amount_paise) VALUES (?, ?, ?)",
                arguments: [holding.id, date.isoString, amount.paise]
            )
            try Self.remember(db, holding.id, today, value, invested)
        }
    }

    func contributions(of id: Int64) throws -> [HoldingContribution] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: """
                SELECT id, date, amount_paise FROM holding_contribution WHERE holding_id = ? ORDER BY date, id
                """, arguments: [id]).map {
                HoldingContribution(id: $0["id"], date: try CalendarDate(isoString: $0["date"]), amount: Money(paise: $0["amount_paise"]))
            }
        }
    }

    func history(of id: Int64) throws -> [HoldingPoint] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: """
                SELECT date, value_paise, invested_paise FROM holding_value WHERE holding_id = ? ORDER BY date
                """, arguments: [id]).map {
                HoldingPoint(
                    date: try CalendarDate(isoString: $0["date"]), value: Money(paise: $0["value_paise"]),
                    invested: ($0["invested_paise"] as Int?).map { Money(paise: $0) }
                )
            }
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
            let home: (Money) -> Money = { money in
                guard let code = holding.currency, let rate = rates.first(where: { $0.currency == code })?.rate else { return money }
                var exact = Decimal(money.paise) * rate
                var rounded = Decimal()
                NSDecimalRound(&rounded, &exact, 0, .plain)
                return Money(paise: NSDecimalNumber(decimal: rounded).intValue)
            }
            return HoldingLine(holding: holding, valueInHome: home(holding.amount), gainInHome: holding.gain.map(home))
        }
        let tracked = lines.filter { $0.holding.invested != nil }
        let performance = tracked.isEmpty ? nil : InvestmentPerformance(
            invested: tracked.reduce(.zero) { $0 + $1.valueInHome - ($1.gainInHome ?? .zero) },
            value: tracked.reduce(.zero) { $0 + $1.valueInHome }
        )
        let schemeTotal = try schemes.all().filter { !$0.isClosed }.reduce(Money.zero) { $0 + $1.invested }
        let investments = lines.reduce(Money.zero) { $0 + $1.valueInHome } + schemeTotal
        let available = bank.balance - ledgerTotal - funds.reduce(Money.zero) { $0 + $1.amount }
        return Portfolio(
            bankBalance: bank.balance, bankBalanceAsOf: bank.asOf, availableForAllocation: available,
            investments: investments, netWorth: available + investments + counted, holdings: lines,
            allocatedFunds: funds, rates: rates,
            warning: available < .zero ? "Allocations exceed the bank balance by \(IndianMoneyFormat.plain(.zero - available))" : nil,
            performance: performance
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
    let clock: any DayClock

    public func callAsFunction(_ new: NewHolding) throws {
        let checked = try validatedHolding(new, portfolio: portfolio, setRate: setRate)
        try portfolio.addHolding(checked, currency: new.currency, invested: new.invested, investedOn: new.investedOn, on: clock.today())
    }
}

public struct UpdateHolding: Sendable {
    let portfolio: PortfolioRepository
    let setRate: SetExchangeRate
    let clock: any DayClock

    public func callAsFunction(_ id: Int64, _ new: NewHolding) throws {
        let checked = try validatedHolding(new, portfolio: portfolio, setRate: setRate)
        try portfolio.updateHolding(
            id, checked, currency: new.currency, invested: new.invested, investedOn: new.investedOn, on: clock.today()
        )
    }
}

public struct AddToHolding: Sendable {
    let portfolio: PortfolioRepository
    let clock: any DayClock

    /// A SIP instalment or a top-up: what was paid and what it is worth both go up by `amount`, as of `date` (default today).
    public func callAsFunction(_ id: Int64, amount: Money?, on date: CalendarDate? = nil) throws {
        guard let amount, amount > .zero else { throw PortfolioError.amountInvalid }
        guard let holding = try portfolio.holdings().first(where: { $0.id == id }) else { throw PortfolioError.notFound(id) }
        guard holding.invested != nil else { throw PortfolioError.investedMissing }
        let today = clock.today()
        guard (date ?? today) <= today else { throw PortfolioError.dateInFuture }
        try portfolio.contribute(holding, amount: amount, on: date ?? today, today: today)
    }
}

public struct GetHoldingDetail: Sendable {
    let portfolio: GetPortfolio
    let repository: PortfolioRepository
    let clock: any DayClock

    public func callAsFunction(_ id: Int64) throws -> HoldingDetail {
        guard let line = try portfolio().holdings.first(where: { $0.holding.id == id }) else { throw PortfolioError.notFound(id) }
        let holding = line.holding
        let contributions = try repository.contributions(of: id)
        let days = holding.investedOn.map { max(0, $0.days(until: clock.today())) }
        var yearly: Int?
        if let days, days >= 365, contributions.isEmpty, let invested = holding.invested, invested > .zero {
            let ratio = Double(holding.amount.paise) / Double(invested.paise)
            yearly = Int(((pow(ratio, 365 / Double(days)) - 1) * 1_000).rounded())
        }
        let instalment = Self.instalment(holding, contributions: contributions, today: clock.today())
        return HoldingDetail(
            line: line, daysHeld: days, yearlyGrowthTenths: yearly, contributions: contributions,
            boughtAmount: holding.invested.map { $0 - contributions.reduce(Money.zero) { $0 + $1.amount } },
            history: try repository.history(of: id), nextInstalment: instalment.next, instalmentDue: instalment.due
        )
    }
}

extension GetHoldingDetail {
    /// This month's instalment day (the last day of a shorter month); once something was added or bought this month, next month's.
    static func instalment(
        _ holding: Holding, contributions: [HoldingContribution], today: CalendarDate
    ) -> (next: CalendarDate?, due: Bool) {
        guard holding.kind == .sip, holding.sipAmount != nil, let sipDay = holding.sipDay else { return (nil, false) }
        let month = today.yearMonth
        let added = contributions.contains { $0.date.yearMonth == month } || holding.investedOn?.yearMonth == month
        let thisMonth = month.date(day: min(sipDay, month.dayCount))
        if added {
            let following = month.shifted(by: 1)
            return (following.date(day: min(sipDay, following.dayCount)), false)
        }
        guard let thisMonth else { return (nil, false) }
        return (thisMonth, today >= thisMonth)
    }
}

public struct UpdateHoldingWorth: Sendable {
    let portfolio: PortfolioRepository
    let clock: any DayClock

    /// The quick update: only what it is worth today changes, and the new value is remembered.
    public func callAsFunction(_ id: Int64, _ worth: Money?) throws {
        guard let worth, worth >= .zero else { throw PortfolioError.amountInvalid }
        guard let holding = try portfolio.holdings().first(where: { $0.id == id }) else { throw PortfolioError.notFound(id) }
        let checked = CheckedHolding(
            name: holding.name, amount: worth, kind: holding.kind, sipAmount: holding.sipAmount, sipDay: holding.sipDay
        )
        try portfolio.updateHolding(
            id, checked, currency: holding.currency, invested: holding.invested, investedOn: holding.investedOn, on: clock.today()
        )
    }
}

public struct GetHoldingHistory: Sendable {
    let portfolio: PortfolioRepository

    /// The values she has noted, oldest first, one per day.
    public func callAsFunction(_ id: Int64) throws -> [HoldingPoint] {
        try portfolio.history(of: id)
    }
}

/// What a holding form is saved as once it has been checked; a stock or "other" never keeps instalment details.
struct CheckedHolding {
    let name: String
    let amount: Money
    let kind: HoldingKind
    let sipAmount: Money?
    let sipDay: Int?
}

private func validatedHolding(_ new: NewHolding, portfolio: PortfolioRepository, setRate: SetExchangeRate) throws -> CheckedHolding {
    let name = new.name.trimmed
    guard !name.isEmpty else { throw PortfolioError.nameMissing }
    guard let amount = new.amount, amount >= .zero else { throw PortfolioError.amountInvalid }
    if let invested = new.invested, invested < .zero { throw PortfolioError.amountInvalid }
    if let boughtOn = new.investedOn, boughtOn > setRate.clock.today() { throw PortfolioError.dateInFuture }
    if let currency = new.currency {
        if let rate = new.rate {
            try setRate(currency, rate)
        } else if try !portfolio.rates().contains(where: { $0.currency == currency }) {
            throw PortfolioError.rateMissing
        }
    }
    var sipAmount: Money?
    var sipDay: Int?
    if new.kind == .sip {
        if let instalment = new.sipAmount {
            guard instalment > .zero else { throw PortfolioError.sipAmountInvalid }
            guard let sipDayChosen = new.sipDay, (1...31).contains(sipDayChosen) else { throw PortfolioError.sipDayMissing }
            (sipAmount, sipDay) = (instalment, sipDayChosen)
        }
    }
    return CheckedHolding(name: name, amount: amount, kind: new.kind, sipAmount: sipAmount, sipDay: sipDay)
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
