/// Where Left to spend is heading: day 0 is today, then one point per day.
public struct CashForecast: Equatable, Sendable {
    public let points: [Money]
    public let lowest: Money
    /// The first day the line reaches its lowest point.
    public let lowestDay: Int
    public let billsOut: Money
    public let payoutsIn: Money
    /// Her usual spending per day that is not a bill.
    public let dailySpend: Money
}

public struct GetCashForecast: Sendable {
    let budget: GetMonthBudget
    let bills: BillStore
    let schemes: SchemeStore
    let expenses: ExpenseRepository
    let income: IncomeRepository
    let trips: TripStore
    let clock: any DayClock

    public func callAsFunction(days: Int = 30) throws -> CashForecast {
        let today = clock.today()
        let end = today.adding(days: days)
        let billBook = try bills.book()
        let allExpenses = try expenses.all()
        var changes = [Int: Money]()
        var billsOut = Money.zero
        var payoutsIn = Money.zero
        func place(_ date: CalendarDate, _ amount: Money) {
            changes[max(0, today.days(until: date)), default: .zero] = changes[max(0, today.days(until: date)), default: .zero] + amount
        }

        for bill in billBook.bills where bill.paymentMethod.movesLeftToSpend {
            var due = billBook.nextDue(bill)
            while let current = due, current <= end {
                place(current, .zero - bill.amount)
                billsOut = billsOut + bill.amount
                due = bill.endsOn.map { current >= $0 } == true ? nil : bill.repeats.next(after: current, anchorDay: bill.firstDue.day)
            }
        }

        for due in try trips.dues(within: days) where due.affectsLeftToSpend {
            place(due.dueDate, .zero - due.amountHome)
            billsOut = billsOut + due.amountHome
        }

        let schemeBook = try schemes.book()
        let received = try income.all().filter { $0.kind == .investmentIncome }
        var month = today.yearMonth
        while month <= end.yearMonth {
            for payout in schemeBook.expectedPayouts(in: month) where payout.date <= end {
                let last = received.filter { $0.note == payout.name }.max { ($0.date, $0.id) < ($1.date, $1.id) }
                if last?.toSavings == true { continue }
                place(payout.date, payout.amount)
                payoutsIn = payoutsIn + payout.amount
            }
            month = month.shifted(by: 1)
        }

        let daily = Self.usualDailySpend(allExpenses, billBook: billBook, today: today)
        var balance = try budget().leftToSpend + (changes[0] ?? .zero)
        var points = [balance]
        for day in stride(from: 1, through: max(days, 0), by: 1) {
            balance = balance - daily + (changes[day] ?? .zero)
            points.append(balance)
        }
        let lowest = points.min() ?? balance
        return CashForecast(
            points: points, lowest: lowest, lowestDay: points.firstIndex(of: lowest) ?? 0, billsOut: billsOut,
            payoutsIn: payoutsIn, dailySpend: daily
        )
    }

    /// Bank-side spending over the last 3 full months, without what the bills made, per day.
    private static func usualDailySpend(_ expenses: [Expense], billBook: BillBook, today: CalendarDate) -> Money {
        let months = (1...3).map { today.yearMonth.shifted(by: -$0) }
        let billExpenses = Set(billBook.occurrences.map(\.expenseID))
        let total = expenses
            .filter { months.contains($0.date.yearMonth) && $0.paymentMethod.movesLeftToSpend && !billExpenses.contains($0.id ?? 0) }
            .reduce(0) { $0 + $1.netAmount.paise }
        return Money(paise: total / months.reduce(0) { $0 + $1.dayCount })
    }
}
