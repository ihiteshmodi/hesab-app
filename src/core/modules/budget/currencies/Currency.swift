import Foundation

/// Money paid in another currency, with the rate that turned it into the home amount.
public struct ForeignAmount: Equatable, Sendable {
    public let currency: String
    /// In the same hundredths as every `Money`, so 150,000 IDR is `.rupees(150_000)`.
    public let amount: Money
    /// Home currency per one unit of the foreign currency.
    public let rate: Decimal
}

/// What the person typed for a foreign expense. Give a `rate`, or `paidInHome` (what the card charged) to work it out.
public struct ForeignSpend: Sendable {
    public var currency: String
    public var amount: Money?
    public var rate: Decimal?
    public var paidInHome: Money?

    public init(currency: String, amount: Money?, rate: Decimal? = nil, paidInHome: Money? = nil) {
        self.currency = currency
        self.amount = amount
        self.rate = rate
        self.paidInHome = paidInHome
    }

    /// The validated foreign amount and the home amount it comes to.
    func resolved() throws -> (foreign: ForeignAmount, home: Money) {
        guard let amount, amount > .zero else { throw ExpenseValidationError.amountMissingOrZero }
        if let paidInHome {
            guard paidInHome > .zero else { throw ExpenseValidationError.amountMissingOrZero }
            let derived = Decimal(paidInHome.paise) / Decimal(amount.paise)
            return (ForeignAmount(currency: currency, amount: amount, rate: derived), paidInHome)
        }
        guard let rate else { throw ExpenseValidationError.rateMissing }
        guard rate > 0 else { throw ExpenseValidationError.rateNotPositive }
        var exact = Decimal(amount.paise) * rate
        var rounded = Decimal()
        NSDecimalRound(&rounded, &exact, 0, .plain)
        return (ForeignAmount(currency: currency, amount: amount, rate: rate), Money(paise: NSDecimalNumber(decimal: rounded).intValue))
    }
}

public struct Currency: Equatable, Sendable {
    public let code: String
    public let name: String
    /// Nil means the code is shown, for example "IDR 150,000".
    public let symbol: String?
    public let decimals: Int

    public init(code: String, name: String, symbol: String?, decimals: Int) {
        self.code = code
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
    }
}

public enum CurrencyError: Error, Equatable, Sendable {
    case codeMissing
    case codeTaken(String)
    case homeLocked(String)

    public var message: String {
        switch self {
        case .codeMissing: "Enter a currency code"
        case .codeTaken(let code): "A currency called \(code) already exists"
        case .homeLocked(let code):
            "Your records are in \(code). Export a backup and start a new file to use another home currency."
        }
    }
}

/// Amounts in a currency's own style: the home rupee groups in lakhs, the others in thousands.
public enum CurrencyFormat {
    public static func string(_ money: Money, in currency: Currency) -> String {
        if currency.code == "INR" { return IndianMoneyFormat.string(money) }
        let absolute = abs(money.paise)
        let whole = grouped(String(absolute / 100))
        let fraction = absolute % 100
        let decimals = currency.decimals > 0 ? "." + (fraction < 10 ? "0" : "") + String(fraction) : ""
        let prefix = currency.symbol ?? "\(currency.code) "
        return "\(money.paise < 0 ? "−" : "")\(prefix)\(whole)\(decimals)"
    }

    private static func grouped(_ digits: String) -> String {
        var groups: [String] = []
        var rest = Substring(digits)
        while rest.count > 3 {
            groups.append(String(rest.suffix(3)))
            rest = rest.dropLast(3)
        }
        groups.append(String(rest))
        return groups.reversed().joined(separator: ",")
    }
}
