import GRDB

final class ExpenseRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(_ expense: Expense) throws -> Expense {
        try database.writer.write { db in
            var record = ExpenseRecord(expense)
            try record.insert(db)
            return try record.expense()
        }
    }

    func all() throws -> [Expense] {
        try database.writer.read { db in
            try ExpenseRecord.fetchAll(db).map { try $0.expense() }
        }
    }
}

private struct ExpenseRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "expense"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var date: String
    var description: String
    var amountPaise: Int
    var category: String

    init(_ expense: Expense) {
        id = expense.id
        date = expense.date.isoString
        description = expense.description
        amountPaise = expense.amount.paise
        category = expense.category
    }

    func expense() throws -> Expense {
        Expense(id: id, date: try CalendarDate(isoString: date), description: description,
                amount: Money(paise: amountPaise), category: category)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
