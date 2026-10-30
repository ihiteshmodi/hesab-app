import HisaabCore
import SwiftUI

struct SettingsScreen: View {
    let model: BudgetViewModel
    @State private var addingCurrency = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Currency") {
                Picker("Home currency", selection: Binding(
                    get: { model.preferences.homeCurrency },
                    set: { errorMessage = model.setHomeCurrency($0) }
                )) {
                    ForEach(model.currencies, id: \.code) { Text($0.code).tag($0.code) }
                }
                Picker("Spending in", selection: Binding(
                    get: { model.preferences.spendingIn ?? "" },
                    set: { value in model.updatePreferences { $0.spendingIn = value.isEmpty ? nil : value } }
                )) {
                    Text("Home currency").tag("")
                    ForEach(model.currencies.filter { $0.code != model.preferences.homeCurrency }, id: \.code) {
                        Text($0.code).tag($0.code)
                    }
                }
                .accessibilityIdentifier("spendingInPicker")
                Button("Add Currency") { addingCurrency = true }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            Section("Income & Expense Settings") {
                toggle("Count money received as income", \.countMoneyReceivedAsIncome)
                toggle("Count borrowed money as income", \.countBorrowedAsIncome)
                toggle("Include cash and ledger spending in Spent this month", \.includeCashAndLedgerInSpent)
            }
            Section("Due Date Settings") {
                Picker("Payment date", selection: Binding(
                    get: { model.preferences.paymentDate }, set: { value in model.updatePreferences { $0.paymentDate = value } }
                )) {
                    Text("Use due date").tag(Preferences.PaymentDate.useDueDate)
                    Text("Use today").tag(Preferences.PaymentDate.useToday)
                    Text("Ask each time").tag(Preferences.PaymentDate.askEachTime)
                }
                .accessibilityIdentifier("paymentDatePicker")
                toggle("Show exact days", \.showExactDays)
            }
            Section("Upcoming Bill Filters") {
                Picker("Show bills due within", selection: Binding(
                    get: { model.preferences.upcomingWindowDays }, set: { value in model.updatePreferences { $0.upcomingWindowDays = value } }
                )) {
                    Text("1 week").tag(7)
                    Text("2 weeks").tag(14)
                    Text("1 month").tag(30)
                    Text("2 months").tag(60)
                }
                toggle("Include past due", \.includePastDue)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $addingCurrency) { NewCurrencySheet(model: model) }
    }

    private func toggle(_ title: String, _ keyPath: WritableKeyPath<Preferences, Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { model.preferences[keyPath: keyPath] }, set: { value in model.updatePreferences { $0[keyPath: keyPath] = value } }
        ))
    }
}

private struct NewCurrencySheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var name = ""
    @State private var symbol = ""
    @State private var decimals = 2
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Code, for example VND", text: $code).textInputAutocapitalization(.characters)
                TextField("Name", text: $name)
                TextField("Symbol (optional)", text: $symbol)
                Picker("Decimals", selection: $decimals) {
                    Text("None").tag(0)
                    Text("2").tag(2)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("New Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addCurrency(code: code, name: name, symbol: symbol, decimals: decimals)
                        if errorMessage == nil { dismiss() }
                    }
                }
            }
        }
    }
}
