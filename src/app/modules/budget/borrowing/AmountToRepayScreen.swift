import HisaabCore
import SwiftUI

struct AmountToRepayScreen: View {
    let model: BudgetViewModel
    @State private var repaying: Int64?

    var body: some View {
        List {
            if let owed = model.amountToRepay {
                Section {
                    HStack {
                        Text("Amount to repay")
                        Spacer()
                        Text(IndianMoneyFormat.string(owed.total)).monospacedDigit()
                            .accessibilityIdentifier("repayTotal")
                    }
                }
                if owed.borrowings.isEmpty {
                    Text("Nothing borrowed. Add Income with the type Borrowed to track it here.")
                        .foregroundStyle(.secondary)
                }
                if !owed.lenders.isEmpty {
                    Section("Owed to") {
                        ForEach(owed.lenders, id: \.lender) { debt in
                            HStack {
                                Text(debt.lender)
                                Spacer()
                                Text(IndianMoneyFormat.string(debt.owed)).monospacedDigit()
                            }
                        }
                    }
                }
                Section("Borrowings") {
                    ForEach(owed.borrowings, id: \.borrowing.id) { line in
                        Button { repaying = line.borrowing.id } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(line.lender)
                                    Text("\(line.borrowing.date.shortTitle) · borrowed \(IndianMoneyFormat.string(line.borrowing.amount))")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(line.isRepaid ? "Repaid" : IndianMoneyFormat.string(line.owed))
                                    .foregroundStyle(line.isRepaid ? .green : .primary)
                                    .monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("borrowingRow")
                    }
                }
            }
        }
        .navigationTitle("Amount to Repay")
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
            Form {
                TextField("Amount repaid", text: $amountText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("repaymentAmountField")
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("repaymentError")
                }
                if let repayments = model.amountToRepay?.borrowings.first(where: { $0.borrowing.id == borrowingID })?.repayments,
                   !repayments.isEmpty {
                    Section("Repaid so far") {
                        ForEach(repayments, id: \.id) { repayment in
                            HStack {
                                Text(repayment.date.shortTitle)
                                Spacer()
                                Text(IndianMoneyFormat.string(repayment.amount)).monospacedDigit()
                            }
                            .accessibilityIdentifier("repaymentRow")
                            .swipeActions {
                                Button("Delete", role: .destructive) { errorMessage = model.deleteRepayment(repayment.id) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Record Repayment")
            .navigationBarTitleDisplayMode(.inline)
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
