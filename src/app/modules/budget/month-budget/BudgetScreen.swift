import HisaabCore
import SwiftUI

struct BudgetScreen: View {
    let model: BudgetViewModel
    @State private var addingExpense = false

    var body: some View {
        NavigationStack {
            List {
                if let loadError = model.loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                if let budget = model.budget {
                    Section {
                        LeftToSpendCard(budget: budget)
                    }
                    Section(budget.month.title) {
                        if budget.expenses.isEmpty {
                            Text("No entries yet. Add your first expense.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(budget.expenses, id: \.id) { expense in
                            ExpenseRow(expense: expense)
                        }
                    }
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Expense", systemImage: "plus") { addingExpense = true }
                        .accessibilityIdentifier("addExpenseButton")
                }
            }
            .sheet(isPresented: $addingExpense) {
                NewExpenseSheet(model: model)
            }
        }
    }
}

private struct LeftToSpendCard: View {
    let budget: MonthBudget

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Left to spend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IndianMoneyFormat.string(budget.leftToSpend))
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(budget.leftToSpend < .zero ? Color.red : Color.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityIdentifier("leftToSpend")
            Divider()
            Text("Spent this month")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(IndianMoneyFormat.string(budget.spentThisMonth))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("spentThisMonth")
        }
        .padding(.vertical, 6)
    }
}

private struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                Text("\(expense.category) · \(expense.date.shortTitle)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(IndianMoneyFormat.string(expense.amount))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("expenseRow")
    }
}
