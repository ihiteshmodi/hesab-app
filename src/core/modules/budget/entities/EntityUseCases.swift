public struct GetEntities: Sendable {
    let entities: EntityRepository

    public func callAsFunction() throws -> [EntitySummary] {
        try entities.all()
    }
}

public struct SuggestEntities: Sendable {
    let entities: EntityRepository

    /// Saved entities containing what was typed, ignoring case.
    public func callAsFunction(_ typed: String) throws -> [String] {
        let text = typed.trimmed.lowercased()
        guard !text.isEmpty else { return [] }
        return try entities.all().map(\.name).filter { $0.lowercased().contains(text) }
    }
}

public struct AddEntity: Sendable {
    let entities: EntityRepository

    @discardableResult
    public func callAsFunction(_ name: String) throws -> Entity {
        let name = name.trimmed
        guard !name.isEmpty else { throw EntityError.nameMissing }
        if let existing = try entities.all().first(where: { $0.name.lowercased() == name.lowercased() }) {
            throw EntityError.nameTaken(existing.name)
        }
        return try entities.add(name)
    }
}

public struct RenameEntity: Sendable {
    let entities: EntityRepository

    public func callAsFunction(_ id: Int64, to newName: String) throws {
        let name = newName.trimmed
        guard !name.isEmpty else { throw EntityError.nameMissing }
        if let existing = try entities.all().first(where: { $0.id != id && $0.name.lowercased() == name.lowercased() }) {
            throw EntityError.nameTaken(existing.name)
        }
        try entities.rename(id, to: name)
    }
}

public struct MergeEntities: Sendable {
    let entities: EntityRepository

    /// Everything that used `id` moves to `target`, and `id` is removed.
    public func callAsFunction(_ id: Int64, into target: Int64) throws {
        try entities.merge(id, into: target)
    }
}

public struct DeleteEntity: Sendable {
    let entities: EntityRepository

    public func callAsFunction(_ id: Int64) throws {
        let entity = try entities.summary(id)
        guard entity.expenseCount == 0 else { throw EntityError.inUse(name: entity.name, count: entity.expenseCount) }
        try entities.delete(id)
    }
}

public struct GetEntityLastUse: Sendable {
    let entities: EntityRepository

    public func callAsFunction(forName name: String) throws -> EntityLastUse? {
        try entities.lastUse(of: name)
    }
}

public struct GetEntityHistory: Sendable {
    let entities: EntityRepository
    let expenses: ExpenseRepository

    public func callAsFunction(_ id: Int64) throws -> EntityHistory {
        let name = try entities.summary(id).name.lowercased()
        let mine = try expenses.all().filter { $0.entity?.lowercased() == name }
        let months = Dictionary(grouping: mine, by: { $0.date.yearMonth }).map { month, expenses in
            EntityMonth(
                month: month, total: expenses.reduce(.zero) { $0 + $1.netAmount },
                expenses: expenses.sorted { ($0.date, $0.id ?? 0) > ($1.date, $1.id ?? 0) }
            )
        }
        return EntityHistory(
            total: months.reduce(.zero) { $0 + $1.total }, months: months.sorted { $0.month > $1.month }
        )
    }
}
