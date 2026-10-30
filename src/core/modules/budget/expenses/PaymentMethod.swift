/// How an expense was paid. Only bank-side payments move "left to spend".
public struct PaymentMethod: Hashable, Sendable {
    public enum Source: String, Sendable {
        case bank, cash, ledger
    }

    public let name: String
    public let source: Source

    public init(name: String, source: Source) {
        self.name = name
        self.source = source
    }

    public static let upi = PaymentMethod(name: "UPI", source: .bank)
    public static let cashWithdrawal = PaymentMethod(name: "Cash Withdrawal", source: .bank)
    public static let cash = PaymentMethod(name: "Cash", source: .cash)

    public static func bank(_ name: String) -> PaymentMethod { PaymentMethod(name: name, source: .bank) }
    public static func ledger(_ person: String) -> PaymentMethod { PaymentMethod(name: person, source: .ledger) }

    var movesLeftToSpend: Bool { source == .bank }
}
