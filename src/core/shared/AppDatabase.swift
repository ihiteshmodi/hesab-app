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

    private static var migrator: DatabaseMigrator {
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

        return migrator
    }
}
