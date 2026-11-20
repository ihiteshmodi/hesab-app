import GRDB

public struct NetWorthPoint: Equatable, Sendable {
    public let date: CalendarDate
    public let amount: Money

    public init(date: CalendarDate, amount: Money) {
        self.date = date
        self.amount = amount
    }
}

public struct NetWorthHistory: Equatable, Sendable {
    /// Oldest first, one per day at most.
    public let points: [NetWorthPoint]

    /// How far net worth has moved from the first point to the last; nil until there are two points.
    public var change: Money? {
        guard let first = points.first, let last = points.last, points.count > 1 else { return nil }
        return last.amount - first.amount
    }
}

final class NetWorthRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func all() throws -> [NetWorthPoint] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT date, amount_paise FROM net_worth_snapshot ORDER BY date").map {
                NetWorthPoint(date: try CalendarDate(isoString: $0["date"]), amount: Money(paise: $0["amount_paise"]))
            }
        }
    }

    func save(_ point: NetWorthPoint) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO net_worth_snapshot (date, amount_paise) VALUES (?, ?)",
                arguments: [point.date.isoString, point.amount.paise]
            )
        }
    }
}

public struct RecordNetWorth: Sendable {
    let portfolio: GetPortfolio
    let snapshots: NetWorthRepository
    let clock: any DayClock

    /// Saves today's net worth when it differs from the last snapshot, or when the month has none yet.
    public func callAsFunction() throws {
        let today = clock.today()
        let amount = try portfolio().netWorth
        if let latest = try snapshots.all().last, latest.amount == amount, latest.date.yearMonth == today.yearMonth { return }
        try snapshots.save(NetWorthPoint(date: today, amount: amount))
    }
}

public struct GetNetWorthHistory: Sendable {
    let snapshots: NetWorthRepository

    public func callAsFunction() throws -> NetWorthHistory {
        NetWorthHistory(points: try snapshots.all())
    }
}
