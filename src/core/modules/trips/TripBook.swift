import Foundation

/// Everything about one trip, with every total worked out from the entries rather than stored.
struct TripBook {
    let trip: Trip
    let people: [Person]
    let groups: [TripGroup]
    let expenses: [TripExpense]
    let settlements: [TripSettlement]
    let cashAdjustments: [CashAdjustment]

    private var isForeign: Bool { trip.currency != nil }

    /// A trip-currency amount at the trip rate, in the home currency.
    func homeValue(_ amount: Money) -> Money {
        guard isForeign, let rate = trip.rate else { return amount }
        return Self.rounded(Decimal(amount.paise) * rate)
    }

    /// What the whole expense cost in the home currency: the card's own charge when given, else the trip rate.
    func home(of expense: TripExpense) -> Money {
        expense.paidInHome ?? homeValue(expense.amount)
    }

    /// One person's share in the home currency, in proportion to what the expense cost.
    func homeShare(of expense: TripExpense, _ who: Participant) -> Money {
        guard isForeign else { return expense.shares[who] ?? .zero }
        guard let share = expense.shares[who], expense.amount > .zero else { return .zero }
        return Self.rounded(Decimal(share.paise) * Decimal(home(of: expense).paise) / Decimal(expense.amount.paise))
    }

    static func rounded(_ value: Decimal) -> Money {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .plain)
        return Money(paise: NSDecimalNumber(decimal: output).intValue)
    }

    func name(of who: Participant) -> String {
        switch who {
        case .me: "Me"
        case .person(let id): people.first { $0.id == id }?.name ?? "Someone"
        }
    }

    func balance(with personID: Int64) -> Money {
        let who = Participant.person(personID)
        var owes = Money.zero
        for expense in expenses {
            if expense.paidBy == .me { owes = owes + (expense.shares[who] ?? .zero) }
            if expense.paidBy == who { owes = owes - (expense.shares[.me] ?? .zero) }
        }
        for settlement in settlements where settlement.personID == personID {
            owes = settlement.direction == .theyPaidMe ? owes - settlement.cleared : owes + settlement.cleared
        }
        return owes
    }

    /// Money moved by a settlement in the home currency: rupees as given, trip cash at the trip rate.
    private func homeAmount(of settlement: TripSettlement) -> Money {
        settlement.method == .cashTrip ? homeValue(settlement.received) : settlement.received
    }

    /// Only bank and card money: what I paid by card or bank, plus what I paid friends by bank, minus what they paid me by bank.
    var ledgerAmount: Money {
        var total = Money.zero
        for expense in expenses where expense.paidBy == .me && expense.paidWith == .bank { total = total + home(of: expense) }
        for settlement in settlements where settlement.method == .bank {
            total = settlement.direction == .iPaidThem ? total + settlement.received : total - settlement.received
        }
        return total
    }

    /// Bank and cash together, so cash I spent or was handed counts inside the trip.
    var netCost: Money {
        var total = Money.zero
        for expense in expenses where expense.paidBy == .me {
            total = total + (expense.paidWith == .bank ? home(of: expense) : homeValue(expense.amount))
        }
        for settlement in settlements {
            let value = homeAmount(of: settlement)
            total = settlement.direction == .iPaidThem ? total + value : total - value
        }
        return total
    }

    var cash: TripCash {
        struct Movement { let kind: TripCashLine.Kind; let date: CalendarDate; let text: String; let amount: Money; let order: Int }
        guard isForeign else { return TripCash(balance: .zero, warning: nil, lines: []) }
        var movements = cashAdjustments.map { Movement(kind: .adjustment, date: $0.date, text: $0.note, amount: $0.amount, order: Int($0.id)) }
        for settlement in settlements where settlement.method == .cashTrip {
            let who = name(of: .person(settlement.personID))
            let received = settlement.direction == .theyPaidMe
            movements.append(Movement(
                kind: received ? .receivedFromFriend : .paidToFriend, date: settlement.date,
                text: received ? "\(who) paid me" : "Paid \(who)",
                amount: received ? settlement.received : .zero - settlement.received, order: Int(settlement.id)
            ))
        }
        for expense in expenses where expense.paidBy == .me && expense.paidWith == .cash {
            movements.append(Movement(kind: .expense, date: expense.date, text: expense.description, amount: .zero - expense.amount, order: Int(expense.id)))
        }
        let rank: (TripCashLine.Kind) -> Int = { $0 == .adjustment ? 0 : $0 == .expense ? 2 : 1 }
        movements.sort { ($0.date, rank($0.kind), $0.order) < ($1.date, rank($1.kind), $1.order) }
        var running = Money.zero
        let lines = movements.map { movement -> TripCashLine in
            running = running + movement.amount
            return TripCashLine(kind: movement.kind, date: movement.date, description: movement.text, amount: movement.amount, runningBalance: running)
        }
        return TripCash(
            balance: running,
            warning: running < .zero ? "You have spent \(IndianMoneyFormat.plain(.zero - running)) more cash than you have recorded." : nil,
            lines: lines
        )
    }

    func statement(for personID: Int64) -> PersonStatement? {
        guard let person = people.first(where: { $0.id == personID }) else { return nil }
        let who = Participant.person(personID)
        var lines: [StatementLine] = []
        for expense in expenses {
            if expense.paidBy == .me, let share = expense.shares[who] {
                lines.append(StatementLine(kind: .iPaid, date: expense.date, title: expense.description, amount: share, expenseID: expense.id, settlementID: nil))
            }
            if expense.paidBy == who, let share = expense.shares[.me] {
                lines.append(StatementLine(kind: .theyPaid, date: expense.date, title: expense.description, amount: .zero - share, expenseID: expense.id, settlementID: nil))
            }
        }
        for settlement in settlements where settlement.personID == personID {
            let received = settlement.direction == .theyPaidMe
            lines.append(StatementLine(
                kind: .payment, date: settlement.date, title: received ? "Paid me" : "I paid",
                amount: received ? .zero - settlement.cleared : settlement.cleared, expenseID: nil, settlementID: settlement.id
            ))
        }
        lines.sort { ($0.date, $0.expenseID ?? 0, $0.settlementID ?? 0) < ($1.date, $1.expenseID ?? 0, $1.settlementID ?? 0) }
        let owes = balance(with: personID)
        return PersonStatement(person: person, owesMe: owes, owesMeHome: homeValue(owes), lines: lines)
    }

    func summary() -> TripSummary {
        let members = people.sorted { $0.name.lowercased() < $1.name.lowercased() }
        let balances = members.map { person -> PersonBalance in
            let owes = balance(with: person.id)
            return PersonBalance(person: person, owesMe: owes, owesMeHome: homeValue(owes))
        }
        var bank = Money.zero, cashHome = Money.zero, cashTrip = Money.zero, cost = Money.zero, gain = Money.zero
        for settlement in settlements {
            let sign = settlement.direction == .theyPaidMe ? 1 : -1
            switch settlement.method {
            case .bank: bank = bank + Money(paise: sign * settlement.received.paise)
            case .cashHome: cashHome = cashHome + Money(paise: sign * settlement.received.paise)
            case .cashTrip: cashTrip = cashTrip + Money(paise: sign * settlement.received.paise)
            }
            if settlement.writtenOff > .zero { cost = cost + settlement.writtenOff }
            if settlement.writtenOff < .zero { gain = gain + (.zero - settlement.writtenOff) }
        }

        var byTag: [String: Money] = [:]
        for expense in expenses { byTag[expense.tag, default: .zero] = byTag[expense.tag, default: .zero] + expense.amount }
        let spendByTag = byTag.map { TagSpend(tag: $0.key, amount: $0.value) }
            .sorted { ($1.amount, $0.tag) < ($0.amount, $1.tag) }

        let everyone = [Participant.me] + people.map { Participant.person($0.id) }
        let totals = everyone.map { who in
            ParticipantTotal(
                participant: who, paid: expenses.filter { $0.paidBy == who }.reduce(.zero) { $0 + $1.amount },
                share: expenses.reduce(.zero) { $0 + ($1.shares[who] ?? .zero) }
            )
        }
        return TripSummary(
            trip: trip, members: members, groups: groups, expenses: expenses.sorted { ($0.date, $0.id) > ($1.date, $1.id) },
            settlements: settlements, balances: balances, totalSpent: expenses.reduce(.zero) { $0 + $1.amount },
            myShare: expenses.reduce(.zero) { $0 + ($1.shares[.me] ?? .zero) }, totalSpentHome: expenses.reduce(.zero) { $0 + home(of: $1) },
            myShareHome: expenses.reduce(.zero) { $0 + homeShare(of: $1, .me) }, ledgerAmount: ledgerAmount, netCost: netCost,
            receivedBankHome: bank, receivedCashHome: cashHome, receivedCashTrip: cashTrip, writtenOffHome: homeValue(cost),
            extraReceivedHome: homeValue(gain), cash: cash, spendByTag: spendByTag, totals: totals
        )
    }
}
