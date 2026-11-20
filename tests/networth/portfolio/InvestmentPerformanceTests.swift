import Foundation
import Testing
@testable import HisaabCore

/// Scenarios from tests/networth/portfolio/investment-performance.feature
struct InvestmentPerformanceTests {
    private func holding(_ app: BudgetApp, _ name: String) throws -> HoldingLine {
        try #require(try app.portfolio().holdings.first { $0.holding.name == name })
    }

    @discardableResult
    private func add(_ app: BudgetApp, _ name: String, paid: Int?, now: Int, currency: String? = nil, rate: String? = nil) throws -> Int64 {
        try app.addHolding(NewHolding(
            name: name, amount: .rupees(now), currency: currency, rate: rate.flatMap { Decimal(string: $0) }, invested: paid.map { .rupees($0) }
        ))
        return try holding(app, name).holding.id
    }

    @Test func aHoldingThatGainedShowsTheGainAndPercent() throws {
        let app = try makeApp()
        try add(app, "Index fund", paid: 10_000, now: 12_500)

        let line = try holding(app, "Index fund")

        #expect(line.holding.gain == .rupees(2_500))
        #expect(line.holding.gainPercentTenths == 250)
    }

    @Test func aHoldingThatLostShowsTheLossAndPercent() throws {
        let app = try makeApp()
        try add(app, "Stock A", paid: 10_000, now: 9_000)

        let line = try holding(app, "Stock A")

        #expect(line.holding.gain == .rupees(-1_000))
        #expect(line.holding.gainPercentTenths == -100)
    }

    @Test func aHoldingWithoutWhatWasPaidShowsNoGainAndIsLeftOutOfTheTotals() throws {
        let app = try makeApp()
        try add(app, "Gold", paid: nil, now: 50_000)

        let portfolio = try app.portfolio()

        #expect(portfolio.holdings.first?.holding.gain == nil)
        #expect(portfolio.holdings.first?.holding.gainPercentTenths == nil)
        #expect(portfolio.performance == nil)
    }

    @Test func trackedHoldingsAreTotalledTogether() throws {
        let app = try makeApp()
        try add(app, "Index fund", paid: 10_000, now: 12_500)
        try add(app, "Stock A", paid: 10_000, now: 9_000)
        try add(app, "Gold", paid: nil, now: 50_000)

        let performance = try #require(try app.portfolio().performance)

        #expect(performance.invested == .rupees(20_000))
        #expect(performance.value == .rupees(21_500))
        #expect(performance.gain == .rupees(1_500))
        #expect(performance.gainPercentTenths == 75)
    }

    @Test func aForeignHoldingIsUpOrDownInItsCurrencyAndInRupees() throws {
        let app = try makeApp()
        try add(app, "US stocks", paid: 400, now: 440, currency: "USD", rate: "90")

        let line = try holding(app, "US stocks")

        #expect(line.holding.gain == .rupees(40))
        #expect(line.holding.gainPercentTenths == 100)
        #expect(line.gainInHome == .rupees(3_600))
        #expect(try app.portfolio().performance?.gain == .rupees(3_600))
    }

    @Test func updatingWhatItIsWorthChangesTheGainAndIsRemembered() throws {
        let app = try makeApp()
        let id = try add(app, "Index fund", paid: 10_000, now: 12_500)

        try app.updateHolding(id, NewHolding(name: "Index fund", amount: .rupees(13_000), invested: .rupees(10_000)))

        #expect(try holding(app, "Index fund").holding.gain == .rupees(3_000))
        #expect(try holding(app, "Index fund").holding.gainPercentTenths == 300)
        let history = try app.holdingHistory(id)
        #expect(history == [HoldingPoint(date: day("2026-10-30"), value: .rupees(13_000), invested: .rupees(10_000))])
    }

    @Test func historyKeepsOneLastValuePerDayOldestFirst() throws {
        let clock = SteppingClock("2026-10-01")
        let app = BudgetApp(database: try AppDatabase.inMemory(), clock: clock)
        try app.addHolding(NewHolding(name: "Index fund", amount: .rupees(100), invested: .rupees(100)))
        let id = try holding(app, "Index fund").holding.id

        clock.date = day("2026-10-15")
        try app.updateHolding(id, NewHolding(name: "Index fund", amount: .rupees(110), invested: .rupees(100)))
        try app.updateHolding(id, NewHolding(name: "Index fund", amount: .rupees(120), invested: .rupees(100)))

        #expect(try app.holdingHistory(id).map(\.value) == [.rupees(100), .rupees(120)])
        #expect(try app.holdingHistory(id).map(\.date) == [day("2026-10-01"), day("2026-10-15")])
    }

    @Test func aSIPInstalmentAddsToWhatWasPaidAndWhatItIsWorth() throws {
        let app = try makeApp()
        let id = try add(app, "Index fund", paid: 10_000, now: 12_000)

        try app.addToHolding(id, amount: .rupees(5_000))

        let line = try holding(app, "Index fund")
        #expect(line.holding.invested == .rupees(15_000))
        #expect(line.holding.amount == .rupees(17_000))
        #expect(line.holding.gain == .rupees(2_000))
    }

    @Test func addingMoneyNeedsAnAmountInvestedFirst() throws {
        let app = try makeApp()
        let id = try add(app, "Gold", paid: nil, now: 50_000)

        let error = #expect(throws: PortfolioError.self) { try app.addToHolding(id, amount: .rupees(5_000)) }

        #expect(error?.message == "Enter what you paid for it first.")
    }

    @Test func whatWasPaidCannotBeNegative() throws {
        let app = try makeApp()

        let error = #expect(throws: PortfolioError.self) {
            try app.addHolding(NewHolding(name: "Stock", amount: .rupees(100), invested: .rupees(-100)))
        }

        #expect(error?.message == "Enter an amount of 0 or more")
    }

    @Test func notingWhatWasPaidDoesNotChangeNetWorth() throws {
        let app = try makeApp()
        let id = try add(app, "Index fund", paid: nil, now: 12_500)
        let before = try app.portfolio().netWorth

        try app.updateHolding(id, NewHolding(name: "Index fund", amount: .rupees(12_500), invested: .rupees(10_000)))

        #expect(try app.portfolio().netWorth == before)
    }
}

struct HoldingDetailTests {
    private func add(
        _ app: BudgetApp, _ name: String = "Index fund", paid: Int? = 100_000, now: Int = 121_000, on date: String? = "2025-11-20"
    ) throws -> Int64 {
        try app.addHolding(NewHolding(
            name: name, amount: .rupees(now), invested: paid.map { .rupees($0) }, investedOn: date.map(day)
        ))
        return try #require(try app.portfolio().holdings.first { $0.holding.name == name }).holding.id
    }

    @Test func anInvestmentRemembersTheDayItWasBoughtAndHowLongItHasBeenHeld() throws {
        let app = try makeApp(today: "2027-11-20")
        let id = try add(app)

        let detail = try app.holdingDetail(id)

        #expect(detail.holding.investedOn == day("2025-11-20"))
        #expect(detail.daysHeld == 730)
        #expect(detail.holding.gain == .rupees(21_000))
    }

    @Test func aLumpSumShowsHowMuchItGrowsAYear() throws {
        let app = try makeApp(today: "2027-11-20")
        let id = try add(app)

        #expect(try app.holdingDetail(id).yearlyGrowthTenths == 100)
    }

    @Test func aShortHoldingShowsNoYearlyFigure() throws {
        let app = try makeApp(today: "2026-02-20")
        let id = try add(app)

        #expect(try app.holdingDetail(id).yearlyGrowthTenths == nil)
    }

    @Test func aHoldingWithMoneyAddedShowsNoYearlyFigure() throws {
        let app = try makeApp(today: "2027-11-20")
        let id = try add(app)
        try app.addToHolding(id, amount: .rupees(5_000), on: day("2026-10-05"))

        #expect(try app.holdingDetail(id).yearlyGrowthTenths == nil)
    }

    @Test func moneyAddedIsListedWithItsDateAndTheFirstBuyIsWhatRemains() throws {
        let app = try makeApp(today: "2026-11-20")
        let id = try add(app, paid: 10_000, now: 12_000, on: "2026-01-10")
        try app.addToHolding(id, amount: .rupees(2_000), on: day("2026-11-05"))
        try app.addToHolding(id, amount: .rupees(5_000), on: day("2026-10-05"))

        let detail = try app.holdingDetail(id)

        #expect(detail.contributions.map(\.date) == [day("2026-10-05"), day("2026-11-05")])
        #expect(detail.contributions.map(\.amount) == [.rupees(5_000), .rupees(2_000)])
        #expect(detail.boughtAmount == .rupees(10_000))
        #expect(detail.holding.invested == .rupees(17_000))
    }

    @Test func addingMoneyWithoutADateUsesToday() throws {
        let app = try makeApp(today: "2026-11-20")
        let id = try add(app, paid: 10_000, now: 12_000, on: nil)

        try app.addToHolding(id, amount: .rupees(1_000))

        #expect(try app.holdingDetail(id).contributions.map(\.date) == [day("2026-11-20")])
    }

    @Test func theDateCannotBeInTheFuture() throws {
        let app = try makeApp(today: "2026-11-20")

        let error = #expect(throws: PortfolioError.self) {
            try app.addHolding(NewHolding(name: "Stock", amount: .rupees(100), invested: .rupees(100), investedOn: day("2026-11-21")))
        }

        #expect(error?.message == "The date can't be in the future.")
    }

    @Test func aHoldingWithoutADateOrAmountInvestedStillOpens() throws {
        let app = try makeApp()
        let id = try add(app, "Gold", paid: nil, now: 50_000, on: nil)

        let detail = try app.holdingDetail(id)

        #expect(detail.daysHeld == nil)
        #expect(detail.holding.gain == nil)
        #expect(detail.contributions.isEmpty)
        #expect(detail.boughtAmount == nil)
    }

    @Test func aMissingHoldingIsRefused() throws {
        #expect(throws: PortfolioError.self) { try makeApp().holdingDetail(99) }
    }
}

struct HoldingModeTests {
    private func sip(
        _ app: BudgetApp, amount: Int? = 2_000, day sipDay: Int? = 5, bought: String? = "2026-01-10"
    ) throws -> Int64 {
        try app.addHolding(NewHolding(
            name: "Index fund", amount: .rupees(12_000), invested: .rupees(10_000), investedOn: bought.map(day),
            kind: .sip, sipAmount: amount.map { .rupees($0) }, sipDay: sipDay
        ))
        return try #require(try app.portfolio().holdings.first).holding.id
    }

    @Test func aHoldingHasAModeAndASIPKeepsItsInstalmentAndDay() throws {
        let app = try makeApp()
        let id = try sip(app)

        let holding = try app.holdingDetail(id).holding

        #expect(holding.kind == .sip)
        #expect(holding.sipAmount == .rupees(2_000))
        #expect(holding.sipDay == 5)
    }

    @Test func aHoldingWithoutAModeIsOther() throws {
        let app = try makeApp()
        try app.addHolding(NewHolding(name: "Gold", amount: .rupees(100)))

        #expect(try app.portfolio().holdings.first?.holding.kind == .other)
    }

    @Test func aStockKeepsNoInstalmentDetails() throws {
        let app = try makeApp()
        try app.addHolding(NewHolding(
            name: "Stock", amount: .rupees(100), invested: .rupees(90), kind: .stock, sipAmount: .rupees(500), sipDay: 5
        ))

        let holding = try #require(try app.portfolio().holdings.first).holding

        #expect(holding.kind == .stock)
        #expect(holding.sipAmount == nil)
        #expect(holding.sipDay == nil)
    }

    @Test func aSIPAmountNeedsADay() throws {
        let app = try makeApp()

        let error = #expect(throws: PortfolioError.self) { _ = try sip(app, day: nil) }

        #expect(error?.message == "Pick the day of the month the instalment goes out.")
    }

    @Test func aSIPAmountMustBeAboveZero() throws {
        let app = try makeApp()

        let error = #expect(throws: PortfolioError.self) { _ = try sip(app, amount: 0) }

        #expect(error?.message == "Enter an amount above 0")
    }

    @Test func theInstalmentIsDueOnceItsDayHasPassedAndNothingWasAddedThisMonth() throws {
        let app = try makeApp(today: "2026-11-20")
        let id = try sip(app)

        let detail = try app.holdingDetail(id)

        #expect(detail.instalmentDue)
        #expect(detail.nextInstalment == day("2026-11-05"))
    }

    @Test func beforeItsDayTheNextInstalmentIsShownAndNothingIsDue() throws {
        let app = try makeApp(today: "2026-11-03")
        let id = try sip(app)

        let detail = try app.holdingDetail(id)

        #expect(!detail.instalmentDue)
        #expect(detail.nextInstalment == day("2026-11-05"))
    }

    @Test func addingTheInstalmentMovesTheNextOneToNextMonth() throws {
        let app = try makeApp(today: "2026-11-20")
        let id = try sip(app)

        try app.addToHolding(id, amount: .rupees(2_000), on: day("2026-11-05"))

        let detail = try app.holdingDetail(id)
        #expect(!detail.instalmentDue)
        #expect(detail.nextInstalment == day("2026-12-05"))
    }

    @Test func aShortMonthUsesItsLastDay() throws {
        let app = try makeApp(today: "2026-11-30")
        let id = try sip(app, day: 31)

        let detail = try app.holdingDetail(id)

        #expect(detail.instalmentDue)
        #expect(detail.nextInstalment == day("2026-11-30"))
    }

    @Test func buyingInTheMonthCountsAsThatMonthsInstalment() throws {
        let app = try makeApp(today: "2026-11-20")
        let id = try sip(app, bought: "2026-11-02")

        #expect(try app.holdingDetail(id).instalmentDue == false)
    }

    @Test func aStockHasNoInstalment() throws {
        let app = try makeApp()
        try app.addHolding(NewHolding(name: "Stock", amount: .rupees(100), invested: .rupees(90), kind: .stock))
        let id = try #require(try app.portfolio().holdings.first).holding.id

        let detail = try app.holdingDetail(id)

        #expect(!detail.instalmentDue)
        #expect(detail.nextInstalment == nil)
    }

    @Test func updatingOnlyTheWorthKeepsEverythingElseAndAddsAPoint() throws {
        let app = try makeApp(today: "2026-11-20")
        let id = try sip(app)

        try app.updateHoldingWorth(id, .rupees(13_000))

        let detail = try app.holdingDetail(id)
        #expect(detail.holding.amount == .rupees(13_000))
        #expect(detail.holding.invested == .rupees(10_000))
        #expect(detail.holding.kind == .sip)
        #expect(detail.holding.sipDay == 5)
        #expect(detail.history.last?.value == .rupees(13_000))
    }

    @Test func theNewWorthCannotBeNegative() throws {
        let app = try makeApp()
        let id = try sip(app)

        #expect(throws: PortfolioError.self) { try app.updateHoldingWorth(id, nil) }
    }
}

final class SteppingClock: DayClock, @unchecked Sendable {
    var date: CalendarDate
    init(_ iso: String) { date = day(iso) }
    func today() -> CalendarDate { date }
}
