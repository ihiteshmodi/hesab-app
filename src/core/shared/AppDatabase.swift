import Foundation
import GRDB

/// The single SQLite file that holds everything. Schema changes are added as new migrations, never edited.
public final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    private init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(writer: try DatabaseQueue())
    }

    public static func file(at url: URL) throws -> AppDatabase {
        try AppDatabase(writer: try DatabaseQueue(path: url.path))
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1-expenses") { db in
            try db.create(table: "expense") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("date", .text).notNull()
                table.column("description", .text).notNull()
                table.column("amount_paise", .integer).notNull()
                table.column("category", .text).notNull()
            }
        }

        migrator.registerMigration("v2-expense-details") { db in
            try db.alter(table: "expense") { table in
                table.add(column: "sub_category", .text)
                table.add(column: "entity", .text)
                table.add(column: "spent_for", .text)
                table.add(column: "tags", .text).notNull().defaults(to: "[]")
                table.add(column: "payment_name", .text).notNull().defaults(to: "UPI")
                table.add(column: "payment_source", .text).notNull().defaults(to: "bank")
                table.add(column: "notes", .text).notNull().defaults(to: "")
            }
        }

        migrator.registerMigration("v3-income") { db in
            try db.create(table: "income_entry") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("date", .text).notNull()
                table.column("kind", .text).notNull()
                table.column("amount_paise", .integer).notNull()
                table.column("note", .text).notNull().defaults(to: "")
            }
        }

        migrator.registerMigration("v4-refunds") { db in
            try db.alter(table: "expense") { table in
                table.add(column: "refund_state", .text).notNull().defaults(to: "none")
                table.add(column: "received_paise", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v5-ledgers-and-cash") { db in
            try db.alter(table: "expense") { table in
                table.add(column: "kept_as_cash", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "ledger") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull()
                table.column("counts_towards_net_worth", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "ledger_entry") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("ledger_id", .integer).notNull().references("ledger", onDelete: .cascade)
                table.column("date", .text).notNull()
                table.column("description", .text).notNull()
                table.column("amount_paise", .integer).notNull()
            }
            try db.create(table: "cash_adjustment") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("date", .text).notNull()
                table.column("amount_paise", .integer).notNull()
                table.column("note", .text).notNull()
            }
        }

        migrator.registerMigration("v6-cards") { db in
            try db.create(table: "card") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull()
            }
            try db.create(table: "card_bill_payment") { table in
                table.column("card_id", .integer).notNull().references("card", onDelete: .cascade)
                table.column("month", .text).notNull()
                table.column("paid_paise", .integer).notNull()
                table.primaryKey(["card_id", "month"])
            }
            try db.execute(sql: "INSERT INTO card (name) VALUES ('Credit Card')")
        }

        migrator.registerMigration("v7-repayments") { db in
            try db.create(table: "repayment") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("income_id", .integer).notNull().references("income_entry", onDelete: .cascade)
                table.column("date", .text).notNull()
                table.column("amount_paise", .integer).notNull()
            }
        }

        migrator.registerMigration("v8-settings") { db in
            try db.create(table: "setting") { table in
                table.primaryKey("key", .text)
                table.column("value", .text).notNull()
            }
        }

        migrator.registerMigration("v9-categories") { db in
            try db.create(table: "category") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull().unique().collate(.nocase)
                table.column("colour", .text).notNull().defaults(to: "blue")
                table.column("icon", .text).notNull().defaults(to: "tag")
            }
            try db.create(table: "sub_category") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("category_id", .integer).notNull().references("category", onDelete: .cascade)
                table.column("name", .text).notNull().collate(.nocase)
                table.uniqueKey(["category_id", "name"])
            }
            let palette = ["blue", "orange", "green", "red", "purple", "teal", "pink", "yellow"]
            for (index, group) in DefaultCategories.tree.enumerated() {
                try db.execute(
                    sql: "INSERT INTO category (name, colour, icon) VALUES (?, ?, 'tag')",
                    arguments: [group.name, palette[index % palette.count]]
                )
                let parentID = db.lastInsertedRowID
                for name in group.subCategories {
                    try db.execute(sql: "INSERT INTO sub_category (category_id, name) VALUES (?, ?)", arguments: [parentID, name])
                }
            }
        }

        migrator.registerMigration("v10-entities") { db in
            try db.create(table: "entity") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull().unique().collate(.nocase)
            }
            try db.execute(sql: """
                INSERT INTO entity (name)
                SELECT trim(entity) FROM expense
                WHERE id IN (
                    SELECT MIN(id) FROM expense WHERE entity IS NOT NULL AND trim(entity) <> '' GROUP BY lower(trim(entity))
                )
                """)
            try db.execute(sql: """
                UPDATE expense SET entity = (SELECT name FROM entity WHERE name = trim(expense.entity) COLLATE NOCASE)
                WHERE entity IS NOT NULL AND trim(entity) <> ''
                """)
        }

        migrator.registerMigration("v11-planned-items") { db in
            try db.create(table: "planned_item") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("description", .text).notNull()
                table.column("amount_paise", .integer).notNull()
            }
        }

        migrator.registerMigration("v12-bills") { db in
            try db.create(table: "bill") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull()
                table.column("amount_paise", .integer).notNull()
                table.column("category", .text).notNull()
                table.column("sub_category", .text).notNull().defaults(to: "")
                table.column("entity", .text).notNull().defaults(to: "")
                table.column("payment_name", .text).notNull()
                table.column("payment_source", .text).notNull()
                table.column("first_due", .text).notNull()
                table.column("repeats", .text).notNull()
                table.column("ends_on", .text)
                table.column("automatic", .boolean).notNull().defaults(to: false)
                table.column("alert", .text).notNull().defaults(to: "none")
                table.column("notes", .text).notNull().defaults(to: "")
                table.column("auto_skip_due", .text)
            }
            try db.create(table: "bill_occurrence") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("bill_id", .integer).notNull().references("bill", onDelete: .cascade)
                table.column("due_date", .text).notNull()
                table.column("expense_id", .integer).notNull().references("expense", onDelete: .cascade)
                table.column("automatic", .boolean).notNull().defaults(to: false)
                table.column("seen", .boolean).notNull().defaults(to: false)
                table.uniqueKey(["bill_id", "due_date"])
            }
        }

        migrator.registerMigration("v13-currencies") { db in
            try db.alter(table: "expense") { table in
                table.add(column: "foreign_currency", .text)
                table.add(column: "foreign_paise", .integer)
                table.add(column: "rate", .text)
            }
            try db.create(table: "currency") { table in
                table.primaryKey("code", .text)
                table.column("name", .text).notNull()
                table.column("symbol", .text)
                table.column("decimals", .integer).notNull()
            }
            let seeded: [(String, String, String?, Int)] = [
                ("INR", "Indian Rupee", "₹", 2), ("USD", "US Dollar", "$", 2), ("EUR", "Euro", "€", 2),
                ("GBP", "British Pound", "£", 2), ("AED", "UAE Dirham", nil, 2), ("SGD", "Singapore Dollar", "S$", 2),
                ("THB", "Thai Baht", "฿", 2), ("JPY", "Japanese Yen", "¥", 0), ("IDR", "Indonesian Rupiah", nil, 0),
            ]
            for (code, name, symbol, decimals) in seeded {
                try db.execute(
                    sql: "INSERT INTO currency (code, name, symbol, decimals) VALUES (?, ?, ?, ?)",
                    arguments: [code, name, symbol, decimals]
                )
            }
        }

        migrator.registerMigration("v14-portfolio-and-schemes") { db in
            try db.create(table: "holding") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull()
                table.column("amount_paise", .integer).notNull()
                table.column("currency", .text)
            }
            try db.create(table: "allocated_fund") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull()
                table.column("amount_paise", .integer).notNull()
            }
            try db.create(table: "exchange_rate") { table in
                table.primaryKey("currency", .text)
                table.column("rate", .text).notNull()
                table.column("set_on", .text).notNull()
            }
            try db.create(table: "payout_scheme") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull()
                table.column("invested_paise", .integer).notNull()
                table.column("payout_paise", .integer).notNull()
                table.column("payout_day", .integer).notNull()
                table.column("maturity", .text)
                table.column("closed", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "payout_record") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("scheme_id", .integer).notNull().references("payout_scheme", onDelete: .cascade)
                table.column("month", .text).notNull()
                table.column("income_id", .integer).notNull().references("income_entry", onDelete: .cascade)
                table.uniqueKey(["scheme_id", "month"])
            }
        }

        migrator.registerMigration("v15-trips") { db in
            try db.create(table: "trip") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("name", .text).notNull()
                table.column("currency", .text)
                table.column("rate", .text)
                table.column("ledger_name", .text).notNull()
                table.column("settled", .boolean).notNull().defaults(to: false)
                table.column("category", .text).notNull()
                table.column("sub_category", .text).notNull().defaults(to: "")
                table.column("payment_name", .text).notNull()
                table.column("payment_source", .text).notNull()
                table.column("end_date", .text)
                table.column("expense_id", .integer).references("expense", onDelete: .setNull)
            }
            try db.create(table: "trip_person") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("trip_id", .integer).notNull().references("trip", onDelete: .cascade)
                table.column("name", .text).notNull().collate(.nocase)
                table.uniqueKey(["trip_id", "name"])
            }
            try db.create(table: "trip_group") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("trip_id", .integer).notNull().references("trip", onDelete: .cascade)
                table.column("name", .text).notNull().collate(.nocase)
                table.uniqueKey(["trip_id", "name"])
            }
            try db.create(table: "trip_group_member") { table in
                table.column("group_id", .integer).notNull().references("trip_group", onDelete: .cascade)
                table.column("participant_id", .integer).notNull()
                table.primaryKey(["group_id", "participant_id"])
            }
            try db.create(table: "trip_tag") { table in
                table.primaryKey("name", .text).collate(.nocase)
            }
            try db.create(table: "trip_expense") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("trip_id", .integer).notNull().references("trip", onDelete: .cascade)
                table.column("description", .text).notNull()
                table.column("date", .text).notNull()
                table.column("amount_paise", .integer).notNull()
                table.column("paid_by", .integer).notNull()
                table.column("paid_in_home_paise", .integer)
                table.column("paid_with", .text).notNull().defaults(to: "bank")
                table.column("tag", .text).notNull().defaults(to: "")
                table.column("note", .text).notNull().defaults(to: "")
            }
            try db.create(table: "trip_receipt") { table in
                table.primaryKey("expense_id", .integer).references("trip_expense", onDelete: .cascade)
                table.column("image", .blob).notNull()
            }
            try db.create(table: "trip_share") { table in
                table.column("trip_expense_id", .integer).notNull().references("trip_expense", onDelete: .cascade)
                table.column("participant_id", .integer).notNull()
                table.column("amount_paise", .integer).notNull()
                table.primaryKey(["trip_expense_id", "participant_id"])
            }
            try db.create(table: "trip_settlement") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("trip_id", .integer).notNull().references("trip", onDelete: .cascade)
                table.column("person_id", .integer).notNull()
                table.column("date", .text).notNull()
                table.column("amount_paise", .integer).notNull()
                table.column("direction", .text).notNull()
                table.column("method", .text).notNull().defaults(to: "bank")
                table.column("cleared_paise", .integer).notNull()
                table.column("written_off_paise", .integer).notNull().defaults(to: 0)
            }
            try db.create(table: "trip_cash_adjustment") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("trip_id", .integer).notNull().references("trip", onDelete: .cascade)
                table.column("date", .text).notNull()
                table.column("amount_paise", .integer).notNull()
                table.column("note", .text).notNull()
            }
        }

        return migrator
    }
}
