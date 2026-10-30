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
            Form {
                Section {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("incomeAmountField")
                    Picker("Type", selection: $kind) {
                        Text("Choose").tag(IncomeKind?.none)
                        ForEach(IncomeKind.allCases, id: \.self) { Text($0.title).tag(IncomeKind?.some($0)) }
                    }
                    .accessibilityIdentifier("incomeTypePicker")
                    TextField(kind == .borrowed ? "Borrowed from" : "Note (optional)", text: $note)
                        .accessibilityIdentifier("incomeNoteField")
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("incomeErrorMessage")
                    }
                }
            }
            .navigationTitle("New Income")
            .navigationBarTitleDisplayMode(.inline)
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

extension IncomeKind {
    var title: String {
        switch self {
        case .salary: "Salary"
        case .savings: "Savings"
        case .investmentIncome: "Investment Income"
        case .moneyReceived: "Money Received"
        case .borrowed: "Borrowed"
        }
    }
}
