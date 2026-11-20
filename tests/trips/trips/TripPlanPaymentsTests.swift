import Foundation
import Testing
@testable import HisaabCore

/// Scenarios from tests/trips/trips/trip-planner.feature: start date, notes, paying in parts, reminders and travel legs.
struct TripPlanPaymentsTests {
    private func started(today: String = "2026-11-20", currency: Bool = false, planning: Bool = false) throws -> (app: BudgetApp, trip: Trip) {
        let app = try makeApp(today: today)
        let trip = try app.createTrip(NewTrip(
            name: "Himalaya trek", currency: currency ? "IDR" : nil, rate: currency ? Decimal(string: "0.0053") : nil,
            category: "Lifestyle", subCategory: "Vacation", isPlanning: planning
        ))
        if !planning { try app.startTrip(trip.id) }
        return (app, trip)
    }

    private func summary(_ s: (app: BudgetApp, trip: Trip)) throws -> TripSummary { try s.app.tripSummary(s.trip.id) }

    private func part(_ label: String, _ rupees: Int, due: String?) -> NewTripPlanPayment {
        NewTripPlanPayment(label: label, amount: .rupees(rupees), dueDate: due.map(day))
    }

    @discardableResult
    private func tour(_ s: (app: BudgetApp, trip: Trip)) throws -> TripPlanItem {
        let item = try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(description: "Group tour", amount: .rupees(80_000)))
        try s.app.addTripPlanPayment(item.id, part("Balance", 60_000, due: "2027-01-10"))
        try s.app.addTripPlanPayment(item.id, part("Advance", 20_000, due: "2026-11-25"))
        return item
    }

    // MARK: start date

    @Test func aTripKeepsItsStartAndEndDates() throws {
        let app = try makeApp()

        let trip = try app.createTrip(NewTrip(
            name: "Goa", category: "Lifestyle", endDate: day("2026-12-18"), startDate: day("2026-12-10")
        ))

        #expect(trip.startDate == day("2026-12-10"))
        #expect(trip.endDate == day("2026-12-18"))
    }

    @Test func aTripCannotEndBeforeItStarts() throws {
        let app = try makeApp()

        let error = #expect(throws: TripError.self) {
            try app.createTrip(NewTrip(name: "Goa", category: "Lifestyle", endDate: day("2026-12-01"), startDate: day("2026-12-10")))
        }

        #expect(error?.message == "The trip can't end before it starts.")
    }

    @Test func theStartDateCanBeChangedLater() throws {
        let app = try makeApp()
        let trip = try app.createTrip(NewTrip(name: "Goa", category: "Lifestyle"))

        try app.updateTrip(trip.id, NewTrip(name: "Goa", category: "Lifestyle", startDate: day("2026-12-10")))

        #expect(try app.tripSummary(trip.id).trip.startDate == day("2026-12-10"))
    }

    // MARK: notes

    @Test func aPlanItemKeepsANoteAndTheNoteFollowsItToTheExpense() throws {
        let s = try started()
        let item = try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(
            description: "Flights", amount: .rupees(9_000), note: "  Window seat, 2 bags "
        ))
        #expect(item.note == "Window seat, 2 bags")

        let expense = try s.app.markTripPlanItemPaid(item.id)

        #expect(expense.note == "Window seat, 2 bags")
    }

    // MARK: paying in parts

    @Test func anItemPaidInPartsTotalsItsPartsAndListsThemByDueDate() throws {
        let s = try started()

        let item = try tour(s)

        let saved = try #require(try summary(s).plan.items.first { $0.id == item.id })
        #expect(saved.amount == .rupees(80_000))
        #expect(saved.payments.map(\.label) == ["Advance", "Balance"])
        #expect(!saved.isPaid)
        #expect(try summary(s).plan.plannedTotal == .rupees(80_000))
        #expect(try summary(s).plan.pendingTotal == .rupees(80_000))
    }

    @Test func eachPartIsTickedOnItsOwnAndTheItemIsPaidWhenAllAre() throws {
        let s = try started()
        try tour(s)
        let advance = try #require(try summary(s).plan.items.first?.payments.first)
        let balance = try #require(try summary(s).plan.items.first?.payments.last)

        let expense = try s.app.markTripPlanPaymentPaid(advance.id, PlanItemPayment(date: day("2026-11-20")))

        #expect(expense.description == "Group tour · Advance")
        #expect(expense.amount == .rupees(20_000))
        #expect(try summary(s).plan.pendingTotal == .rupees(60_000))
        #expect(try summary(s).plan.items.first?.isPaid == false)

        try s.app.markTripPlanPaymentPaid(balance.id, PlanItemPayment(date: day("2026-11-20")))

        #expect(try summary(s).plan.items.first?.isPaid == true)
        #expect(try summary(s).plan.pendingTotal == .zero)
    }

    @Test func anItemPaidInPartsCannotBeTickedAsAWhole() throws {
        let s = try started()
        let item = try tour(s)

        let error = #expect(throws: TripError.self) { try s.app.markTripPlanItemPaid(item.id) }

        #expect(error?.message == "This item is paid in parts. Tick each part instead.")
    }

    @Test func aPaidPartCannotBeChangedOrRemovedUntilUnticked() throws {
        let s = try started()
        try tour(s)
        let advance = try #require(try summary(s).plan.items.first?.payments.first)
        try s.app.markTripPlanPaymentPaid(advance.id)

        let error = #expect(throws: TripError.self) { try s.app.deleteTripPlanPayment(advance.id) }
        #expect(error?.message == "A part that is paid can't be changed. Untick it first.")
        #expect(throws: TripError.self) { try s.app.updateTripPlanPayment(advance.id, part("Advance", 25_000, due: nil)) }

        try s.app.unmarkTripPlanPaymentPaid(advance.id)
        try s.app.deleteTripPlanPayment(advance.id)
        #expect(try summary(s).expenses.isEmpty)
    }

    @Test func anItemAlreadyPaidCannotBeSplitIntoParts() throws {
        let s = try started()
        let item = try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(description: "Flights", amount: .rupees(9_000)))
        try s.app.markTripPlanItemPaid(item.id)

        let error = #expect(throws: TripError.self) { try s.app.addTripPlanPayment(item.id, part("Advance", 1_000, due: nil)) }

        #expect(error?.message == "Flights is already paid, so it can't be split into parts.")
    }

    @Test func removingEveryPartPutsTheItemBackToOneAmount() throws {
        let s = try started()
        let item = try tour(s)
        for payment in try #require(try summary(s).plan.items.first?.payments) { try s.app.deleteTripPlanPayment(payment.id) }

        let saved = try #require(try summary(s).plan.items.first)

        #expect(saved.payments.isEmpty)
        #expect(saved.amount == .rupees(80_000))
        try s.app.markTripPlanItemPaid(item.id)
    }

    @Test func aPartNeedsAnAmountAboveZero() throws {
        let s = try started()
        let item = try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(description: "Tour", amount: .rupees(100)))

        let error = #expect(throws: TripError.self) { try s.app.addTripPlanPayment(item.id, part("Advance", 0, due: nil)) }

        #expect(error?.message == "Enter an amount above 0")
    }

    @Test func partsCanBeGivenWhenTheItemIsFirstPlanned() throws {
        let s = try started()

        let item = try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(
            description: "Group tour", amount: nil, payments: [part("Advance", 20_000, due: "2026-11-25"), part("Balance", 60_000, due: nil)]
        ))

        #expect(item.payments.count == 2)
        #expect(item.amount == .rupees(80_000))
    }

    @Test func aSinglePaymentCanHaveADueDate() throws {
        let s = try started()

        let item = try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(
            description: "Visa", amount: .rupees(5_000), dueDate: day("2026-11-30")
        ))

        #expect(item.dueDate == day("2026-11-30"))
    }

    // MARK: reminders

    @Test func aPaymentDueSoonIsRemindedAndALaterOneIsNot() throws {
        let s = try started(today: "2026-11-20")
        try tour(s)

        let dues = try s.app.tripDues()

        #expect(dues.map(\.title) == ["Group tour · Advance"])
        #expect(dues.first?.daysUntil == 5)
        #expect(dues.first?.amount == .rupees(20_000))
    }

    @Test func aPaymentPastItsDateIsStillRemindedAndReadsOverdue() throws {
        let s = try started(today: "2026-11-27")
        try tour(s)

        let due = try #require(try s.app.tripDues().first)

        #expect(due.daysUntil == -2)
    }

    @Test func aSingleItemWithADueDateIsRemindedToo() throws {
        let s = try started()
        try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(description: "Visa", amount: .rupees(5_000), dueDate: day("2026-11-22")))

        #expect(try s.app.tripDues().map(\.title) == ["Visa"])
    }

    @Test func paidPaymentsAndPlanningOrSettledTripsDoNotRemind() throws {
        let s = try started()
        try tour(s)
        let advance = try #require(try summary(s).plan.items.first?.payments.first)
        try s.app.markTripPlanPaymentPaid(advance.id)
        let planned = try s.app.createTrip(NewTrip(name: "Plan only", category: "Lifestyle", isPlanning: true))
        try s.app.addTripPlanItem(planned.id, NewTripPlanItem(description: "Visa", amount: .rupees(5_000), dueDate: day("2026-11-22")))

        #expect(try s.app.tripDues().isEmpty)

        let item = try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(description: "Hotel", amount: .rupees(1), dueDate: day("2026-11-22")))
        #expect(try s.app.tripDues().map(\.itemID) == [item.id])
        try s.app.setTripSettled(s.trip.id, true)
        #expect(try s.app.tripDues().isEmpty)
    }

    @Test func theReminderWindowFollowsTheUpcomingDaysSetting() throws {
        let s = try started()
        try tour(s)
        try s.app.updatePreferences { $0.upcomingWindowDays = 30 }

        #expect(try s.app.tripDues().count == 1)
        try s.app.updatePreferences { $0.upcomingWindowDays = 60 }
        #expect(try s.app.tripDues().count == 2)
    }

    @Test func aForeignPaymentIsGivenInRupeesToo() throws {
        let s = try started(currency: true)
        try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(description: "Villa", amount: .rupees(1_000_000), dueDate: day("2026-11-25")))

        let due = try #require(try s.app.tripDues().first)

        #expect(due.amount == .rupees(1_000_000))
        #expect(due.amountHome == .rupees(5_300))
    }

    @Test func unpaidTripPaymentsComeOffTheThirtyDayLook() throws {
        let app = try makeApp(today: "2026-11-20")
        try app.addIncome(NewIncome(date: day("2026-07-01"), kind: .salary, amount: .rupees(100_000)))
        let trip = try app.createTrip(NewTrip(name: "Trek", category: "Lifestyle"))
        try app.startTrip(trip.id)
        try app.addTripPlanItem(trip.id, NewTripPlanItem(description: "Permit", amount: .rupees(10_000), dueDate: day("2026-11-25")))

        let forecast = try app.cashForecast()

        #expect(forecast.points[4] == .rupees(100_000))
        #expect(forecast.points[5] == .rupees(90_000))
        #expect(forecast.billsOut == .rupees(10_000))
    }

    // MARK: travel legs

    private func flights(_ s: (app: BudgetApp, trip: Trip), _ name: String = "Flights") throws -> TripPlanItem {
        try s.app.addTripPlanItem(s.trip.id, NewTripPlanItem(description: name, amount: .rupees(9_000)))
    }

    @Test func aLegKeepsModeRouteCarrierNumberAndTimesAndStartsAsPlanned() throws {
        let s = try started()
        let item = try flights(s)

        let leg = try s.app.addTripLeg(item.id, NewTripLeg(
            mode: .flight, from: "Delhi", to: "Denpasar", carrier: "IndiGo", number: "6E 1175", departure: day("2026-12-10"),
            departureMinutes: 6 * 60 + 40, arrivalDate: day("2026-12-10"), arrivalMinutes: 15 * 60 + 5
        ))

        #expect(leg.mode == .flight)
        #expect(leg.carrier == "IndiGo")
        #expect(leg.number == "6E 1175")
        #expect(leg.departureMinutes == 400)
        #expect(leg.arrivalMinutes == 905)
        #expect(!leg.isBooked)
        let saved = try #require(try summary(s).plan.items.first?.legs.first)
        #expect(saved == leg)
    }

    @Test func aLegCanBeMarkedBookedAndChangedAndRemoved() throws {
        let s = try started()
        let item = try flights(s)
        let leg = try s.app.addTripLeg(item.id, NewTripLeg(from: "Delhi", to: "Denpasar"))

        try s.app.updateTripLeg(leg.id, NewTripLeg(from: "Delhi", to: "Bali", number: "6E 1175", isBooked: true))
        let changed = try #require(try summary(s).plan.items.first?.legs.first)
        #expect(changed.to == "Bali")
        #expect(changed.isBooked)

        try s.app.deleteTripLeg(leg.id)
        #expect(try summary(s).plan.items.first?.legs.isEmpty == true)
    }

    @Test func theItineraryListsEveryLegByDateAndTimeWithItsItemAndUndatedLast() throws {
        let s = try started()
        let onward = try flights(s, "Onward")
        let back = try flights(s, "Return")
        try s.app.addTripLeg(back.id, NewTripLeg(from: "Denpasar", to: "Delhi", departure: day("2026-12-18"), departureMinutes: 600))
        try s.app.addTripLeg(onward.id, NewTripLeg(mode: .train, from: "Dehradun", to: "Delhi", departure: day("2026-12-09"), departureMinutes: 1_300))
        try s.app.addTripLeg(onward.id, NewTripLeg(from: "Delhi", to: "Denpasar", departure: day("2026-12-10"), departureMinutes: 400))
        try s.app.addTripLeg(onward.id, NewTripLeg(from: "Somewhere", to: "Else"))

        let itinerary = try summary(s).plan.itinerary

        #expect(itinerary.map(\.from) == ["Dehradun", "Delhi", "Denpasar", "Somewhere"])
        #expect(itinerary.map(\.itemName) == ["Onward", "Onward", "Return", "Onward"])
    }

    @Test func aLegCannotArriveBeforeItLeaves() throws {
        let s = try started()
        let item = try flights(s)

        let error = #expect(throws: TripError.self) {
            try s.app.addTripLeg(item.id, NewTripLeg(
                from: "A", to: "B", departure: day("2026-12-10"), departureMinutes: 600, arrivalDate: day("2026-12-10"), arrivalMinutes: 540
            ))
        }

        #expect(error?.message == "The leg can't arrive before it leaves.")
    }

    @Test func aTimeMustBeInsideTheDay() throws {
        let s = try started()
        let item = try flights(s)

        let error = #expect(throws: TripError.self) {
            try s.app.addTripLeg(item.id, NewTripLeg(from: "A", to: "B", departure: day("2026-12-10"), departureMinutes: 25 * 60))
        }

        #expect(error?.message == "Enter a time between 00:00 and 23:59")
    }

    @Test func legsAreRemovedWithTheirItem() throws {
        let s = try started()
        let item = try flights(s)
        try s.app.addTripLeg(item.id, NewTripLeg(from: "A", to: "B"))

        try s.app.deleteTripPlanItem(item.id)

        #expect(try summary(s).plan.itinerary.isEmpty)
    }
}
