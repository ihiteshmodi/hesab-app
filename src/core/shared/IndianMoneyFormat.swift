import Foundation

/// Rupees with Indian digit grouping: ₹12,34,567.89. A negative amount gets a true minus sign.
public enum IndianMoneyFormat {
    public static func string(_ money: Money) -> String {
        let absolute = abs(money.paise)
        let rupees = grouped(String(absolute / 100))
        let paise = absolute % 100
        let sign = money.paise < 0 ? "−" : ""
        return "\(sign)₹\(rupees).\(paise < 10 ? "0" : "")\(paise)"
    }

    /// For sentences: no symbol, and no decimals when the amount is a whole number of rupees.
    public static func plain(_ money: Money) -> String {
        let text = string(money).replacingOccurrences(of: "₹", with: "")
        return text.hasSuffix(".00") ? String(text.dropLast(3)) : text
    }

    private static func grouped(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        let lastThree = String(digits.suffix(3))
        var head = Substring(digits.dropLast(3))
        var groups: [String] = []
        while head.count > 2 {
            groups.append(String(head.suffix(2)))
            head = head.dropLast(2)
        }
        if !head.isEmpty { groups.append(String(head)) }
        return (groups.reversed() + [lastThree]).joined(separator: ",")
    }
}
