import Foundation
import Testing
@testable import HisaabCore

/// Trip cash, tags, notes and receipts, the settled mark, and what the insights show.
struct TripExtrasTests {
    // MARK: trip cash

    @Test func settingTripCashRecordsAnAdjustment() throws {
        let b = try bali()

        try b.app.setTripCash(b.trip.id, to: .rupees(50_000))

        let cash = try b.summary().cash
        #expect(cash.balance == .rupees(50_000))
        #expect(cash.lines.map(\.kind) == [.adjustment])
        #expect(cash.lines.first?.amount == .rupees(50_000))
    }

    @Test func settingTripCashAgainRecordsOnlyTheDifference() throws {
        let b = try bali()
        try b.app.setTripCash(b.trip.id, to: .rupees(50_000))

        try b.app.setTripCash(b.trip.id, to: .rupees(30_000))

        #expect(try b.summary().cash.lines.map(\.amount) == [.rupees(50_000), .rupees(-20_000)])
        try b.app.setTripCash(b.trip.id, to: .rupees(30_000))
        #expect(try b.summary().cash.lines.count == 2)
    }

    @Test func tripCashHistoryHasARunningBalanceOldestFirst() throws {
        let b = try bali()
        try b.app.setTripCash(b.trip.id, to: .rupees(50_000))
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)
        try b.app.recordTripSettlement(
            b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(100_000), method: .cashTrip, on: day("2026-10-31")
        )

        let lines = try b.summary().cash.lines

        #expect(lines.map(\.description) == ["Adjustment", "Raj paid me"])
        #expect(lines.map(\.runningBalance) == [.rupees(50_000), .rupees(150_000)])
    }

    @Test func spendingMoreCashThanRecordedWarnsButStillSaves() throws {
        let b = try bali()
        try b.app.setTripCash(b.trip.id, to: .rupees(50_000))

        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Warung", amount: .rupees(120_000), paidWith: .cash, split: .equal([.me])
        ))

        let cash = try b.summary().cash
        #expect(cash.balance == .rupees(-70_000))
        #expect(cash.warning == "You have spent \(IndianMoneyFormat.plain(.rupees(70_000))) more cash than you have recorded.")
    }

    @Test func aHomeCurrencyTripHasNoTripCash() throws {
        let g = try goa()

        let error = #expect(throws: TripError.self) { try g.app.setTripCash(g.trip.id, to: .rupees(100)) }

        #expect(error?.message == "This trip is in your home currency, so it uses your main Cash in Hand.")
        #expect(try g.app.tripSummary(g.trip.id).cash.lines.isEmpty)
    }

    @Test func tripCashCannotBeSetBelowZero() throws {
        let b = try bali()

        #expect(throws: TripError.amountMissingOrZero) { try b.app.setTripCash(b.trip.id, to: .rupees(-1)) }
        #expect(throws: TripError.amountMissingOrZero) { try b.app.setTripCash(b.trip.id, to: nil) }
    }

    // MARK: tags

    @Test func theEightDefaultTagsComeFirst() throws {
        let app = try makeApp()

        let tags = try app.tripTags()

        #expect(tags.map(\.name) == ["Food", "Stay", "Transport", "Activities", "Shopping", "Drinks", "Tickets", "Other"])
        #expect(tags.allSatisfy { $0.isDefault })
    }

    @Test func aTypedTagIsRememberedForEveryTrip() throws {
        let b = try bali()

        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Massage", amount: .rupees(300_000), split: .equal([.me]), tag: "Massage"
        ))

        let other = try b.app.createTrip(NewTrip(name: "Goa", category: "Lifestyle"))
        _ = other
        let tags = try b.app.tripTags()
        #expect(tags.last == TripTag(name: "Massage", isDefault: false))
        #expect(tags.count == 9)
    }

    @Test func typingADefaultTagAgainOrInAnotherCaseAddsNothing() throws {
        let app = try makeApp()

        try app.addTripTag("food")
        try app.addTripTag("Massage")
        try app.addTripTag("massage")

        #expect(try app.tripTags().count == 9)
        #expect(throws: TripError.tagMissing) { try app.addTripTag("  ") }
    }

    @Test func myOwnTagCanBeDeletedButADefaultStays() throws {
        let app = try makeApp()
        try app.addTripTag("Massage")

        try app.deleteTripTag("Massage")

        #expect(try app.tripTags().count == 8)
        let error = #expect(throws: TripError.self) { try app.deleteTripTag("Food") }
        #expect(error?.message == "Food is a default tag and stays")
    }

    // MARK: notes and receipts

    @Test func anExpenseKeepsItsNoteTagAndReceiptPhoto() throws {
        let b = try bali()
        let photo = Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3])

        let saved = try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Dinner", amount: .rupees(400_000), split: .equal(b.everyone), tag: "Food",
            note: "  Seafood set + drinks ", receipt: photo
        ))

        #expect(saved.tag == "Food")
        #expect(saved.note == "Seafood set + drinks")
        #expect(saved.hasReceipt)
        #expect(try b.app.tripReceipt(saved.id) == photo)
    }

    @Test func aReceiptCanBeAddedReplacedAndRemoved() throws {
        let b = try bali()
        let saved = try b.iPaid("Dinner", idr: 400_000)
        #expect(!saved.hasReceipt)

        try b.app.setTripReceipt(saved.id, Data([1, 2, 3]))
        try b.app.setTripReceipt(saved.id, Data([4, 5]))
        #expect(try b.app.tripReceipt(saved.id) == Data([4, 5]))
        #expect(try b.summary().expenses.first?.hasReceipt == true)

        try b.app.setTripReceipt(saved.id, nil)
        #expect(try b.app.tripReceipt(saved.id) == nil)
        #expect(try b.summary().expenses.first?.hasReceipt == false)
    }

    @Test func editingAnExpenseKeepsItsReceipt() throws {
        let b = try bali()
        let saved = try b.iPaid("Dinner", idr: 400_000)
        try b.app.setTripReceipt(saved.id, Data([1, 2, 3]))

        let edited = try b.app.updateTripExpense(saved.id, NewTripExpense(
            description: "Dinner at Jimbaran", amount: .rupees(450_000), split: .equal(b.everyone), note: "Added drinks"
        ))

        #expect(edited.description == "Dinner at Jimbaran")
        #expect(edited.note == "Added drinks")
        #expect(edited.hasReceipt)
        #expect(try b.owes(b.ana) == Money(paise: 11_250_000))
    }

    @Test func deletingAnExpenseDeletesItsReceipt() throws {
        let b = try bali()
        let saved = try b.iPaid("Dinner", idr: 400_000)
        try b.app.setTripReceipt(saved.id, Data([1, 2, 3]))

        try b.app.deleteTripExpense(saved.id)

        #expect(try b.app.tripReceipt(saved.id) == nil)
    }

    // MARK: settled

    @Test func aTripCanBeMarkedSettledAndUndone() throws {
        let b = try bali()
        let goa = try b.app.createTrip(NewTrip(name: "Goa", category: "Lifestyle"))

        try b.app.setTripSettled(b.trip.id, true)

        #expect(try b.app.trips().map(\.trip.name) == ["Goa", "Bali trip"])
        #expect(try b.app.trips().last?.trip.isSettled == true)
        try b.app.setTripSettled(b.trip.id, false)
        #expect(try b.app.trips().map(\.trip.name) == ["Bali trip", "Goa"])
        _ = goa
    }

    @Test func markingAMissingTripSettledIsRefused() throws {
        let app = try makeApp()

        #expect(throws: TripError.notFound(42)) { try app.setTripSettled(42, true) }
    }

    // MARK: the trips list and insights

    @Test func theTripsListShowsWhatEachTripCostsAndWhoOwes() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)

        let row = try #require(try b.app.trips().first)

        #expect(row.netCost == .rupees(2_150))
        #expect(row.ledgerAmount == .rupees(2_150))
        #expect(row.balances.map(\.owesMe) == [.rupees(100_000), .rupees(100_000), .rupees(100_000)])
    }

    @Test func spendByTagAddsUpPerTagBiggestFirst() throws {
        let b = try bali()
        try b.app.addTripExpense(b.trip.id, NewTripExpense(description: "Dinner", amount: .rupees(400_000), split: .equal([.me]), tag: "Food"))
        try b.app.addTripExpense(b.trip.id, NewTripExpense(description: "Lunch", amount: .rupees(100_000), split: .equal([.me]), tag: "Food"))
        try b.app.addTripExpense(b.trip.id, NewTripExpense(description: "Scooter", amount: .rupees(300_000), split: .equal([.me]), tag: "Transport"))

        let spend = try b.summary().spendByTag

        #expect(spend == [TagSpend(tag: "Food", amount: .rupees(500_000)), TagSpend(tag: "Transport", amount: .rupees(300_000))])
    }

    @Test func eachPersonsPaidAndShareAreTotalled() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000)
        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Scooter", amount: .rupees(300_000), paidBy: .person(b.ana.id), split: .equal([.me, .person(b.ana.id)])
        ))

        let totals = try b.summary().totals

        #expect(totals.first { $0.participant == .me } == ParticipantTotal(participant: .me, paid: .rupees(400_000), share: .rupees(250_000)))
        #expect(totals.first { $0.participant == .person(b.ana.id) } == ParticipantTotal(
            participant: .person(b.ana.id), paid: .rupees(300_000), share: .rupees(250_000)
        ))
    }

    @Test func theTotalsOfAHomeTripNeedNoRate() throws {
        let g = try goa()
        try g.app.addTripExpense(g.trip.id, NewTripExpense(description: "Villa", amount: .rupees(5_622), split: .equal([.me, .person(g.ana.id)])))

        let summary = try g.app.tripSummary(g.trip.id)

        #expect(summary.totalSpentHome == .rupees(5_622))
        #expect(summary.myShareHome == .rupees(2_811))
    }

    // MARK: trip details

    @Test func aTripNeedsANameAndACategoryAndARateForAForeignCurrency() throws {
        let app = try makeApp()

        #expect(throws: TripError.nameMissing) { try app.createTrip(NewTrip(name: " ", category: "Lifestyle")) }
        #expect(throws: TripError.categoryMissing) { try app.createTrip(NewTrip(name: "Bali", category: "")) }
        #expect(throws: TripError.rateMissing) { try app.createTrip(NewTrip(name: "Bali", currency: "IDR", category: "Lifestyle")) }
        #expect(throws: TripError.rateNotPositive) {
            try app.createTrip(NewTrip(name: "Bali", currency: "IDR", rate: 0, category: "Lifestyle"))
        }
    }

    @Test func changingTheRateUpdatesTheRupeesShownBesideBalances() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000)

        try b.app.updateTrip(b.trip.id, NewTrip(
            name: "Bali trip", currency: "IDR", rate: Decimal(string: "0.006")!, category: "Lifestyle", subCategory: "Vacation"
        ))

        #expect(try b.summary().balances.first?.owesMeHome == .rupees(600))
    }

    @Test func updatingAMissingTripIsRefused() throws {
        let app = try makeApp()

        #expect(throws: TripError.notFound(7)) { try app.updateTrip(7, NewTrip(name: "x", category: "Lifestyle")) }
    }
}
