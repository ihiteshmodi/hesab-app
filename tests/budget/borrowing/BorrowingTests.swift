import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/borrowing/amount-to-repay.feature
struct BorrowingTests {
    /// The feature's background: 20,000 left to spend.
    private func appWithTwentyThousand() throws -> BudgetApp {
        let app = try makeApp()
        try app.addIncome(NewIncome(kind: .salary, amount: .rupees(20_000)))
        return app
    }

    @discardableResult
    private func borrow(_ app: BudgetApp, _ rupees: Int, from lender: String) throws -> IncomeEntry {
        try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(rupees), note: lender))
    }

    private func line(_ app: BudgetApp, _ borrowing: IncomeEntry) throws -> BorrowingLine {
        try #require(try app.amountToRepay().borrowings.first { $0.borrowing.id == borrowing.id })
    }

    @Test func borrowingRaisesWhatIsOwedAndLeftToSpend() throws {
        let app = try appWithTwentyThousand()

        try borrow(app, 10_000, from: "Savings")

        #expect(try app.amountToRepay().total == .rupees(10_000))
        #expect(try app.monthBudget().leftToSpend == .rupees(30_000))
    }

    @Test func repayingPartOfItLowersWhatIsOwedAndLeftToSpend() throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")

        try app.recordRepayment(loan.id, .rupees(4_000))

        #expect(try app.amountToRepay().total == .rupees(6_000))
        #expect(try app.monthBudget().leftToSpend == .rupees(26_000))
        #expect(try line(app, loan).repaid == .rupees(4_000))
        #expect(try !line(app, loan).isRepaid)
    }

    @Test func repayingTheRestMarksTheBorrowingRepaid() throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")
        try app.recordRepayment(loan.id, .rupees(4_000))

        try app.recordRepayment(loan.id, .rupees(6_000))

        #expect(try line(app, loan).isRepaid)
        #expect(try app.amountToRepay().total == .zero)
        #expect(try app.amountToRepay().lenders.isEmpty)
    }

    @Test func repayingMoreThanIsOwedIsRefused() throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")
        try app.recordRepayment(loan.id, .rupees(4_000))

        let error = #expect(throws: BorrowingError.self) { try app.recordRepayment(loan.id, .rupees(7_000)) }

        #expect(error?.message == "Repayment can't be more than the 6,000 still to repay")
        #expect(try app.amountToRepay().total == .rupees(6_000))
    }

    @Test func repayingExactlyWhatIsOwedIsAllowed() throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")

        try app.recordRepayment(loan.id, .rupees(10_000))

        #expect(try line(app, loan).isRepaid)
    }

    @Test(arguments: [nil, Money.zero, Money.rupees(-5)] as [Money?])
    func aRepaymentNeedsAnAmountAboveZero(amount: Money?) throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")

        let error = #expect(throws: BorrowingError.self) { try app.recordRepayment(loan.id, amount) }

        #expect(error?.message == "Enter an amount above 0")
        #expect(try app.amountToRepay().total == .rupees(10_000))
    }

    @Test func eachLenderIsListedWithWhatIsStillOwed() throws {
        let app = try appWithTwentyThousand()
        let savings = try borrow(app, 10_000, from: "Savings")
        try borrow(app, 2_500, from: "Ben")
        try app.recordRepayment(savings.id, .rupees(4_000))

        let owed = try app.amountToRepay()

        #expect(owed.total == .rupees(8_500))
        #expect(owed.lenders == [
            LenderDebt(lender: "Savings", owed: .rupees(6_000)),
            LenderDebt(lender: "Ben", owed: .rupees(2_500)),
        ])
    }

    @Test func borrowingsFromTheSameLenderAreAddedTogetherWhateverTheCase() throws {
        let app = try appWithTwentyThousand()
        try borrow(app, 1_000, from: "Ben")
        try borrow(app, 500, from: " ben ")

        #expect(try app.amountToRepay().lenders == [LenderDebt(lender: "Ben", owed: .rupees(1_500))])
    }

    @Test func aLenderWithNothingLeftToRepayIsNotListed() throws {
        let app = try appWithTwentyThousand()
        let paidOff = try borrow(app, 1_000, from: "Ben")
        try borrow(app, 500, from: "Savings")
        try app.recordRepayment(paidOff.id, .rupees(1_000))

        #expect(try app.amountToRepay().lenders.map(\.lender) == ["Savings"])
    }

    @Test func deletingABorrowingRemovesItsRepaymentsAndRestoresLeftToSpend() throws {
        let app = try appWithTwentyThousand()
        let before = try app.monthBudget().leftToSpend
        let loan = try borrow(app, 10_000, from: "Savings")
        try app.recordRepayment(loan.id, .rupees(4_000))

        try app.deleteIncome(loan.id)

        #expect(try app.monthBudget().leftToSpend == before)
        #expect(try app.amountToRepay().borrowings.isEmpty)
    }

    @Test func aRepaymentIsDatedTodayUnlessGiven() throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")

        let today = try app.recordRepayment(loan.id, .rupees(1_000))
        let earlier = try app.recordRepayment(loan.id, .rupees(1_000), on: day("2026-10-01"))

        #expect(today.date == day("2026-10-30"))
        #expect(earlier.date == day("2026-10-01"))
        #expect(try line(app, loan).repayments.map(\.date) == [day("2026-10-30"), day("2026-10-01")])
    }

    @Test func onlyBorrowedMoneyCanBeRepaid() throws {
        let app = try appWithTwentyThousand()
        let salary = try app.addIncome(NewIncome(kind: .salary, amount: .rupees(5_000)))

        #expect(throws: BorrowingError.notABorrowing) { try app.recordRepayment(salary.id, .rupees(100)) }
        #expect(throws: BorrowingError.notFound(999)) { try app.recordRepayment(999, .rupees(100)) }
    }

    @Test func borrowedMoneyNeedsToSayWhoItCameFrom() throws {
        let app = try makeApp()

        let error = #expect(throws: IncomeValidationError.self) {
            try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(1_000), note: "  "))
        }

        #expect(error?.message == "Enter who you borrowed from")
        #expect(try app.monthBudget().incomeEntries.isEmpty)
    }

    @Test func deletingARepaymentPutsTheMoneyBackAsOwed() throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")
        let repayment = try app.recordRepayment(loan.id, .rupees(4_000))

        try app.deleteRepayment(repayment.id)

        #expect(try app.amountToRepay().total == .rupees(10_000))
        #expect(try app.monthBudget().leftToSpend == .rupees(30_000))
        #expect(try line(app, loan).repayments.isEmpty)
    }

    @Test func deletingARepaymentThatIsGoneSaysSo() throws {
        let app = try makeApp()

        #expect(throws: BorrowingError.repaymentNotFound(999)) { try app.deleteRepayment(999) }
    }

    @Test func errorsReadInPlainWords() {
        #expect(BorrowingError.notABorrowing.message == "Only borrowed money can be repaid.")
        #expect(BorrowingError.notFound(1).message == "That borrowing no longer exists.")
        #expect(BorrowingError.repaymentNotFound(1).message == "That repayment no longer exists.")
    }

    @Test func borrowingInCashRaisesCashInHandButNotLeftToSpend() throws {
        let app = try appWithTwentyThousand()

        try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(3_000), note: "Ben", viaCash: true))

        #expect(try app.cashInHand().balance == .rupees(3_000))
        #expect(try app.monthBudget().leftToSpend == .rupees(20_000))
        #expect(try app.amountToRepay().total == .rupees(3_000))
    }

    @Test func borrowingIntoTheBankRaisesLeftToSpendButNotCash() throws {
        let app = try appWithTwentyThousand()

        try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(3_000), note: "Ben", viaCash: false))

        #expect(try app.cashInHand().balance == .zero)
        #expect(try app.monthBudget().leftToSpend == .rupees(23_000))
    }

    @Test func repayingFromCashLowersCashButNotLeftToSpend() throws {
        let app = try appWithTwentyThousand()
        let loan = try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(3_000), note: "Ben", viaCash: true))

        try app.recordRepayment(loan.id, .rupees(1_000))

        #expect(try app.cashInHand().balance == .rupees(2_000))
        #expect(try app.monthBudget().leftToSpend == .rupees(20_000))
    }

    @Test func aRepaymentCanComeFromADifferentPocketThanTheBorrowing() throws {
        let app = try appWithTwentyThousand()
        let loan = try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(3_000), note: "Ben", viaCash: true))

        try app.recordRepayment(loan.id, .rupees(1_000), fromCash: false)

        #expect(try app.cashInHand().balance == .rupees(3_000))
        #expect(try app.monthBudget().leftToSpend == .rupees(19_000))
    }

    @Test func cashBorrowingsAndRepaymentsShowInTheCashListWithTheirTitles() throws {
        let app = try appWithTwentyThousand()
        let loan = try app.addIncome(NewIncome(date: day("2026-10-30"), kind: .borrowed, amount: .rupees(3_000), note: "Ben", viaCash: true))
        try app.recordRepayment(loan.id, .rupees(1_000), on: day("2026-10-30"))

        let lines = try app.cashInHand().lines

        #expect(lines.map(\.description) == ["Borrowed from Ben", "Repaid Ben"])
        #expect(lines.map(\.amount) == [.rupees(3_000), .rupees(-1_000)])
        #expect(lines.last?.runningBalance == .rupees(2_000))
    }

    @Test func aBorrowingEditedToBankMovesItsMoneyOutOfCash() throws {
        let app = try appWithTwentyThousand()
        let loan = try app.addIncome(NewIncome(kind: .borrowed, amount: .rupees(3_000), note: "Ben", viaCash: true))

        try app.updateIncome(loan.id, NewIncome(kind: .borrowed, amount: .rupees(3_000), note: "Ben", viaCash: false))

        #expect(try app.cashInHand().balance == .zero)
        #expect(try app.monthBudget().leftToSpend == .rupees(23_000))
    }

    @Test func aRepaymentCanBeChangedWithinWhatWasOwed() throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")
        let repayment = try app.recordRepayment(loan.id, .rupees(4_000), on: day("2026-10-01"))

        try app.updateRepayment(repayment.id, amount: .rupees(7_000), on: day("2026-10-02"), fromCash: false)

        let edited = try #require(try line(app, loan).repayments.first)
        #expect(edited.amount == .rupees(7_000))
        #expect(edited.date == day("2026-10-02"))
        #expect(try app.amountToRepay().total == .rupees(3_000))
        #expect(throws: BorrowingError.moreThanOwed(.rupees(10_000))) {
            try app.updateRepayment(repayment.id, amount: .rupees(11_000), on: day("2026-10-02"), fromCash: false)
        }
    }

    @Test func aRepaymentCanBeMovedFromBankToCash() throws {
        let app = try appWithTwentyThousand()
        let loan = try borrow(app, 10_000, from: "Savings")
        let repayment = try app.recordRepayment(loan.id, .rupees(4_000))

        try app.updateRepayment(repayment.id, amount: .rupees(4_000), on: nil, fromCash: true)

        #expect(try app.monthBudget().leftToSpend == .rupees(30_000))
        #expect(try app.cashInHand().balance == .rupees(-4_000))
    }
}
