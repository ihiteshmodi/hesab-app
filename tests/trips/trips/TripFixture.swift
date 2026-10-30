import Foundation
@testable import HisaabCore

/// A trip to Bali in IDR at 0.0053 rupees per rupiah, with three friends in it.
struct Bali {
    let app: BudgetApp
    let trip: Trip
    let ana: Person
    let raj: Person
    let mira: Person

    var everyone: Set<Participant> { [.me, .person(ana.id), .person(raj.id), .person(mira.id)] }

    func summary() throws -> TripSummary { try app.tripSummary(trip.id) }

    func owes(_ person: Person) throws -> Money {
        try summary().balances.first { $0.person == person }!.owesMe
    }

    /// An expense I paid, split equally between everyone, charged to the card at `card` rupees.
    @discardableResult
    func iPaid(_ description: String, idr: Int, card: Int? = nil, date: String = "2026-10-12") throws -> TripExpense {
        try app.addTripExpense(trip.id, NewTripExpense(
            description: description, date: day(date), amount: .rupees(idr), split: .equal(everyone), paidInHome: card.map { .rupees($0) }
        ))
    }
}

func bali(rate: String = "0.0053") throws -> Bali {
    let app = try makeApp()
    let trip = try app.createTrip(NewTrip(
        name: "Bali trip", currency: "IDR", rate: Decimal(string: rate)!, category: "Lifestyle", subCategory: "Vacation"
    ))
    return Bali(
        app: app, trip: trip, ana: try app.addPerson(trip.id, "Ana"), raj: try app.addPerson(trip.id, "Raj"),
        mira: try app.addPerson(trip.id, "Mira")
    )
}

/// A trip in the home currency with two friends.
struct Goa {
    let app: BudgetApp
    let trip: Trip
    let ana: Person
    let dev: Person
}

func goa() throws -> Goa {
    let app = try makeApp()
    let trip = try app.createTrip(NewTrip(name: "Goa weekend", category: "Lifestyle"))
    return Goa(app: app, trip: trip, ana: try app.addPerson(trip.id, "Ana"), dev: try app.addPerson(trip.id, "Dev"))
}

/// The one entry a trip puts in the main ledger, if it has one.
func ledgerEntry(_ app: BudgetApp, named name: String, in month: CalendarDate.YearMonth = .init(year: 2026, month: 10)) throws -> Money? {
    try app.monthBudget(for: month).expenses.first { $0.description == name }?.amount
}
