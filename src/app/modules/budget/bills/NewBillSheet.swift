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
    @State private var alert = BillAlert.none
    @State private var notes = ""
    @State private var autoDebit = false
    @State private var automatic = false
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    @State private var changingPlan = false
    @FocusState private var typing: Bool

    init(model: BudgetViewModel, editing id: Int64? = nil, startingFrom item: PlannedItem? = nil) {
        self.model = model
        editingID = id
        startingFrom = item
        if let item {
            _name = State(initialValue: item.description)
            _amountText = State(initialValue: IndianMoneyFormat.plain(item.amount))
            _repeats = State(initialValue: .never)
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
            _alert = State(initialValue: bill.alert)
            _notes = State(initialValue: bill.notes)
            _autoDebit = State(initialValue: bill.autoDebit)
            _automatic = State(initialValue: bill.addAutomatically)
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
            CardScreen {
                CardGroup {
                    TextField("Name", text: $name).focused($typing).rowPadding().accessibilityIdentifier("billNameField")
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($typing)
                        .rowPadding()
                        .accessibilityIdentifier("billAmountField")
                    FieldRow("Category") {
                        Picker("Category", selection: $category) {
                            Text("Choose").tag("")
                            ForEach(model.categories, id: \.name) { Text($0.name).tag($0.name) }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("billCategoryPicker")
                    }
                    if !subCategories.isEmpty {
                        FieldRow("Sub-category") {
                            Picker("Sub-category", selection: $subCategory) {
                                Text("None").tag("")
                                ForEach(subCategories, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                        }
                    }
                    FieldRow("Paid with") {
                        Picker("Paid with", selection: $payment) {
                            ForEach(paymentChoices, id: \.title) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                    }
                    TextField("Shop or person (optional)", text: $entity).rowPadding()
                }
                CardGroup {
                    FieldRow("Due date") {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date).labelsHidden()
                    }
                    FieldRow("Repeat") {
                        Picker("Repeat", selection: $repeats) {
                            ForEach(BillRepeat.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("billRepeatPicker")
                    }
                    if repeats != .never {
                        Toggle("Ends", isOn: $hasEnd).rowPadding()
                        if hasEnd {
                            FieldRow("End date") {
                                DatePicker("End date", selection: $endDate, displayedComponents: .date).labelsHidden()
                            }
                        }
                    }
                    Toggle("Debits by itself", isOn: $autoDebit).rowPadding()
                        .accessibilityIdentifier("billAutoDebitToggle")
                    if repeats != .never {
                        Toggle("Add to budget automatically on its day", isOn: $automatic).rowPadding()
                            .accessibilityIdentifier("billAutoToggle")
                    }
                    FieldRow("Alert") {
                        Picker("Alert", selection: $alert) {
                            ForEach(BillAlert.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                    }
                    TextField("Notes", text: $notes).rowPadding()
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("billError")
                }
                if editingID != nil {
                    Button("Change Plan") { changingPlan = true }.buttonStyle(GreyButtonStyle())
                    Button("Delete Bill", role: .destructive) { confirmingDelete = true }
                        .buttonStyle(GreyButtonStyle(tint: Theme.red))
                }
            }
            .onChange(of: autoDebit) { if autoDebit, repeats != .never { automatic = true } }
            .cardNavigation(editingID == nil ? "New Bill" : "Edit Bill")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { typing = false }.accessibilityIdentifier("keyboardDoneButton")
                }
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


    private func save() {
        let bill = NewBill(
            name: name, amount: MoneyInput.parse(amountText), category: category, subCategory: subCategory,
            entity: entity, paymentMethod: payment.method, dueDate: CalendarDate(dueDate), repeats: repeats,
            endsOn: hasEnd && repeats != .never ? CalendarDate(endDate) : nil,
            addAutomatically: automatic && repeats != .never, alert: alert, notes: notes, autoDebit: autoDebit
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
            CardScreen {
                CardGroup {
                    FieldRow("Old plan ends on") {
                        DatePicker("Old plan ends on", selection: $oldEnds, displayedComponents: .date).labelsHidden()
                    }
                    TextField("New plan name", text: $name).rowPadding()
                    TextField("New amount", text: $amountText).keyboardType(.decimalPad).rowPadding()
                    FieldRow("New plan starts on") {
                        DatePicker("New plan starts on", selection: $newStarts, displayedComponents: .date).labelsHidden()
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
            }
            .cardNavigation("Change Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let old = model.bills.first(where: { $0.bill.id == billID })?.bill else { return }
                        let replacement = NewBill(
                            name: name, amount: MoneyInput.parse(amountText), category: old.category,
                            subCategory: old.subCategory, entity: old.entity, paymentMethod: old.paymentMethod,
                            dueDate: CalendarDate(newStarts), repeats: old.repeats, addAutomatically: old.addAutomatically,
                            alert: old.alert, notes: old.notes, autoDebit: old.autoDebit
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
