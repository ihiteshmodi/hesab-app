import HisaabCore
import SwiftUI

extension PlannedItem: @retroactive Identifiable {}

struct NewBillSheet: View {
    let model: BudgetViewModel
    let editingID: Int64?
    let startingFrom: PlannedItem?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var category = ""
    @State private var subCategory = ""
    @State private var entity = ""
    @State private var payment = PaymentChoice.all[0]
    @State private var dueDate = Date()
    @State private var repeats = BillRepeat.monthly
    @State private var hasEnd = false
    @State private var endDate = Date()
    @State private var automatic = true
    @State private var alert = BillAlert.none
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    @State private var changingPlan = false

    init(model: BudgetViewModel, editing id: Int64? = nil, startingFrom item: PlannedItem? = nil) {
        self.model = model
        editingID = id
        startingFrom = item
        if let item {
            _name = State(initialValue: item.description)
            _amountText = State(initialValue: IndianMoneyFormat.plain(item.amount))
            _repeats = State(initialValue: .never)
            _automatic = State(initialValue: false)
        }
        if let id, let bill = model.bills.first(where: { $0.bill.id == id })?.bill {
            _name = State(initialValue: bill.name)
            _amountText = State(initialValue: IndianMoneyFormat.plain(bill.amount))
            _category = State(initialValue: bill.category)
            _subCategory = State(initialValue: bill.subCategory)
            _entity = State(initialValue: bill.entity)
            _payment = State(initialValue: PaymentChoice(method: bill.paymentMethod))
            _dueDate = State(initialValue: bill.firstDue.instant())
            _repeats = State(initialValue: bill.repeats)
            _hasEnd = State(initialValue: bill.endsOn != nil)
            _endDate = State(initialValue: bill.endsOn?.instant() ?? Date())
            _automatic = State(initialValue: bill.addAutomatically)
            _alert = State(initialValue: bill.alert)
            _notes = State(initialValue: bill.notes)
        }
    }

    private var paymentChoices: [PaymentChoice] {
        PaymentChoice.all
            + model.cards.map { PaymentChoice(method: .bank($0.name)) }
            + (model.ledgers?.ledgers ?? []).map { PaymentChoice(method: .ledger($0.ledger.name)) }
    }

    private var subCategories: [String] {
        model.categories.first { $0.name == category }?.subCategories.map(\.name) ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).accessibilityIdentifier("billNameField")
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("billAmountField")
                    Picker("Category", selection: $category) {
                        Text("Choose").tag("")
                        ForEach(model.categories, id: \.name) { Text($0.name).tag($0.name) }
                    }
                    .accessibilityIdentifier("billCategoryPicker")
                    if !subCategories.isEmpty {
                        Picker("Sub-category", selection: $subCategory) {
                            Text("None").tag("")
                            ForEach(subCategories, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Picker("Paid with", selection: $payment) {
                        ForEach(paymentChoices, id: \.title) { Text($0.title).tag($0) }
                    }
                    TextField("Shop or person (optional)", text: $entity)
                }
                Section {
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    Picker("Repeat", selection: $repeats) {
                        ForEach(BillRepeat.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("billRepeatPicker")
                    if repeats != .never {
                        Toggle("Ends", isOn: $hasEnd)
                        if hasEnd { DatePicker("End date", selection: $endDate, displayedComponents: .date) }
                    }
                    Toggle("Add automatically", isOn: automaticBinding)
                        .disabled(repeats == .never)
                    Picker("Alert", selection: $alert) {
                        ForEach(BillAlert.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField("Notes", text: $notes)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("billError") }
                }
                if editingID != nil {
                    Section {
                        Button("Change Plan") { changingPlan = true }
                        Button("Delete Bill", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(editingID == nil ? "New Bill" : "Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: repeats) { automatic = repeats != .never }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.accessibilityIdentifier("saveBillButton")
                }
            }
            .confirmationDialog("Delete this bill?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Bill", role: .destructive) {
                    if let editingID { errorMessage = model.deleteBill(editingID) }
                    if errorMessage == nil { dismiss() }
                }
            }
            .sheet(isPresented: $changingPlan) {
                if let editingID { ChangePlanSheet(model: model, billID: editingID) { dismiss() } }
            }
        }
    }

    private var automaticBinding: Binding<Bool> {
        Binding(get: { automatic && repeats != .never }, set: { automatic = $0 })
    }

    private func save() {
        let bill = NewBill(
            name: name, amount: MoneyInput.parse(amountText), category: category, subCategory: subCategory,
            entity: entity, paymentMethod: payment.method, dueDate: CalendarDate(dueDate), repeats: repeats,
            endsOn: hasEnd && repeats != .never ? CalendarDate(endDate) : nil,
            addAutomatically: automatic && repeats != .never, alert: alert, notes: notes
        )
        if let editingID {
            errorMessage = model.updateBill(editingID, bill)
        } else {
            errorMessage = model.addBill(bill)
            if errorMessage == nil, let startingFrom { _ = model.deletePlanned(startingFrom.id) }
        }
        if errorMessage == nil { dismiss() }
    }
}

private struct ChangePlanSheet: View {
    let model: BudgetViewModel
    let billID: Int64
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var oldEnds = Date()
    @State private var newStarts = Date()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Old plan ends on", selection: $oldEnds, displayedComponents: .date)
                TextField("New plan name", text: $name)
                TextField("New amount", text: $amountText).keyboardType(.decimalPad)
                DatePicker("New plan starts on", selection: $newStarts, displayedComponents: .date)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Change Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let old = model.bills.first(where: { $0.bill.id == billID })?.bill else { return }
                        let replacement = NewBill(
                            name: name, amount: MoneyInput.parse(amountText), category: old.category,
                            subCategory: old.subCategory, entity: old.entity, paymentMethod: old.paymentMethod,
                            dueDate: CalendarDate(newStarts), repeats: old.repeats, addAutomatically: old.addAutomatically,
                            alert: old.alert, notes: old.notes
                        )
                        errorMessage = model.changeBillPlan(billID, endsOn: CalendarDate(oldEnds), startingWith: replacement)
                        if errorMessage == nil {
                            dismiss()
                            onDone()
                        }
                    }
                }
            }
        }
    }
}
