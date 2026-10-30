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

    func all() throws -> [CashAdjustment] {
        try database.writer.read { db in
            try CashAdjustmentRecord.fetchAll(db).map {
                CashAdjustment(
                    id: $0.id ?? 0, date: try CalendarDate(isoString: $0.date),
                    amount: Money(paise: $0.amountPaise), note: $0.note
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
