import Foundation

/// Someone in one trip's split. People never carry over from trip to trip.
public struct Person: Hashable, Sendable {
    public let id: Int64
    public let tripID: Int64
    public let name: String
}

/// Someone in a split: the owner, or one of the trip's people.
public enum Participant: Hashable, Sendable {
    case me
    case person(Int64)

    /// Stored as 0 for the owner.
    var storedID: Int64 {
        switch self {
        case .me: 0
        case .person(let id): id
        }
    }

    init(stored: Int64) {
        self = stored == 0 ? .me : .person(stored)
    }

    /// The owner first, then people in the order they were added.
    var order: Int64 { storedID }
}

public struct SplitItem: Equatable, Sendable {
    public var name: String
    public var amount: Money
    public var people: Set<Participant>

    public init(name: String, amount: Money, people: Set<Participant>) {
        self.name = name
        self.amount = amount
        self.people = people
    }
}

public enum SplitMethod: Equatable, Sendable {
    case equal(Set<Participant>)
    case shares([Participant: Int])
    case exact([Participant: Money])
    case percentage([Participant: Int])
    /// Each item is shared by its own people; `extra` (tax, service) follows what each person ordered.
    case items([SplitItem], extra: Money)
}

public enum SettlementDirection: String, Sendable {
    case theyPaidMe = "they_paid_me"
    case iPaidThem = "i_paid_them"
}

/// How money changed hands. Only `bank` moves the main ledger.
public enum SettlementMethod: String, Sendable {
    /// Rupees through the bank or UPI.
    case bank
    /// Rupee notes: moves the main Cash in Hand.
    case cashHome = "cash_home"
    /// Cash in the trip's currency: moves the trip's cash.
    case cashTrip = "cash_trip"
}

public enum ExpensePayment: String, Sendable {
    case bank, cash
}

public struct TripGroup: Equatable, Sendable {
    public let id: Int64
    public let tripID: Int64
    public let name: String
    public let members: Set<Participant>
}

public struct Trip: Equatable, Sendable {
    public let id: Int64
    public let name: String
    /// Nil means the home currency.
    public let currency: String?
    /// Home currency per one unit of `currency`.
    public let rate: Decimal?
    /// What the single main-ledger entry is called.
    public let ledgerName: String
    public let category: String
    public let subCategory: String
    public let paymentMethod: PaymentMethod
    public let endDate: CalendarDate?
    public let isSettled: Bool
}

public struct NewTrip: Sendable {
    public var name: String
    public var currency: String?
    public var rate: Decimal?
    /// Blank means "<name> expenses".
    public var ledgerName: String
    public var category: String
    public var subCategory: String
    public var paymentMethod: PaymentMethod
    public var endDate: CalendarDate?

    public init(
        name: String, currency: String? = nil, rate: Decimal? = nil, ledgerName: String = "", category: String,
        subCategory: String = "", paymentMethod: PaymentMethod = .upi, endDate: CalendarDate? = nil
    ) {
        self.name = name
        self.currency = currency
        self.rate = rate
        self.ledgerName = ledgerName
        self.category = category
        self.subCategory = subCategory
        self.paymentMethod = paymentMethod
        self.endDate = endDate
    }
}

public struct NewTripExpense: Sendable {
    public var description: String
    public var date: CalendarDate?
    public var amount: Money?
    public var paidBy: Participant
    /// Only meaningful when I paid; what someone else paid is never mine to track as cash.
    public var paidWith: ExpensePayment
    public var split: SplitMethod
    /// What the card actually charged in the home currency for the whole expense; otherwise the trip rate is used.
    public var paidInHome: Money?
    public var tag: String
    public var note: String
    public var receipt: Data?

    public init(
        description: String, date: CalendarDate? = nil, amount: Money?, paidBy: Participant = .me,
        paidWith: ExpensePayment = .bank, split: SplitMethod, paidInHome: Money? = nil, tag: String = "",
        note: String = "", receipt: Data? = nil
    ) {
        self.description = description
        self.date = date
        self.amount = amount
        self.paidBy = paidBy
        self.paidWith = paidWith
        self.split = split
        self.paidInHome = paidInHome
        self.tag = tag
        self.note = note
        self.receipt = receipt
    }
}

public struct TripExpense: Equatable, Sendable {
    public let id: Int64
    public let tripID: Int64
    public let description: String
    public let date: CalendarDate
    public let amount: Money
    public let paidBy: Participant
    public let paidWith: ExpensePayment
    public let shares: [Participant: Money]
    public let paidInHome: Money?
    public let tag: String
    public let note: String
    public let hasReceipt: Bool
}

public struct TripSettlement: Equatable, Sendable {
    public let id: Int64
    public let tripID: Int64
    public let personID: Int64
    public let date: CalendarDate
    public let direction: SettlementDirection
    public let method: SettlementMethod
    /// What changed hands: rupees for `bank` and `cashHome`, the trip currency for `cashTrip`.
    public let received: Money
    /// How much of the balance it cleared, in the trip currency.
    public let cleared: Money
    /// In the trip currency. Positive: forgiven, a cost to me. Negative: paid extra, a gain to me.
    public let writtenOff: Money
}

public struct PersonBalance: Equatable, Sendable {
    public let person: Person
    /// Positive: they owe me. Negative: I owe them. In the trip currency.
    public let owesMe: Money
    /// The same at the trip rate, in the home currency.
    public let owesMeHome: Money
}

public struct TripCashLine: Equatable, Sendable {
    public enum Kind: Sendable { case adjustment, receivedFromFriend, paidToFriend, expense }

    public let kind: Kind
    public let date: CalendarDate
    public let description: String
    public let amount: Money
    public let runningBalance: Money
}

/// Cash held in the trip's currency.
public struct TripCash: Equatable, Sendable {
    public let balance: Money
    public let warning: String?
    /// Oldest first, each with the balance after it.
    public let lines: [TripCashLine]
}

public struct TagSpend: Equatable, Sendable {
    public let tag: String
    public let amount: Money
}

public struct ParticipantTotal: Equatable, Sendable {
    public let participant: Participant
    public let paid: Money
    public let share: Money
}

public struct TripSummary: Equatable, Sendable {
    public let trip: Trip
    public let members: [Person]
    public let groups: [TripGroup]
    /// Newest first.
    public let expenses: [TripExpense]
    public let settlements: [TripSettlement]
    public let balances: [PersonBalance]
    public let totalSpent: Money
    /// What the trip cost me in the trip currency.
    public let myShare: Money
    public let totalSpentHome: Money
    /// My share in the home currency, using each expense's own charge where it was given.
    public let myShareHome: Money
    /// What the main-ledger entry holds: only bank and card money, out minus in.
    public let ledgerAmount: Money
    /// Everything I paid out minus everything paid back, bank and cash, in the home currency.
    public let netCost: Money
    public let receivedBankHome: Money
    public let receivedCashHome: Money
    public let receivedCashTrip: Money
    /// Forgiven in full settlements, in the home currency.
    public let writtenOffHome: Money
    /// Paid extra in full settlements, in the home currency.
    public let extraReceivedHome: Money
    public let cash: TripCash
    public let spendByTag: [TagSpend]
    public let totals: [ParticipantTotal]
}

public struct StatementLine: Equatable, Sendable {
    public enum Kind: Sendable { case iPaid, theyPaid, payment }

    public let kind: Kind
    public let date: CalendarDate
    public let title: String
    /// In the trip currency. Positive: it adds to what they owe me.
    public let amount: Money
    public let expenseID: Int64?
    public let settlementID: Int64?
}

public struct PersonStatement: Equatable, Sendable {
    public let person: Person
    public let owesMe: Money
    public let owesMeHome: Money
    /// Oldest first.
    public let lines: [StatementLine]
}

public struct TripTag: Equatable, Sendable {
    public let name: String
    public let isDefault: Bool
}

public enum TripTags {
    public static let defaults = ["Food", "Stay", "Transport", "Activities", "Shopping", "Drinks", "Tickets", "Other"]
}

public enum TripError: Error, Equatable, Sendable {
    case nameMissing
    case categoryMissing
    case rateMissing
    case rateNotPositive
    case personNameMissing
    case personNameTaken(String)
    case personInUse(String)
    case groupNameMissing
    case groupNameTaken(String)
    case descriptionMissing
    case amountMissingOrZero
    case nobodySharing
    case notAMember(String)
    case sharesMismatch(Money)
    case percentagesMismatch
    case sharesInvalid
    case itemsMismatch(Money)
    case notFound(Int64)
    case nothingToSettle(String)
    case noTripCash
    case tagMissing
    case tagIsDefault(String)

    public var message: String {
        switch self {
        case .nothingToSettle(let name): "There is nothing to settle with \(name)."
        case .nameMissing: "Enter a trip name"
        case .categoryMissing: "Choose a category"
        case .rateMissing: "Enter the exchange rate"
        case .rateNotPositive: "Enter an exchange rate above 0"
        case .personNameMissing: "Enter a name"
        case .personNameTaken(let name): "A person called \(name) is already in this trip"
        case .personInUse(let name): "\(name) has expenses or payments in this trip."
        case .groupNameMissing: "Enter a group name"
        case .groupNameTaken(let name): "A group called \(name) already exists in this trip"
        case .descriptionMissing: "Enter a description"
        case .amountMissingOrZero: "Enter an amount above 0"
        case .nobodySharing: "Choose who shared it"
        case .notAMember(let name): "\(name) isn't in this trip"
        case .sharesMismatch(let amount): "The shares must add up to \(IndianMoneyFormat.plain(amount))"
        case .percentagesMismatch: "Percentages must add up to 100"
        case .sharesInvalid: "Give each person at least 1 share"
        case .itemsMismatch(let amount): "The items and extra must add up to \(IndianMoneyFormat.plain(amount))"
        case .notFound: "That trip no longer exists."
        case .noTripCash: "This trip is in your home currency, so it uses your main Cash in Hand."
        case .tagMissing: "Enter a tag"
        case .tagIsDefault(let name): "\(name) is a default tag and stays"
        }
    }
}
