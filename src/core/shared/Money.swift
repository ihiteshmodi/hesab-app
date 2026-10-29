/// Whole paise, so sums are exact. Never a floating point number.
public struct Money: Hashable, Comparable, Sendable {
    public let paise: Int

    public init(paise: Int) {
        self.paise = paise
    }

    public static let zero = Money(paise: 0)

    public static func rupees(_ rupees: Int, paise: Int = 0) -> Money {
        Money(paise: rupees * 100 + paise)
    }

    public static func + (lhs: Money, rhs: Money) -> Money { Money(paise: lhs.paise + rhs.paise) }
    public static func - (lhs: Money, rhs: Money) -> Money { Money(paise: lhs.paise - rhs.paise) }
    public static func < (lhs: Money, rhs: Money) -> Bool { lhs.paise < rhs.paise }
}
