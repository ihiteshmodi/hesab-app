import HisaabCore
import SwiftUI

struct NewExpenseSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var description = ""
    @State private var entity = ""
    @State private var date = Date()
    @State private var category = ""
    @State private var subCategory = ""
    @State private var spentFor = ""
    @State private var tagsText = ""
    @State private var payment = PaymentChoice.all[0]
    @State private var errorMessage: String?

    private var subCategories: [String] {
        DefaultCategories.tree.first { $0.name == category }?.subCategories ?? []
    }

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
                    TextField("Shop or person (optional)", text: $entity)
                        .accessibilityIdentifier("entityField")
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    Picker("Category", selection: $category) {
                        Text("Choose").tag("")
                        ForEach(DefaultCategories.tree, id: \.name) { Text($0.name).tag($0.name) }
                    }
                    .accessibilityIdentifier("categoryPicker")
                    if !subCategories.isEmpty {
                        Picker("Sub-category", selection: $subCategory) {
                            Text("None").tag("")
                            ForEach(subCategories, id: \.self) { Text($0).tag($0) }
                        }
                        .accessibilityIdentifier("subCategoryPicker")
                    }
                    Picker("Paid with", selection: $payment) {
                        ForEach(PaymentChoice.all, id: \.title) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("paymentPicker")
                }
                Section {
                    TextField("Spent for (leave empty for you)", text: $spentFor)
                        .accessibilityIdentifier("spentForField")
                    TextField("Tags, separated by commas", text: $tagsText)
                        .accessibilityIdentifier("tagsField")
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
            .onChange(of: category) { subCategory = "" }
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
        errorMessage = model.addExpense(NewExpense(
            date: CalendarDate(date), description: description, amount: MoneyInput.parse(amountText),
            category: category, subCategory: subCategory, entity: entity, spentFor: spentFor,
            tags: tagsText.split(separator: ",").map(String.init), paymentMethod: payment.method
        ))
        if errorMessage == nil { dismiss() }
    }
}

/// Until cards and ledgers are built, the payment methods are a short fixed list.
struct PaymentChoice: Hashable {
    let title: String
    let method: PaymentMethod

    static let all = [
        PaymentChoice(title: "UPI", method: .upi),
        PaymentChoice(title: "Credit Card", method: .bank("Credit Card")),
        PaymentChoice(title: "Cash Withdrawal", method: .cashWithdrawal),
        PaymentChoice(title: "Cash", method: .cash),
    ]
}
