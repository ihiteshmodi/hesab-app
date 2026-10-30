import GRDB

final class SettingsRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func all() throws -> [String: String] {
        try database.writer.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT key, value FROM setting")
            return Dictionary(uniqueKeysWithValues: rows.map { (String($0["key"] as String), String($0["value"] as String)) })
        }
    }

    func save(_ values: [String: String]) throws {
        try database.writer.write { db in
            for (key, value) in values {
                try db.execute(
                    sql: "INSERT INTO setting (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                    arguments: [key, value]
                )
            }
        }
    }
}
