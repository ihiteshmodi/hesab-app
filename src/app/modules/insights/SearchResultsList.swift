import HisaabCore
import SwiftUI

/// What a search found, expenses and income together; shared by the Search tab and the Activity search field.
struct SearchResultsList: View {
    /// What to look through: the Search tab shows both, Activity follows its tab.
    enum Scope { case expenses, income, both }

    let model: BudgetViewModel
    let text: String
    var scope = Scope.both
    let openExpense: (Int64) -> Void
    let openIncome: (IncomeEntry) -> Void

    private var expenseGroups: [SearchMonth] { scope == .income ? [] : model.searchResults.groups }
    private var incomeEntries: [IncomeEntry] { scope == .expenses ? [] : model.incomeResults.entries }

    var body: some View {
        if expenseGroups.isEmpty, incomeEntries.isEmpty {
            CardPanel {
                Text("Nothing matches \"\(text)\".").foregroundStyle(Theme.secondary)
                    .accessibilityIdentifier("noResults")
            }
        }
        if !expenseGroups.isEmpty {
            CardGroup {
                CardRow(title: "Expenses total") {
                    Text(IndianMoneyFormat.string(model.searchResults.total)).monospacedDigit().fontWeight(.semibold)
                        .accessibilityIdentifier("searchTotal")
                }
            }
            ForEach(expenseGroups, id: \.month) { group in
                CardGroup(header: group.month.title) {
                    ForEach(group.expenses, id: \.id) { expense in
                        Button { openExpense(expense.id ?? 0) } label: {
                            CardRow(title: expense.description,
                                    subtitle: [expense.entity, expense.category, expense.date.shortTitle]
                                        .compactMap { $0 }.joined(separator: " · ")) {
                                Text(IndianMoneyFormat.string(expense.amount)).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("searchResultRow")
                    }
                }
            }
        }
        if !incomeEntries.isEmpty {
            CardGroup(header: "Income", footer: "Tap an entry to change it.") {
                CardRow(title: "Income total") {
                    Text(IndianMoneyFormat.string(model.incomeResults.total)).monospacedDigit().fontWeight(.semibold)
                        .accessibilityIdentifier("searchIncomeTotal")
                }
                ForEach(incomeEntries, id: \.id) { entry in
                    Button { openIncome(entry) } label: { IncomeRow(entry: entry) }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("searchIncomeRow")
                }
            }
        }
    }
}
