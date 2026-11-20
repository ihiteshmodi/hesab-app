import Foundation
import Testing
@testable import HisaabCore

/// Scenarios from tests/trips/trips/trip-planner.feature
struct TripPlannerTests {
    private let october = CalendarDate.YearMonth(year: 2026, month: 10)

    private struct Planned {
        let app: BudgetApp
        let trip: Trip

        func plan(_ name: String, idr: Int?, tag: String = "") throws -> TripPlanItem {
            try app.addTripPlanItem(trip.id, NewTripPlanItem(description: name, amount: idr.map { .rupees($0) }, tag: tag))
        }

        func summary() throws -> TripSummary { try app.tripSummary(trip.id) }
        func expense(named name: String) throws -> TripExpense? { try summary().expenses.first { $0.description == name } }
    }

    private func planning(started: Bool = false) throws -> Planned {
        let app = try makeApp()
        let trip = try app.createTrip(NewTrip(
            name: "Bali trip", currency: "IDR", rate: Decimal(string: "0.0053")!, category: "Lifestyle", subCategory: "Vacation",
            isPlanning: true
        ))
        if started { try app.startTrip(trip.id) }
        return Planned(app: app, trip: trip)
    }

    // MARK: planning mode

    @Test func aTripCanBeMadeAsAPlanWithNothingPlannedYet() throws {
        let p = try planning()

        let summary = try p.summary()

        #expect(summary.trip.isPlanning)
        #expect(summary.plan.items.isEmpty)
        #expect(summary.plan.plannedTotal == .zero)
    }

    @Test func aNormalTripIsNotInPlanningMode() throws {
        let app = try makeApp()
        let trip = try app.createTrip(NewTrip(name: "Goa", category: "Lifestyle"))

        #expect(!trip.isPlanning)
    }

    @Test func thePlanAddsUpWhatTheTripWouldCostWithTotalsByTag() throws {
        let p = try planning()
        try p.plan("Flights", idr: 6_000_000, tag: "Transport")
        try p.plan("Hotel", idr: 8_000_000, tag: "Stay")
        try p.plan("Shirts", idr: 1_000_000, tag: "Shopping")

        let plan = try p.summary().plan

        #expect(plan.plannedTotal == .rupees(15_000_000))
        #expect(plan.plannedTotalHome == .rupees(79_500))
        #expect(plan.byTag == [
            TagSpend(tag: "Stay", amount: .rupees(8_000_000)),
            TagSpend(tag: "Transport", amount: .rupees(6_000_000)),
            TagSpend(tag: "Shopping", amount: .rupees(1_000_000)),
        ])
    }

    @Test func planningNeverTouchesTheMainLedger() throws {
        let p = try planning()

        try p.plan("Flights", idr: 6_000_000)

        let budget = try p.app.monthBudget(for: october)
        #expect(budget.expenses.isEmpty)
        #expect(budget.leftToSpend == .zero)
    }

    @Test(arguments: [
        ("", 100 as Int?, "Enter a description"),
        ("Flights", nil, "Enter an amount above 0"),
        ("Flights", 0, "Enter an amount above 0"),
    ])
    func aPlanItemNeedsANameAndAnAmount(name: String, amount: Int?, message: String) throws {
        let p = try planning()

        let error = #expect(throws: TripError.self) { try p.plan(name, idr: amount) }

        #expect(error?.message == message)
    }

    @Test func aPlanItemCanBeChangedAndRemoved() throws {
        let p = try planning()
        let flights = try p.plan("Flights", idr: 6_000_000, tag: "Transport")

        try p.app.updateTripPlanItem(flights.id, NewTripPlanItem(description: "Flights", amount: .rupees(7_000_000), tag: "Transport"))
        #expect(try p.summary().plan.plannedTotal == .rupees(7_000_000))

        try p.app.deleteTripPlanItem(flights.id)
        #expect(try p.summary().plan.items.isEmpty)
    }

    @Test func aTagTypedInThePlanIsRememberedForEveryTrip() throws {
        let p = try planning()

        try p.plan("Scuba", idr: 900_000, tag: "Diving")

        #expect(try p.app.tripTags().contains { $0.name == "Diving" })
    }

    // MARK: starting

    @Test func startingTheTripTakesItOutOfPlanningMode() throws {
        let p = try planning()

        try p.app.startTrip(p.trip.id)

        #expect(try !p.summary().trip.isPlanning)
    }

    @Test func editingATripKeepsItInPlanningMode() throws {
        let p = try planning()

        try p.app.updateTrip(p.trip.id, NewTrip(
            name: "Bali holiday", currency: "IDR", rate: Decimal(string: "0.0053")!, category: "Lifestyle", subCategory: "Vacation"
        ))

        #expect(try p.summary().trip.isPlanning)
    }

    @Test func nothingCanBeTickedAsPaidBeforeTheTripStarts() throws {
        let p = try planning()
        let flights = try p.plan("Flights", idr: 6_000_000)

        let error = #expect(throws: TripError.self) { try p.app.markTripPlanItemPaid(flights.id) }

        #expect(error?.message == "Start the trip before ticking things as paid.")
    }

    // MARK: paying

    @Test func tickingAnItemAsPaidMakesARealExpenseOnlyIShareAndChargesTheLedger() throws {
        let p = try planning(started: true)
        let flights = try p.plan("Flights", idr: 6_000_000, tag: "Transport")

        try p.app.markTripPlanItemPaid(flights.id, PlanItemPayment(date: day("2026-10-12"), paidInHome: .rupees(31_500)))

        let expense = try #require(try p.expense(named: "Flights"))
        #expect(expense.amount == .rupees(6_000_000))
        #expect(expense.shares == [.me: .rupees(6_000_000)])
        #expect(expense.tag == "Transport")
        #expect(try ledgerEntry(p.app, named: "Bali trip expenses") == .rupees(31_500))
        #expect(try p.app.monthBudget(for: october).leftToSpend == .rupees(-31_500))
        let item = try #require(try p.summary().plan.items.first)
        #expect(item.isPaid)
        #expect(try p.summary().plan.pendingTotal == .zero)
    }

    @Test func whatWasReallyPaidCanDifferFromTheEstimate() throws {
        let p = try planning(started: true)
        let flights = try p.plan("Flights", idr: 6_000_000)

        try p.app.markTripPlanItemPaid(flights.id, PlanItemPayment(amount: .rupees(6_500_000), date: day("2026-10-12")))

        let expense = try #require(try p.expense(named: "Flights"))
        #expect(expense.amount == .rupees(6_500_000))
        #expect(expense.date == day("2026-10-12"))
        let plan = try p.summary().plan
        #expect(plan.items.first?.amount == .rupees(6_000_000))
        #expect(plan.paidTotal == .rupees(6_500_000))
    }

    @Test func whatIsStillToPayStaysInsideTheTripAndOutOfLeftToSpend() throws {
        let p = try planning(started: true)
        let flights = try p.plan("Flights", idr: 6_000_000)
        try p.plan("Hotel", idr: 8_000_000)

        try p.app.markTripPlanItemPaid(flights.id, PlanItemPayment(date: day("2026-10-12")))

        let plan = try p.summary().plan
        #expect(plan.pendingTotal == .rupees(8_000_000))
        #expect(plan.pendingTotalHome == .rupees(42_400))
        #expect(plan.plannedTotal == .rupees(14_000_000))
        #expect(try p.app.monthBudget(for: october).leftToSpend == .rupees(-31_800))
    }

    @Test func tickingAnItemAgainIsRefused() throws {
        let p = try planning(started: true)
        let flights = try p.plan("Flights", idr: 6_000_000)
        try p.app.markTripPlanItemPaid(flights.id)

        #expect(throws: TripError.self) { try p.app.markTripPlanItemPaid(flights.id) }
        #expect(try p.summary().expenses.count == 1)
    }

    @Test func unTickingRemovesTheExpenseAndTheLedgerEntry() throws {
        let p = try planning(started: true)
        let flights = try p.plan("Flights", idr: 6_000_000)
        try p.app.markTripPlanItemPaid(flights.id, PlanItemPayment(date: day("2026-10-12")))

        try p.app.unmarkTripPlanItemPaid(flights.id)

        #expect(try p.summary().expenses.isEmpty)
        #expect(try ledgerEntry(p.app, named: "Bali trip expenses") == nil)
        #expect(try p.summary().plan.pendingTotal == .rupees(6_000_000))
    }

    @Test func deletingTheExpenseFromTheTripPutsTheItemBackToStillToPay() throws {
        let p = try planning(started: true)
        let flights = try p.plan("Flights", idr: 6_000_000)
        let expense = try p.app.markTripPlanItemPaid(flights.id)

        try p.app.deleteTripExpense(expense.id)

        let plan = try p.summary().plan
        #expect(plan.items.first?.isPaid == false)
        #expect(plan.pendingTotal == .rupees(6_000_000))
    }

    @Test func aPaidExpenseEditedInTheTripStaysLinkedToItsPlanItem() throws {
        let p = try planning(started: true)
        let flights = try p.plan("Flights", idr: 6_000_000)
        let expense = try p.app.markTripPlanItemPaid(flights.id)

        try p.app.updateTripExpense(expense.id, NewTripExpense(
            description: "Flights Bali", amount: .rupees(6_100_000), split: .equal([.me])
        ))

        #expect(try p.summary().plan.items.first?.isPaid == true)
    }

    @Test func deletingATripRemovesItsPlan() throws {
        let p = try planning(started: true)
        try p.plan("Flights", idr: 6_000_000)

        try p.app.deleteTrip(p.trip.id)

        #expect(throws: TripError.self) { try p.app.tripSummary(p.trip.id) }
    }

    // MARK: the app's categories in the plan

    @Test func planItemsKeepTheirCategoryAndTotalByCategory() throws {
        let p = try planning()
        try p.app.addTripPlanItem(p.trip.id, NewTripPlanItem(
            description: "Flights", amount: .rupees(6_000_000), category: "Transport", subCategory: "Flight"
        ))
        try p.app.addTripPlanItem(p.trip.id, NewTripPlanItem(description: "Ferry", amount: .rupees(500_000), category: "Transport"))
        try p.app.addTripPlanItem(p.trip.id, NewTripPlanItem(description: "Dinners", amount: .rupees(2_000_000), category: "Food & Dining"))

        let plan = try p.summary().plan

        #expect(plan.items.first?.category == "Transport")
        #expect(plan.items.first?.subCategory == "Flight")
        #expect(plan.byCategory == [
            CategorySpend(category: "Transport", amount: .rupees(6_500_000)),
            CategorySpend(category: "Food & Dining", amount: .rupees(2_000_000)),
        ])
    }

    @Test func tickingAPlanItemKeepsItsCategoryOnTheExpenseAndTheLedgerStaysOneEntry() throws {
        let p = try planning(started: true)
        let flights = try p.app.addTripPlanItem(p.trip.id, NewTripPlanItem(
            description: "Flights", amount: .rupees(6_000_000), category: "Transport", subCategory: "Flight"
        ))

        try p.app.markTripPlanItemPaid(flights.id, PlanItemPayment(date: day("2026-10-12")))

        let expense = try #require(try p.expense(named: "Flights"))
        #expect(expense.category == "Transport")
        #expect(expense.subCategory == "Flight")
        #expect(try p.app.monthBudget(for: october).expenses.count == 1)
    }

    @Test func aSubCategoryTypedInThePlanJoinsTheMainList() throws {
        let p = try planning()

        try p.app.addTripPlanItem(p.trip.id, NewTripPlanItem(
            description: "Scuba", amount: .rupees(900_000), category: "Lifestyle", subCategory: "Diving"
        ))

        let lifestyle = try #require(try p.app.categories().first { $0.name == "Lifestyle" })
        #expect(lifestyle.subCategories.map(\.name).contains("Diving"))
    }
}
