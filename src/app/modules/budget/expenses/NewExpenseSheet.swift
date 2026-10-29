import HisaabCore
import SwiftUI

struct NewExpenseSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var category = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("amountField")
                    TextField("Description", text: $description)
                        .accessibilityIdentifier("descriptionField")
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    Picker("Category", selection: $category) {
                        Text("Choose").tag("")
                        ForEach(DefaultCategories.expense, id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityIdentifier("categoryPicker")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("errorMessage")
                    }
                }
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("saveExpenseButton")
                }
            }
        }
    }

    private func save() {
        errorMessage = model.addExpense(
            date: date, description: description, amountText: amountText, category: category
        )
        if errorMessage == nil { dismiss() }
    }
}
