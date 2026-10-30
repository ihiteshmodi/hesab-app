import HisaabCore
import SwiftUI

struct LedgersScreen: View {
    let model: BudgetViewModel
    @State private var adding = false

    var body: some View {
        List {
            if let overview = model.ledgers {
                if overview.ledgers.isEmpty {
                    Text("No ledgers yet. Add one for each person whose money you hold.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        HStack {
                            Text("Held for others")
                            Spacer()
                            Text(IndianMoneyFormat.string(overview.total)).monospacedDigit()
                                .accessibilityIdentifier("ledgersTotal")
                        }
                    }
                    Section {
                        ForEach(overview.ledgers, id: \.ledger.id) { summary in
                            NavigationLink {
                                LedgerDetailScreen(model: model, ledgerID: summary.ledger.id)
                            } label: {
                                HStack {
                                    Text(summary.ledger.name)
                                    Spacer()
                                    Text(IndianMoneyFormat.string(summary.balance)).monospacedDigit()
                                }
                            }
                            .accessibilityIdentifier("ledgerRow")
                        }
                    }
                }
            }
        }
        .navigationTitle("Ledgers")
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
            Form {
                TextField("Person", text: $name).accessibilityIdentifier("ledgerNameField")
                Toggle("Counts towards my net worth", isOn: $countsTowardsNetWorth)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("ledgerError")
                }
            }
            .navigationTitle("New Ledger")
            .navigationBarTitleDisplayMode(.inline)
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
        List {
            if let summary {
                Section {
                    HStack {
                        Text("Balance")
                        Spacer()
                        Text(IndianMoneyFormat.string(summary.balance)).monospacedDigit()
                            .accessibilityIdentifier("ledgerBalance")
                    }
                }
                Section("Entries") {
                    ForEach(Array(summary.lines.enumerated()), id: \.offset) { _, line in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(line.description)
                                Text(line.date.shortTitle).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(IndianMoneyFormat.string(line.amount)).monospacedDigit()
                        }
                        .swipeActions {
                            if let entryID = line.entryID {
                                Button("Delete", role: .destructive) { errorMessage = model.deleteLedgerEntry(entryID) }
                            }
                        }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button("Delete Ledger", role: .destructive) { confirmingDelete = true }
                }
            }
        }
        .navigationTitle(summary?.ledger.name ?? "Ledger")
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
            Form {
                TextField("What for", text: $description)
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("ledgerEntryAmountField")
                Picker("Direction", selection: $moneyOut) {
                    Text("Money in").tag(false)
                    Text("Money out").tag(true)
                }
                .pickerStyle(.segmented)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("ledgerEntryError")
                }
                if let warning {
                    Text(warning).foregroundStyle(.orange).accessibilityIdentifier("ledgerWarning")
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
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
