import Foundation
import Testing
@testable import HisaabCore

/// People and groups belong to one trip; every split adds up to the amount to the paisa.
struct TripPeopleAndSplitTests {
    // MARK: people

    @Test func peopleBelongToOneTrip() throws {
        let b = try bali()

        let goa = try b.app.createTrip(NewTrip(name: "Goa weekend", category: "Lifestyle"))

        #expect(try b.app.people(goa.id).isEmpty)
        #expect(try b.app.people(b.trip.id).map(\.name) == ["Ana", "Raj", "Mira"])
        #expect(try b.app.addPerson(goa.id, "Ana").tripID == goa.id)
    }

    @Test func aNameIsAddedOnceToATripWhateverTheCase() throws {
        let b = try bali()

        let error = #expect(throws: TripError.self) { try b.app.addPerson(b.trip.id, "ana") }

        #expect(error?.message == "A person called Ana is already in this trip")
        #expect(throws: TripError.personNameMissing) { try b.app.addPerson(b.trip.id, "  ") }
    }

    @Test func aPersonWithExpensesCannotBeRemoved() throws {
        let b = try bali()
        try b.iPaid("Dinner", idr: 400_000)

        let error = #expect(throws: TripError.self) { try b.app.deletePerson(b.trip.id, b.ana.id) }

        #expect(error?.message == "Ana has expenses or payments in this trip.")
    }

    @Test func aPersonWithNothingCanBeRemoved() throws {
        let b = try bali()

        try b.app.deletePerson(b.trip.id, b.mira.id)

        #expect(try b.app.people(b.trip.id).map(\.name) == ["Ana", "Raj"])
    }

    // MARK: groups

    @Test func aGroupRemembersWhoIsInIt() throws {
        let b = try bali()

        let group = try b.app.saveTripGroup(b.trip.id, name: "Daily people", members: b.everyone)

        #expect(group.members == b.everyone)
        #expect(try b.summary().groups == [group])
    }

    @Test func aGroupCanBeChangedAndDeleted() throws {
        let b = try bali()
        let group = try b.app.saveTripGroup(b.trip.id, name: "Daily people", members: b.everyone)

        try b.app.saveTripGroup(b.trip.id, id: group.id, name: "Dinner crew", members: [.me, .person(b.ana.id)])

        #expect(try b.summary().groups.map(\.name) == ["Dinner crew"])
        #expect(try b.summary().groups.first?.members == [.me, .person(b.ana.id)])
        try b.app.deleteTripGroup(group.id)
        #expect(try b.summary().groups.isEmpty)
    }

    @Test func aGroupNeedsAUniqueNameAndPeopleFromThisTrip() throws {
        let b = try bali()
        try b.app.saveTripGroup(b.trip.id, name: "Daily people", members: [.me])
        let elsewhere = try b.app.createTrip(NewTrip(name: "Goa", category: "Lifestyle"))
        let stranger = try b.app.addPerson(elsewhere.id, "Dev")

        #expect(throws: TripError.groupNameTaken("Daily people")) {
            try b.app.saveTripGroup(b.trip.id, name: "daily people", members: [.me])
        }
        #expect(throws: TripError.groupNameMissing) { try b.app.saveTripGroup(b.trip.id, name: " ", members: [.me]) }
        #expect(throws: TripError.nobodySharing) { try b.app.saveTripGroup(b.trip.id, name: "Empty", members: []) }
        #expect(throws: TripError.notAMember("Someone")) {
            try b.app.saveTripGroup(b.trip.id, name: "Mixed", members: [.person(stranger.id)])
        }
    }

    @Test func removingAPersonTakesThemOutOfGroups() throws {
        let b = try bali()
        try b.app.saveTripGroup(b.trip.id, name: "Daily people", members: b.everyone)

        try b.app.deletePerson(b.trip.id, b.mira.id)

        #expect(try b.summary().groups.first?.members == [.me, .person(b.ana.id), .person(b.raj.id)])
    }

    // MARK: splits

    private func shares(_ b: Bali, _ split: SplitMethod, amount: Money = .rupees(300_000)) throws -> [Participant: Money] {
        try b.app.addTripExpense(b.trip.id, NewTripExpense(description: "Dinner", amount: amount, split: split)).shares
    }

    @Test func equalSplitGivesTheOddPaiseToTheFirstPeople() throws {
        let b = try bali()
        let people: Set<Participant> = [.me, .person(b.ana.id), .person(b.raj.id)]

        let result = try shares(b, .equal(people), amount: Money(paise: 10_000_001))

        #expect(result[.me] == Money(paise: 3_333_334))
        #expect(result[.person(b.ana.id)] == Money(paise: 3_333_334))
        #expect(result[.person(b.raj.id)] == Money(paise: 3_333_333))
    }

    @Test func sharesSplitInProportion() throws {
        let b = try bali()

        let result = try shares(b, .shares([.me: 1, .person(b.ana.id): 2]))

        #expect(result[.me] == .rupees(100_000))
        #expect(result[.person(b.ana.id)] == .rupees(200_000))
    }

    @Test func everyoneNeedsAtLeastOneShare() throws {
        let b = try bali()

        #expect(throws: TripError.sharesInvalid) { try shares(b, .shares([.me: 1, .person(b.ana.id): 0])) }
    }

    @Test func exactAmountsMustAddUp() throws {
        let b = try bali()

        let error = #expect(throws: TripError.self) {
            try shares(b, .exact([.me: .rupees(100_000), .person(b.ana.id): .rupees(100_000)]))
        }

        #expect(error?.message == "The shares must add up to \(IndianMoneyFormat.plain(.rupees(300_000)))")
        let fine = try shares(b, .exact([.me: .rupees(100_000), .person(b.ana.id): .rupees(200_000)]))
        #expect(fine[.person(b.ana.id)] == .rupees(200_000))
    }

    @Test func percentagesMustReachOneHundredAndAddUpToTheAmount() throws {
        let b = try bali()

        #expect(throws: TripError.percentagesMismatch) { try shares(b, .percentage([.me: 50, .person(b.ana.id): 40])) }
        let result = try shares(b, .percentage([.me: 50, .person(b.ana.id): 30, .person(b.raj.id): 20]), amount: .rupees(1_000))
        #expect(result[.me] == .rupees(500))
        #expect(result[.person(b.ana.id)] == .rupees(300))
        #expect(result[.person(b.raj.id)] == .rupees(200))
    }

    @Test func itemsAreSharedByTheirOwnPeopleAndTaxFollowsWhatEachOrdered() throws {
        let b = try bali()
        let split = SplitMethod.items([
            SplitItem(name: "Grilled fish", amount: .rupees(180_000), people: [.me, .person(b.ana.id), .person(b.raj.id)]),
            SplitItem(name: "Cocktails", amount: .rupees(120_000), people: [.person(b.ana.id), .person(b.raj.id)]),
            SplitItem(name: "Juice", amount: .rupees(40_000), people: [.person(b.mira.id)]),
        ], extra: .rupees(60_000))

        let result = try shares(b, split, amount: .rupees(400_000))

        #expect(result.values.reduce(Money.zero, +) == .rupees(400_000))
        #expect(result[.person(b.ana.id)] == result[.person(b.raj.id)])
        #expect(result[.person(b.ana.id)] == Money(paise: 14_117_647))
        #expect(result[.person(b.mira.id)] == Money(paise: 4_705_882))
        #expect(result[.me] == Money(paise: 7_058_824))
    }

    @Test func itemsThatDoNotAddUpToTheBillAreRefused() throws {
        let b = try bali()
        let split = SplitMethod.items([SplitItem(name: "Fish", amount: .rupees(100_000), people: [.me])], extra: .rupees(10_000))

        let error = #expect(throws: TripError.self) { try shares(b, split, amount: .rupees(400_000)) }

        #expect(error?.message == "The items and extra must add up to \(IndianMoneyFormat.plain(.rupees(400_000)))")
    }

    @Test func anItemNobodyShareIsRefused() throws {
        let b = try bali()
        let split = SplitMethod.items([SplitItem(name: "Fish", amount: .rupees(300_000), people: [])], extra: .zero)

        #expect(throws: TripError.nobodySharing) { try shares(b, split) }
    }

    @Test func someoneFromAnotherTripCannotShare() throws {
        let b = try bali()
        let elsewhere = try b.app.createTrip(NewTrip(name: "Goa", category: "Lifestyle"))
        let stranger = try b.app.addPerson(elsewhere.id, "Dev")

        #expect(throws: TripError.notAMember("Someone")) { try shares(b, .equal([.me, .person(stranger.id)])) }
    }

    @Test func nobodySharingIsRefused() throws {
        let b = try bali()

        #expect(throws: TripError.nobodySharing) { try shares(b, .equal([])) }
    }
}
