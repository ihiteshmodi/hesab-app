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

struct NewLedgerSheet: View {
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
    /// Portfolio hides amounts until its eye is used; so does the ledger opened from it.
    var hidden = false
    @Environment(\.dismiss) private var dismiss
    @State private var addingEntry = false
    @State private var editingLine: LedgerLine?
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    private var summary: LedgerSummary? {
        model.ledgers?.ledgers.first { $0.ledger.id == ledgerID }
    }

    private func money(_ value: Money) -> String { hidden ? "••••••" : IndianMoneyFormat.string(value) }

    var body: some View {
        CardScreen {
            if let summary {
                CardGroup {
                    CardRow(title: "Balance") {
                        Text(money(summary.balance)).monospacedDigit()
                            .accessibilityIdentifier("ledgerBalance")
                    }
                    Toggle("Counts towards my net worth", isOn: Binding(
                        get: { summary.ledger.countsTowardsNetWorth },
                        set: { errorMessage = model.setLedgerCountsTowardsNetWorth(ledgerID, $0) }
                    ))
                    .rowPadding()
                    .accessibilityIdentifier("ledgerCountedToggle")
                }
                CardGroup(header: "Entries", footer: summary.lines.isEmpty ? nil : "Tap an entry to change it. Touch and hold to delete it.") {
                    ForEach(Array(summary.lines.enumerated()), id: \.offset) { _, line in
                        Button { if line.entryID != nil { editingLine = line } } label: {
                            CardRow(title: line.description, subtitle: line.date.shortTitle) {
                                Text(money(line.amount)).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("ledgerEntryRow")
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
                Button("Rename", systemImage: "pencil") { newName = summary?.ledger.name ?? ""; renaming = true }
                    .accessibilityIdentifier("renameLedgerButton")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Entry", systemImage: "plus") { addingEntry = true }
                    .accessibilityIdentifier("addLedgerEntryButton")
            }
        }
        .alert("Rename", isPresented: $renaming) {
            TextField("Person", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { errorMessage = model.renameLedger(ledgerID, to: newName) }
        }
        .sheet(isPresented: $addingEntry) { NewLedgerEntrySheet(model: model, ledgerID: ledgerID) }
        .sheet(item: $editingLine) { NewLedgerEntrySheet(model: model, ledgerID: ledgerID, editing: $0) }
        .confirmationDialog("Delete this ledger and all its entries?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Ledger", role: .destructive) {
                errorMessage = model.deleteLedger(ledgerID)
                if errorMessage == nil { dismiss() }
            }
        }
    }
}

extension LedgerLine: @retroactive Identifiable {
    public var id: Int64 { entryID ?? 0 }
}

private struct NewLedgerEntrySheet: View {
    let model: BudgetViewModel
    let ledgerID: Int64
    var editing: LedgerLine?
    @Environment(\.dismiss) private var dismiss
    @State private var description: String
    @State private var amountText: String
    @State private var moneyOut: Bool
    @State private var date: Date
    @State private var errorMessage: String?
    @State private var warning: String?

    init(model: BudgetViewModel, ledgerID: Int64, editing line: LedgerLine? = nil) {
        self.model = model
        self.ledgerID = ledgerID
        editing = line
        _description = State(initialValue: line?.description ?? "")
        _amountText = State(initialValue: line.map { IndianMoneyFormat.plain($0.amount < .zero ? .zero - $0.amount : $0.amount) } ?? "")
        _moneyOut = State(initialValue: (line?.amount ?? .zero) < .zero)
        _date = State(initialValue: line?.date.instant() ?? Date())
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("What for", text: $description).rowPadding().accessibilityIdentifier("ledgerEntryTitleField")
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
                    FieldRow("Date") { DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden() }
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
            .cardNavigation(editing == nil ? "New Entry" : "Edit Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.accessibilityIdentifier("saveLedgerEntryButton")
                }
            }
        }
    }

    private func save() {
        let result = model.addLedgerEntry(
            ledgerID, description: description, amountText: amountText, moneyOut: moneyOut,
            date: CalendarDate(date), editing: editing?.entryID
        )
        errorMessage = result.error
        warning = result.warning
        if result.error == nil && result.warning == nil { dismiss() }
    }
}
