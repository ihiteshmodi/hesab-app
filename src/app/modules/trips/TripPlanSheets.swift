import HisaabCore
import SwiftUI

/// A plan item: what it is, what it should cost, a note, when it is due, how it is paid and the legs it covers.
struct TripPlanItemSheet: View {
    let model: BudgetViewModel
    let tripID: Int64
    @Environment(\.dismiss) private var dismiss
    /// Set once the item exists; a new item gets one when she chooses "Save and Add Parts or Legs".
    @State private var itemID: Int64?
    @State private var description = ""
    @State private var amountText = ""
    @State private var tag = ""
    @State private var category = ""
    @State private var subCategory = ""
    @State private var note = ""
    @State private var hasDue = false
    @State private var dueDate = Date()
    @State private var choosingTag = false
    @State private var confirmingDelete = false
    @State private var addingPart = false
    @State private var editingPart: TripPlanPayment?
    @State private var addingLeg = false
    @State private var editingLeg: TripLeg?
    @State private var errorMessage: String?

    init(model: BudgetViewModel, tripID: Int64, editing: TripPlanItem?) {
        self.model = model
        self.tripID = tripID
        _itemID = State(initialValue: editing?.id)
        guard let editing else { return }
        _description = State(initialValue: editing.description)
        _amountText = State(initialValue: IndianMoneyFormat.plain(editing.amount))
        _tag = State(initialValue: editing.tag)
        _category = State(initialValue: editing.category)
        _subCategory = State(initialValue: editing.subCategory)
        _note = State(initialValue: editing.note)
        _hasDue = State(initialValue: editing.dueDate != nil)
        _dueDate = State(initialValue: editing.dueDate?.instant() ?? Date())
    }

    private var item: TripPlanItem? { itemID.flatMap { model.tripPlanItem(tripID, $0) } }
    private var trip: Trip? { model.tripSummary(tripID)?.trip }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("What is it? (Flights, Hotel, Shirts ...)", text: $description).rowPadding()
                        .accessibilityIdentifier("planItemNameField")
                    if let item, !item.payments.isEmpty, let trip {
                        CardRow(title: "Total", subtitle: "from the parts below") {
                            Text(model.tripText(item.amount, trip)).monospacedDigit().accessibilityIdentifier("planItemTotal")
                        }
                    } else {
                        TextField("Expected cost", text: $amountText).keyboardType(.decimalPad).rowPadding()
                            .accessibilityIdentifier("planItemAmountField")
                        Toggle("Has a due date", isOn: $hasDue).rowPadding().accessibilityIdentifier("planItemDueToggle")
                        if hasDue {
                            FieldRow("Due") { DatePicker("Due", selection: $dueDate, displayedComponents: .date).labelsHidden() }
                        }
                    }
                    TripCategoryFields(model: model, category: $category, subCategory: $subCategory)
                    Button { choosingTag = true } label: {
                        CardRow(title: "Tag") { Text(tag.isEmpty ? "None" : tag).foregroundStyle(Theme.secondary) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("planItemTagButton")
                    TextField("Notes (optional)", text: $note, axis: .vertical).lineLimit(1...4).rowPadding()
                        .accessibilityIdentifier("planItemNoteField")
                }
                if let item, let trip { details(item, trip) }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
                if itemID == nil {
                    Button("Save and Add Parts or Legs") { saveNew(keepOpen: true) }
                        .buttonStyle(GreyButtonStyle()).accessibilityIdentifier("saveAndAddDetailsButton")
                } else {
                    Button("Remove From Plan", role: .destructive) { confirmingDelete = true }
                        .buttonStyle(GreyButtonStyle(tint: Theme.red))
                }
            }
            .cardNavigation(itemID == nil ? "Plan Something" : "Plan Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(itemID == nil ? "Cancel" : "Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(itemID == nil ? "Save" : "Done") { save() }.accessibilityIdentifier("savePlanItemButton")
                }
            }
            .sheet(isPresented: $choosingTag) { TagPickerSheet(model: model, selection: $tag) }
            .sheet(isPresented: $addingPart) { if let item { TripPartSheet(model: model, item: item, editing: nil) } }
            .sheet(item: $editingPart) { part in if let item { TripPartSheet(model: model, item: item, editing: part) } }
            .sheet(isPresented: $addingLeg) { if let item { TripLegSheet(model: model, item: item, editing: nil) } }
            .sheet(item: $editingLeg) { leg in if let item { TripLegSheet(model: model, item: item, editing: leg) } }
            .confirmationDialog("Remove this from the plan?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let itemID { errorMessage = model.deleteTripPlanItem(itemID) }
                    if errorMessage == nil { dismiss() }
                }
            } message: {
                if item?.isPaid == true { Text("The expense it made stays in the trip.") }
            }
        }
    }

    @ViewBuilder private func details(_ item: TripPlanItem, _ trip: Trip) -> some View {
        CardGroup(header: "Paid in parts", footer: "An advance now and a balance later, each with its own due date. The parts make the total.") {
            ForEach(item.payments, id: \.id) { part in
                Button { if !part.isPaid { editingPart = part } } label: {
                    CardRow(
                        title: part.label.isEmpty ? "Part" : part.label,
                        subtitle: part.isPaid ? "Paid" : part.dueDate.map { "Due \($0.shortTitleWithYear)" } ?? "No date"
                    ) {
                        Text(model.tripText(part.amount, trip)).monospacedDigit()
                        if part.isPaid { Image(systemName: "lock.fill").font(.footnote).foregroundStyle(Theme.secondary) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("itemPartRow")
            }
            Button { addingPart = true } label: { Text("Add Part").foregroundStyle(Theme.blue).rowPadding() }
                .buttonStyle(.plain).accessibilityIdentifier("addPartButton")
        }
        CardGroup(header: "Travel legs", footer: "For flights, trains and buses: the route, the times and the number.") {
            ForEach(item.legs, id: \.id) { leg in
                Button { editingLeg = leg } label: { LegRow(leg: leg) }
                    .buttonStyle(.plain).accessibilityIdentifier("itemLegRow")
            }
            Button { addingLeg = true } label: { Text("Add Leg").foregroundStyle(Theme.blue).rowPadding() }
                .buttonStyle(.plain).accessibilityIdentifier("addLegButton")
        }
    }

    private var form: PlanItemForm {
        PlanItemForm(
            description: description, amountText: amountText, tag: tag, category: category, subCategory: subCategory, note: note,
            dueDate: hasDue && (item?.payments.isEmpty ?? true) ? CalendarDate(dueDate) : nil
        )
    }

    private func save() {
        if itemID == nil { saveNew(keepOpen: false); return }
        guard let itemID else { return }
        errorMessage = model.updateTripPlanItem(itemID, form)
        if errorMessage == nil { dismiss() }
    }

    private func saveNew(keepOpen: Bool) {
        let result = model.addTripPlanItem(tripID, form)
        errorMessage = result.error
        guard result.error == nil else { return }
        if keepOpen { itemID = result.item?.id } else { dismiss() }
    }
}

/// One part of an item paid in instalments.
struct TripPartSheet: View {
    let model: BudgetViewModel
    let item: TripPlanItem
    let editing: TripPlanPayment?
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var amountText = ""
    @State private var hasDue = false
    @State private var dueDate = Date()
    @State private var errorMessage: String?

    init(model: BudgetViewModel, item: TripPlanItem, editing: TripPlanPayment?) {
        self.model = model
        self.item = item
        self.editing = editing
        guard let editing else { return }
        _label = State(initialValue: editing.label)
        _amountText = State(initialValue: IndianMoneyFormat.plain(editing.amount))
        _hasDue = State(initialValue: editing.dueDate != nil)
        _dueDate = State(initialValue: editing.dueDate?.instant() ?? Date())
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "For \(item.description).") {
                    TextField("Name (Advance, Balance ...)", text: $label).rowPadding().accessibilityIdentifier("partLabelField")
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad).rowPadding().accessibilityIdentifier("partAmountField")
                    Toggle("Has a due date", isOn: $hasDue).rowPadding().accessibilityIdentifier("partDueToggle")
                    if hasDue {
                        FieldRow("Due") { DatePicker("Due", selection: $dueDate, displayedComponents: .date).labelsHidden() }
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
                if let editing {
                    Button("Remove Part", role: .destructive) {
                        errorMessage = model.deleteTripPlanPayment(editing.id)
                        if errorMessage == nil { dismiss() }
                    }
                    .buttonStyle(GreyButtonStyle(tint: Theme.red))
                }
            }
            .cardNavigation(editing == nil ? "Add Part" : "Part")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let due = hasDue ? CalendarDate(dueDate) : nil
                        errorMessage = editing.map { model.updateTripPlanPayment($0.id, label: label, amountText: amountText, dueDate: due) }
                            ?? model.addTripPlanPayment(item.id, label: label, amountText: amountText, dueDate: due)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("savePartButton")
                }
            }
        }
    }
}

/// One leg of the journey: a flight, train or bus, with route, times, carrier and number.
struct TripLegSheet: View {
    let model: BudgetViewModel
    let item: TripPlanItem
    let editing: TripLeg?
    @Environment(\.dismiss) private var dismiss
    @State private var mode = TravelMode.flight
    @State private var from = ""
    @State private var to = ""
    @State private var carrier = ""
    @State private var number = ""
    @State private var hasDeparture = false
    @State private var departureDate = Date()
    @State private var hasDepartureTime = false
    @State private var departureTime = Date()
    @State private var hasArrival = false
    @State private var arrivalDate = Date()
    @State private var hasArrivalTime = false
    @State private var arrivalTime = Date()
    @State private var booked = false
    @State private var errorMessage: String?

    init(model: BudgetViewModel, item: TripPlanItem, editing: TripLeg?) {
        self.model = model
        self.item = item
        self.editing = editing
        guard let leg = editing else { return }
        _mode = State(initialValue: leg.mode)
        _from = State(initialValue: leg.from)
        _to = State(initialValue: leg.to)
        _carrier = State(initialValue: leg.carrier)
        _number = State(initialValue: leg.number)
        _hasDeparture = State(initialValue: leg.departure != nil)
        _departureDate = State(initialValue: leg.departure?.instant() ?? Date())
        _hasDepartureTime = State(initialValue: leg.departureMinutes != nil)
        _departureTime = State(initialValue: Self.time(leg.departureMinutes))
        _hasArrival = State(initialValue: leg.arrivalDate != nil)
        _arrivalDate = State(initialValue: leg.arrivalDate?.instant() ?? Date())
        _hasArrivalTime = State(initialValue: leg.arrivalMinutes != nil)
        _arrivalTime = State(initialValue: Self.time(leg.arrivalMinutes))
        _booked = State(initialValue: leg.isBooked)
    }

    private var carrierTitle: String {
        switch mode {
        case .flight: "Airline"
        case .train: "Railway or train name"
        case .bus: "Bus company"
        case .other: "Company"
        }
    }

    private var numberTitle: String {
        switch mode {
        case .flight: "Flight number"
        case .train: "Train number"
        case .bus: "Bus number"
        case .other: "Number"
        }
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "For \(item.description). Leave out whatever you do not know yet.") {
                    Picker("Mode", selection: $mode) {
                        ForEach(TravelMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).rowPadding().accessibilityIdentifier("legModePicker")
                    TextField("From", text: $from).rowPadding().accessibilityIdentifier("legFromField")
                    TextField("To", text: $to).rowPadding().accessibilityIdentifier("legToField")
                    TextField(carrierTitle, text: $carrier).rowPadding().accessibilityIdentifier("legCarrierField")
                    TextField(numberTitle, text: $number).textInputAutocapitalization(.characters).rowPadding()
                        .accessibilityIdentifier("legNumberField")
                }
                CardGroup(header: "Leaves") {
                    Toggle("Date known", isOn: $hasDeparture).rowPadding().accessibilityIdentifier("legDepartureToggle")
                    if hasDeparture {
                        FieldRow("Date") { DatePicker("Date", selection: $departureDate, displayedComponents: .date).labelsHidden() }
                    }
                    Toggle("Time known", isOn: $hasDepartureTime).rowPadding().accessibilityIdentifier("legDepartureTimeToggle")
                    if hasDepartureTime {
                        FieldRow("Time") { DatePicker("Time", selection: $departureTime, displayedComponents: .hourAndMinute).labelsHidden() }
                    }
                }
                CardGroup(header: "Arrives") {
                    Toggle("Date known", isOn: $hasArrival).rowPadding().accessibilityIdentifier("legArrivalToggle")
                    if hasArrival {
                        FieldRow("Date") { DatePicker("Date", selection: $arrivalDate, displayedComponents: .date).labelsHidden() }
                    }
                    Toggle("Time known", isOn: $hasArrivalTime).rowPadding().accessibilityIdentifier("legArrivalTimeToggle")
                    if hasArrivalTime {
                        FieldRow("Time") { DatePicker("Time", selection: $arrivalTime, displayedComponents: .hourAndMinute).labelsHidden() }
                    }
                }
                CardGroup(footer: "Switch this on once the ticket is booked.") {
                    Toggle("Booked", isOn: $booked).rowPadding().accessibilityIdentifier("legBookedToggle")
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
                if let editing {
                    Button("Remove Leg", role: .destructive) {
                        errorMessage = model.deleteTripLeg(editing.id)
                        if errorMessage == nil { dismiss() }
                    }
                    .buttonStyle(GreyButtonStyle(tint: Theme.red))
                }
            }
            .cardNavigation(editing == nil ? "Add Leg" : "Leg")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.accessibilityIdentifier("saveLegButton") }
            }
        }
    }

    private func save() {
        let leg = NewTripLeg(
            mode: mode, from: from, to: to, carrier: carrier, number: number,
            departure: hasDeparture ? CalendarDate(departureDate) : nil,
            departureMinutes: hasDepartureTime ? Self.minutes(departureTime) : nil,
            arrivalDate: hasArrival ? CalendarDate(arrivalDate) : nil,
            arrivalMinutes: hasArrivalTime ? Self.minutes(arrivalTime) : nil, isBooked: booked
        )
        errorMessage = editing.map { model.updateTripLeg($0.id, leg) } ?? model.addTripLeg(item.id, leg)
        if errorMessage == nil { dismiss() }
    }

    private static func minutes(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func time(_ minutes: Int?) -> Date {
        guard let minutes else { return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date() }
        return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }
}

extension TripPlanPayment: @retroactive Identifiable {}
extension TripLeg: @retroactive Identifiable {}

/// Ticking an item, or one part of it, as paid: the real amount, date, how it was paid and the card's charge.
struct TripPlanPaySheet: View {
    let model: BudgetViewModel
    let trip: Trip
    let item: TripPlanItem
    /// Set when one part of the item is being paid.
    var part: TripPlanPayment?
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var date = Date()
    @State private var paidWith = ExpensePayment.bank
    @State private var chargeText = ""
    @State private var errorMessage: String?

    private var planned: Money { part?.amount ?? item.amount }
    private var title: String { part.map { $0.label.isEmpty ? item.description : "\(item.description) · \($0.label)" } ?? item.description }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "It becomes a trip expense that only you share. You can change the split from the trip afterwards.") {
                    CardRow(title: title) { Text("planned \(model.tripText(planned, trip))").foregroundStyle(Theme.secondary) }
                    TextField("Amount paid", text: $amountText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("planPayAmountField")
                    FieldRow("Date") { DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden() }
                    FieldRow("Paid with") {
                        Picker("Paid with", selection: $paidWith) {
                            Text("Card / bank").tag(ExpensePayment.bank)
                            Text(trip.currency == nil ? "Cash" : "Cash (\(trip.currency ?? ""))").tag(ExpensePayment.cash)
                        }
                        .labelsHidden()
                    }
                    if trip.currency != nil, paidWith == .bank {
                        TextField("What the card charged in \(model.preferences.homeCurrency) (optional)", text: $chargeText)
                            .keyboardType(.decimalPad).rowPadding()
                            .accessibilityIdentifier("planPayChargeField")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
            }
            .cardNavigation("Mark as Paid")
            .onAppear { if amountText.isEmpty { amountText = IndianMoneyFormat.plain(planned) } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Paid") {
                        errorMessage = part.map {
                            model.markTripPlanPaymentPaid($0.id, amountText: amountText, date: CalendarDate(date), paidWith: paidWith, chargeText: chargeText)
                        } ?? model.markTripPlanItemPaid(
                            item.id, amountText: amountText, date: CalendarDate(date), paidWith: paidWith, chargeText: chargeText
                        )
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("confirmPlanPaidButton")
                }
            }
        }
    }
}
