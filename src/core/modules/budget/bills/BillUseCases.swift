/// Everything about when each bill falls due, worked out from the bills and what has been added so far.
struct BillBook {
    let bills: [Bill]
    let occurrences: [BillOccurrence]
    let today: CalendarDate
    let preferences: Preferences

    private func latestDue(of bill: Bill) -> CalendarDate? {
        occurrences.filter { $0.billID == bill.id }.map(\.dueDate).max()
    }

    func nextDue(_ bill: Bill) -> CalendarDate? {
        bill.nextDue(afterLatest: latestDue(of: bill))
    }

    func summaries() -> [BillSummary] {
        bills.map { bill in
            BillSummary(
                bill: bill, nextDue: nextDue(bill), lastAddedMonth: latestDue(of: bill)?.yearMonth
            )
        }
    }

    func upcoming() -> Upcoming {
        let items = bills.compactMap { bill -> UpcomingBill? in
            guard let due = nextDue(bill) else { return nil }
            let delta = today.days(until: due)
            guard delta <= preferences.upcomingWindowDays, delta >= 0 || preferences.includePastDue else { return nil }
            return UpcomingBill(bill: bill, dueDate: due, label: label(for: delta, due: due))
        }
        return Upcoming(items: items.sorted { ($0.dueDate, $0.bill.name) < ($1.dueDate, $1.bill.name) })
    }

    private func label(for delta: Int, due: CalendarDate) -> String {
        if delta < 0 { return "Past due by \(-delta) day\(delta == -1 ? "" : "s")" }
        if preferences.showExactDays { return "Due \(due.shortTitle)" }
        switch delta {
        case 0: return "Due today"
        case 1: return "Due in 1 day"
        default: return "Due in \(delta) days"
        }
    }

    func choices(for month: CalendarDate.YearMonth) -> [BillChoice] {
        let found = bills.filter { !$0.addAutomatically }.compactMap { bill -> BillChoice? in
            if let due = nextDue(bill), due.yearMonth == month {
                return BillChoice(bill: bill, dueDate: due, alreadyAdded: false)
            }
            if let added = occurrences.filter({ $0.billID == bill.id && $0.dueDate.yearMonth == month }).map(\.dueDate).max() {
                return BillChoice(bill: bill, dueDate: added, alreadyAdded: true)
            }
            return nil
        }
        return found.sorted { ($0.dueDate, $0.bill.name) < ($1.dueDate, $1.bill.name) }
    }

    func attention() -> BillsAttention {
        let unseen = occurrences.filter { $0.automatic && !$0.seen }.count
        let alerts = bills.filter { bill in
            guard let due = nextDue(bill) else { return false }
            switch bill.alert {
            case .none: return false
            case .dayBefore: return due.adding(days: -1) <= today
            case .onDueDate: return due <= today
            }
        }.count
        let dueNow = bills.filter { bill in nextDue(bill).map { $0 <= today } ?? false }.count
        return BillsAttention(badge: alerts + unseen, autoAddedUnseen: unseen, menuCount: dueNow)
    }
}

struct BillStore: Sendable {
    let bills: BillRepository
    let settings: SettingsRepository
    let clock: any DayClock

    func book() throws -> BillBook {
        BillBook(
            bills: try bills.all(), occurrences: try bills.occurrences(), today: clock.today(),
            preferences: Preferences(stored: try settings.all())
        )
    }
}

private func validated(_ new: NewBill) throws -> Money {
    guard !new.name.trimmed.isEmpty else { throw BillError.nameMissing }
    guard let amount = new.amount, amount > .zero else { throw BillError.amountMissingOrZero }
    guard !new.category.isEmpty else { throw BillError.categoryMissing }
    if let end = new.endsOn, end < new.dueDate { throw BillError.endBeforeDue }
    return amount
}

public struct AddBill: Sendable {
    let bills: BillRepository

    @discardableResult
    public func callAsFunction(_ new: NewBill) throws -> Bill {
        try bills.add(new, amount: try validated(new))
    }
}

public struct UpdateBill: Sendable {
    let bills: BillRepository

    @discardableResult
    public func callAsFunction(_ id: Int64, _ new: NewBill) throws -> Bill {
        try bills.update(id, new, amount: try validated(new))
    }
}

public struct DeleteBill: Sendable {
    let bills: BillRepository

    public func callAsFunction(_ id: Int64) throws {
        try bills.delete(id)
    }
}

public struct ChangeBillPlan: Sendable {
    let bills: BillRepository

    /// Ends the old bill on `date` and starts the new one; expenses already added stay as they are.
    @discardableResult
    public func callAsFunction(_ oldID: Int64, endsOn date: CalendarDate, startingWith new: NewBill) throws -> Bill {
        let old = try bills.bill(oldID)
        let replacement = try bills.add(new, amount: try validated(new))
        _ = try bills.update(oldID, NewBill(
            name: old.name, amount: old.amount, category: old.category, subCategory: old.subCategory, entity: old.entity,
            paymentMethod: old.paymentMethod, dueDate: old.firstDue, repeats: old.repeats, endsOn: date,
            addAutomatically: old.addAutomatically, alert: old.alert, notes: old.notes
        ), amount: old.amount)
        return replacement
    }
}

public struct GetBills: Sendable {
    let store: BillStore

    public func callAsFunction() throws -> [BillSummary] {
        try store.book().summaries()
    }
}

public struct GetUpcoming: Sendable {
    let store: BillStore

    public func callAsFunction() throws -> Upcoming {
        try store.book().upcoming()
    }
}

public struct GetBillDraft: Sendable {
    let store: BillStore

    /// The expense form for the bill's next due date; the date is nil when the setting says to ask.
    public func callAsFunction(_ id: Int64) throws -> NewExpense {
        let book = try store.book()
        guard let bill = book.bills.first(where: { $0.id == id }) else { throw BillError.notFound(id) }
        guard let due = book.nextDue(bill) else { throw BillError.ended }
        let date: CalendarDate? = switch book.preferences.paymentDate {
        case .useDueDate: due
        case .useToday: book.today
        case .askEachTime: nil
        }
        return NewExpense(
            date: date, description: bill.name, amount: bill.amount, category: bill.category,
            subCategory: bill.subCategory, entity: bill.entity, paymentMethod: bill.paymentMethod, notes: bill.notes
        )
    }
}

public struct AddBillOccurrence: Sendable {
    let store: BillStore
    let addExpense: AddExpense

    /// Saves the expense as the person adjusted it, then moves the bill on to its next due date.
    @discardableResult
    public func callAsFunction(_ id: Int64, _ expense: NewExpense) throws -> Expense {
        let book = try store.book()
        guard let bill = book.bills.first(where: { $0.id == id }) else { throw BillError.notFound(id) }
        guard let due = book.nextDue(bill) else { throw BillError.ended }
        let saved = try addExpense(expense)
        try store.bills.record(billID: id, dueDate: due, expenseID: saved.id ?? 0, automatic: false)
        return saved
    }
}

public struct GetBillsToAdd: Sendable {
    let store: BillStore

    public func callAsFunction(for month: CalendarDate.YearMonth) throws -> [BillChoice] {
        try store.book().choices(for: month)
    }
}

public struct AddSeveralBills: Sendable {
    let store: BillStore
    let addExpense: AddExpense

    @discardableResult
    public func callAsFunction(_ ids: [Int64], for month: CalendarDate.YearMonth) throws -> [Expense] {
        var added: [Expense] = []
        for id in ids {
            while true {
                let book = try store.book()
                guard let bill = book.bills.first(where: { $0.id == id }), let due = book.nextDue(bill),
                      due.yearMonth == month else { break }
                let date = book.preferences.paymentDate == .useToday ? book.today : due
                let saved = try addExpense(NewExpense(
                    date: date, description: bill.name, amount: bill.amount, category: bill.category,
                    subCategory: bill.subCategory, entity: bill.entity, paymentMethod: bill.paymentMethod, notes: bill.notes
                ))
                try store.bills.record(billID: id, dueDate: due, expenseID: saved.id ?? 0, automatic: false)
                added.append(saved)
            }
        }
        return added
    }
}

public struct RunAutomaticBills: Sendable {
    let store: BillStore
    let addExpense: AddExpense

    /// Adds every automatic bill that has fallen due, catching up on days the app was not opened.
    public func callAsFunction() throws -> [String] {
        var notices: [String] = []
        for start in try store.book().bills where start.addAutomatically {
            while true {
                let book = try store.book()
                guard let bill = book.bills.first(where: { $0.id == start.id }), let due = book.nextDue(bill),
                      due <= book.today, due != bill.autoSkipDue else { break }
                let saved = try addExpense(NewExpense(
                    date: due, description: bill.name, amount: bill.amount, category: bill.category,
                    subCategory: bill.subCategory, entity: bill.entity, paymentMethod: bill.paymentMethod, notes: bill.notes
                ))
                try store.bills.record(billID: bill.id, dueDate: due, expenseID: saved.id ?? 0, automatic: true)
                notices.append("Added automatically: \(bill.name) \(IndianMoneyFormat.plain(bill.amount))")
            }
        }
        return notices
    }
}

public struct GetAutoAdded: Sendable {
    let store: BillStore
    let expenses: ExpenseRepository

    /// Newest first, seen or not.
    public func callAsFunction() throws -> [AutoAddedBill] {
        let book = try store.book()
        let amounts = Dictionary(uniqueKeysWithValues: try expenses.all().compactMap { expense in expense.id.map { ($0, expense.amount) } })
        return book.occurrences.filter(\.automatic).sorted { ($0.dueDate, $0.id) > ($1.dueDate, $1.id) }.compactMap { occurrence in
            guard let bill = book.bills.first(where: { $0.id == occurrence.billID }) else { return nil }
            return AutoAddedBill(
                occurrenceID: occurrence.id, billName: bill.name, amount: amounts[occurrence.expenseID] ?? bill.amount,
                dueDate: occurrence.dueDate, seen: occurrence.seen
            )
        }
    }
}

public struct MarkAutoAddedSeen: Sendable {
    let bills: BillRepository

    public func callAsFunction() throws {
        try bills.markAutomaticSeen()
    }
}

public struct UndoAutoAdded: Sendable {
    let store: BillStore
    let expenses: ExpenseRepository

    /// Removes the expense; the bill is due again for that date but will not add itself for it a second time.
    public func callAsFunction(_ occurrenceID: Int64) throws {
        guard let occurrence = try store.bills.occurrences().first(where: { $0.id == occurrenceID && $0.automatic }) else {
            throw BillError.occurrenceNotFound(occurrenceID)
        }
        try store.bills.setAutoSkip(billID: occurrence.billID, occurrence.dueDate)
        try expenses.delete(occurrence.expenseID)
    }
}

public struct GetBillsAttention: Sendable {
    let store: BillStore

    public func callAsFunction() throws -> BillsAttention {
        try store.book().attention()
    }
}
