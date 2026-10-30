import Foundation
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

    /// Loads the expense, lets `transform` rewrite it, and saves the result, all in one transaction.
    @discardableResult
    func change(_ id: Int64, _ transform: (Expense) throws -> Expense) throws -> Expense {
        try database.writer.write { db in
            guard let existing = try ExpenseRecord.fetchOne(db, key: id) else { throw ExpenseNotFound(id: id) }
            let record = ExpenseRecord(try transform(try existing.expense()))
            try record.update(db)
            return try record.expense()
        }
    }

    func delete(_ id: Int64) throws {
        try database.writer.write { db in
            guard try ExpenseRecord.deleteOne(db, key: id) else { throw ExpenseNotFound(id: id) }
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
    var subCategory: String?
    var entity: String?
    var spentFor: String?
    var tags: String
    var paymentName: String
    var paymentSource: String
    var notes: String
    var refundState: String
    var receivedPaise: Int
    var keptAsCash: Bool

    init(_ expense: Expense) {
        id = expense.id
        date = expense.date.isoString
        description = expense.description
        amountPaise = expense.amount.paise
        category = expense.category
        subCategory = expense.subCategory
        entity = expense.entity
        spentFor = expense.spentFor
        tags = String(decoding: (try? JSONEncoder().encode(expense.tags)) ?? Data("[]".utf8), as: UTF8.self)
        paymentName = expense.paymentMethod.name
        paymentSource = expense.paymentMethod.source.rawValue
        notes = expense.notes
        keptAsCash = expense.keptAsCash
        switch expense.refund {
        case .notRefundable: (refundState, receivedPaise) = ("none", 0)
        case .pending: (refundState, receivedPaise) = ("pending", 0)
        case .settled(let received): (refundState, receivedPaise) = ("settled", received.paise)
        }
    }

    func expense() throws -> Expense {
        let refund: RefundState = switch refundState {
        case "pending": .pending
        case "settled": .settled(received: Money(paise: receivedPaise))
        default: .notRefundable
        }
        return Expense(
            id: id, date: try CalendarDate(isoString: date), description: description,
            amount: Money(paise: amountPaise), category: category, subCategory: subCategory,
            entity: entity, spentFor: spentFor,
            tags: (try? JSONDecoder().decode([String].self, from: Data(tags.utf8))) ?? [],
            paymentMethod: PaymentMethod(
                name: paymentName, source: PaymentMethod.Source(rawValue: paymentSource) ?? .bank
            ),
            notes: notes, refund: refund, keptAsCash: keptAsCash
        )
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
