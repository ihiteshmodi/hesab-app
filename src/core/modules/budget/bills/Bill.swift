public enum BillRepeat: String, CaseIterable, Sendable {
    case never, daily, weekly, biweekly, every3Weeks, every4Weeks, monthly, lastDayOfMonth
    case bimonthly, every3Months, twiceAYear, yearly

    public var title: String {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .every3Weeks: "Every 3 Weeks"
        case .every4Weeks: "Every 4 Weeks"
        case .monthly: "Every Month"
        case .lastDayOfMonth: "Last Day of Every Month"
        case .bimonthly: "Bimonthly"
        case .every3Months: "Every 3 Months"
        case .twiceAYear: "Twice a Year"
        case .yearly: "Yearly"
        }
    }

    /// The due date after `due`; monthly repeats go back to `anchorDay` after a short month.
    func next(after due: CalendarDate, anchorDay: Int) -> CalendarDate? {
        switch self {
        case .never: nil
        case .daily: due.adding(days: 1)
        case .weekly: due.adding(days: 7)
        case .biweekly: due.adding(days: 14)
        case .every3Weeks: due.adding(days: 21)
        case .every4Weeks: due.adding(days: 28)
        case .monthly: due.addingMonths(1, preferredDay: anchorDay)
        case .lastDayOfMonth: due.addingMonths(1, preferredDay: 1).lastDayOfMonth
        case .bimonthly: due.addingMonths(2, preferredDay: anchorDay)
        case .every3Months: due.addingMonths(3, preferredDay: anchorDay)
        case .twiceAYear: due.addingMonths(6, preferredDay: anchorDay)
        case .yearly: due.addingMonths(12, preferredDay: anchorDay)
        }
    }
}

public enum BillAlert: String, CaseIterable, Sendable {
    case none, dayBefore, onDueDate

    public var title: String {
        switch self {
        case .none: "None"
        case .dayBefore: "Day before due date"
        case .onDueDate: "On due date"
        }
    }
}

public struct Bill: Equatable, Sendable {
    public let id: Int64
    public let name: String
    public let amount: Money
    public let category: String
    public let subCategory: String
    public let entity: String
    public let paymentMethod: PaymentMethod
    public let firstDue: CalendarDate
    public let repeats: BillRepeat
    public let endsOn: CalendarDate?
    public let addAutomatically: Bool
    public let alert: BillAlert
    public let notes: String
    /// The due date whose automatic add was undone; that one date waits for a manual add.
    public let autoSkipDue: CalendarDate?

    /// The next date this bill falls due, given the due date of its latest add; nil once it has ended.
    func nextDue(afterLatest latest: CalendarDate?) -> CalendarDate? {
        let candidate = latest.map { repeats.next(after: $0, anchorDay: firstDue.day) } ?? firstDue
        guard let candidate else { return nil }
        if let endsOn, candidate > endsOn { return nil }
        return candidate
    }
}

public struct NewBill: Sendable {
    public var name: String
    public var amount: Money?
    public var category: String
    public var subCategory: String
    public var entity: String
    public var paymentMethod: PaymentMethod
    public var dueDate: CalendarDate
    public var repeats: BillRepeat
    public var endsOn: CalendarDate?
    public var addAutomatically: Bool
    public var alert: BillAlert
    public var notes: String

    public init(
        name: String, amount: Money?, category: String, subCategory: String = "", entity: String = "",
        paymentMethod: PaymentMethod = .upi, dueDate: CalendarDate, repeats: BillRepeat = .monthly,
        endsOn: CalendarDate? = nil, addAutomatically: Bool = false, alert: BillAlert = .none, notes: String = ""
    ) {
        self.name = name
        self.amount = amount
        self.category = category
        self.subCategory = subCategory
        self.entity = entity
        self.paymentMethod = paymentMethod
        self.dueDate = dueDate
        self.repeats = repeats
        self.endsOn = endsOn
        self.addAutomatically = addAutomatically
        self.alert = alert
        self.notes = notes
    }
}

/// One due date of a bill that has been put into the budget.
struct BillOccurrence: Equatable, Sendable {
    let id: Int64
    let billID: Int64
    let dueDate: CalendarDate
    let expenseID: Int64
    let automatic: Bool
    let seen: Bool
}

public struct BillSummary: Equatable, Sendable {
    public let bill: Bill
    public let nextDue: CalendarDate?
    public let lastAddedMonth: CalendarDate.YearMonth?

    public var isEnded: Bool { nextDue == nil }
    public var addedLabel: String? { lastAddedMonth.map { "Added for \(Self.monthNames[$0.month - 1])" } }

    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
}

public struct UpcomingBill: Equatable, Sendable {
    public let bill: Bill
    public let dueDate: CalendarDate
    public let label: String
}

public struct Upcoming: Equatable, Sendable {
    public let items: [UpcomingBill]

    public init(items: [UpcomingBill]) {
        self.items = items
    }
}

public struct BillChoice: Equatable, Sendable {
    public let bill: Bill
    public let dueDate: CalendarDate
    public let alreadyAdded: Bool
}

public struct AutoAddedBill: Equatable, Sendable {
    public let occurrenceID: Int64
    public let billName: String
    public let amount: Money
    public let dueDate: CalendarDate
    public let seen: Bool
}

public struct BillsAttention: Equatable, Sendable {
    /// Bills whose alert has started and that are not added yet, plus automatic adds not seen yet.
    public let badge: Int
    public let autoAddedUnseen: Int
    /// Bills due today or earlier that are not added.
    public let menuCount: Int

    public init(badge: Int, autoAddedUnseen: Int, menuCount: Int) {
        self.badge = badge
        self.autoAddedUnseen = autoAddedUnseen
        self.menuCount = menuCount
    }
}

public enum BillError: Error, Equatable, Sendable {
    case nameMissing
    case amountMissingOrZero
    case categoryMissing
    case endBeforeDue
    case notFound(Int64)
    case ended
    case occurrenceNotFound(Int64)

    public var message: String {
        switch self {
        case .nameMissing: "Enter a name"
        case .amountMissingOrZero: "Enter an amount above 0"
        case .categoryMissing: "Choose a category"
        case .endBeforeDue: "The end date must be on or after the due date"
        case .notFound: "That bill no longer exists."
        case .ended: "This bill has ended."
        case .occurrenceNotFound: "That automatic add no longer exists."
        }
    }
}
