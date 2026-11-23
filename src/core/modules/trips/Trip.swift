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
    public let startDate: CalendarDate?
    public let isSettled: Bool
    /// A trip still being worked out: its plan is a price list, and nothing in it has been paid yet.
    public let isPlanning: Bool
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
    public var startDate: CalendarDate?
    /// Only read when the trip is created; `startTrip` is what ends planning.
    public var isPlanning: Bool

    public init(
        name: String, currency: String? = nil, rate: Decimal? = nil, ledgerName: String = "", category: String,
        subCategory: String = "", paymentMethod: PaymentMethod = .upi, endDate: CalendarDate? = nil, startDate: CalendarDate? = nil,
        isPlanning: Bool = false
    ) {
        self.name = name
        self.currency = currency
        self.rate = rate
        self.ledgerName = ledgerName
        self.category = category
        self.subCategory = subCategory
        self.paymentMethod = paymentMethod
        self.endDate = endDate
        self.startDate = startDate
        self.isPlanning = isPlanning
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
    /// From the main category list; blank for none. A new sub-category typed here joins that list.
    public var category: String
    public var subCategory: String
    public var note: String
    public var receipt: Data?

    public init(
        description: String, date: CalendarDate? = nil, amount: Money?, paidBy: Participant = .me,
        paidWith: ExpensePayment = .bank, split: SplitMethod, paidInHome: Money? = nil, tag: String = "",
        category: String = "", subCategory: String = "", note: String = "", receipt: Data? = nil
    ) {
        self.description = description
        self.date = date
        self.amount = amount
        self.paidBy = paidBy
        self.paidWith = paidWith
        self.split = split
        self.paidInHome = paidInHome
        self.tag = tag
        self.category = category
        self.subCategory = subCategory
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
    public let category: String
    public let subCategory: String
    public let note: String
    public let hasReceipt: Bool
}

/// One part of a plan item that is paid in instalments, such as an advance or a balance.
public struct TripPlanPayment: Equatable, Sendable {
    public let id: Int64
    public let itemID: Int64
    /// "Advance", "Balance" ...; may be blank.
    public let label: String
    public let amount: Money
    public let dueDate: CalendarDate?
    /// The trip expense made when the part was ticked as paid.
    public let paidExpenseID: Int64?

    public var isPaid: Bool { paidExpenseID != nil }
}

public struct NewTripPlanPayment: Sendable {
    public var label: String
    public var amount: Money?
    public var dueDate: CalendarDate?

    public init(label: String = "", amount: Money?, dueDate: CalendarDate? = nil) {
        self.label = label
        self.amount = amount
        self.dueDate = dueDate
    }
}

public enum TravelMode: String, CaseIterable, Sendable {
    case flight, train, bus, other

    public var title: String {
        switch self {
        case .flight: "Flight"
        case .train: "Train"
        case .bus: "Bus"
        case .other: "Other"
        }
    }
}

/// One leg of the journey: where, when, and on what. A plan item (such as "Flights") can hold several.
public struct TripLeg: Equatable, Sendable {
    public let id: Int64
    public let itemID: Int64
    /// The plan item it belongs to.
    public let itemName: String
    public let mode: TravelMode
    public let from: String
    public let to: String
    /// The airline, railway or bus company.
    public let carrier: String
    /// The flight, train or bus number.
    public let number: String
    public let departure: CalendarDate?
    /// Minutes after midnight, so 6:40 is 400.
    public let departureMinutes: Int?
    public let arrivalDate: CalendarDate?
    public let arrivalMinutes: Int?
    /// False while it is only planned.
    public let isBooked: Bool
}

public struct NewTripLeg: Sendable {
    public var mode: TravelMode
    public var from: String
    public var to: String
    public var carrier: String
    public var number: String
    public var departure: CalendarDate?
    public var departureMinutes: Int?
    public var arrivalDate: CalendarDate?
    public var arrivalMinutes: Int?
    public var isBooked: Bool

    public init(
        mode: TravelMode = .flight, from: String = "", to: String = "", carrier: String = "", number: String = "",
        departure: CalendarDate? = nil, departureMinutes: Int? = nil, arrivalDate: CalendarDate? = nil,
        arrivalMinutes: Int? = nil, isBooked: Bool = false
    ) {
        self.mode = mode
        self.from = from
        self.to = to
        self.carrier = carrier
        self.number = number
        self.departure = departure
        self.departureMinutes = departureMinutes
        self.arrivalDate = arrivalDate
        self.arrivalMinutes = arrivalMinutes
        self.isBooked = isBooked
    }
}

/// One thing in a trip's plan, with what it is expected to cost in the trip currency.
public struct TripPlanItem: Equatable, Sendable {
    public let id: Int64
    public let tripID: Int64
    public let description: String
    /// What was typed; once the item has parts, the parts' total is what counts (see `amount`).
    let enteredAmount: Money
    public let tag: String
    public let category: String
    public let subCategory: String
    public let note: String
    /// When a single payment is due; parts have their own dates.
    public let dueDate: CalendarDate?
    /// The trip expense made when a single-payment item was ticked as paid.
    public let paidExpenseID: Int64?
    /// Earliest due date first, parts without a date last.
    public let payments: [TripPlanPayment]
    public let legs: [TripLeg]

    public var amount: Money { payments.isEmpty ? enteredAmount : payments.reduce(.zero) { $0 + $1.amount } }

    public var isPaid: Bool { payments.isEmpty ? paidExpenseID != nil : payments.allSatisfy(\.isPaid) }

    /// What is still to pay on it.
    public var pendingAmount: Money {
        payments.isEmpty ? (isPaid ? .zero : enteredAmount) : payments.filter { !$0.isPaid }.reduce(.zero) { $0 + $1.amount }
    }

    /// The trip expenses it has made so far.
    var paidExpenseIDs: [Int64] { payments.isEmpty ? paidExpenseID.map { [$0] } ?? [] : payments.compactMap(\.paidExpenseID) }
}

public struct NewTripPlanItem: Sendable {
    public var description: String
    /// May be left out when the item is given parts, which then set the total.
    public var amount: Money?
    public var tag: String
    public var category: String
    public var subCategory: String
    public var note: String
    public var dueDate: CalendarDate?
    /// Only used when the item is first planned; parts and legs are changed one by one afterwards.
    public var payments: [NewTripPlanPayment]
    public var legs: [NewTripLeg]

    public init(
        description: String, amount: Money?, tag: String = "", category: String = "", subCategory: String = "", note: String = "",
        dueDate: CalendarDate? = nil, payments: [NewTripPlanPayment] = [], legs: [NewTripLeg] = []
    ) {
        self.description = description
        self.amount = amount
        self.tag = tag
        self.category = category
        self.subCategory = subCategory
        self.note = note
        self.dueDate = dueDate
        self.payments = payments
        self.legs = legs
    }
}

/// A payment that is coming up (or overdue) on a trip that has started.
public struct TripDue: Equatable, Sendable {
    public let tripID: Int64
    public let tripName: String
    public let itemID: Int64
    public let paymentID: Int64?
    /// "Group tour · Advance", or just the item's name.
    public let title: String
    /// In the trip's currency.
    public let amount: Money
    public let amountHome: Money
    public let dueDate: CalendarDate
    /// Negative once it is overdue.
    public let daysUntil: Int
    /// Whether the money leaves the bank, and so lowers Left to spend.
    public let affectsLeftToSpend: Bool
}

/// What is really paid when an item is ticked; anything left out is taken from the plan or from today.
public struct PlanItemPayment: Sendable {
    public var amount: Money?
    public var date: CalendarDate?
    public var paidWith: ExpensePayment
    /// What the card charged in the home currency, as on any trip expense.
    public var paidInHome: Money?

    public init(amount: Money? = nil, date: CalendarDate? = nil, paidWith: ExpensePayment = .bank, paidInHome: Money? = nil) {
        self.amount = amount
        self.date = date
        self.paidWith = paidWith
        self.paidInHome = paidInHome
    }
}

/// The plan of a trip: what it is expected to cost, what is paid and what is still to pay.
public struct TripPlan: Equatable, Sendable {
    /// Oldest first.
    public let items: [TripPlanItem]
    /// Every item at its estimate, in the trip currency.
    public let plannedTotal: Money
    public let plannedTotalHome: Money
    /// Estimates of the items not paid yet.
    public let pendingTotal: Money
    public let pendingTotalHome: Money
    /// What the paid items really cost.
    public let paidTotal: Money
    /// Every leg of the journey, earliest first; legs with no date come last.
    public let itinerary: [TripLeg]
    /// Estimates by tag, largest first.
    public let byTag: [TagSpend]
    /// Estimates by main category, largest first; items with none are together under a blank name.
    public let byCategory: [CategorySpend]
    /// Planned against really spent in each category, the bigger of the two first. Empty when nothing is planned.
    public let categoryProgress: [CategoryProgress]
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

public struct CategorySpend: Equatable, Sendable {
    /// Blank for spending with no category.
    public let category: String
    public let amount: Money
}

public struct CategoryProgress: Equatable, Sendable {
    public let category: String
    public let planned: Money
    public let spent: Money
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
    public let spendByCategory: [CategorySpend]
    public let totals: [ParticipantTotal]
    public let plan: TripPlan

    /// Shown beneath "net cost so far" on the Trips list once a trip has started and has a plan.
    public var plannedAlongsideNetCost: Money? {
        !trip.isPlanning && plan.plannedTotal > .zero ? plan.plannedTotal : nil
    }
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
    case endBeforeStart
    case paidInParts
    case itemAlreadyPaid(String)
    case paymentPaid
    case paymentNotFound(Int64)
    case legNotFound(Int64)
    case legArrivesBeforeLeaving
    case timeInvalid
    case planItemNotFound(Int64)
    case tripNotStarted
    case alreadyPaid(String)
    case notPaidYet(String)

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
        case .endBeforeStart: "The trip can't end before it starts."
        case .paidInParts: "This item is paid in parts. Tick each part instead."
        case .itemAlreadyPaid(let name): "\(name) is already paid, so it can't be split into parts."
        case .paymentPaid: "A part that is paid can't be changed. Untick it first."
        case .paymentNotFound: "That part no longer exists."
        case .legNotFound: "That leg no longer exists."
        case .legArrivesBeforeLeaving: "The leg can't arrive before it leaves."
        case .timeInvalid: "Enter a time between 00:00 and 23:59"
        case .planItemNotFound: "That plan item no longer exists."
        case .tripNotStarted: "Start the trip before ticking things as paid."
        case .alreadyPaid(let name): "\(name) is already paid."
        case .notPaidYet(let name): "\(name) is not paid yet."
        }
    }
}
