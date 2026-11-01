/// What the filter menu on the Bills tab can show.
public enum BillsFilter: String, CaseIterable, Sendable {
    case allTransactions, bills, notAdded, added, autoAdded, income, upcomingIncome, receivedIncome, planned

    public var title: String {
        switch self {
        case .allTransactions: "All Transactions"
        case .bills: "Bills"
        case .notAdded: "Not Added"
        case .added: "Added"
        case .autoAdded: "Auto-added"
        case .income: "Income"
        case .upcomingIncome: "Upcoming Income"
        case .receivedIncome: "Received Income"
        case .planned: "Planned (no date)"
        }
    }

    func includes(_ kind: CalendarItem.Kind) -> Bool {
        switch self {
        case .allTransactions: true
        case .bills: [.billNotAdded, .billAdded, .billAutoAdded].contains(kind)
        case .notAdded: kind == .billNotAdded
        case .added: kind == .billAdded
        case .autoAdded: kind == .billAutoAdded
        case .income: kind == .expectedPayout || kind == .receivedIncome
        case .upcomingIncome: kind == .expectedPayout
        case .receivedIncome: kind == .receivedIncome
        case .planned: false
        }
    }
}

/// One thing on one day of the Bills calendar.
public struct CalendarItem: Equatable, Sendable {
    public enum Kind: Sendable { case billNotAdded, billAdded, billAutoAdded, expectedPayout, receivedIncome }

    public let kind: Kind
    public let date: CalendarDate
    public let name: String
    public let amount: Money
    public let detail: String
    /// A bill that will add itself on its day.
    public let isAutomatic: Bool
    /// Only the next due date of a bill she adds herself can be added now.
    public let canAdd: Bool
    /// Only the next expected payout can be recorded now.
    public let canRecord: Bool
    public let billID: Int64?
    public let schemeID: Int64?
}

/// A month of bills, expected payouts and income received, for the Bills calendar.
public struct BillsCalendar: Equatable, Sendable {
    public let month: CalendarDate.YearMonth
    /// In date order, then by name.
    public let items: [CalendarItem]

    public func items(_ filter: BillsFilter) -> [CalendarItem] {
        items.filter { filter.includes($0.kind) }
    }

    public func items(_ filter: BillsFilter, on day: Int) -> [CalendarItem] {
        items(filter).filter { $0.date.day == day }
    }

    /// How many dots each day gets.
    public func counts(_ filter: BillsFilter) -> [Int: Int] {
        Dictionary(grouping: items(filter), by: \.date.day).mapValues(\.count)
    }
}

extension BillBook {
    func calendarItems(for month: CalendarDate.YearMonth) -> [CalendarItem] {
        bills.flatMap { bill -> [CalendarItem] in
            let added = occurrences.filter { $0.billID == bill.id && $0.dueDate.yearMonth == month }.map { occurrence in
                CalendarItem(
                    kind: occurrence.automatic ? .billAutoAdded : .billAdded, date: occurrence.dueDate, name: bill.name,
                    amount: bill.amount, detail: occurrence.automatic ? "Auto-added" : "Added", isAutomatic: occurrence.automatic,
                    canAdd: false, canRecord: false, billID: bill.id, schemeID: nil
                )
            }
            return added + dueDates(of: bill, in: month).map { due in
                let waitsForHer = !bill.addAutomatically || due == bill.autoSkipDue
                return CalendarItem(
                    kind: .billNotAdded, date: due, name: bill.name, amount: bill.amount,
                    detail: repeatText(bill), isAutomatic: !waitsForHer,
                    canAdd: waitsForHer && due == nextDue(bill), canRecord: false, billID: bill.id, schemeID: nil
                )
            }
        }
    }

    /// Due dates in `month` from the next one onwards; the repeat is walked from the next due date so it stays on its day.
    private func dueDates(of bill: Bill, in month: CalendarDate.YearMonth) -> [CalendarDate] {
        var found: [CalendarDate] = []
        var due = nextDue(bill)
        while let current = due, current.yearMonth <= month {
            if let endsOn = bill.endsOn, current > endsOn { break }
            if current.yearMonth == month { found.append(current) }
            due = bill.repeats.next(after: current, anchorDay: bill.firstDue.day)
        }
        return found
    }

    private func repeatText(_ bill: Bill) -> String {
        let repeats = bill.repeats == .never ? "One-off" : bill.repeats.title
        return bill.addAutomatically ? "\(repeats) · adds itself" : repeats
    }
}

extension SchemeBook {
    func expectedPayouts(in month: CalendarDate.YearMonth) -> [CalendarItem] {
        schemes.compactMap { scheme -> CalendarItem? in
            guard paysIn(scheme, month), let next = expectedPayout(scheme) else { return nil }
            let date = payoutDate(scheme, in: month)
            // Recorded months are always before the next expected payout, so `date >= next` leaves them out.
            guard date >= next, scheme.maturity.map({ date <= $0 }) ?? true else { return nil }
            return CalendarItem(
                kind: .expectedPayout, date: date, name: scheme.name, amount: scheme.payoutAmount,
                detail: "Payout expected", isAutomatic: false, canAdd: false, canRecord: date == next,
                billID: nil, schemeID: scheme.id
            )
        }
    }
}

public struct GetBillsCalendar: Sendable {
    let store: BillStore
    let schemes: SchemeStore
    let income: IncomeRepository

    public func callAsFunction(for month: CalendarDate.YearMonth) throws -> BillsCalendar {
        let received = try income.all().filter { $0.date.yearMonth == month }.map { entry in
            CalendarItem(
                kind: .receivedIncome, date: entry.date, name: entry.note.isEmpty ? entry.kind.title : entry.note,
                amount: entry.amount, detail: entry.kind.title, isAutomatic: false, canAdd: false, canRecord: false,
                billID: nil, schemeID: nil
            )
        }
        let items = try store.book().calendarItems(for: month) + schemes.book().expectedPayouts(in: month) + received
        return BillsCalendar(month: month, items: items.sorted { ($0.date, $0.name) < ($1.date, $1.name) })
    }
}
