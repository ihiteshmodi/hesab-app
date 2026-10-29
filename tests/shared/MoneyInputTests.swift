import Testing
@testable import HisaabCore

struct MoneyInputTests {
    @Test(arguments: [
        ("1250", Money.rupees(1250)),
        ("1,250", Money.rupees(1250)),
        ("1,250.50", Money.rupees(1250, paise: 50)),
        ("₹ 1,23,456.78", Money.rupees(123_456, paise: 78)),
        ("0.05", Money(paise: 5)),
        ("12.5", Money.rupees(12, paise: 50)),
        (" 99 ", Money.rupees(99)),
        ("-50", Money.rupees(-50)),
    ] as [(String, Money)])
    func readsWhatThePersonTypedAsExactMoney(text: String, expected: Money) {
        #expect(MoneyInput.parse(text) == expected)
    }

    @Test(arguments: ["", "   ", "abc", "12.345", "1.2.3", ".", "12a"])
    func treatsEmptyOrUnreadableTextAsNoAmount(text: String) {
        #expect(MoneyInput.parse(text) == nil)
    }
}
