import HisaabCore
import SwiftUI

struct ExpenseDetailSheet: View {
    let model: BudgetViewModel
    let expenseID: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var receivedText = ""
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let expense = model.expense(id: expenseID) {
                    Section {
                        row("Description", expense.description)
                        row("Amount", IndianMoneyFormat.string(expense.amount))
                        row("Costs you", IndianMoneyFormat.string(expense.netAmount))
                        row("Category", [expense.category, expense.subCategory].compactMap { $0 }.joined(separator: " › "))
                        if let entity = expense.entity { row("Shop or person", entity) }
                        if let spentFor = expense.spentFor { row("Spent for", spentFor) }
                        row("Paid with", expense.paymentMethod.name)
                    }
                    refundSection(expense)
                    if let errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("detailError")
                        }
                    }
                    Section {
                        Button("Delete Expense", role: .destructive) { confirmingDelete = true }
                            .accessibilityIdentifier("deleteExpenseButton")
                    }
                }
            }
            .navigationTitle("Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("doneButton")
                }
            }
            .confirmationDialog("Delete this expense?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Expense", role: .destructive) {
                    errorMessage = model.deleteExpense(expenseID)
                    if errorMessage == nil { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func refundSection(_ expense: Expense) -> some View {
        Section("Refund") {
            switch expense.refund {
            case .notRefundable:
                Button("Mark as Refundable") { errorMessage = model.markRefundable(expenseID) }
                    .accessibilityIdentifier("markRefundableButton")
            case .pending:
                receivedField
                Button("Record Received") { record() }
                    .accessibilityIdentifier("recordReceivedButton")
                Button("Unmark as Refundable") { errorMessage = model.unmarkRefundable(expenseID) }
            case .settled(let received):
                row("Received", IndianMoneyFormat.string(received))
                receivedField
                Button("Change Received Amount") { record() }
                Button("Undo Settlement") { errorMessage = model.undoSettlement(expenseID) }
                    .accessibilityIdentifier("undoSettlementButton")
            }
        }
    }

    private var receivedField: some View {
        TextField("Amount received", text: $receivedText)
            .keyboardType(.decimalPad)
            .accessibilityIdentifier("receivedField")
    }

    private func record() {
        errorMessage = model.recordReceived(expenseID, amountText: receivedText)
        if errorMessage == nil { receivedText = "" }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
