import HisaabCore
import SwiftUI

struct SearchScreen: View {
    let model: BudgetViewModel
    @State private var text = ""
    @State private var openedExpense: Int64?

    var body: some View {
        NavigationStack {
            CardScreen {
                if text.trimmingCharacters(in: .whitespaces).isEmpty {
                    CardPanel {
                        Text("Search by description, shop or person, category, note or amount.").foregroundStyle(Theme.secondary)
                    }
                } else if model.searchResults.groups.isEmpty {
                    CardPanel {
                        Text("No expenses match \"\(text)\".").foregroundStyle(Theme.secondary)
                            .accessibilityIdentifier("noResults")
                    }
                } else {
                    CardGroup {
                        CardRow(title: "Total") {
                            Text(IndianMoneyFormat.string(model.searchResults.total)).monospacedDigit().fontWeight(.semibold)
                                .accessibilityIdentifier("searchTotal")
                        }
                    }
                    ForEach(model.searchResults.groups, id: \.month) { group in
                        CardGroup(header: group.month.title) {
                            ForEach(group.expenses, id: \.id) { expense in
                                Button { openedExpense = expense.id } label: {
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
            }
            .cardNavigation("Search")
            // iOS 26 anchors the default field at the bottom, behind the custom tab bar in RootView.
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search expenses")
            .onChange(of: text) { model.search(text) }
            .sheet(item: $openedExpense) { id in ExpenseDetailSheet(model: model, expenseID: id) }
        }
    }
}
