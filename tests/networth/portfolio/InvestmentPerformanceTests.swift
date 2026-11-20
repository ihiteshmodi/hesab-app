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

final class SteppingClock: DayClock, @unchecked Sendable {
    var date: CalendarDate
    init(_ iso: String) { date = day(iso) }
    func today() -> CalendarDate { date }
}
