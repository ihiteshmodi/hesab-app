import HisaabCore
import SwiftUI

struct SearchScreen: View {
    let model: BudgetViewModel
    @State private var text = ""
    @State private var openedExpense: Int64?

    var body: some View {
        NavigationStack {
            List {
                if text.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Search by description, shop or person, category, note or amount.").foregroundStyle(.secondary)
                } else if model.searchResults.groups.isEmpty {
                    Text("No expenses match \"\(text)\".").foregroundStyle(.secondary)
                        .accessibilityIdentifier("noResults")
                } else {
                    Section {
                        HStack {
                            Text("Total")
                            Spacer()
                            Text(IndianMoneyFormat.string(model.searchResults.total)).monospacedDigit()
                                .accessibilityIdentifier("searchTotal")
                        }
                    }
                    ForEach(model.searchResults.groups, id: \.month) { group in
                        Section(group.month.title) {
                            ForEach(group.expenses, id: \.id) { expense in
                                Button { openedExpense = expense.id } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(expense.description)
                                            Text([expense.entity, expense.category, expense.date.shortTitle]
                                                .compactMap { $0 }.joined(separator: " · "))
                                                .font(.footnote).foregroundStyle(.secondary)
                                        }
                                        Spacer()
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
            .navigationTitle("Search")
            .searchable(text: $text, prompt: "Search expenses")
            .onChange(of: text) { model.search(text) }
            .sheet(item: $openedExpense) { id in ExpenseDetailSheet(model: model, expenseID: id) }
        }
    }
}
