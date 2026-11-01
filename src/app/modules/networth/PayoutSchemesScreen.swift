import HisaabCore
import SwiftUI

extension PayoutScheme: @retroactive Identifiable {}

struct PayoutSchemesScreen: View {
    let model: BudgetViewModel
    let hidden: Bool
    let toggleHidden: () -> Void
    @State private var adding = false
    @State private var editing: PayoutScheme?
    @State private var recording: PayoutScheme?
    @State private var closing: PayoutScheme?
    @State private var reminder: String?
    @State private var errorMessage: String?

    private func money(_ value: Money) -> String { hidden ? "••••••" : IndianMoneyFormat.string(value) }

    var body: some View {
        CardScreen {
            if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
            if let reminder { Text(reminder).foregroundStyle(Theme.orange).padding(.horizontal, 18).accessibilityIdentifier("schemeReminder") }
            CardGroup {
                CardRow(title: "Invested") { Text(money(model.payouts.investedTotal)).monospacedDigit() }
                CardRow(title: "Monthly payout") { Text(money(model.payouts.monthlyPayoutTotal)).monospacedDigit() }
            }
            CardGroup(header: "Schemes", footer: model.payouts.schemes.isEmpty ? nil : "Touch and hold a scheme to edit it, record a payout or close it.") {
                if model.payouts.schemes.isEmpty { Text("No schemes yet.").foregroundStyle(Theme.secondary).rowPadding() }
                ForEach(model.payouts.schemes, id: \.scheme.id) { line in
                    let scheme = line.scheme
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                Text(scheme.name).font(.headline)
                                if scheme.isClosed { StatusPill(text: "closed") }
                            }
                            Text("Pays on the \(scheme.payoutDay)th" + (scheme.maturity.map { " · matures \($0.shortTitle)" } ?? ""))
                                .font(.footnote).foregroundStyle(Theme.secondary)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(money(scheme.invested)).monospacedDigit()
                            Text("\(money(scheme.monthlyPayout)) / month").font(.footnote).foregroundStyle(Theme.green).monospacedDigit()
                        }
                    }
                    .rowPadding()
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { editing = scheme }
                        if !scheme.isClosed {
                            Button("Record Payout", systemImage: "indianrupeesign.circle") { recording = scheme }
                            Button("Close", systemImage: "xmark.circle") { closing = scheme }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("schemeRow")
                }
            }
        }
        .cardNavigation("Payout Schemes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.preferences.hideBalances {
                    Button(hidden ? "Show" : "Hide", systemImage: hidden ? "eye" : "eye.slash") { toggleHidden() }
                        .accessibilityIdentifier("schemesEyeButton")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Scheme", systemImage: "plus") { adding = true }.accessibilityIdentifier("addSchemeButton")
            }
        }
        .sheet(isPresented: $adding) { NewSchemeSheet(model: model) }
        .sheet(item: $editing) { NewSchemeSheet(model: model, editing: $0) }
        .sheet(item: $recording) { RecordPayoutSheet(model: model, scheme: $0) }
        .confirmationDialog("Close this scheme?", isPresented: Binding(get: { closing != nil }, set: { if !$0 { closing = nil } }), titleVisibility: .visible) {
            Button("Close Scheme", role: .destructive) {
                if let closing { errorMessage = model.closeScheme(closing.id); if errorMessage == nil { reminder = "Closed. Update your bank balance." } }
                closing = nil
            }
        }
    }
}

struct NewSchemeSheet: View {
    let model: BudgetViewModel
    var editing: PayoutScheme?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var investedText = ""
    @State private var payoutText = ""
    @State private var payoutDay = 5
    @State private var hasMaturity = false
    @State private var maturity = Date()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Name", text: $name).rowPadding().accessibilityIdentifier("schemeNameField")
                    TextField("Amount invested", text: $investedText).keyboardType(.decimalPad).rowPadding().accessibilityIdentifier("schemeInvestedField")
                    TextField("Monthly payout", text: $payoutText).keyboardType(.decimalPad).rowPadding().accessibilityIdentifier("schemePayoutField")
                    Stepper("Pays on day \(payoutDay)", value: $payoutDay, in: 1...31).rowPadding()
                    Toggle("Has a maturity date", isOn: $hasMaturity).rowPadding()
                    if hasMaturity {
                        FieldRow("Matures on") { DatePicker("Matures on", selection: $maturity, displayedComponents: .date).labelsHidden() }
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding().accessibilityIdentifier("schemeError") }
                }
            }
            .cardNavigation(editing == nil ? "New Scheme" : "Edit Scheme")
            .onAppear {
                guard let editing, name.isEmpty else { return }
                name = editing.name
                investedText = IndianMoneyFormat.plain(editing.invested)
                payoutText = IndianMoneyFormat.plain(editing.monthlyPayout)
                payoutDay = editing.payoutDay
                hasMaturity = editing.maturity != nil
                maturity = editing.maturity?.instant() ?? Date()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let scheme = NewPayoutScheme(
                            name: name, invested: MoneyInput.parse(investedText), monthlyPayout: MoneyInput.parse(payoutText),
                            payoutDay: payoutDay, maturity: hasMaturity ? CalendarDate(maturity) : nil
                        )
                        errorMessage = editing.map { model.updateScheme($0.id, scheme) } ?? model.addScheme(scheme)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveSchemeButton")
                }
            }
        }
    }
}

struct RecordPayoutSheet: View {
    let model: BudgetViewModel
    let scheme: PayoutScheme
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: note.isEmpty ? nil : note) {
                    CardRow(title: "Scheme") { Text(scheme.name).foregroundStyle(Theme.secondary) }
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad).rowPadding().accessibilityIdentifier("payoutAmountField")
                    FieldRow("Date received") { DatePicker("Date received", selection: $date, displayedComponents: .date).labelsHidden() }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
            }
            .cardNavigation("Record Payout")
            .onAppear {
                guard let draft = model.payoutDraft(scheme.id) else { return }
                amountText = IndianMoneyFormat.plain(draft.amount)
                date = draft.date.instant()
                note = draft.note
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.recordPayout(scheme.id, amountText: amountText, on: CalendarDate(date))
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("savePayoutButton")
                }
            }
        }
    }
}
