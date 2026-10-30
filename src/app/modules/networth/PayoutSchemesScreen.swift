import HisaabCore
import SwiftUI

extension PayoutScheme: @retroactive Identifiable {}

struct PayoutSchemesScreen: View {
    let model: BudgetViewModel
    let hidden: Bool
    @State private var adding = false
    @State private var recording: PayoutScheme?
    @State private var closing: PayoutScheme?
    @State private var reminder: String?
    @State private var errorMessage: String?

    private func money(_ value: Money) -> String { hidden ? "••••••" : IndianMoneyFormat.string(value) }

    var body: some View {
        List {
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            if let reminder { Text(reminder).foregroundStyle(.orange).accessibilityIdentifier("schemeReminder") }
            Section {
                HStack { Text("Invested"); Spacer(); Text(money(model.payouts.investedTotal)).monospacedDigit() }
                HStack { Text("Monthly payout"); Spacer(); Text(money(model.payouts.monthlyPayoutTotal)).monospacedDigit() }
            }
            Section("Schemes") {
                if model.payouts.schemes.isEmpty { Text("No schemes yet.").foregroundStyle(.secondary) }
                ForEach(model.payouts.schemes, id: \.scheme.id) { line in
                    let scheme = line.scheme
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(scheme.name).font(.headline)
                                if scheme.isClosed { Text("closed").font(.caption).foregroundStyle(.secondary) }
                            }
                            Text("Pays on the \(scheme.payoutDay)th" + (scheme.maturity.map { " · matures \($0.shortTitle)" } ?? ""))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(money(scheme.invested)).monospacedDigit()
                            Text("\(money(scheme.monthlyPayout)) / month").font(.footnote).foregroundStyle(.green)
                        }
                    }
                    .swipeActions {
                        if !scheme.isClosed {
                            Button("Record Payout") { recording = scheme }.tint(.blue)
                            Button("Close") { closing = scheme }.tint(.red)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("schemeRow")
                }
            }
        }
        .navigationTitle("Payout Schemes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Scheme", systemImage: "plus") { adding = true }.accessibilityIdentifier("addSchemeButton")
            }
        }
        .sheet(isPresented: $adding) { NewSchemeSheet(model: model) }
        .sheet(item: $recording) { RecordPayoutSheet(model: model, scheme: $0) }
        .confirmationDialog("Close this scheme?", isPresented: Binding(get: { closing != nil }, set: { if !$0 { closing = nil } }), titleVisibility: .visible) {
            Button("Close Scheme", role: .destructive) {
                if let closing { errorMessage = model.closeScheme(closing.id); if errorMessage == nil { reminder = "Closed. Update your bank balance." } }
                closing = nil
            }
        }
    }
}

private struct NewSchemeSheet: View {
    let model: BudgetViewModel
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
            Form {
                TextField("Name", text: $name).accessibilityIdentifier("schemeNameField")
                TextField("Amount invested", text: $investedText).keyboardType(.decimalPad).accessibilityIdentifier("schemeInvestedField")
                TextField("Monthly payout", text: $payoutText).keyboardType(.decimalPad).accessibilityIdentifier("schemePayoutField")
                Stepper("Pays on day \(payoutDay)", value: $payoutDay, in: 1...31)
                Toggle("Has a maturity date", isOn: $hasMaturity)
                if hasMaturity { DatePicker("Matures on", selection: $maturity, displayedComponents: .date) }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("schemeError") }
            }
            .navigationTitle("New Scheme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addScheme(NewPayoutScheme(
                            name: name, invested: MoneyInput.parse(investedText), monthlyPayout: MoneyInput.parse(payoutText),
                            payoutDay: payoutDay, maturity: hasMaturity ? CalendarDate(maturity) : nil
                        ))
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
            Form {
                Section {
                    LabeledContent("Scheme", value: scheme.name)
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad).accessibilityIdentifier("payoutAmountField")
                    DatePicker("Date received", selection: $date, displayedComponents: .date)
                } footer: {
                    if !note.isEmpty { Text(note) }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Record Payout")
            .navigationBarTitleDisplayMode(.inline)
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
