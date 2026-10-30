import GRDB

final class LedgerRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(_ new: NewLedger, name: String) throws -> Ledger {
        try database.writer.write { db in
            var record = LedgerRecord(id: nil, name: name, countsTowardsNetWorth: new.countsTowardsNetWorth)
            try record.insert(db)
            return record.ledger
        }
    }

    func delete(_ id: Int64) throws {
        try database.writer.write { db in
            guard try LedgerRecord.deleteOne(db, key: id) else { throw LedgerError.notFound(id) }
        }
    }

    func setCountsTowardsNetWorth(_ id: Int64, _ counts: Bool) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE ledger SET counts_towards_net_worth = ? WHERE id = ?", arguments: [counts, id])
            guard db.changesCount > 0 else { throw LedgerError.notFound(id) }
        }
    }

    func ledger(_ id: Int64) throws -> Ledger {
        try database.writer.read { db in
            guard let record = try LedgerRecord.fetchOne(db, key: id) else { throw LedgerError.notFound(id) }
            return record.ledger
        }
    }

    func allLedgers() throws -> [Ledger] {
        try database.writer.read { db in
            try LedgerRecord.order(Column("name")).fetchAll(db).map(\.ledger)
        }
    }

    func addEntry(ledgerID: Int64, date: CalendarDate, description: String, amount: Money) throws -> LedgerEntry {
        try database.writer.write { db in
            guard try LedgerRecord.exists(db, key: ledgerID) else { throw LedgerError.notFound(ledgerID) }
            var record = LedgerEntryRecord(
                id: nil, ledgerId: ledgerID, date: date.isoString, description: description, amountPaise: amount.paise
            )
            try record.insert(db)
            return try record.entry()
        }
    }

    func deleteEntry(_ id: Int64) throws {
        try database.writer.write { db in
            guard try LedgerEntryRecord.deleteOne(db, key: id) else { throw LedgerError.notFound(id) }
        }
    }

    func allEntries() throws -> [LedgerEntry] {
        try database.writer.read { db in
            try LedgerEntryRecord.fetchAll(db).map { try $0.entry() }
        }
    }
}

private struct LedgerRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "ledger"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var name: String
    var countsTowardsNetWorth: Bool

    var ledger: Ledger { Ledger(id: id ?? 0, name: name, countsTowardsNetWorth: countsTowardsNetWorth) }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

private struct LedgerEntryRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "ledger_entry"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var ledgerId: Int64
    var date: String
    var description: String
    var amountPaise: Int

    func entry() throws -> LedgerEntry {
        LedgerEntry(
            id: id ?? 0, ledgerID: ledgerId, date: try CalendarDate(isoString: date),
            description: description, amount: Money(paise: amountPaise)
        )
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
