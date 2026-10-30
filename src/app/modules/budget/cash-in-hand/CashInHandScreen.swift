import HisaabCore
import SwiftUI

struct CashInHandScreen: View {
    let model: BudgetViewModel
    @State private var setting = false

    var body: some View {
        List {
            if let cash = model.cash {
                Section {
                    HStack {
                        Text("Cash in hand")
                        Spacer()
                        Text(IndianMoneyFormat.string(cash.balance)).monospacedDigit()
                            .accessibilityIdentifier("cashBalance")
                    }
                    if let warning = cash.warning {
                        Text(warning).foregroundStyle(.orange).accessibilityIdentifier("cashWarning")
                    }
                }
                Section("Where it went") {
                    if cash.lines.isEmpty {
                        Text("Nothing yet. Keep a cash withdrawal or set what you are holding.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(cash.lines.enumerated()), id: \.offset) { _, line in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(line.description)
                                Text(line.date.shortTitle).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(IndianMoneyFormat.string(line.amount)).monospacedDigit()
                                Text(IndianMoneyFormat.string(line.runningBalance))
                                    .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Cash in Hand")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Set Cash", systemImage: "pencil") { setting = true }
                    .accessibilityIdentifier("setCashButton")
            }
        }
        .sheet(isPresented: $setting) { SetCashSheet(model: model) }
    }
}

private struct SetCashSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Cash you are holding", text: $amountText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("setCashField")
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Set Cash in Hand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.setCashInHand(amountText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveCashButton")
                }
            }
        }
    }
}
