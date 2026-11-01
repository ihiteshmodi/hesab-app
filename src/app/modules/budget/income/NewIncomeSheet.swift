import HisaabCore
import SwiftUI

struct NewIncomeSheet: View {
    let model: BudgetViewModel
    let editing: IncomeEntry?
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var kind: IncomeKind?
    @State private var note: String
    @State private var date: Date
    @State private var errorMessage: String?

    init(model: BudgetViewModel, editing entry: IncomeEntry? = nil) {
        self.model = model
        editing = entry
        _amountText = State(initialValue: entry.map { IndianMoneyFormat.plain($0.amount) } ?? "")
        _kind = State(initialValue: entry?.kind)
        _note = State(initialValue: entry?.note ?? "")
        _date = State(initialValue: entry?.date.instant() ?? Date())
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .rowPadding()
                        .accessibilityIdentifier("incomeAmountField")
                    FieldRow("Type") {
                        Picker("Type", selection: $kind) {
                            Text("Choose").tag(IncomeKind?.none)
                            ForEach(IncomeKind.allCases, id: \.self) { Text($0.title).tag(IncomeKind?.some($0)) }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("incomeTypePicker")
                    }
                    TextField(kind == .borrowed ? "Borrowed from" : "Note (optional)", text: $note)
                        .rowPadding()
                        .accessibilityIdentifier("incomeNoteField")
                    FieldRow("Date") {
                        DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden()
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Theme.red)
                        .padding(.horizontal, 18)
                        .accessibilityIdentifier("incomeErrorMessage")
                }
            }
            .cardNavigation(editing == nil ? "New Income" : "Edit Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("saveIncomeButton")
                }
            }
        }
    }

    private func save() {
        let income = NewIncome(date: CalendarDate(date), kind: kind, amount: MoneyInput.parse(amountText), note: note)
        errorMessage = if let editing { model.updateIncome(editing.id, income) } else { model.addIncome(income) }
        if errorMessage == nil { dismiss() }
    }
}


