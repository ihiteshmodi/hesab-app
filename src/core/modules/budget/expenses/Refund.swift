public enum RefundState: Equatable, Sendable {
    case notRefundable
    case pending
    case settled(received: Money)
}

public enum RefundError: Error, Equatable, Sendable {
    case cashCannotBeRefunded
    case cashNeedsUnmarkingFirst
    case notRefundable
    case settlementMustBeUndoneFirst
    case receivedNegative
    case receivedMoreThan(Money)

    public var message: String {
        switch self {
        case .cashCannotBeRefunded: "Cash expenses can't be refunded."
        case .cashNeedsUnmarkingFirst: "Unmark it as refundable first. Cash expenses can't be refunded."
        case .notRefundable: "Mark it as refundable first."
        case .settlementMustBeUndoneFirst: "Undo the settlement first."
        case .receivedNegative: "Enter an amount of 0 or more"
        case .receivedMoreThan(let amount): "Received can't be more than \(IndianMoneyFormat.plain(amount))"
        }
    }
}

/// The refund lifecycle: not refundable, pending, settled. Each arrow is one method; the others throw.
extension Expense {
    func markedRefundable() throws -> Expense {
        guard paymentMethod.source != .cash else { throw RefundError.cashCannotBeRefunded }
        guard refund == .notRefundable else { return self }
        return with(refund: .pending)
    }

    func receiving(_ received: Money) throws -> Expense {
        guard refund != .notRefundable else { throw RefundError.notRefundable }
        guard received >= .zero else { throw RefundError.receivedNegative }
        guard received <= amount else { throw RefundError.receivedMoreThan(amount) }
        return with(refund: .settled(received: received))
    }

    func settlementUndone() -> Expense {
        guard case .settled = refund else { return self }
        return with(refund: .pending)
    }

    func unmarked() throws -> Expense {
        if case .settled = refund { throw RefundError.settlementMustBeUndoneFirst }
        return with(refund: .notRefundable)
    }

    /// An edit keeps the refund state, but may not break its rules.
    func edited(to edit: Expense) throws -> Expense {
        if refund != .notRefundable, edit.paymentMethod.source == .cash { throw RefundError.cashNeedsUnmarkingFirst }
        if case .settled(let received) = refund, received > edit.amount { throw RefundError.receivedMoreThan(edit.amount) }
        return edit.with(refund: refund)
    }

    private func with(refund: RefundState) -> Expense {
        Expense(
            id: id, date: date, description: description, amount: amount, category: category,
            subCategory: subCategory, entity: entity, spentFor: spentFor, tags: tags,
            paymentMethod: paymentMethod, notes: notes, refund: refund, keptAsCash: keptAsCash, foreign: foreign
        )
    }
}
