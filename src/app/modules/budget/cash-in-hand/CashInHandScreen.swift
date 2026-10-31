import HisaabCore
import SwiftUI

struct CashInHandScreen: View {
    let model: BudgetViewModel
    @State private var setting = false

    var body: some View {
        CardScreen {
            if let cash = model.cash {
                CardPanel {
                    CardCaption("Cash in hand")
                    Text(IndianMoneyFormat.string(cash.balance)).font(.system(size: 34, weight: .bold)).monospacedDigit()
                        .accessibilityIdentifier("cashBalance")
                    if let warning = cash.warning {
                        Text(warning).foregroundStyle(Theme.orange).accessibilityIdentifier("cashWarning")
                    }
                }
                CardGroup(header: "Where it went") {
                    if cash.lines.isEmpty {
                        Text("Nothing yet. Keep a cash withdrawal or set what you are holding.")
                            .foregroundStyle(Theme.secondary).rowPadding()
                    }
                    ForEach(Array(cash.lines.enumerated()), id: \.offset) { _, line in
                        CardRow(title: line.description, subtitle: line.date.shortTitle) {
                            VStack(alignment: .trailing) {
                                Text(IndianMoneyFormat.string(line.amount)).monospacedDigit()
                                Text(IndianMoneyFormat.string(line.runningBalance))
                                    .font(.footnote).foregroundStyle(Theme.secondary).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .cardNavigation("Cash in Hand")
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
            CardScreen {
                CardGroup {
                    TextField("Cash you are holding", text: $amountText)
                        .keyboardType(.decimalPad)
                        .rowPadding()
                        .accessibilityIdentifier("setCashField")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18)
                }
            }
            .cardNavigation("Set Cash in Hand")
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
