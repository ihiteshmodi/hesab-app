import HisaabCore
import SwiftUI

struct AmountToRepayScreen: View {
    let model: BudgetViewModel
    @State private var repaying: Int64?

    var body: some View {
        CardScreen {
            if let owed = model.amountToRepay {
                CardPanel {
                    CardCaption("Amount to repay")
                    Text(IndianMoneyFormat.string(owed.total)).font(.system(size: 34, weight: .bold)).monospacedDigit()
                        .accessibilityIdentifier("repayTotal")
                }
                if owed.borrowings.isEmpty {
                    Text("Nothing borrowed. Add Income with the type Borrowed to track it here.")
                        .foregroundStyle(Theme.secondary).padding(.horizontal, 18)
                }
                if !owed.lenders.isEmpty {
                    CardGroup(header: "Owed to") {
                        ForEach(owed.lenders, id: \.lender) { debt in
                            CardRow(title: debt.lender) {
                                Text(IndianMoneyFormat.string(debt.owed)).monospacedDigit()
                            }
                        }
                    }
                }
                if !owed.borrowings.isEmpty {
                    CardGroup(header: "Borrowings") {
                        ForEach(owed.borrowings, id: \.borrowing.id) { line in
                            Button { repaying = line.borrowing.id } label: {
                                CardRow(
                                    title: line.lender,
                                    subtitle: "\(line.borrowing.date.shortTitle) · borrowed \(IndianMoneyFormat.string(line.borrowing.amount))"
                                ) {
                                    Text(line.isRepaid ? "Repaid" : IndianMoneyFormat.string(line.owed))
                                        .foregroundStyle(line.isRepaid ? Theme.green : .primary)
                                        .monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("borrowingRow")
                        }
                    }
                }
            }
        }
        .cardNavigation("Amount to Repay")
        .sheet(item: $repaying) { id in RepaymentSheet(model: model, borrowingID: id) }
    }
}

private struct RepaymentSheet: View {
    let model: BudgetViewModel
    let borrowingID: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Amount repaid", text: $amountText)
                        .keyboardType(.decimalPad)
                        .rowPadding()
                        .accessibilityIdentifier("repaymentAmountField")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18)
                        .accessibilityIdentifier("repaymentError")
                }
                if let repayments = model.amountToRepay?.borrowings.first(where: { $0.borrowing.id == borrowingID })?.repayments,
                   !repayments.isEmpty {
                    CardGroup(header: "Repaid so far", footer: "Touch and hold an entry to delete it.") {
                        ForEach(repayments, id: \.id) { repayment in
                            CardRow(title: repayment.date.shortTitle) {
                                Text(IndianMoneyFormat.string(repayment.amount)).monospacedDigit()
                            }
                            .accessibilityIdentifier("repaymentRow")
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    errorMessage = model.deleteRepayment(repayment.id)
                                }
                            }
                        }
                    }
                }
            }
            .cardNavigation("Record Repayment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.recordRepayment(borrowingID, amountText: amountText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveRepaymentButton")
                }
            }
        }
    }
}
