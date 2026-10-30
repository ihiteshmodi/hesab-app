import GRDB

final class BillRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(_ new: NewBill, amount: Money) throws -> Bill {
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO bill (name, amount_paise, category, sub_category, entity, payment_name, payment_source,
                                  first_due, repeats, ends_on, automatic, alert, notes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: Self.arguments(new, amount))
            return try Self.bill(db, db.lastInsertedRowID)
        }
    }

    func update(_ id: Int64, _ new: NewBill, amount: Money) throws -> Bill {
        try database.writer.write { db in
            _ = try Self.bill(db, id)
            try db.execute(sql: """
                UPDATE bill SET name = ?, amount_paise = ?, category = ?, sub_category = ?, entity = ?, payment_name = ?,
                    payment_source = ?, first_due = ?, repeats = ?, ends_on = ?, automatic = ?, alert = ?, notes = ?
                WHERE id = ?
                """, arguments: Self.arguments(new, amount) + [id])
            return try Self.bill(db, id)
        }
    }

    func delete(_ id: Int64) throws {
        try database.writer.write { db in
            _ = try Self.bill(db, id)
            try db.execute(sql: "DELETE FROM bill WHERE id = ?", arguments: [id])
        }
    }

    func bill(_ id: Int64) throws -> Bill {
        try database.writer.read { try Self.bill($0, id) }
    }

    func all() throws -> [Bill] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM bill ORDER BY id").map(Self.bill)
        }
    }

    func occurrences() throws -> [BillOccurrence] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM bill_occurrence ORDER BY id").map { row in
                BillOccurrence(
                    id: row["id"], billID: row["bill_id"], dueDate: try CalendarDate(isoString: row["due_date"]),
                    expenseID: row["expense_id"], automatic: row["automatic"], seen: row["seen"]
                )
            }
        }
    }

    func record(billID: Int64, dueDate: CalendarDate, expenseID: Int64, automatic: Bool) throws {
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO bill_occurrence (bill_id, due_date, expense_id, automatic, seen) VALUES (?, ?, ?, ?, 0)
                """, arguments: [billID, dueDate.isoString, expenseID, automatic])
        }
    }

    func setAutoSkip(billID: Int64, _ date: CalendarDate?) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE bill SET auto_skip_due = ? WHERE id = ?", arguments: [date?.isoString, billID])
        }
    }

    func markAutomaticSeen() throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE bill_occurrence SET seen = 1 WHERE automatic = 1")
        }
    }

    private static func arguments(_ new: NewBill, _ amount: Money) -> StatementArguments {
        [
            new.name.trimmed, amount.paise, new.category, new.subCategory.trimmed, new.entity.trimmed,
            new.paymentMethod.name, new.paymentMethod.source.rawValue, new.dueDate.isoString, new.repeats.rawValue,
            new.endsOn?.isoString, new.repeats != .never && new.addAutomatically, new.alert.rawValue, new.notes.trimmed,
        ]
    }

    private static func bill(_ db: Database, _ id: Int64) throws -> Bill {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM bill WHERE id = ?", arguments: [id]) else {
            throw BillError.notFound(id)
        }
        return try bill(row)
    }

    private static func bill(_ row: Row) throws -> Bill {
        Bill(
            id: row["id"], name: row["name"], amount: Money(paise: row["amount_paise"]), category: row["category"],
            subCategory: row["sub_category"], entity: row["entity"],
            paymentMethod: PaymentMethod(
                name: row["payment_name"], source: PaymentMethod.Source(rawValue: row["payment_source"]) ?? .bank
            ),
            firstDue: try CalendarDate(isoString: row["first_due"]),
            repeats: BillRepeat(rawValue: row["repeats"]) ?? .never,
            endsOn: try (row["ends_on"] as String?).map { try CalendarDate(isoString: $0) },
            addAutomatically: row["automatic"], alert: BillAlert(rawValue: row["alert"]) ?? .none, notes: row["notes"],
            autoSkipDue: try (row["auto_skip_due"] as String?).map { try CalendarDate(isoString: $0) }
        )
    }
}
