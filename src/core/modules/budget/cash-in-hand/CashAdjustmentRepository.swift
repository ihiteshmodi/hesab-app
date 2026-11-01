import GRDB

final class CashAdjustmentRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(date: CalendarDate, amount: Money, note: String) throws {
        try database.writer.write { db in
            var record = CashAdjustmentRecord(id: nil, date: date.isoString, amountPaise: amount.paise, note: note)
            try record.insert(db)
        }
    }

    func update(_ id: Int64, date: CalendarDate, amount: Money, note: String) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE cash_adjustment SET date = ?, amount_paise = ?, note = ? WHERE id = ?",
                arguments: [date.isoString, amount.paise, note, id]
            )
            guard db.changesCount > 0 else { throw CashError.notFound(id) }
        }
    }

    func delete(_ id: Int64) throws {
        try database.writer.write { db in
            try db.execute(sql: "DELETE FROM cash_adjustment WHERE id = ?", arguments: [id])
            guard db.changesCount > 0 else { throw CashError.notFound(id) }
        }
    }

    func all() throws -> [CashAdjustment] {
        try database.writer.read { db in
            try CashAdjustmentRecord.fetchAll(db).map {
                CashAdjustment(
                    id: $0.id ?? 0, date: try CalendarDate(isoString: $0.date),
                    amount: Money(paise: $0.amountPaise), note: $0.note, editable: true
                )
            }
        }
    }
}

private struct CashAdjustmentRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "cash_adjustment"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var date: String
    var amountPaise: Int
    var note: String

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
