import GRDB

final class BorrowingRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(borrowingID: Int64, date: CalendarDate, amount: Money) throws -> Repayment {
        try database.writer.write { db in
            var record = RepaymentRecord(id: nil, incomeId: borrowingID, date: date.isoString, amountPaise: amount.paise)
            try record.insert(db)
            return try record.repayment()
        }
    }

    func delete(_ id: Int64) throws {
        try database.writer.write { db in
            guard try RepaymentRecord.deleteOne(db, key: id) else { throw BorrowingError.repaymentNotFound(id) }
        }
    }

    func all() throws -> [Repayment] {
        try database.writer.read { db in
            try RepaymentRecord.fetchAll(db).map { try $0.repayment() }
        }
    }
}

private struct RepaymentRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "repayment"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var incomeId: Int64
    var date: String
    var amountPaise: Int

    func repayment() throws -> Repayment {
        Repayment(
            id: id ?? 0, borrowingID: incomeId, date: try CalendarDate(isoString: date), amount: Money(paise: amountPaise)
        )
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
