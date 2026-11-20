import HisaabCore
import SwiftUI

struct SearchScreen: View {
    let model: BudgetViewModel
    @State private var text = ""
    @State private var openedExpense: Int64?
    @State private var editingIncome: IncomeEntry?

    var body: some View {
        NavigationStack {
            CardScreen {
                if text.trimmingCharacters(in: .whitespaces).isEmpty {
                    CardPanel {
                        Text("Search expenses and income by description, shop or person, category, note, type or amount.")
                            .foregroundStyle(Theme.secondary)
                    }
                } else {
                    SearchResultsList(model: model, text: text, openExpense: { openedExpense = $0 }, openIncome: { editingIncome = $0 })
                }
            }
            .cardNavigation("Search")
            // iOS 26 anchors the default field at the bottom, behind the custom tab bar in RootView.
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search expenses and income")
            .onChange(of: text) { model.search(text) }
            .sheet(item: $openedExpense) { id in ExpenseDetailSheet(model: model, expenseID: id) }
            .sheet(item: $editingIncome) { NewIncomeSheet(model: model, editing: $0) }
        }
    }
}
