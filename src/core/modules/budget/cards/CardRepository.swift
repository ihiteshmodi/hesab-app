import GRDB

final class CardRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(name: String) throws -> Card {
        try database.writer.write { db in
            var record = CardRecord(id: nil, name: name)
            try record.insert(db)
            return record.card
        }
    }

    func card(_ id: Int64) throws -> Card {
        try database.writer.read { db in
            guard let record = try CardRecord.fetchOne(db, key: id) else { throw CardError.notFound(id) }
            return record.card
        }
    }

    func all() throws -> [Card] {
        try database.writer.read { db in
            try CardRecord.order(Column("name")).fetchAll(db).map(\.card)
        }
    }

    /// What was ticked as paid for the month, by card.
    func paid(in month: CalendarDate.YearMonth) throws -> [Int64: Money] {
        try database.writer.read { db in
            let rows = try BillPaymentRecord.filter(Column("month") == Self.key(month)).fetchAll(db)
            return Dictionary(uniqueKeysWithValues: rows.map { ($0.cardId, Money(paise: $0.paidPaise)) })
        }
    }

    func setPaid(_ amount: Money, cardID: Int64, month: CalendarDate.YearMonth) throws {
        try database.writer.write { db in
            try BillPaymentRecord(cardId: cardID, month: Self.key(month), paidPaise: amount.paise).save(db)
        }
    }

    func clearPaid(cardID: Int64, month: CalendarDate.YearMonth) throws {
        try database.writer.write { db in
            _ = try BillPaymentRecord.deleteOne(db, key: ["card_id": cardID, "month": Self.key(month)])
        }
    }

    private static func key(_ month: CalendarDate.YearMonth) -> String {
        let padded = month.month < 10 ? "0\(month.month)" : "\(month.month)"
        return "\(month.year)-\(padded)"
    }
}

private struct CardRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "card"

    var id: Int64?
    var name: String

    var card: Card { Card(id: id ?? 0, name: name) }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

private struct BillPaymentRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "card_bill_payment"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var cardId: Int64
    var month: String
    var paidPaise: Int
}
