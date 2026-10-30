public struct SubCategoryNode: Equatable, Sendable {
    public let id: Int64
    public let name: String
}

public struct CategoryNode: Equatable, Sendable {
    public let id: Int64
    public let name: String
    public let colour: String
    public let icon: String
    public let subCategories: [SubCategoryNode]

    public init(id: Int64, name: String, colour: String, icon: String, subCategories: [SubCategoryNode]) {
        self.id = id
        self.name = name
        self.colour = colour
        self.icon = icon
        self.subCategories = subCategories
    }
}

public struct NewCategory: Sendable {
    public var name: String
    public var colour: String
    public var icon: String

    public init(name: String, colour: String = "blue", icon: String = "tag") {
        self.name = name
        self.colour = colour
        self.icon = icon
    }
}

/// A parent with an optional sub-category; `subCategory` is empty when only the parent was chosen.
public struct CategoryChoice: Hashable, Sendable {
    public let category: String
    public let subCategory: String
}

public enum CategoryError: Error, Equatable, Sendable {
    case nameMissing
    case nameTaken(String)
    case subCategoryTaken(parent: String, existing: String)
    case notFound(Int64)
    case inUse(name: String, count: Int, isParent: Bool)

    public var message: String {
        switch self {
        case .nameMissing: "Enter a name"
        case .nameTaken(let name): "A category called \(name) already exists"
        case .subCategoryTaken(let parent, let existing): "\(parent) already has an \(existing)"
        case .notFound: "That category no longer exists."
        case .inUse(let name, let count, let isParent):
            "\(count) expense\(count == 1 ? " uses" : "s use") \(name). Move them to another \(isParent ? "category" : "sub-category") first."
        }
    }
}
