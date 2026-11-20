import Foundation
import HisaabCore

/// Made-up data for screenshot runs (`-ui-testing -ui-demo-data`); never touches a real database.
enum DemoData {
    static func seed(_ app: BudgetApp) {
        let today = CalendarDate(Date())
        func ago(_ days: Int) -> CalendarDate { today.adding(days: -days) }
        func soon(_ days: Int) -> CalendarDate { today.adding(days: days) }

        _ = try? app.addIncome(NewIncome(date: ago(0), kind: .salary, amount: .rupees(150_000)))
        _ = try? app.addIncome(NewIncome(date: ago(1), kind: .investmentIncome, amount: .rupees(4_100), note: "Bond A"))
        _ = try? app.addIncome(NewIncome(date: ago(2), kind: .moneyReceived, amount: .rupees(1_200), note: "Dinner split"))
        _ = try? app.addIncome(NewIncome(date: ago(3), kind: .savings, amount: .rupees(20_000)))

        let spending: [(Int, String, Int, String, String, PaymentMethod)] = [
            (0, "Weekly groceries", 3_250, "Groceries", "Ration", .upi),
            (1, "Building maintenance", 7_344, "Monthly Fixed Expenses", "", .bank("NEFT (SBI)")),
            (1, "Laptop charger", 2_499, "Technology & Gadgets", "Accessories", .bank("Credit Card (Amazon Pay)")),
            (2, "Cash withdrawal for home", 5_000, "Monthly Fixed Expenses", "", .cashWithdrawal),
            (3, "Dinner with friends", 1_850, "Food & Dining", "Restaurant", .upi),
            (4, "Auto rides", 640, "Transport", "Ride share", .upi),
            (5, "Light Bill", 890, "Home & Utilities", "Electric", .bank("Credit Card (Amazon Pay)")),
            (6, "Yoga class", 1_500, "Lifestyle", "", .cash),
        ]
        var firstIDs: [Int64] = []
        for (days, name, rupees, category, sub, method) in spending {
            if let expense = try? app.addExpense(NewExpense(
                date: ago(days), description: name, amount: .rupees(rupees), category: category, subCategory: sub,
                paymentMethod: method, keepAsCash: method == .cashWithdrawal
            )), let id = expense.id { firstIDs.append(id) }
        }
        for id in firstIDs.prefix(2) { try? app.markRefundable(id) }

        _ = try? app.addCash(.rupees(2_000), note: "Birthday gift")
        _ = try? app.addPlannedItem(NewPlannedItem(description: "Sofa", amount: .rupees(25_000)))

        _ = try? app.addBill(NewBill(name: "Light Bill", amount: .rupees(890), category: "Home & Utilities", dueDate: soon(2)))
        _ = try? app.addBill(NewBill(
            name: "My term life premium", amount: .rupees(2_550), category: "Insurance", dueDate: soon(9),
            addAutomatically: true, autoDebit: true
        ))
        _ = try? app.addBill(NewBill(
            name: "Building maintenance", amount: .rupees(7_344), category: "Monthly Fixed Expenses",
            dueDate: soon(12), repeats: .every3Months
        ))
        _ = try? app.addBill(NewBill(name: "Cash withdrawal for home", amount: .rupees(5_000), category: "Monthly Fixed Expenses", dueDate: ago(0)))
        let rent = try? app.addBill(NewBill(name: "Rent", amount: .rupees(20_000), category: "Home & Utilities", dueDate: ago(1)))
        if let rent, let draft = try? app.billDraft(rent.id) { _ = try? app.addBillOccurrence(rent.id, draft) }

        let asha = try? app.addLedger(NewLedger(name: "Asha"))
        let ravi = try? app.addLedger(NewLedger(name: "Ravi", countsTowardsNetWorth: true))
        if let asha {
            _ = try? app.addLedgerEntry(asha.id, NewLedgerEntry(date: ago(60), description: "Opening balance", value: .rupees(60_000)))
            _ = try? app.addLedgerEntry(asha.id, NewLedgerEntry(date: ago(40), description: "Withdrawal", value: .rupees(-10_000)))
        }
        if let ravi {
            _ = try? app.addLedgerEntry(ravi.id, NewLedgerEntry(date: ago(30), description: "Deposit", value: .rupees(300_000)))
            _ = try? app.addLedgerEntry(ravi.id, NewLedgerEntry(date: ago(20), description: "Sent to Ravi's account for rent", value: .rupees(-15_000)))
        }

        if let loan = try? app.addIncome(NewIncome(date: ago(5), kind: .borrowed, amount: .rupees(5_000), note: "Priya", viaCash: false)) {
            _ = try? app.recordRepayment(loan.id, .rupees(1_000), on: ago(2))
        }
        _ = try? app.addIncome(NewIncome(date: ago(1), kind: .borrowed, amount: .rupees(3_000), note: "Sam", viaCash: true))

        try? app.setBankBalance(.rupees(444_598), asOf: ago(2))
        _ = try? app.addHolding(NewHolding(name: "Groww Stocks", amount: .rupees(10_862)))
        _ = try? app.addAllocatedFund(name: "Holiday fund", amount: .rupees(50_000))
        _ = try? app.addScheme(NewPayoutScheme(
            name: "Post office monthly scheme part 2", invested: .rupees(100_000), payoutAmount: .rupees(616),
            payoutDay: CalendarDate(Date()).day, maturity: soon(60)
        ))
        _ = try? app.addScheme(NewPayoutScheme(
            name: "Example Finance monthly bond (via Example Broker)", invested: .rupees(200_000), payoutAmount: .rupees(6_000),
            payoutDay: 29, maturity: ago(30), frequency: .quarterly, firstPayout: soon(4)
        ))
    }
}

/// A clock that can be moved, so made-up history can be dated in the past.
private final class DemoClock: DayClock, @unchecked Sendable {
    var date: CalendarDate
    init(_ date: CalendarDate) { self.date = date }
    func today() -> CalendarDate { date }
}

extension DemoData {
    /// Investments with noted values and instalments, net worth snapshots over six months, and trips (one still
    /// being planned), all dated in the past; for screenshots of the newer screens, on any database.
    static func seedExtras(_ database: AppDatabase) {
        let today = CalendarDate(Date())
        let clock = DemoClock(today)
        let app = BudgetApp(database: database, clock: clock)
        func at(_ days: Int) { clock.date = today.adding(days: days) }

        at(-300)
        try? app.addHolding(NewHolding(name: "Demo stock", amount: .rupees(7_000), invested: .rupees(7_000), investedOn: clock.date, kind: .stock))
        at(-200)
        try? app.addHolding(NewHolding(
            name: "Demo index SIP", amount: .rupees(10_000), invested: .rupees(10_000), investedOn: clock.date, kind: .sip,
            sipAmount: .rupees(2_000), sipDay: 5
        ))
        let holdings = (try? app.portfolio().holdings) ?? []
        if let stock = holdings.first(where: { $0.holding.name == "Demo stock" })?.holding.id {
            for (days, worth) in [(-240, 7_600), (-180, 8_100), (-120, 7_900), (-60, 9_800), (-10, 10_862)] {
                at(days)
                try? app.updateHoldingWorth(stock, .rupees(worth))
            }
        }
        if let sip = holdings.first(where: { $0.holding.name == "Demo index SIP" })?.holding.id {
            for (days, worth) in [(-150, 12_300), (-120, 14_600), (-90, 16_300), (-60, 18_900), (-35, 20_400)] {
                at(days)
                try? app.addToHolding(sip, amount: .rupees(2_000), on: clock.date)
                try? app.updateHoldingWorth(sip, .rupees(worth))
            }
        }

        for (index, months) in [5, 4, 3, 2, 1, 0].enumerated() {
            at(-30 * months)
            try? app.setBankBalance(.rupees(380_000 + index * 21_000 - (index == 3 ? 15_000 : 0)))
            try? app.recordNetWorth()
        }

        at(0)
        if let bali = try? app.createTrip(NewTrip(
            name: "Bali trip", currency: "IDR", rate: Decimal(string: "0.0053"), category: "Lifestyle", subCategory: "Vacation"
        )) {
            let plan: [(String, Int, String, String)] = [
                ("Flights", 6_500_000, "Transport", "Flight tickets"), ("Villa, 4 nights", 8_000_000, "Lifestyle", "Vacation"),
                ("Dinners", 2_000_000, "Food & Dining", "Restaurant"), ("Scooter hire", 900_000, "Transport", "Ride share"),
                ("Shirts and gifts", 1_000_000, "Shopping - Wants", ""),
            ]
            var ids: [Int64] = []
            for (name, idr, category, sub) in plan {
                if let item = try? app.addTripPlanItem(bali.id, NewTripPlanItem(description: name, amount: .rupees(idr), category: category, subCategory: sub)) {
                    ids.append(item.id)
                }
            }
            try? app.startTrip(bali.id)
            for id in ids.prefix(2) { try? app.markTripPlanItemPaid(id, PlanItemPayment(date: today.adding(days: -3))) }
            try? app.addTripExpense(bali.id, NewTripExpense(
                description: "Seafood dinner", date: today.adding(days: -2), amount: .rupees(2_400_000), split: .equal([.me]),
                category: "Food & Dining", subCategory: "Restaurant"
            ))
        }
        if let goa = try? app.createTrip(NewTrip(name: "Goa plan", category: "Lifestyle", subCategory: "Vacation", isPlanning: true)) {
            for (name, rupees, category) in [("Train tickets", 4_800, "Transport"), ("Hotel", 14_000, "Lifestyle"), ("Food", 6_000, "Food & Dining")] {
                try? app.addTripPlanItem(goa.id, NewTripPlanItem(description: name, amount: .rupees(rupees), category: category))
            }
        }
    }
}

