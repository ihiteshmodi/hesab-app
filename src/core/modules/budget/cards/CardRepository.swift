import GRDB

final class CardRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(name: String, dueDay: Int? = nil) throws -> Card {
        try database.writer.write { db in
            var record = CardRecord(id: nil, name: name, dueDay: dueDay)
            try record.insert(db)
            return record.card
        }
    }

    func update(_ id: Int64, name: String, dueDay: Int?) throws -> Card {
        try database.writer.write { db in
            guard var record = try CardRecord.fetchOne(db, key: id) else { throw CardError.notFound(id) }
            let oldName = record.name
            record.name = name
            record.dueDay = dueDay
            try record.update(db)
            if oldName != name {
                for table in ["expense", "bill", "trip"] {
                    try db.execute(
                        sql: "UPDATE \(table) SET payment_name = ? WHERE payment_source = 'bank' AND payment_name = ?",
                        arguments: [name, oldName]
                    )
                }
            }
            return record.card
        }
    }

    func delete(_ id: Int64) throws {
        try database.writer.write { db in
            guard try CardRecord.deleteOne(db, key: id) else { throw CardError.notFound(id) }
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

    func allPayments() throws -> [CardPayment] {
        try database.writer.read { db in
            try BillPaymentRecord.fetchAll(db).compactMap { row in
                guard let ym = Self.parseMonth(row.month) else { return nil }
                return CardPayment(
                    cardID: row.cardId, month: ym, paid: Money(paise: row.paidPaise),
                    paidUpTo: try row.paidUpTo.map { try CalendarDate(isoString: $0) }
                )
            }
        }
    }

    func setPaid(_ amount: Money, cardID: Int64, month: CalendarDate.YearMonth, paidUpTo: CalendarDate? = nil) throws {
        try database.writer.write { db in
            try BillPaymentRecord(
                cardId: cardID, month: Self.key(month), paidPaise: amount.paise, paidUpTo: paidUpTo?.isoString
            ).save(db)
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

    private static func parseMonth(_ text: String) -> CalendarDate.YearMonth? {
        let parts = text.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]), (1...12).contains(m) else { return nil }
        return CalendarDate.YearMonth(year: y, month: m)
    }
}

private struct CardRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "card"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase

    var id: Int64?
    var name: String
    var dueDay: Int?

    var card: Card { Card(id: id ?? 0, name: name, dueDay: dueDay) }

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
    var paidUpTo: String?
}
