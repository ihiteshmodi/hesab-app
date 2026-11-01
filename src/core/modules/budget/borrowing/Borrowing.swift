public struct Repayment: Equatable, Sendable {
    public let id: Int64
    public let borrowingID: Int64
    public let date: CalendarDate
    public let amount: Money
    /// Paid back out of cash in hand rather than from the bank.
    public let fromCash: Bool
}

/// One borrowing (an income entry of kind borrowed; its note says who lent it) with what has been paid back.
public struct BorrowingLine: Equatable, Sendable {
    public let borrowing: IncomeEntry
    /// Newest first.
    public let repayments: [Repayment]

    public var lender: String { borrowing.note }
    public var repaid: Money { repayments.reduce(.zero) { $0 + $1.amount } }
    public var owed: Money { borrowing.amount - repaid }
    public var isRepaid: Bool { owed == .zero }
}

public struct LenderDebt: Equatable, Sendable {
    public let lender: String
    public let owed: Money
}

public struct AmountToRepay: Equatable, Sendable {
    public let total: Money
    /// Lenders still owed money, the biggest debt first.
    public let lenders: [LenderDebt]
    /// Newest first, repaid ones included.
    public let borrowings: [BorrowingLine]

    init(income: [IncomeEntry], repayments: [Repayment]) {
        borrowings = income
            .filter { $0.kind == .borrowed }
            .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
            .map { loan in
                BorrowingLine(
                    borrowing: loan,
                    repayments: repayments.filter { $0.borrowingID == loan.id }
                        .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
                )
            }
        total = borrowings.reduce(.zero) { $0 + $1.owed }

        var perLender: [String: LenderDebt] = [:]
        for line in borrowings.reversed() where !line.isRepaid {
            let key = line.lender.lowercased()
            let owed = (perLender[key]?.owed ?? .zero) + line.owed
            perLender[key] = LenderDebt(lender: perLender[key]?.lender ?? line.lender, owed: owed)
        }
        lenders = perLender.values.sorted { ($1.owed, $0.lender) < ($0.owed, $1.lender) }
    }
}

public enum BorrowingError: Error, Equatable, Sendable {
    case amountMissingOrZero
    case moreThanOwed(Money)
    case notABorrowing
    case notFound(Int64)
    case repaymentNotFound(Int64)

    public var message: String {
        switch self {
        case .amountMissingOrZero: "Enter an amount above 0"
        case .moreThanOwed(let owed): "Repayment can't be more than the \(IndianMoneyFormat.plain(owed)) still to repay"
        case .notABorrowing: "Only borrowed money can be repaid."
        case .notFound: "That borrowing no longer exists."
        case .repaymentNotFound: "That repayment no longer exists."
        }
    }
}
