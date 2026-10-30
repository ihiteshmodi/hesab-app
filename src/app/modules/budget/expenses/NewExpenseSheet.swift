import HisaabCore
import SwiftUI

struct NewExpenseSheet: View {
    let model: BudgetViewModel
    /// Set when the sheet edits an existing expense instead of adding a new one.
    let editing: Expense?
    /// Set when the form starts from something else, such as a bill, and hands the result back instead of adding.
    let submit: ((NewExpense) -> String?)?
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
    @State private var keepAsCash = false
    @State private var dateStillToPick = false
    @State private var currency = ""
    @State private var rateText = ""
    @State private var paidText = ""
    @State private var pendingSubCategory: String?
    @State private var errorMessage: String?

    init(
        model: BudgetViewModel, editing: Expense? = nil, draft: NewExpense? = nil,
        submit: ((NewExpense) -> String?)? = nil
    ) {
        self.model = model
        self.editing = editing
        self.submit = submit
        if editing == nil, draft == nil, let travelling = model.preferences.spendingIn {
            _currency = State(initialValue: travelling)
            _rateText = State(initialValue: model.lastRate(for: travelling).map { "\($0)" } ?? "")
        }
        if let foreign = (editing?.foreign) {
            _currency = State(initialValue: foreign.currency)
            _rateText = State(initialValue: "\(foreign.rate)")
        }
        if let draft {
            _amountText = State(initialValue: draft.amount.map { IndianMoneyFormat.plain($0) } ?? "")
            _description = State(initialValue: draft.description)
            _entity = State(initialValue: draft.entity)
            _date = State(initialValue: draft.date?.instant() ?? Date())
            _dateStillToPick = State(initialValue: draft.date == nil)
            _category = State(initialValue: draft.category)
            _subCategory = State(initialValue: draft.subCategory)
            _spentFor = State(initialValue: draft.spentFor)
            _tagsText = State(initialValue: draft.tags.joined(separator: ", "))
            _payment = State(initialValue: PaymentChoice(method: draft.paymentMethod))
        }
        guard let editing else { return }
        _amountText = State(initialValue: IndianMoneyFormat.plain(editing.foreign?.amount ?? editing.amount))
        _description = State(initialValue: editing.description)
        _entity = State(initialValue: editing.entity ?? "")
        _date = State(initialValue: editing.date.instant())
        _category = State(initialValue: editing.category)
        _subCategory = State(initialValue: editing.subCategory ?? "")
        _spentFor = State(initialValue: editing.spentFor ?? "")
        _tagsText = State(initialValue: editing.tags.joined(separator: ", "))
        _payment = State(initialValue: PaymentChoice(method: editing.paymentMethod))
        _keepAsCash = State(initialValue: editing.keptAsCash)
    }

    private var paymentChoices: [PaymentChoice] {
        PaymentChoice.all
            + model.cards.map { PaymentChoice(method: .bank($0.name)) }
            + (model.ledgers?.ledgers ?? []).map { PaymentChoice(method: .ledger($0.ledger.name)) }
    }

    private var subCategories: [String] {
        model.categories.first { $0.name == category }?.subCategories.map(\.name) ?? []
    }

    private var categorySuggestion: CategoryChoice? {
        guard category.isEmpty else { return nil }
        return model.suggestCategory(forDescription: description)
            ?? (entity.isEmpty ? nil : model.suggestCategory(forEntity: entity))
    }

    private var entitySuggestions: [String] {
        guard !entity.isEmpty else { return [] }
        let found = model.suggestEntities(entity)
        return found.contains { $0.lowercased() == entity.lowercased() } ? [] : Array(found.prefix(4))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("amountField")
                    if model.currencies.count > 1 {
                        Picker("Currency", selection: $currency) {
                            Text(model.preferences.homeCurrency).tag("")
                            ForEach(model.currencies.filter { $0.code != model.preferences.homeCurrency }, id: \.code) {
                                Text($0.code).tag($0.code)
                            }
                        }
                        .accessibilityIdentifier("currencyPicker")
                        .onChange(of: currency) {
                            if !currency.isEmpty, rateText.isEmpty {
                                rateText = model.lastRate(for: currency).map { "\($0)" } ?? ""
                            }
                        }
                    }
                    if !currency.isEmpty {
                        TextField("Rate: \(model.preferences.homeCurrency) per 1 \(currency)", text: $rateText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("rateField")
                        TextField("Or what you actually paid in \(model.preferences.homeCurrency)", text: $paidText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("paidField")
                    }
                    TextField("Description", text: $description)
                        .accessibilityIdentifier("descriptionField")
                    TextField("Shop or person (optional)", text: $entity)
                        .accessibilityIdentifier("entityField")
                    ForEach(entitySuggestions, id: \.self) { name in
                        Button(name) { entity = name; applyLastUse(of: name) }
                            .accessibilityIdentifier("entitySuggestion")
                    }
                    if dateStillToPick {
                        Button("Pick a date") { dateStillToPick = false }
                            .accessibilityIdentifier("pickDateButton")
                    } else {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                }
                Section {
                    if let suggestion = categorySuggestion {
                        Button("Used before: \(suggestion.category)\(suggestion.subCategory.isEmpty ? "" : " > \(suggestion.subCategory)")") {
                            apply(suggestion)
                        }
                        .accessibilityIdentifier("usedBeforeButton")
                    }
                    if category.isEmpty, !model.recentCategories.isEmpty {
                        ForEach(model.recentCategories, id: \.self) { choice in
                            Button("\(choice.subCategory) (\(choice.category))") { apply(choice) }
                        }
                    }
                    Picker("Category", selection: $category) {
                        Text("Choose").tag("")
                        ForEach(model.categories, id: \.name) { Text($0.name).tag($0.name) }
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
                        ForEach(paymentChoices, id: \.title) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("paymentPicker")
                    if payment.method == .cashWithdrawal {
                        Toggle("Keep as cash in hand", isOn: $keepAsCash)
                            .accessibilityIdentifier("keepAsCashToggle")
                    }
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
            .navigationTitle(editing != nil ? "Edit Expense" : submit != nil ? "Add to Budget" : "New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: category) {
                subCategory = pendingSubCategory ?? ""
                pendingSubCategory = nil
            }
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

    private func apply(_ choice: CategoryChoice) {
        if category == choice.category {
            subCategory = choice.subCategory
        } else {
            pendingSubCategory = choice.subCategory
            category = choice.category
        }
    }

    private func applyLastUse(of name: String) {
        guard let last = model.entityLastUse(name) else { return }
        if category.isEmpty { apply(last.category) }
        if let match = (PaymentChoice.all + model.cards.map { PaymentChoice(method: .bank($0.name)) })
            .first(where: { $0.method == last.paymentMethod }) {
            payment = match
        }
    }

    private func save() {
        guard !dateStillToPick else {
            errorMessage = "Pick a date"
            return
        }
        let expense = NewExpense(
            date: CalendarDate(date), description: description,
            amount: currency.isEmpty ? MoneyInput.parse(amountText) : nil,
            category: category, subCategory: subCategory, entity: entity, spentFor: spentFor,
            tags: tagsText.split(separator: ",").map(String.init), paymentMethod: payment.method,
            notes: editing?.notes ?? "", keepAsCash: keepAsCash,
            foreign: currency.isEmpty ? nil : ForeignSpend(
                currency: currency, amount: MoneyInput.parse(amountText),
                rate: Decimal(string: rateText.trimmingCharacters(in: .whitespaces)),
                paidInHome: paidText.isEmpty ? nil : MoneyInput.parse(paidText)
            )
        )
        if let submit {
            errorMessage = submit(expense)
        } else {
            errorMessage = editing.map { model.updateExpense($0.id ?? 0, expense) } ?? model.addExpense(expense)
        }
        if errorMessage == nil { dismiss() }
    }
}

/// Cards and ledgers are added to these at runtime.
struct PaymentChoice: Hashable {
    let title: String
    let method: PaymentMethod

    init(method: PaymentMethod) {
        self.method = method
        title = method.source == .ledger ? "\(method.name) (ledger)" : method.name
    }

    static let all = [
        PaymentChoice(method: .upi),
        PaymentChoice(method: .cashWithdrawal),
        PaymentChoice(method: .cash),
    ]
}
