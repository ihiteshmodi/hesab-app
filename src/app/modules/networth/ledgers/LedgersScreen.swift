import HisaabCore
import SwiftUI

struct LedgersScreen: View {
    let model: BudgetViewModel
    @State private var adding = false

    var body: some View {
        CardScreen {
            if let overview = model.ledgers {
                if overview.ledgers.isEmpty {
                    CardPanel {
                        Text("No ledgers yet. Add one for each person whose money you hold.")
                            .foregroundStyle(Theme.secondary)
                    }
                } else {
                    CardGroup {
                        CardRow(title: "Held for others") {
                            Text(IndianMoneyFormat.string(overview.total)).monospacedDigit()
                                .accessibilityIdentifier("ledgersTotal")
                        }
                    }
                    CardGroup {
                        ForEach(overview.ledgers, id: \.ledger.id) { summary in
                            LinkRow(title: summary.ledger.name, value: IndianMoneyFormat.string(summary.balance), identifier: "ledgerRow") {
                                LedgerDetailScreen(model: model, ledgerID: summary.ledger.id)
                            }
                        }
                    }
                }
            }
        }
        .cardNavigation("Ledgers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Ledger", systemImage: "plus") { adding = true }
                    .accessibilityIdentifier("addLedgerButton")
            }
        }
        .sheet(isPresented: $adding) { NewLedgerSheet(model: model) }
    }
}

private struct NewLedgerSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var countsTowardsNetWorth = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Person", text: $name).rowPadding().accessibilityIdentifier("ledgerNameField")
                    Toggle("Counts towards my net worth", isOn: $countsTowardsNetWorth).rowPadding()
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Theme.red).rowPadding().accessibilityIdentifier("ledgerError")
                    }
                }
            }
            .cardNavigation("New Ledger")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addLedger(name: name, countsTowardsNetWorth: countsTowardsNetWorth)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveLedgerButton")
                }
            }
        }
    }
}

struct LedgerDetailScreen: View {
    let model: BudgetViewModel
    let ledgerID: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var addingEntry = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    private var summary: LedgerSummary? {
        model.ledgers?.ledgers.first { $0.ledger.id == ledgerID }
    }

    var body: some View {
        CardScreen {
            if let summary {
                CardGroup {
                    CardRow(title: "Balance") {
                        Text(IndianMoneyFormat.string(summary.balance)).monospacedDigit()
                            .accessibilityIdentifier("ledgerBalance")
                    }
                }
                CardGroup(header: "Entries", footer: summary.lines.isEmpty ? nil : "Touch and hold an entry to delete it.") {
                    ForEach(Array(summary.lines.enumerated()), id: \.offset) { _, line in
                        CardRow(title: line.description, subtitle: line.date.shortTitle) {
                            Text(IndianMoneyFormat.string(line.amount)).monospacedDigit()
                        }
                        .contextMenu {
                            if let entryID = line.entryID {
                                Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteLedgerEntry(entryID) }
                            }
                        }
                    }
                }
                if let errorMessage {
                    CardPanel { Text(errorMessage).foregroundStyle(Theme.red) }
                }
                Button("Delete Ledger", role: .destructive) { confirmingDelete = true }
                    .buttonStyle(GreyButtonStyle(tint: Theme.red))
            }
        }
        .cardNavigation(summary?.ledger.name ?? "Ledger")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Entry", systemImage: "plus") { addingEntry = true }
                    .accessibilityIdentifier("addLedgerEntryButton")
            }
        }
        .sheet(isPresented: $addingEntry) { NewLedgerEntrySheet(model: model, ledgerID: ledgerID) }
        .confirmationDialog("Delete this ledger and all its entries?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Ledger", role: .destructive) {
                errorMessage = model.deleteLedger(ledgerID)
                if errorMessage == nil { dismiss() }
            }
        }
    }
}

private struct NewLedgerEntrySheet: View {
    let model: BudgetViewModel
    let ledgerID: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var amountText = ""
    @State private var moneyOut = false
    @State private var errorMessage: String?
    @State private var warning: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("What for", text: $description).rowPadding()
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .rowPadding()
                        .accessibilityIdentifier("ledgerEntryAmountField")
                    FieldRow("Direction") {
                        Picker("Direction", selection: $moneyOut) {
                            Text("Money in").tag(false)
                            Text("Money out").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Theme.red).rowPadding().accessibilityIdentifier("ledgerEntryError")
                    }
                    if let warning {
                        Text(warning).foregroundStyle(Theme.orange).rowPadding().accessibilityIdentifier("ledgerWarning")
                    }
                }
                if warning != nil {
                    Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .cardNavigation("New Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.accessibilityIdentifier("saveLedgerEntryButton")
                }
            }
        }
    }

    private func save() {
        let result = model.addLedgerEntry(ledgerID, description: description, amountText: amountText, moneyOut: moneyOut)
        errorMessage = result.error
        warning = result.warning
        if result.error == nil && result.warning == nil { dismiss() }
    }
}
