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

    /// For a calendar day: whole rupees below a thousand, then thousands (k) and lakhs (L) with one decimal, rounded down.
    public static func compact(_ money: Money) -> String {
        let rupees = abs(money.paise) / 100
        let sign = money.paise < 0 ? "−" : ""
        func tenths(_ unit: Int, _ suffix: String) -> String {
            let value = rupees * 10 / unit
            return "\(sign)₹\(value / 10)\(value % 10 == 0 ? "" : ".\(value % 10)")\(suffix)"
        }
        if rupees >= 1_00_000 { return tenths(1_00_000, "L") }
        if rupees >= 1_000 { return tenths(1_000, "k") }
        return "\(sign)₹\(rupees)"
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
