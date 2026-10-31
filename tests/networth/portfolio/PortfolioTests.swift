import Foundation
import Testing
@testable import HisaabCore

/// Scenarios from tests/networth/portfolio/portfolio.feature
struct PortfolioTests {
    /// The feature's background.
    private func background() throws -> BudgetApp {
        let app = try makeApp()
        try app.setBankBalance(.rupees(300_000))
        for (name, rupees, counts) in [("Mom", 40_000, false), ("Sam", 40_000, false), ("Neighbor", 30_000, true)] {
            let ledger = try app.addLedger(NewLedger(name: name, countsTowardsNetWorth: counts))
            try app.addLedgerEntry(ledger.id, NewLedgerEntry(description: "Opening", value: .rupees(rupees)))
        }
        try app.addAllocatedFund(name: "Trip", amount: .rupees(20_000))
        try app.addHolding(NewHolding(name: "Stocks", amount: .rupees(10_000)))
        try app.addScheme(NewPayoutScheme(
            name: "Schemes", invested: .rupees(1_000_000), monthlyPayout: .rupees(1_000), payoutDay: 5, maturity: nil
        ))
        try app.addHolding(NewHolding(name: "Dollars", amount: .rupees(400), currency: "USD", rate: Decimal(string: "90.00")!))
        return app
    }

    @Test func availableForAllocationIsTheBankMinusLedgersAndAllocatedFunds() throws {
        #expect(try background().portfolio().availableForAllocation == .rupees(170_000))
    }

    @Test func investmentsAndNetWorthAddEverythingUp() throws {
        let portfolio = try background().portfolio()

        #expect(portfolio.investments == .rupees(1_046_000))
        #expect(portfolio.netWorth == .rupees(1_246_000))
    }

    @Test func updatingTheExchangeRateRevaluesTheHoldingAndRemembersTheDate() throws {
        let app = try background()

        try app.setExchangeRate("USD", Decimal(string: "92.50")!)

        let portfolio = try app.portfolio()
        #expect(portfolio.holdings.first { $0.holding.name == "Dollars" }?.valueInHome == .rupees(37_000))
        #expect(portfolio.netWorth == .rupees(1_247_000))
        let rate = try #require(portfolio.rates.first { $0.currency == "USD" })
        #expect(rate.rate == Decimal(string: "92.50")!)
        #expect(rate.setOn == day("2026-10-30"))
    }

    @Test func updatingTheBankBalanceRaisesWhatIsAvailableAndKeepsItsDate() throws {
        let app = try background()

        try app.setBankBalance(.rupees(310_000), asOf: day("2026-10-28"))

        let portfolio = try app.portfolio()
        #expect(portfolio.availableForAllocation == .rupees(180_000))
        #expect(portfolio.bankBalanceAsOf == day("2026-10-28"))
    }

    @Test func theBankBalanceDateDefaultsToToday() throws {
        let app = try makeApp()

        try app.setBankBalance(.rupees(5))

        #expect(try app.portfolio().bankBalanceAsOf == day("2026-10-30"))
        #expect(try makeApp().portfolio().bankBalanceAsOf == nil)
    }

    @Test func aLedgerNotCountedTowardsNetWorthDoesNotAddToIt() throws {
        let app = try background()
        let neighbor = try #require(try app.ledgers().ledgers.first { $0.ledger.name == "Neighbor" }?.ledger)

        try app.setLedgerCountsTowardsNetWorth(neighbor.id, false)

        #expect(try app.portfolio().netWorth == .rupees(1_216_000))
    }

    @Test func allocationsBeyondTheBankShowANegativeBalanceAndAWarning() throws {
        let app = try background()
        try app.setBankBalance(.rupees(80_000))

        let portfolio = try app.portfolio()

        #expect(portfolio.availableForAllocation == .rupees(-50_000))
        #expect(portfolio.warning == "Allocations exceed the bank balance by 50,000")
        #expect(try background().portfolio().warning == nil)
    }

    @Test func allocatingMoneyToAGoalLowersWhatIsAvailable() throws {
        let app = try background()

        try app.addAllocatedFund(name: "Repairs", amount: .rupees(15_000))

        #expect(try app.portfolio().availableForAllocation == .rupees(155_000))
    }

    @Test func addingAHoldingRaisesInvestments() throws {
        let app = try background()

        try app.addHolding(NewHolding(name: "Gold coin", amount: .rupees(25_000)))

        #expect(try app.portfolio().investments == .rupees(1_071_000))
    }

    @Test(arguments: [
        ("", Money.rupees(100) as Money?, "Enter a name"),
        ("Stock", Money.rupees(-5), "Enter an amount of 0 or more"),
        ("Stock", nil, "Enter an amount of 0 or more"),
    ] as [(String, Money?, String)])
    func invalidHoldingsAreRejected(name: String, amount: Money?, message: String) throws {
        let app = try makeApp()

        let error = #expect(throws: PortfolioError.self) { try app.addHolding(NewHolding(name: name, amount: amount)) }

        #expect(error?.message == message)
        #expect(try app.portfolio().holdings.isEmpty)
    }

    @Test func aForeignHoldingNeedsARateTheFirstTime() throws {
        let app = try makeApp()

        let error = #expect(throws: PortfolioError.self) {
            try app.addHolding(NewHolding(name: "Euros", amount: .rupees(10), currency: "EUR"))
        }

        #expect(error?.message == "Enter the exchange rate")
    }

    @Test func aForeignHoldingUsesTheStoredRateWhenNoneIsGiven() throws {
        let app = try makeApp()
        try app.setExchangeRate("EUR", Decimal(string: "100")!)

        try app.addHolding(NewHolding(name: "Euros", amount: .rupees(10), currency: "EUR"))

        #expect(try app.portfolio().investments == .rupees(1_000))
    }

    @Test func aRateMustBeAboveZero() throws {
        let app = try makeApp()

        #expect(throws: PortfolioError.rateNotPositive) { try app.setExchangeRate("USD", Decimal(0)) }
        #expect(PortfolioError.rateNotPositive.message == "Enter an exchange rate above 0")
    }

    @Test func removingAHoldingLowersInvestments() throws {
        let app = try background()
        let stocks = try #require(try app.portfolio().holdings.first { $0.holding.name == "Stocks" }?.holding)

        try app.deleteHolding(stocks.id)

        #expect(try app.portfolio().investments == .rupees(1_036_000))
        #expect(throws: PortfolioError.notFound(stocks.id)) { try app.deleteHolding(stocks.id) }
        #expect(PortfolioError.notFound(1).message == "That item no longer exists.")
    }

    @Test func anAllocatedFundCanBeRemoved() throws {
        let app = try background()
        let trip = try #require(try app.portfolio().allocatedFunds.first)

        try app.deleteAllocatedFund(trip.id)

        #expect(try app.portfolio().availableForAllocation == .rupees(190_000))
    }

    @Test func allocatedFundsNeedANameAndAnAmount() throws {
        let app = try makeApp()

        #expect(throws: PortfolioError.nameMissing) { try app.addAllocatedFund(name: " ", amount: .rupees(1)) }
        #expect(throws: PortfolioError.amountInvalid) { try app.addAllocatedFund(name: "Trip", amount: nil) }
    }

    @Test func closedSchemesLeaveInvestmentsButStayInHistory() throws {
        let app = try background()
        let scheme = try #require(try app.payoutSchemes().schemes.first)

        try app.closeScheme(scheme.scheme.id)

        #expect(try app.portfolio().investments == .rupees(46_000))
        #expect(try app.payoutSchemes().schemes.count == 1)
    }

    // MARK: editing

    @Test func priyaEditsAnInvestment() throws {
        let app = try background()
        let stocks = try #require(try app.portfolio().holdings.first { $0.holding.name == "Stocks" }).holding

        try app.updateHolding(stocks.id, NewHolding(name: "Index fund", amount: .rupees(12_000)))

        let portfolio = try app.portfolio()
        #expect(portfolio.holdings.first { $0.holding.id == stocks.id }?.holding.name == "Index fund")
        #expect(portfolio.investments == .rupees(1_048_000))
    }

    @Test func priyaEditsAnAllocation() throws {
        let app = try background()
        let trip = try #require(try app.portfolio().allocatedFunds.first { $0.name == "Trip" })

        try app.updateAllocatedFund(trip.id, name: "Trip", amount: .rupees(25_000))

        #expect(try app.portfolio().availableForAllocation == .rupees(165_000))
    }
}
