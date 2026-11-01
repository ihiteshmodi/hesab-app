import HisaabCore
import SwiftUI

struct ExpenseDetailSheet: View {
    let model: BudgetViewModel
    let expenseID: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var receivedText = ""
    @State private var confirmingDelete = false
    @State private var editingID: Int64?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                if let expense = model.expense(id: expenseID) {
                    CardGroup {
                        row("Description", expense.description)
                        row("Amount", IndianMoneyFormat.string(expense.amount))
                        row("Costs you", IndianMoneyFormat.string(expense.netAmount))
                        if let foreign = expense.foreign {
                            row("Paid", model.text(foreign))
                            row("Rate", "\(foreign.rate) per 1 \(foreign.currency)")
                        }
                        row("Category", [expense.category, expense.subCategory].compactMap { $0 }.joined(separator: " › "))
                        if let entity = expense.entity { row("Shop or person", entity) }
                        if let spentFor = expense.spentFor { row("Spent for", spentFor) }
                        row("Paid with", expense.paymentMethod.name)
                        VStack(alignment: .leading, spacing: 4) {
                            CardCaption("Notes")
                            Text(expense.notes.isEmpty ? "No note" : expense.notes)
                                .foregroundStyle(expense.notes.isEmpty ? Theme.secondary : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("expenseNote")
                        }
                        .rowPadding()
                    }
                    refundSection(expense)
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18)
                            .accessibilityIdentifier("detailError")
                    }
                    Button("Delete Expense", role: .destructive) { confirmingDelete = true }
                        .buttonStyle(GreyButtonStyle(tint: Theme.red))
                        .accessibilityIdentifier("deleteExpenseButton")
                }
            }
            .cardNavigation("Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit") { editingID = expenseID }
                        .accessibilityIdentifier("editExpenseButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("doneButton")
                }
            }
            .sheet(item: $editingID) { id in
                if let expense = model.expense(id: id) {
                    NewExpenseSheet(model: model, editing: expense)
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
        CardGroup(header: "Refund") {
            switch expense.refund {
            case .notRefundable:
                action("Mark as Refundable") { errorMessage = model.markRefundable(expenseID) }
                    .accessibilityIdentifier("markRefundableButton")
            case .pending:
                receivedField
                action("Record Received") { record() }
                    .accessibilityIdentifier("recordReceivedButton")
                action("Unmark as Refundable") { errorMessage = model.unmarkRefundable(expenseID) }
            case .settled(let received):
                row("Received", IndianMoneyFormat.string(received))
                receivedField
                action("Change Received Amount") { record() }
                action("Undo Settlement") { errorMessage = model.undoSettlement(expenseID) }
                    .accessibilityIdentifier("undoSettlementButton")
            }
        }
    }

    private var receivedField: some View {
        TextField("Amount received", text: $receivedText)
            .keyboardType(.decimalPad)
            .rowPadding()
            .accessibilityIdentifier("receivedField")
    }

    private func record() {
        errorMessage = model.recordReceived(expenseID, amountText: receivedText)
        if errorMessage == nil { receivedText = "" }
    }

    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { Text(title).foregroundStyle(Theme.blue).rowPadding() }
            .buttonStyle(.plain)
    }

    private func row(_ title: String, _ value: String) -> some View {
        CardRow(title: title, titleColor: Theme.secondary) {
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}
