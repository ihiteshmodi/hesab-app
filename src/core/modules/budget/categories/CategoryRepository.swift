import GRDB

/// The category lists, and the expense text that refers to them by name.
final class CategoryRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func all() throws -> [CategoryNode] {
        try database.writer.read { db in
            let subs = try Row.fetchAll(db, sql: "SELECT id, category_id, name FROM sub_category ORDER BY id")
            return try Row.fetchAll(db, sql: "SELECT id, name, colour, icon FROM category ORDER BY id").map { row in
                let id: Int64 = row["id"]
                return CategoryNode(
                    id: id, name: row["name"], colour: row["colour"], icon: row["icon"],
                    subCategories: subs.filter { ($0["category_id"] as Int64) == id }
                        .map { SubCategoryNode(id: $0["id"], name: $0["name"]) }
                )
            }
        }
    }

    func parent(_ id: Int64) throws -> CategoryNode {
        guard let found = try all().first(where: { $0.id == id }) else { throw CategoryError.notFound(id) }
        return found
    }

    func addParent(_ new: NewCategory, name: String) throws -> CategoryNode {
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO category (name, colour, icon) VALUES (?, ?, ?)", arguments: [name, new.colour, new.icon]
            )
            return CategoryNode(id: db.lastInsertedRowID, name: name, colour: new.colour, icon: new.icon, subCategories: [])
        }
    }

    func addSub(parentID: Int64, name: String) throws -> SubCategoryNode {
        try database.writer.write { db in
            try db.execute(sql: "INSERT INTO sub_category (category_id, name) VALUES (?, ?)", arguments: [parentID, name])
            return SubCategoryNode(id: db.lastInsertedRowID, name: name)
        }
    }

    func renameParent(_ id: Int64, to name: String) throws {
        let old = try parent(id).name
        try database.writer.write { db in
            try db.execute(sql: "UPDATE category SET name = ? WHERE id = ?", arguments: [name, id])
            try db.execute(sql: "UPDATE expense SET category = ? WHERE category = ?", arguments: [name, old])
            try db.execute(sql: "UPDATE bill SET category = ? WHERE category = ?", arguments: [name, old])
        }
    }

    func renameSub(_ id: Int64, to name: String) throws {
        let (parentName, old) = try owner(of: id)
        try database.writer.write { db in
            try db.execute(sql: "UPDATE sub_category SET name = ? WHERE id = ?", arguments: [name, id])
            try db.execute(
                sql: "UPDATE expense SET sub_category = ? WHERE category = ? AND sub_category = ?",
                arguments: [name, parentName, old]
            )
            try db.execute(
                sql: "UPDATE bill SET sub_category = ? WHERE category = ? AND sub_category = ?",
                arguments: [name, parentName, old]
            )
        }
    }

    func merge(_ id: Int64, into targetID: Int64) throws {
        let (fromParent, fromName) = try owner(of: id)
        let (toParent, toName) = try owner(of: targetID)
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE expense SET category = ?, sub_category = ? WHERE category = ? AND sub_category = ?",
                arguments: [toParent, toName, fromParent, fromName]
            )
            try db.execute(
                sql: "UPDATE bill SET category = ?, sub_category = ? WHERE category = ? AND sub_category = ?",
                arguments: [toParent, toName, fromParent, fromName]
            )
            try db.execute(sql: "DELETE FROM sub_category WHERE id = ?", arguments: [id])
        }
    }

    func deleteParent(_ id: Int64) throws {
        _ = try parent(id)
        try database.writer.write { db in try db.execute(sql: "DELETE FROM category WHERE id = ?", arguments: [id]) }
    }

    func deleteSub(_ id: Int64) throws {
        _ = try owner(of: id)
        try database.writer.write { db in try db.execute(sql: "DELETE FROM sub_category WHERE id = ?", arguments: [id]) }
    }

    func expenseCount(parent name: String) throws -> Int {
        try count("SELECT COUNT(*) FROM expense WHERE category = ?", [name])
    }

    func expenseCount(parent: String, sub: String) throws -> Int {
        try count("SELECT COUNT(*) FROM expense WHERE category = ? AND sub_category = ?", [parent, sub])
    }

    /// Newest use first, each pair once.
    func recentChoices(limit: Int) throws -> [CategoryChoice] {
        try database.writer.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT category, sub_category FROM expense
                WHERE sub_category IS NOT NULL AND sub_category <> ''
                ORDER BY date DESC, id DESC
                """)
            var seen = Set<CategoryChoice>()
            var result: [CategoryChoice] = []
            for row in rows {
                let choice = CategoryChoice(category: row["category"], subCategory: row["sub_category"])
                if seen.insert(choice).inserted { result.append(choice) }
                if result.count == limit { break }
            }
            return result
        }
    }

    func latestChoice(forDescription text: String) throws -> CategoryChoice? {
        try choice("""
            SELECT category, COALESCE(sub_category, '') AS sub FROM expense
            WHERE lower(trim(description)) = lower(trim(?)) ORDER BY date DESC, id DESC LIMIT 1
            """, [text])
    }

    func commonChoice(forEntity name: String) throws -> CategoryChoice? {
        try choice("""
            SELECT category, COALESCE(sub_category, '') AS sub FROM expense WHERE entity = ? COLLATE NOCASE
            GROUP BY category, sub ORDER BY COUNT(*) DESC, MAX(date) DESC LIMIT 1
            """, [name.trimmed])
    }

    func search(_ text: String) throws -> [CategoryChoice] {
        let pattern = "%\(text.trimmed)%"
        return try database.writer.read { db in
            let parents = try Row.fetchAll(db, sql: "SELECT name FROM category WHERE name LIKE ? ORDER BY id", arguments: [pattern])
            let subs = try Row.fetchAll(db, sql: """
                SELECT category.name AS parent, sub_category.name AS sub FROM sub_category
                JOIN category ON category.id = sub_category.category_id
                WHERE sub_category.name LIKE ? ORDER BY sub_category.id
                """, arguments: [pattern])
            return parents.map { CategoryChoice(category: $0["name"], subCategory: "") }
                + subs.map { CategoryChoice(category: $0["parent"], subCategory: $0["sub"]) }
        }
    }

    func owner(of subID: Int64) throws -> (parent: String, name: String) {
        try database.writer.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT category.name AS parent, sub_category.name AS sub FROM sub_category
                JOIN category ON category.id = sub_category.category_id WHERE sub_category.id = ?
                """, arguments: [subID]) else { throw CategoryError.notFound(subID) }
            return (row["parent"], row["sub"])
        }
    }

    private func count(_ sql: String, _ arguments: [String]) throws -> Int {
        try database.writer.read { try Int.fetchOne($0, sql: sql, arguments: StatementArguments(arguments)) ?? 0 }
    }

    private func choice(_ sql: String, _ arguments: [String]) throws -> CategoryChoice? {
        try database.writer.read { db in
            try Row.fetchOne(db, sql: sql, arguments: StatementArguments(arguments))
                .map { CategoryChoice(category: $0["category"], subCategory: $0["sub"]) }
        }
    }
}
