import HisaabCore
import SwiftUI

struct PendingRefundsScreen: View {
    let model: BudgetViewModel
    @State private var openedExpense: Int64?

    var body: some View {
        CardScreen {
            if let pending = model.pendingRefunds {
                if pending.expenses.isEmpty {
                    CardPanel {
                        Text("Nothing pending. Refunds you are waiting for appear here.")
                            .foregroundStyle(Theme.secondary)
                    }
                } else {
                    CardGroup {
                        CardRow(title: "Still to come back") {
                            Text(IndianMoneyFormat.string(pending.stillToCome)).monospacedDigit()
                        }
                    }
                    CardGroup {
                        ForEach(pending.expenses, id: \.id) { expense in
                            Button { openedExpense = expense.id } label: {
                                CardRow(title: expense.description, subtitle: expense.date.shortTitle) {
                                    Text(IndianMoneyFormat.string(expense.amount)).monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .cardNavigation("Pending Refunds")
        .sheet(item: $openedExpense) { id in
            ExpenseDetailSheet(model: model, expenseID: id)
        }
    }
}
