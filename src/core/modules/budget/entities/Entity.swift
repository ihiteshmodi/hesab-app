public struct Entity: Equatable, Sendable {
    public let id: Int64
    public let name: String
}

public struct EntitySummary: Equatable, Sendable {
    public let id: Int64
    public let name: String
    public let expenseCount: Int
}

public struct EntityMonth: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    public let total: Money
    public let expenses: [Expense]
}

public struct EntityHistory: Equatable, Sendable {
    public let total: Money
    /// Newest month first.
    public let months: [EntityMonth]
}

public struct EntityLastUse: Equatable, Sendable {
    public let category: CategoryChoice
    public let paymentMethod: PaymentMethod
}

public enum EntityError: Error, Equatable, Sendable {
    case nameMissing
    case nameTaken(String)
    case notFound(Int64)
    case inUse(name: String, count: Int)

    public var message: String {
        switch self {
        case .nameMissing: "Enter a name"
        case .nameTaken(let name): "An entity called \(name) already exists"
        case .notFound: "That entity no longer exists."
        case .inUse(let name, let count):
            "\(count) expense\(count == 1 ? " uses" : "s use") \(name). Merge it into another entity first."
        }
    }
}
