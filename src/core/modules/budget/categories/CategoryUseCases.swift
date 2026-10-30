public struct GetCategories: Sendable {
    let categories: CategoryRepository

    public func callAsFunction() throws -> [CategoryNode] {
        try categories.all()
    }
}

public struct AddCategory: Sendable {
    let categories: CategoryRepository

    @discardableResult
    public func callAsFunction(_ new: NewCategory) throws -> CategoryNode {
        let name = new.name.trimmed
        guard !name.isEmpty else { throw CategoryError.nameMissing }
        guard !(try categories.all()).contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            throw CategoryError.nameTaken(name)
        }
        return try categories.addParent(new, name: name)
    }
}

public struct AddSubCategory: Sendable {
    let categories: CategoryRepository

    @discardableResult
    public func callAsFunction(_ parentID: Int64, _ name: String) throws -> SubCategoryNode {
        let name = name.trimmed
        guard !name.isEmpty else { throw CategoryError.nameMissing }
        let parent = try categories.parent(parentID)
        if let existing = parent.subCategories.first(where: { $0.name.lowercased() == name.lowercased() }) {
            throw CategoryError.subCategoryTaken(parent: parent.name, existing: existing.name)
        }
        return try categories.addSub(parentID: parentID, name: name)
    }
}

public struct RenameCategory: Sendable {
    let categories: CategoryRepository

    public func callAsFunction(_ id: Int64, _ newName: String) throws {
        let name = newName.trimmed
        guard !name.isEmpty else { throw CategoryError.nameMissing }
        let others = try categories.all().filter { $0.id != id }
        guard !others.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            throw CategoryError.nameTaken(name)
        }
        try categories.renameParent(id, to: name)
    }
}

public struct RenameSubCategory: Sendable {
    let categories: CategoryRepository

    public func callAsFunction(_ id: Int64, _ newName: String) throws {
        let name = newName.trimmed
        guard !name.isEmpty else { throw CategoryError.nameMissing }
        let (parentName, _) = try categories.owner(of: id)
        let siblings = try categories.all().first { $0.name == parentName }?.subCategories.filter { $0.id != id } ?? []
        if let existing = siblings.first(where: { $0.name.lowercased() == name.lowercased() }) {
            throw CategoryError.subCategoryTaken(parent: parentName, existing: existing.name)
        }
        try categories.renameSub(id, to: name)
    }
}

public struct MergeSubCategories: Sendable {
    let categories: CategoryRepository

    /// Everything that used `id` moves to `target`, and `id` is removed.
    public func callAsFunction(_ id: Int64, into target: Int64) throws {
        try categories.merge(id, into: target)
    }
}

public struct DeleteCategory: Sendable {
    let categories: CategoryRepository

    public func callAsFunction(_ id: Int64) throws {
        let parent = try categories.parent(id)
        let used = try categories.expenseCount(parent: parent.name)
        guard used == 0 else { throw CategoryError.inUse(name: parent.name, count: used, isParent: true) }
        try categories.deleteParent(id)
    }
}

public struct DeleteSubCategory: Sendable {
    let categories: CategoryRepository

    public func callAsFunction(_ id: Int64) throws {
        let (parentName, name) = try categories.owner(of: id)
        let used = try categories.expenseCount(parent: parentName, sub: name)
        guard used == 0 else { throw CategoryError.inUse(name: name, count: used, isParent: false) }
        try categories.deleteSub(id)
    }
}

public struct GetRecentCategories: Sendable {
    let categories: CategoryRepository

    public func callAsFunction(limit: Int = 3) throws -> [CategoryChoice] {
        try categories.recentChoices(limit: limit)
    }
}

public struct SuggestCategory: Sendable {
    let categories: CategoryRepository

    public func callAsFunction(forDescription text: String) throws -> CategoryChoice? {
        text.trimmed.isEmpty ? nil : try categories.latestChoice(forDescription: text)
    }

    public func callAsFunction(forEntity name: String) throws -> CategoryChoice? {
        name.trimmed.isEmpty ? nil : try categories.commonChoice(forEntity: name)
    }
}

public struct SearchCategories: Sendable {
    let categories: CategoryRepository

    public func callAsFunction(_ text: String) throws -> [CategoryChoice] {
        text.trimmed.isEmpty ? [] : try categories.search(text)
    }
}
