import HisaabCore
import SwiftUI

struct PendingRefundsScreen: View {
    let model: BudgetViewModel
    @State private var openedExpense: Int64?

    var body: some View {
        List {
            if let pending = model.pendingRefunds {
                if pending.expenses.isEmpty {
                    Text("Nothing pending. Refunds you are waiting for appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        HStack {
                            Text("Still to come back")
                            Spacer()
                            Text(IndianMoneyFormat.string(pending.stillToCome)).monospacedDigit()
                        }
                    }
                    Section {
                        ForEach(pending.expenses, id: \.id) { expense in
                            Button { openedExpense = expense.id } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(expense.description)
                                        Text(expense.date.shortTitle).font(.footnote).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(IndianMoneyFormat.string(expense.amount)).monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Pending Refunds")
        .sheet(item: $openedExpense) { id in
            ExpenseDetailSheet(model: model, expenseID: id)
        }
    }
}
