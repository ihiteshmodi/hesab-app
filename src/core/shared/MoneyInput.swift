import Foundation

/// Reads an amount as typed: "1,250.50", "₹ 1,23,456.78" or "-50". Anything unreadable is "no amount".
public enum MoneyInput {
    public static func parse(_ text: String) -> Money? {
        var cleaned = text.filter { !$0.isWhitespace && $0 != "," && $0 != "₹" }
        let isNegative = cleaned.hasPrefix("-")
        if isNegative { cleaned.removeFirst() }

        let parts = cleaned.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 2 else { return nil }
        let whole = String(parts[0])
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        guard whole.allSatisfy(\.isASCIIDigit), fraction.allSatisfy(\.isASCIIDigit),
              fraction.count <= 2, !(whole.isEmpty && fraction.isEmpty),
              let rupees = whole.isEmpty ? 0 : Int(whole)
        else { return nil }

        let paise = fraction.isEmpty ? 0 : Int(fraction.count == 1 ? fraction + "0" : fraction)!
        let total = rupees * 100 + paise
        return Money(paise: isNegative ? -total : total)
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
