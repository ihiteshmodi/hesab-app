import HisaabCore
import SwiftUI

struct BudgetScreen: View {
    let model: BudgetViewModel
    @State private var addingExpense = false
    @State private var addingIncome = false

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
                        if budget.hasNoEntriesAtAll {
                            Text("No entries yet. Add your first expense or income.")
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
                    Menu {
                        Button("Add Expense", systemImage: "minus.circle") { addingExpense = true }
                            .accessibilityIdentifier("addExpenseButton")
                        Button("Add Income", systemImage: "plus.circle") { addingIncome = true }
                            .accessibilityIdentifier("addIncomeButton")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addMenu")
                }
            }
            .sheet(isPresented: $addingExpense) {
                NewExpenseSheet(model: model)
            }
            .sheet(isPresented: $addingIncome) {
                NewIncomeSheet(model: model)
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
            Text("Income this month")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(IndianMoneyFormat.string(budget.incomeThisMonth))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("incomeThisMonth")
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
                Text([expense.subCategory ?? expense.category, expense.entity, expense.date.shortTitle]
                    .compactMap { $0 }.joined(separator: " · "))
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
