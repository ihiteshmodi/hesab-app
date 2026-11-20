import GRDB

final class IncomeRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(
        date: CalendarDate, kind: IncomeKind, amount: Money, note: String, viaCash: Bool = false, toSavings: Bool = false
    ) throws -> IncomeEntry {
        try database.writer.write { db in
            var record = IncomeRecord(
                id: nil, date: date.isoString, kind: kind.rawValue, amountPaise: amount.paise, note: note, viaCash: viaCash,
                toSavings: toSavings
            )
            try record.insert(db)
            return try record.entry()
        }
    }

    func update(
        _ id: Int64, date: CalendarDate, kind: IncomeKind, amount: Money, note: String, viaCash: Bool = false, toSavings: Bool = false
    ) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE income_entry SET date = ?, kind = ?, amount_paise = ?, note = ?, via_cash = ?, to_savings = ? WHERE id = ?",
                arguments: [date.isoString, kind.rawValue, amount.paise, note, viaCash, toSavings, id]
            )
            guard db.changesCount > 0 else { throw IncomeNotFound(id: id) }
        }
    }

    func delete(_ id: Int64) throws {
        try database.writer.write { db in
            guard try IncomeRecord.deleteOne(db, key: id) else { throw IncomeNotFound(id: id) }
        }
    }

    func all() throws -> [IncomeEntry] {
        try database.writer.read { db in
            try IncomeRecord.fetchAll(db).map { try $0.entry() }
        }
    }
}

private struct IncomeRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "income_entry"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var date: String
    var kind: String
    var amountPaise: Int
    var note: String
    var viaCash: Bool
    var toSavings: Bool

    func entry() throws -> IncomeEntry {
        IncomeEntry(
            id: id ?? 0, date: try CalendarDate(isoString: date),
            kind: IncomeKind(rawValue: kind) ?? .moneyReceived, amount: Money(paise: amountPaise), note: note,
            viaCash: viaCash, toSavings: toSavings
        )
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
