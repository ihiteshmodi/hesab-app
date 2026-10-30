import Foundation
import Testing
@testable import HisaabCore

/// Debts are kept in the trip currency; payments clear them at an editable rate and keep what was really received.
struct TripSettlementTests {
    /// I paid IDR 400,000 split four ways, so each friend owes IDR 100,000.
    private func dinner() throws -> Bali {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150)
        return b
    }

    @Test func aBalanceIsKeptInTheTripCurrencyAndShownInRupees() throws {
        let b = try dinner()

        let balance = try #require(try b.summary().balances.first { $0.person == b.ana })

        #expect(balance.owesMe == .rupees(100_000))
        #expect(balance.owesMeHome == .rupees(530))
    }

    @Test func rupeesClearTheBalanceAtTheTripRateAndTheRupeesStayAsReceived() throws {
        let b = try dinner()

        let payment = try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(265), method: .bank)

        #expect(payment.cleared == .rupees(50_000))
        #expect(payment.received == .rupees(265))
        #expect(try b.owes(b.ana) == .rupees(50_000))
        #expect(try b.summary().receivedBankHome == .rupees(265))
    }

    @Test func aPaymentCanUseAnAgreedRate() throws {
        let b = try dinner()

        let payment = try b.app.recordTripSettlement(
            b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(500), method: .bank, atRate: Decimal(string: "0.005")!
        )

        #expect(payment.cleared == .rupees(100_000))
        #expect(try b.owes(b.ana) == .zero)
    }

    @Test func aRateOfZeroIsRefused() throws {
        let b = try dinner()

        #expect(throws: TripError.rateNotPositive) {
            try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(530), method: .bank, atRate: 0)
        }
    }

    @Test func cashInTheTripCurrencyClearsThatMuch() throws {
        let b = try dinner()

        let payment = try b.app.recordTripSettlement(b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(60_000), method: .cashTrip)

        #expect(payment.cleared == .rupees(60_000))
        #expect(try b.owes(b.raj) == .rupees(40_000))
        #expect(try b.summary().receivedCashTrip == .rupees(60_000))
    }

    @Test func iCanPayAFriendBack() throws {
        let b = try bali()
        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Hotel", amount: .rupees(200_000), paidBy: .person(b.ana.id), split: .equal([.me, .person(b.ana.id)])
        ))

        try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .iPaidThem, .rupees(530), method: .bank)

        #expect(try b.owes(b.ana) == .zero)
        #expect(try b.summary().receivedBankHome == .rupees(-530))
    }

    // MARK: settling in full

    @Test func payingALittleLessInFullIsACost() throws {
        let b = try bali()
        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Spa", amount: .rupees(200_000), split: .equal([.me, .person(b.raj.id)])
        ))

        let payment = try b.app.recordTripSettlement(
            b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(529), method: .bank, fullSettlement: true
        )

        #expect(payment.cleared == .rupees(100_000))
        #expect(payment.writtenOff == Money(paise: 18_868))
        #expect(try b.owes(b.raj) == .zero)
        #expect(try b.summary().writtenOffHome == .rupees(1))
        #expect(try b.summary().extraReceivedHome == .zero)
    }

    @Test func twoThousandEightHundredElevenSettledByTwoThousandEightHundredTenIsAOneRupeeCost() throws {
        let g = try goa()
        try g.app.addTripExpense(g.trip.id, NewTripExpense(
            description: "Villa", amount: .rupees(5_622), split: .equal([.me, .person(g.ana.id)])
        ))

        let payment = try g.app.recordTripSettlement(g.trip.id, personID: g.ana.id, .theyPaidMe, .rupees(2_810), fullSettlement: true)

        #expect(payment.cleared == .rupees(2_811))
        #expect(payment.writtenOff == .rupees(1))
        #expect(try g.app.tripSummary(g.trip.id).writtenOffHome == .rupees(1))
        #expect(try ledgerEntry(g.app, named: "Goa weekend expenses") == .rupees(2_812))
    }

    @Test func payingALittleMoreInFullIsAGain() throws {
        let g = try goa()
        try g.app.addTripExpense(g.trip.id, NewTripExpense(
            description: "Cabin", amount: .rupees(2_010), split: .equal([.me, .person(g.dev.id)])
        ))

        let payment = try g.app.recordTripSettlement(g.trip.id, personID: g.dev.id, .theyPaidMe, .rupees(1_009), fullSettlement: true)

        #expect(payment.cleared == .rupees(1_005))
        #expect(payment.writtenOff == .rupees(-4))
        let summary = try g.app.tripSummary(g.trip.id)
        #expect(summary.balances.first?.owesMe == .zero)
        #expect(summary.extraReceivedHome == .rupees(4))
        #expect(summary.writtenOffHome == .zero)
        #expect(summary.ledgerAmount == .rupees(2_010 - 1_009))
    }

    @Test func aFullSettlementCanClearWhatIOweToo() throws {
        let g = try goa()
        try g.app.addTripExpense(g.trip.id, NewTripExpense(
            description: "Villa", amount: .rupees(600), paidBy: .person(g.ana.id), split: .equal([.me, .person(g.ana.id)])
        ))

        let payment = try g.app.recordTripSettlement(g.trip.id, personID: g.ana.id, .iPaidThem, .rupees(299), fullSettlement: true)

        #expect(payment.cleared == .rupees(300))
        #expect(payment.writtenOff == .rupees(1))
        #expect(try g.app.tripSummary(g.trip.id).balances.first?.owesMe == .zero)
    }

    @Test func aFullSettlementWithNothingOwedIsRefused() throws {
        let b = try dinner()
        try b.app.recordTripSettlement(b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(100_000), method: .cashTrip)

        let error = #expect(throws: TripError.self) {
            try b.app.recordTripSettlement(b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(10), method: .bank, fullSettlement: true)
        }

        #expect(error?.message == "There is nothing to settle with Raj.")
    }

    @Test func anAmountIsRequired() throws {
        let b = try dinner()

        #expect(throws: TripError.amountMissingOrZero) {
            try b.app.recordTripSettlement(b.trip.id, personID: b.raj.id, .theyPaidMe, nil)
        }
    }

    @Test func tripCashOnAHomeTripCountsAsRupeeNotes() throws {
        let g = try goa()
        try g.app.addTripExpense(g.trip.id, NewTripExpense(
            description: "Villa", amount: .rupees(600), split: .equal([.me, .person(g.ana.id)])
        ))

        let payment = try g.app.recordTripSettlement(g.trip.id, personID: g.ana.id, .theyPaidMe, .rupees(300), method: .cashTrip)

        #expect(payment.method == .cashHome)
        #expect(try g.app.cashInHand().balance == .rupees(300))
    }

    @Test func aPaymentDefaultsToTodayButCanBeLoggedForAnotherDay() throws {
        let b = try dinner()

        let today = try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(100), method: .cashTrip)
        let earlier = try b.app.recordTripSettlement(
            b.trip.id, personID: b.raj.id, .theyPaidMe, .rupees(200), method: .cashTrip, on: day("2026-10-14")
        )

        #expect(today.date == day("2026-10-30"))
        #expect(earlier.date == day("2026-10-14"))
        #expect(try b.summary().cash.lines.map(\.date) == [day("2026-10-14"), day("2026-10-30")])
    }

    @Test func undoingAFullSettlementRestoresTheBalanceAndTheWriteOff() throws {
        let b = try dinner()
        let payment = try b.app.recordTripSettlement(
            b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(529), method: .bank, fullSettlement: true
        )

        try b.app.deleteTripSettlement(payment.id)

        #expect(try b.owes(b.ana) == .rupees(100_000))
        #expect(try b.summary().writtenOffHome == .zero)
    }

    @Test func aPaymentToSomeoneNotInTheTripIsRefused() throws {
        let b = try dinner()
        let elsewhere = try b.app.createTrip(NewTrip(name: "Goa", category: "Lifestyle"))
        let stranger = try b.app.addPerson(elsewhere.id, "Dev")

        #expect(throws: TripError.notAMember("That person")) {
            try b.app.recordTripSettlement(b.trip.id, personID: stranger.id, .theyPaidMe, .rupees(10))
        }
    }

    // MARK: one person's page

    @Test func aPersonsPageListsEveryEntryBehindTheBalance() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000, card: 2_150, date: "2026-10-12")
        try b.app.addTripExpense(b.trip.id, NewTripExpense(
            description: "Scooter", date: day("2026-10-13"), amount: .rupees(300_000), paidBy: .person(b.ana.id),
            split: .equal([.me, .person(b.ana.id)])
        ))
        try b.app.recordTripSettlement(b.trip.id, personID: b.ana.id, .theyPaidMe, .rupees(265), method: .bank, on: day("2026-10-14"))

        let page = try b.app.tripPersonStatement(b.trip.id, b.ana.id)

        #expect(page.lines.map(\.title) == ["Dinner", "Scooter", "Paid me"])
        #expect(page.lines.map(\.amount) == [.rupees(100_000), .rupees(-150_000), .rupees(-50_000)])
        #expect(page.lines.map(\.kind) == [.iPaid, .theyPaid, .payment])
        #expect(page.owesMe == .rupees(-100_000))
        #expect(page.owesMe == page.lines.reduce(.zero) { $0 + $1.amount })
    }

    @Test func aPageForAStrangerIsRefused() throws {
        let b = try bali()

        #expect(throws: TripError.notAMember("That person")) { try b.app.tripPersonStatement(b.trip.id, 9_999) }
    }
}
