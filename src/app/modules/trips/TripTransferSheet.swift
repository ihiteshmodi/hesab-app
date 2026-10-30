import HisaabCore
import SwiftUI

struct TripTransferSheet: View {
    let model: BudgetViewModel
    let summary: TripSummary
    let switchToExpense: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var personID: Int64
    @State private var direction = SettlementDirection.theyPaidMe
    @State private var method = SettlementMethod.bank
    @State private var amountText = ""
    @State private var rateText: String
    @State private var full = false
    @State private var date = Date()
    @State private var errorMessage: String?

    init(model: BudgetViewModel, summary: TripSummary, personID: Int64?, switchToExpense: @escaping () -> Void) {
        self.model = model
        self.summary = summary
        self.switchToExpense = switchToExpense
        _personID = State(initialValue: personID ?? summary.members.first?.id ?? 0)
        _rateText = State(initialValue: summary.trip.rate.map { "\($0)" } ?? "")
    }

    private var trip: Trip { summary.trip }
    private var foreign: Bool { trip.currency != nil }
    private var home: String { model.preferences.homeCurrency }
    private var rate: Decimal? { Decimal(string: rateText.trimmingCharacters(in: .whitespaces)) }
    private var amount: Money? { MoneyInput.parse(amountText) }

    private var outstanding: Money {
        let owes = summary.balances.first { $0.person.id == personID }?.owesMe ?? .zero
        return direction == .theyPaidMe ? owes : .zero - owes
    }

    /// What it would clear in the trip currency, worked the same way the core does.
    private var clears: Money? {
        guard let amount else { return nil }
        if !foreign || method == .cashTrip { return amount }
        guard let rate, rate > 0 else { return nil }
        var exact = Decimal(amount.paise) / rate
        var rounded = Decimal()
        NSDecimalRound(&rounded, &exact, 0, .plain)
        return Money(paise: NSDecimalNumber(decimal: rounded).intValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Button("Expense instead") { switchToExpense() }
                    Spacer()
                    Text("Transfer").fontWeight(.semibold)
                }
                Section {
                    Picker("Person", selection: $personID) {
                        ForEach(summary.members, id: \.id) { Text($0.name).tag($0.id) }
                    }
                    .accessibilityIdentifier("transferPersonPicker")
                    Picker("Direction", selection: $direction) {
                        Text("They paid me").tag(SettlementDirection.theyPaidMe)
                        Text("I paid them").tag(SettlementDirection.iPaidThem)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("transferDirectionPicker")
                }
                Section("How") {
                    Picker("How", selection: $method) {
                        Text("Bank / UPI").tag(SettlementMethod.bank)
                        Text("Cash \(home)").tag(SettlementMethod.cashHome)
                        if foreign { Text("Cash \(trip.currency ?? "")").tag(SettlementMethod.cashTrip) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("transferMethodPicker")
                    Toggle("Settle in full", isOn: $full).accessibilityIdentifier("settleInFullToggle")
                    HStack {
                        Text(direction == .theyPaidMe ? "I received (\(method == .cashTrip ? trip.currency ?? "" : home))"
                             : "I paid (\(method == .cashTrip ? trip.currency ?? "" : home))")
                        Spacer()
                        TextField("0", text: $amountText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("transferAmountField")
                    }
                    if foreign && method != .cashTrip {
                        HStack {
                            Text("Rate (\(home) per 1 \(trip.currency ?? ""))")
                            Spacer()
                            TextField("rate", text: $rateText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("transferRateField")
                        }
                    }
                    DatePicker(direction == .theyPaidMe ? "Date received" : "Date paid", selection: $date, in: ...Date(), displayedComponents: .date)
                        .accessibilityIdentifier("transferDatePicker")
                }
                if let amount, amount > .zero { effect(amount) }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("transferError") }
                }
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.accessibilityIdentifier("saveTransferButton") }
            }
        }
    }

    private func effect(_ amount: Money) -> some View {
        let name = summary.members.first { $0.id == personID }?.name ?? "They"
        return Section("What this changes") {
            if let clears {
                let after = outstanding - clears
                let text = full
                    ? "\(name) is square"
                    : "\(model.tripText(outstanding < .zero ? .zero - outstanding : outstanding, trip)) → \(model.tripText(after < .zero ? .zero - after : after, trip))"
                effectRow(direction == .theyPaidMe ? "\(name) owes" : "I owe \(name)", text)
                if full, outstanding > .zero {
                    let difference = outstanding - clears
                    if difference > .zero { effectRow("Written off (a cost)", model.tripText(difference, trip)) }
                    if difference < .zero { effectRow("Paid extra (a gain)", model.tripText(.zero - difference, trip)) }
                }
            }
            switch method {
            case .bank:
                effectRow("Main ledger", direction == .theyPaidMe ? "− \(IndianMoneyFormat.string(amount))" : "+ \(IndianMoneyFormat.string(amount))")
            case .cashHome:
                effectRow("Main ledger", "no change")
                effectRow("Cash in Hand", (direction == .theyPaidMe ? "+ " : "− ") + IndianMoneyFormat.string(amount))
            case .cashTrip:
                effectRow("Main ledger", "no change")
                effectRow("\(trip.currency ?? "") cash", (direction == .theyPaidMe ? "+ " : "− ") + model.tripText(amount, trip))
            }
        }
        .accessibilityIdentifier("transferEffect")
    }

    private func effectRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private func save() {
        errorMessage = model.recordTripSettlement(
            trip.id, personID: personID, direction, amountText: amountText, method: method, rateText: rateText, fullSettlement: full,
            on: CalendarDate(date)
        )
        if errorMessage == nil { dismiss() }
    }
}
