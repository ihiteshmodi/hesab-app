import HisaabCore
import SwiftUI

struct NewIncomeSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var kind: IncomeKind?
    @State private var note = ""
    @State private var date = Date()
    @State private var errorMessage: String?

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
            .cardNavigation("New Income")
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
        errorMessage = model.addIncome(NewIncome(
            date: CalendarDate(date), kind: kind, amount: MoneyInput.parse(amountText), note: note
        ))
        if errorMessage == nil { dismiss() }
    }
}


