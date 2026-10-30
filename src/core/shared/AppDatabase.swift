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

        return migrator
    }
}
