import GRDB

final class EntityRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    /// The saved spelling of `name`, saving it first when it is new; nil for a blank name.
    static func canonical(_ db: Database, _ name: String?) throws -> String? {
        guard let trimmed = name?.trimmed, !trimmed.isEmpty else { return nil }
        if let saved = try String.fetchOne(db, sql: "SELECT name FROM entity WHERE name = ?", arguments: [trimmed]) {
            return saved
        }
        try db.execute(sql: "INSERT INTO entity (name) VALUES (?)", arguments: [trimmed])
        return trimmed
    }

    func all() throws -> [EntitySummary] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: """
                SELECT entity.id, entity.name, COUNT(expense.id) AS uses FROM entity
                LEFT JOIN expense ON expense.entity = entity.name COLLATE NOCASE
                GROUP BY entity.id ORDER BY entity.name COLLATE NOCASE
                """).map { EntitySummary(id: $0["id"], name: $0["name"], expenseCount: $0["uses"]) }
        }
    }

    func summary(_ id: Int64) throws -> EntitySummary {
        guard let found = try all().first(where: { $0.id == id }) else { throw EntityError.notFound(id) }
        return found
    }

    func add(_ name: String) throws -> Entity {
        try database.writer.write { db in
            try db.execute(sql: "INSERT INTO entity (name) VALUES (?)", arguments: [name])
            return Entity(id: db.lastInsertedRowID, name: name)
        }
    }

    func rename(_ id: Int64, to name: String) throws {
        let old = try summary(id).name
        try database.writer.write { db in
            try db.execute(sql: "UPDATE entity SET name = ? WHERE id = ?", arguments: [name, id])
            try db.execute(sql: "UPDATE expense SET entity = ? WHERE entity = ? COLLATE NOCASE", arguments: [name, old])
            try db.execute(sql: "UPDATE bill SET entity = ? WHERE entity = ? COLLATE NOCASE", arguments: [name, old])
        }
    }

    func merge(_ id: Int64, into targetID: Int64) throws {
        let from = try summary(id).name
        let target = try summary(targetID).name
        try database.writer.write { db in
            try db.execute(sql: "UPDATE expense SET entity = ? WHERE entity = ? COLLATE NOCASE", arguments: [target, from])
            try db.execute(sql: "UPDATE bill SET entity = ? WHERE entity = ? COLLATE NOCASE", arguments: [target, from])
            try db.execute(sql: "DELETE FROM entity WHERE id = ?", arguments: [id])
        }
    }

    func delete(_ id: Int64) throws {
        _ = try summary(id)
        try database.writer.write { db in try db.execute(sql: "DELETE FROM entity WHERE id = ?", arguments: [id]) }
    }

    func lastUse(of name: String) throws -> EntityLastUse? {
        try database.writer.read { db in
            try Row.fetchOne(db, sql: """
                SELECT category, COALESCE(sub_category, '') AS sub, payment_name, payment_source FROM expense
                WHERE entity = ? COLLATE NOCASE ORDER BY date DESC, id DESC LIMIT 1
                """, arguments: [name.trimmed]).map {
                EntityLastUse(
                    category: CategoryChoice(category: $0["category"], subCategory: $0["sub"]),
                    paymentMethod: PaymentMethod(
                        name: $0["payment_name"], source: PaymentMethod.Source(rawValue: $0["payment_source"]) ?? .bank
                    )
                )
            }
        }
    }
}
