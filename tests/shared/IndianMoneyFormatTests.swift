import Testing
@testable import HisaabCore

struct IndianMoneyFormatTests {
    @Test(arguments: [
        (0, "₹0.00"),
        (5, "₹0.05"),
        (100, "₹1.00"),
        (99_999, "₹999.99"),
        (125_000, "₹1,250.00"),
        (122_405, "₹1,224.05"),
        (12_345_678, "₹1,23,456.78"),
        (123_456_789, "₹12,34,567.89"),
        (1_000_000_000, "₹1,00,00,000.00"),
        (-125_000, "−₹1,250.00"),
        (-5, "−₹0.05"),
    ])
    func showsRupeesWithIndianGrouping(paise: Int, expected: String) {
        #expect(IndianMoneyFormat.string(Money(paise: paise)) == expected)
    }

    @Test(arguments: [
        (120_000, "1,200"),
        (0, "0"),
        (12_345_678, "1,23,456.78"),
        (50, "0.50"),
    ])
    func plainFormatDropsTheSymbolAndWholeRupeeDecimals(paise: Int, expected: String) {
        #expect(IndianMoneyFormat.plain(Money(paise: paise)) == expected)
    }

    @Test(arguments: [
        (26_150, "₹261"),
        (99_999, "₹999"),
        (100_000, "₹1k"),
        (920_000, "₹9.2k"),
        (1_115_000, "₹11.1k"),
        (9_999_900, "₹99.9k"),
        (10_000_000, "₹1L"),
        (15_000_000, "₹1.5L"),
    ])
    func compactFormatFitsACalendarDay(paise: Int, expected: String) {
        #expect(IndianMoneyFormat.compact(Money(paise: paise)) == expected)
    }
}
