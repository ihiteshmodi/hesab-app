import HisaabCore
import SwiftUI

struct TripsScreen: View {
    let model: BudgetViewModel
    @State private var creating = false

    private var open: [TripSummary] { model.trips.filter { !$0.trip.isSettled } }
    private var settled: [TripSummary] { model.trips.filter(\.trip.isSettled) }

    var body: some View {
        NavigationStack {
            CardScreen {
                if model.trips.isEmpty {
                    CardPanel { Text("No trips yet. Add one to split what you pay with friends.").foregroundStyle(Theme.secondary) }
                }
                if !open.isEmpty {
                    CardGroup { ForEach(open, id: \.trip.id) { row($0) } }
                }
                if !settled.isEmpty {
                    CardGroup(header: "Settled") { ForEach(settled, id: \.trip.id) { row($0) } }
                }
            }
            .cardNavigation("Trips", large: true)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Trip", systemImage: "plus") { creating = true }
                        .accessibilityIdentifier("newTripButton")
                }
            }
            .sheet(isPresented: $creating) { NewTripSheet(model: model, editing: nil) }
        }
    }

    private func row(_ summary: TripSummary) -> some View {
        NavigationLink {
            TripDetailScreen(model: model, tripID: summary.trip.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.trip.name).font(.headline)
                    if summary.trip.isSettled { StatusPill(text: "Settled", tone: .green) }
                    if summary.trip.isPlanning { StatusPill(text: "Planning") }
                    if model.dueCount(tripID: summary.trip.id) > 0 {
                        Text("\(model.dueCount(tripID: summary.trip.id))").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 5).frame(minWidth: 17, minHeight: 17).background(Theme.red, in: Capsule())
                            .accessibilityLabel("Payments due soon").accessibilityIdentifier("tripRowDueBadge")
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        if summary.trip.isPlanning {
                            Text(model.tripText(summary.plan.plannedTotal, summary.trip)).monospacedDigit()
                            Text("planned").font(.caption).foregroundStyle(Theme.secondary)
                        } else {
                            Text(IndianMoneyFormat.string(summary.netCost)).monospacedDigit()
                            Text("net cost so far").font(.caption).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                if let dates = TripDates.text(summary.trip) {
                    Text(dates).font(.footnote).foregroundStyle(Theme.secondary).accessibilityIdentifier("tripDates")
                }
                if let due = model.tripDues.first(where: { $0.tripID == summary.trip.id }) {
                    Text("\(due.title): \(dueText(due.dueDate, windowDays: model.preferences.upcomingWindowDays).text)")
                        .font(.footnote).foregroundStyle(Theme.red)
                }
                Text((summary.trip.currency ?? "₹") + " · " + (summary.members.isEmpty ? "no people yet" : summary.members.map(\.name).joined(separator: ", ")))
                    .font(.footnote).foregroundStyle(Theme.secondary)
                ForEach(summary.balances.filter { $0.owesMe != .zero }, id: \.person.id) { balance in
                    HStack {
                        Text(balance.owesMe > .zero ? "\(balance.person.name) owes" : "I owe \(balance.person.name)")
                            .font(.footnote).foregroundStyle(Theme.secondary)
                        Spacer()
                        Text(amountText(model.tripText(abs(balance.owesMe), summary.trip), approx: summary, balance))
                            .font(.footnote).monospacedDigit()
                            .foregroundStyle(balance.owesMe > .zero ? Theme.green : Theme.red)
                    }
                }
            }
            .rowPadding()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tripRow")
    }

    private func amountText(_ text: String, approx summary: TripSummary, _ balance: PersonBalance) -> String {
        summary.trip.currency == nil ? text : "\(text) ≈ \(IndianMoneyFormat.string(abs(balance.owesMeHome)))"
    }
}

private func abs(_ money: Money) -> Money { money < .zero ? .zero - money : money }

struct NewTripSheet: View {
    let model: BudgetViewModel
    let editing: Trip?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var currency = ""
    @State private var rateText = ""
    @State private var ledgerName = ""
    @State private var category = ""
    @State private var subCategory = ""
    @State private var payment = PaymentChoice.all[0]
    @State private var hasStart = false
    @State private var startDate = Date()
    @State private var hasEnd = false
    @State private var endDate = Date()
    @State private var planOnly = false
    @State private var errorMessage: String?
    @State private var confirmingDelete = false

    init(model: BudgetViewModel, editing trip: Trip?) {
        self.model = model
        self.editing = trip
        guard let trip else {
            _category = State(initialValue: "Lifestyle")
            _subCategory = State(initialValue: "Vacation")
            return
        }
        _name = State(initialValue: trip.name)
        _currency = State(initialValue: trip.currency ?? "")
        _rateText = State(initialValue: trip.rate.map { "\($0)" } ?? "")
        _ledgerName = State(initialValue: trip.ledgerName)
        _category = State(initialValue: trip.category)
        _subCategory = State(initialValue: trip.subCategory)
        _payment = State(initialValue: PaymentChoice(method: trip.paymentMethod))
        _hasStart = State(initialValue: trip.startDate != nil)
        _startDate = State(initialValue: trip.startDate?.instant() ?? Date())
        _hasEnd = State(initialValue: trip.endDate != nil)
        _endDate = State(initialValue: trip.endDate?.instant() ?? Date())
    }

    private var paymentChoices: [PaymentChoice] {
        PaymentChoice.all
            + model.cards.map { PaymentChoice(method: .bank($0.name)) }
            + (model.ledgers?.ledgers ?? []).map { PaymentChoice(method: .ledger($0.ledger.name)) }
    }

    private var subCategories: [String] {
        model.categories.first { $0.name == category }?.subCategories.map(\.name) ?? []
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: currency.isEmpty ? nil : "Used for expenses without a card charge, and for the amounts shown beside balances.") {
                    TextField("Trip name", text: $name).accessibilityIdentifier("tripNameField").rowPadding()
                    if editing == nil {
                        Toggle("Just planning for now", isOn: $planOnly).rowPadding()
                            .accessibilityIdentifier("tripPlanOnlyToggle")
                    }
                    CurrencyField(model: model, selection: $currency, identifier: "tripCurrencyPicker")
                        .onChange(of: currency) {
                            if !currency.isEmpty, rateText.isEmpty, let last = model.lastRate(for: currency) { rateText = "\(last)" }
                        }
                    if !currency.isEmpty {
                        FieldRow("Rate (\(model.preferences.homeCurrency) per 1 \(currency))") {
                            TextField("0.0053", text: $rateText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityIdentifier("tripRateField")
                        }
                    }
                }
                CardGroup(header: "Main ledger entry", footer: "Only the bank and card money of this trip goes to the main ledger, as one entry.") {
                    TextField("\(name.isEmpty ? "Trip" : name) expenses", text: $ledgerName).accessibilityIdentifier("tripLedgerNameField")
                        .rowPadding()
                    FieldRow("Category") {
                        Picker("Category", selection: $category) {
                            Text("Choose").tag("")
                            ForEach(model.categories, id: \.name) { Text($0.name).tag($0.name) }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("tripCategoryPicker")
                    }
                    if !subCategories.isEmpty {
                        FieldRow("Sub-category") {
                            Picker("Sub-category", selection: $subCategory) {
                                Text("None").tag("")
                                ForEach(subCategories, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                        }
                    }
                    FieldRow("Paid with") {
                        Picker("Paid with", selection: $payment) {
                            ForEach(paymentChoices, id: \.title) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                    }
                    Toggle("Starts on", isOn: $hasStart).rowPadding().accessibilityIdentifier("tripStartToggle")
                    if hasStart {
                        FieldRow("Start date") { DatePicker("Start date", selection: $startDate, displayedComponents: .date).labelsHidden() }
                    }
                    Toggle("Ends on", isOn: $hasEnd).rowPadding()
                    if hasEnd {
                        FieldRow("End date") { DatePicker("End date", selection: $endDate, displayedComponents: .date).labelsHidden() }
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).accessibilityIdentifier("tripError") }
                if editing != nil {
                    Button("Delete Trip", role: .destructive) { confirmingDelete = true }.buttonStyle(GreyButtonStyle(tint: Theme.red))
                }
            }
            .cardNavigation(editing == nil ? "New Trip" : "Edit Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.accessibilityIdentifier("saveTripButton") }
            }
            .confirmationDialog("Delete this trip?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Trip", role: .destructive) {
                    if let editing { errorMessage = model.deleteTrip(editing.id) }
                    if errorMessage == nil { dismiss() }
                }
            }
        }
    }

    private func save() {
        let trip = NewTrip(
            name: name, currency: currency.isEmpty ? nil : currency,
            rate: currency.isEmpty ? nil : Decimal(string: rateText.trimmingCharacters(in: .whitespaces)),
            ledgerName: ledgerName, category: category, subCategory: subCategory, paymentMethod: payment.method,
            endDate: hasEnd ? CalendarDate(endDate) : nil, startDate: hasStart ? CalendarDate(startDate) : nil, isPlanning: planOnly
        )
        errorMessage = editing.map { model.updateTrip($0.id, trip) } ?? model.createTrip(trip)
        if errorMessage == nil { dismiss() }
    }
}

enum TripDates {
    /// "10 Dec – 18 Dec 2026", "From 10 Dec 2026" or "Until 18 Dec 2026"; nil when the trip has no dates.
    static func text(_ trip: Trip) -> String? {
        switch (trip.startDate, trip.endDate) {
        case let (start?, end?): "\(start.shortTitle) – \(end.shortTitleWithYear)"
        case let (start?, nil): "From \(start.shortTitleWithYear)"
        case let (nil, end?): "Until \(end.shortTitleWithYear)"
        default: nil
        }
    }
}
