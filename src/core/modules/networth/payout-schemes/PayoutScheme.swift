import GRDB

public struct PayoutScheme: Equatable, Sendable {
    public let id: Int64
    public let name: String
    public let invested: Money
    public let monthlyPayout: Money
    public let payoutDay: Int
    public let maturity: CalendarDate?
    public let isClosed: Bool
}

public struct NewPayoutScheme: Sendable {
    public var name: String
    public var invested: Money?
    public var monthlyPayout: Money?
    public var payoutDay: Int
    public var maturity: CalendarDate?

    public init(name: String, invested: Money?, monthlyPayout: Money?, payoutDay: Int, maturity: CalendarDate?) {
        self.name = name
        self.invested = invested
        self.monthlyPayout = monthlyPayout
        self.payoutDay = payoutDay
        self.maturity = maturity
    }
}

public struct SchemeLine: Equatable, Sendable {
    public let scheme: PayoutScheme
}

public struct PayoutOverview: Equatable, Sendable {
    public let schemes: [SchemeLine]
    /// Schemes that are not closed.
    public let investedTotal: Money
    public let monthlyPayoutTotal: Money

    public init(schemes: [SchemeLine], investedTotal: Money, monthlyPayoutTotal: Money) {
        self.schemes = schemes
        self.investedTotal = investedTotal
        self.monthlyPayoutTotal = monthlyPayoutTotal
    }
}

public struct UpcomingIncomeItem: Equatable, Sendable {
    public enum Kind: Sendable { case payout, maturity, matured }

    public let kind: Kind
    public let scheme: PayoutScheme
    public let date: CalendarDate
    public let label: String
}

/// What the confirmation for recording a payout starts with; the person can change both.
public struct PayoutDraft: Equatable, Sendable {
    public let date: CalendarDate
    public let amount: Money
    public let expectedDate: CalendarDate
    public let note: String
}

public struct SchemeClosed: Equatable, Sendable {
    public let reminder: String
}

public enum PayoutSchemeError: Error, Equatable, Sendable {
    case nameMissing
    case amountMissingOrZero
    case payoutInvalid
    case payoutDayInvalid
    case notFound(Int64)
    case closed

    public var message: String {
        switch self {
        case .nameMissing: "Enter a name"
        case .amountMissingOrZero: "Enter an amount above 0"
        case .payoutInvalid: "Enter a payout of 0 or more"
        case .payoutDayInvalid: "Enter a payout day between 1 and 31"
        case .notFound: "That scheme no longer exists."
        case .closed: "This scheme is closed."
        }
    }
}

final class PayoutSchemeRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(_ new: NewPayoutScheme, name: String, invested: Money, payout: Money) throws -> PayoutScheme {
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO payout_scheme (name, invested_paise, payout_paise, payout_day, maturity, closed)
                VALUES (?, ?, ?, ?, ?, 0)
                """, arguments: [name, invested.paise, payout.paise, new.payoutDay, new.maturity?.isoString])
            return PayoutScheme(
                id: db.lastInsertedRowID, name: name, invested: invested, monthlyPayout: payout,
                payoutDay: new.payoutDay, maturity: new.maturity, isClosed: false
            )
        }
    }

    func all() throws -> [PayoutScheme] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM payout_scheme ORDER BY id").map { row in
                PayoutScheme(
                    id: row["id"], name: row["name"], invested: Money(paise: row["invested_paise"]),
                    monthlyPayout: Money(paise: row["payout_paise"]), payoutDay: row["payout_day"],
                    maturity: try (row["maturity"] as String?).map { try CalendarDate(isoString: $0) },
                    isClosed: row["closed"]
                )
            }
        }
    }

    func scheme(_ id: Int64) throws -> PayoutScheme {
        guard let found = try all().first(where: { $0.id == id }) else { throw PayoutSchemeError.notFound(id) }
        return found
    }

    func close(_ id: Int64) throws {
        _ = try scheme(id)
        try database.writer.write { db in try db.execute(sql: "UPDATE payout_scheme SET closed = 1 WHERE id = ?", arguments: [id]) }
    }

    /// Months ("2026-11") whose payout was recorded, by scheme.
    func recordedMonths() throws -> [Int64: Set<String>] {
        try database.writer.read { db in
            var result: [Int64: Set<String>] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT scheme_id, month FROM payout_record") {
                result[row["scheme_id"], default: []].insert(row["month"])
            }
            return result
        }
    }

    func record(schemeID: Int64, month: String, incomeID: Int64) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO payout_record (scheme_id, month, income_id) VALUES (?, ?, ?)",
                arguments: [schemeID, month, incomeID]
            )
        }
    }
}

/// When each open scheme pays and matures, as seen from today.
struct SchemeBook {
    let schemes: [PayoutScheme]
    let recorded: [Int64: Set<String>]
    let today: CalendarDate
    let preferences: Preferences

    static func monthKey(_ month: CalendarDate.YearMonth) -> String {
        "\(month.year)-\(month.month < 10 ? "0" : "")\(month.month)"
    }

    /// The next payout not yet recorded; one is still expected for a week after its day, then the next one is.
    func expectedPayout(_ scheme: PayoutScheme) -> CalendarDate? {
        guard !scheme.isClosed, scheme.monthlyPayout > .zero else { return nil }
        var month = today.yearMonth
        if recorded[scheme.id]?.contains(Self.monthKey(month)) == true { month = month.shifted(by: 1) }
        let thisMonth = payoutDate(scheme, in: month)
        if thisMonth < today.adding(days: -Self.overdueDays) { return payoutDate(scheme, in: month.shifted(by: 1)) }
        return thisMonth
    }

    static let overdueDays = 7

    /// Day 1 of the month moved to the payout day, or to the last day of a shorter month.
    func payoutDate(_ scheme: PayoutScheme, in month: CalendarDate.YearMonth) -> CalendarDate {
        // The first of a real month always exists.
        try! CalendarDate(year: month.year, month: month.month, day: 1).addingMonths(0, preferredDay: scheme.payoutDay)
    }

    func upcoming() -> [UpcomingIncomeItem] {
        var items: [UpcomingIncomeItem] = []
        for scheme in schemes where !scheme.isClosed {
            if let expected = expectedPayout(scheme), today.days(until: expected) <= preferences.payoutAlertDays {
                items.append(UpcomingIncomeItem(
                    kind: .payout, scheme: scheme, date: expected,
                    label: "\(scheme.name) payout expected \(expected.shortTitle), about \(IndianMoneyFormat.plain(scheme.monthlyPayout))"
                ))
            }
            if let maturity = scheme.maturity {
                let delta = today.days(until: maturity)
                if delta < 0 {
                    items.append(UpcomingIncomeItem(
                        kind: .matured, scheme: scheme, date: maturity,
                        label: "\(scheme.name) matured \(-delta) day\(delta == -1 ? "" : "s") ago"
                    ))
                } else if delta <= 90 {
                    items.append(UpcomingIncomeItem(
                        kind: .maturity, scheme: scheme, date: maturity,
                        label: delta == 0 ? "\(scheme.name) matures today"
                            : "\(scheme.name) matures in \(delta) day\(delta == 1 ? "" : "s")"
                    ))
                }
            }
        }
        return items.sorted { ($0.date, $0.scheme.name) < ($1.date, $1.scheme.name) }
    }
}

struct SchemeStore: Sendable {
    let schemes: PayoutSchemeRepository
    let settings: SettingsRepository
    let clock: any DayClock

    func book() throws -> SchemeBook {
        SchemeBook(
            schemes: try schemes.all(), recorded: try schemes.recordedMonths(), today: clock.today(),
            preferences: Preferences(stored: try settings.all())
        )
    }
}

public struct AddScheme: Sendable {
    let schemes: PayoutSchemeRepository

    @discardableResult
    public func callAsFunction(_ new: NewPayoutScheme) throws -> PayoutScheme {
        let name = new.name.trimmed
        guard !name.isEmpty else { throw PayoutSchemeError.nameMissing }
        guard let invested = new.invested, invested > .zero else { throw PayoutSchemeError.amountMissingOrZero }
        guard let payout = new.monthlyPayout, payout >= .zero else { throw PayoutSchemeError.payoutInvalid }
        guard (1...31).contains(new.payoutDay) else { throw PayoutSchemeError.payoutDayInvalid }
        return try schemes.add(new, name: name, invested: invested, payout: payout)
    }
}

public struct GetPayoutSchemes: Sendable {
    let schemes: PayoutSchemeRepository

    public func callAsFunction() throws -> PayoutOverview {
        let all = try schemes.all()
        let open = all.filter { !$0.isClosed }
        return PayoutOverview(
            schemes: all.map(SchemeLine.init), investedTotal: open.reduce(.zero) { $0 + $1.invested },
            monthlyPayoutTotal: open.reduce(.zero) { $0 + $1.monthlyPayout }
        )
    }
}

public struct GetUpcomingIncome: Sendable {
    let store: SchemeStore

    public func callAsFunction() throws -> [UpcomingIncomeItem] {
        try store.book().upcoming()
    }
}

public struct GetPayoutDraft: Sendable {
    let store: SchemeStore

    public func callAsFunction(_ id: Int64) throws -> PayoutDraft {
        let book = try store.book()
        guard let scheme = book.schemes.first(where: { $0.id == id }) else { throw PayoutSchemeError.notFound(id) }
        guard let expected = book.expectedPayout(scheme) else { throw PayoutSchemeError.closed }
        let late = expected.days(until: book.today)
        let note = late == 0 ? "on the expected date"
            : late > 0 ? "\(late) day\(late == 1 ? "" : "s") later than expected"
            : "\(-late) day\(late == -1 ? "" : "s") earlier than expected"
        return PayoutDraft(date: book.today, amount: scheme.monthlyPayout, expectedDate: expected, note: note)
    }
}

public struct RecordPayout: Sendable {
    let store: SchemeStore
    let income: IncomeRepository

    /// Creates the "Investment Income" entry and marks that month's payout as recorded.
    @discardableResult
    public func callAsFunction(_ id: Int64, amount: Money?, on date: CalendarDate) throws -> IncomeEntry {
        guard let amount, amount > .zero else { throw PayoutSchemeError.amountMissingOrZero }
        let book = try store.book()
        guard let scheme = book.schemes.first(where: { $0.id == id }) else { throw PayoutSchemeError.notFound(id) }
        guard let expected = book.expectedPayout(scheme) else { throw PayoutSchemeError.closed }
        let entry = try income.add(date: date, kind: .investmentIncome, amount: amount, note: scheme.name)
        try store.schemes.record(schemeID: id, month: SchemeBook.monthKey(expected.yearMonth), incomeID: entry.id)
        return entry
    }
}

public struct CloseScheme: Sendable {
    let schemes: PayoutSchemeRepository

    @discardableResult
    public func callAsFunction(_ id: Int64) throws -> SchemeClosed {
        try schemes.close(id)
        return SchemeClosed(reminder: "Update your bank balance")
    }
}
