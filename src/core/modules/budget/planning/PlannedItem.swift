import GRDB

/// Something expected to be paid, with no date yet; it never touches "left to spend" until it becomes an expense.
public struct PlannedItem: Equatable, Sendable {
    public let id: Int64
    public let description: String
    public let amount: Money
}

public struct NewPlannedItem: Sendable {
    public var description: String
    public var amount: Money?

    public init(description: String, amount: Money?) {
        self.description = description
        self.amount = amount
    }
}

public struct PlannedList: Equatable, Sendable {
    public let items: [PlannedItem]
    public var total: Money { items.reduce(.zero) { $0 + $1.amount } }

    public init(items: [PlannedItem]) {
        self.items = items
    }
}

public enum PlannedItemError: Error, Equatable, Sendable {
    case descriptionMissing
    case amountMissingOrZero
    case notFound(Int64)

    public var message: String {
        switch self {
        case .descriptionMissing: "Enter a description"
        case .amountMissingOrZero: "Enter an amount above 0"
        case .notFound: "That planned item no longer exists."
        }
    }
}

final class PlannedRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func add(description: String, amount: Money) throws -> PlannedItem {
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO planned_item (description, amount_paise) VALUES (?, ?)", arguments: [description, amount.paise]
            )
            return PlannedItem(id: db.lastInsertedRowID, description: description, amount: amount)
        }
    }

    func item(_ id: Int64) throws -> PlannedItem {
        guard let found = try all().first(where: { $0.id == id }) else { throw PlannedItemError.notFound(id) }
        return found
    }

    func all() throws -> [PlannedItem] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT id, description, amount_paise FROM planned_item ORDER BY id").map {
                PlannedItem(id: $0["id"], description: $0["description"], amount: Money(paise: $0["amount_paise"]))
            }
        }
    }

    func update(_ id: Int64, description: String, amount: Money) throws {
        _ = try item(id)
        try database.writer.write { db in
            try db.execute(sql: "UPDATE planned_item SET description = ?, amount_paise = ? WHERE id = ?", arguments: [description, amount.paise, id])
        }
    }

    func delete(_ id: Int64) throws {
        _ = try item(id)
        try database.writer.write { db in try db.execute(sql: "DELETE FROM planned_item WHERE id = ?", arguments: [id]) }
    }
}

public struct AddPlannedItem: Sendable {
    let planned: PlannedRepository

    @discardableResult
    public func callAsFunction(_ new: NewPlannedItem) throws -> PlannedItem {
        let description = new.description.trimmed
        guard !description.isEmpty else { throw PlannedItemError.descriptionMissing }
        guard let amount = new.amount, amount > .zero else { throw PlannedItemError.amountMissingOrZero }
        return try planned.add(description: description, amount: amount)
    }
}

public struct UpdatePlannedItem: Sendable {
    let planned: PlannedRepository

    public func callAsFunction(_ id: Int64, _ new: NewPlannedItem) throws {
        let description = new.description.trimmed
        guard !description.isEmpty else { throw PlannedItemError.descriptionMissing }
        guard let amount = new.amount, amount > .zero else { throw PlannedItemError.amountMissingOrZero }
        try planned.update(id, description: description, amount: amount)
    }
}

public struct GetPlannedItems: Sendable {
    let planned: PlannedRepository

    public func callAsFunction() throws -> PlannedList {
        PlannedList(items: try planned.all())
    }
}

public struct DeletePlannedItem: Sendable {
    let planned: PlannedRepository

    public func callAsFunction(_ id: Int64) throws {
        try planned.delete(id)
    }
}

public struct AddPlannedAsExpense: Sendable {
    let planned: PlannedRepository
    let addExpense: AddExpense

    /// Saves the expense as the person adjusted it; only then does the item leave the plan.
    @discardableResult
    public func callAsFunction(_ id: Int64, _ expense: NewExpense) throws -> Expense {
        _ = try planned.item(id)
        let saved = try addExpense(expense)
        try planned.delete(id)
        return saved
    }
}
