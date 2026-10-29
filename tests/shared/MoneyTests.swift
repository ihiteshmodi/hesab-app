import Testing
@testable import HisaabCore

struct MoneyTests {
    @Test func subtractingKeepsExactPaise() {
        let ticket = Money.rupees(1224, paise: 5)
        let refund = Money.rupees(945, paise: 36)

        #expect(ticket - refund == Money.rupees(278, paise: 69))
    }

    @Test func addingSumsPaiseWithoutDrift() {
        let tenths = Array(repeating: Money(paise: 10), count: 10)

        #expect(tenths.reduce(Money.zero, +) == Money.rupees(1))
    }
}
