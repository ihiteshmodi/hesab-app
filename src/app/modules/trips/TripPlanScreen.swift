import HisaabCore
import SwiftUI

/// What an open sheet on the plan pane is doing.
enum PlanEntry: Identifiable {
    case newItem
    case editItem(TripPlanItem)
    case pay(TripPlanItem)

    var id: String {
        switch self {
        case .newItem: "new"
        case .editItem(let item): "edit-\(item.id)"
        case .pay(let item): "pay-\(item.id)"
        }
    }
}

/// The Plan pane of a trip: the price list while planning, and the same list with tick marks once the trip has started.
struct TripPlanPane: View {
    let model: BudgetViewModel
    let summary: TripSummary
    @Binding var entry: PlanEntry?
    @Binding var errorMessage: String?
    @State private var untickingID: Int64?

    private var trip: Trip { summary.trip }
    private var plan: TripPlan { summary.plan }

    var body: some View {
        CardPanel {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    CardCaption("Planned")
                    Text(model.tripText(plan.plannedTotal, trip)).font(.title2.bold()).monospacedDigit()
                        .accessibilityIdentifier("tripPlannedTotal")
                    if trip.currency != nil {
                        Text("≈ \(IndianMoneyFormat.string(plan.plannedTotalHome))").font(.footnote).foregroundStyle(Theme.secondary)
                    }
                }
                Spacer()
                if !trip.isPlanning {
                    VStack(alignment: .trailing, spacing: 4) {
                        CardCaption("Still to pay")
                        Text(model.tripText(plan.pendingTotal, trip)).font(.title2.bold()).monospacedDigit()
                            .accessibilityIdentifier("tripPendingTotal")
                        if trip.currency != nil {
                            Text("≈ \(IndianMoneyFormat.string(plan.pendingTotalHome))").font(.footnote).foregroundStyle(Theme.secondary)
                        }
                    }
                }
            }
        }
        if trip.isPlanning {
            Button("Start Trip") { errorMessage = model.startTrip(trip.id) }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("startTripButton")
        }
        CardGroup(footer: footer) {
            if plan.items.isEmpty {
                Text("Nothing planned yet. Add flights, stay, clothes and the rest with the + button.")
                    .foregroundStyle(Theme.secondary).rowPadding()
            }
            ForEach(plan.items, id: \.id) { item in
                HStack(spacing: 12) {
                    if !trip.isPlanning {
                        Button { tap(item) } label: {
                            Image(systemName: item.isPaid ? "checkmark.circle.fill" : "circle").font(.title3)
                                .foregroundStyle(item.isPaid ? Theme.green : Theme.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.isPaid ? "Paid" : "Not paid")
                        .accessibilityIdentifier("planPaidToggle")
                    }
                    Button { entry = .editItem(item) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.description)
                                Text(([item.categoryText, item.tag.isEmpty ? nil : item.tag].compactMap { $0 } + [item.isPaid ? "Paid" : "Still to pay"])
                                    .joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(item.isPaid ? Theme.green : Theme.secondary)
                            }
                            Spacer()
                            Text(model.tripText(item.amount, trip)).monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .rowPadding()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("planItemRow")
            }
        }
        if !plan.categoryProgress.isEmpty, !trip.isPlanning {
            CardPanel {
                CardCaption("Planned and spent, by category")
                ForEach(plan.categoryProgress, id: \.category) { progress in
                    ProgressRow(
                        name: progress.category.isEmpty ? "No category" : progress.category, planned: progress.planned,
                        spent: progress.spent, text: { model.tripText($0, trip) }
                    )
                }
            }
        }
        if !plan.byCategory.isEmpty {
            CardGroup(header: "Planned by category") {
                ForEach(plan.byCategory, id: \.category) { spend in
                    CardRow(title: spend.category.isEmpty ? "No category" : spend.category) {
                        Text(model.tripText(spend.amount, trip)).monospacedDigit()
                    }
                }
            }
        }
        if plan.byTag.contains(where: { !$0.tag.isEmpty }) {
            CardGroup(header: "Planned by tag") {
                ForEach(plan.byTag, id: \.tag) { spend in
                    CardRow(title: spend.tag.isEmpty ? "No tag" : spend.tag) {
                        Text(model.tripText(spend.amount, trip)).monospacedDigit()
                    }
                }
            }
        }
        Color.clear.frame(height: 0)
            .confirmationDialog("Take this payment back?", isPresented: Binding(
                get: { untickingID != nil }, set: { if !$0 { untickingID = nil } }
            ), titleVisibility: .visible) {
                Button("Untick and Remove the Expense", role: .destructive) {
                    if let untickingID { errorMessage = model.unmarkTripPlanItemPaid(untickingID) }
                    untickingID = nil
                }
            } message: {
                Text("The expense it made is removed from the trip and the main ledger.")
            }
    }

    private var footer: String? {
        if trip.isPlanning { return "Nothing here touches Left to spend until you start the trip and tick things as paid." }
        return plan.items.isEmpty ? nil : "Tick an item when you pay for it. It becomes a trip expense and leaves Left to spend."
    }

    private func tap(_ item: TripPlanItem) {
        if item.isPaid { untickingID = item.id } else { entry = .pay(item) }
    }
}

/// A plan item: what it is, what it should cost and its tag.
struct TripPlanItemSheet: View {
    let model: BudgetViewModel
    let tripID: Int64
    let editing: TripPlanItem?
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var amountText = ""
    @State private var tag = ""
    @State private var category = ""
    @State private var subCategory = ""
    @State private var choosingTag = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    init(model: BudgetViewModel, tripID: Int64, editing: TripPlanItem?) {
        self.model = model
        self.tripID = tripID
        self.editing = editing
        guard let editing else { return }
        _description = State(initialValue: editing.description)
        _amountText = State(initialValue: IndianMoneyFormat.plain(editing.amount))
        _tag = State(initialValue: editing.tag)
        _category = State(initialValue: editing.category)
        _subCategory = State(initialValue: editing.subCategory)
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("What is it? (Flights, Hotel, Shirts ...)", text: $description).rowPadding()
                        .accessibilityIdentifier("planItemNameField")
                    TextField("Expected cost", text: $amountText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("planItemAmountField")
                    TripCategoryFields(model: model, category: $category, subCategory: $subCategory)
                    Button { choosingTag = true } label: {
                        CardRow(title: "Tag") { Text(tag.isEmpty ? "None" : tag).foregroundStyle(Theme.secondary) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("planItemTagButton")
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
                if editing != nil {
                    Button("Remove From Plan", role: .destructive) { confirmingDelete = true }
                        .buttonStyle(GreyButtonStyle(tint: Theme.red))
                }
            }
            .cardNavigation(editing == nil ? "Plan Something" : "Plan Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.accessibilityIdentifier("savePlanItemButton") }
            }
            .sheet(isPresented: $choosingTag) { TagPickerSheet(model: model, selection: $tag) }
            .confirmationDialog("Remove this from the plan?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let editing { errorMessage = model.deleteTripPlanItem(editing.id) }
                    if errorMessage == nil { dismiss() }
                }
            } message: {
                if editing?.isPaid == true { Text("The expense it made stays in the trip.") }
            }
        }
    }

    private func save() {
        errorMessage = editing.map {
            model.updateTripPlanItem($0.id, description: description, amountText: amountText, tag: tag, category: category, subCategory: subCategory)
        } ?? model.addTripPlanItem(
            tripID, description: description, amountText: amountText, tag: tag, category: category, subCategory: subCategory
        )
        if errorMessage == nil { dismiss() }
    }
}

/// Ticking an item as paid: the real amount, date, how it was paid and the card's charge.
struct TripPlanPaySheet: View {
    let model: BudgetViewModel
    let trip: Trip
    let item: TripPlanItem
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var date = Date()
    @State private var paidWith = ExpensePayment.bank
    @State private var chargeText = ""
    @State private var errorMessage: String?

    init(model: BudgetViewModel, trip: Trip, item: TripPlanItem) {
        self.model = model
        self.trip = trip
        self.item = item
        _amountText = State(initialValue: IndianMoneyFormat.plain(item.amount))
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "It becomes a trip expense that only you share. You can change the split from the trip afterwards.") {
                    CardRow(title: item.description) {
                        Text("planned \(model.tripText(item.amount, trip))").foregroundStyle(Theme.secondary)
                    }
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Paid") {
                        errorMessage = model.markTripPlanItemPaid(
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

/// One category: a grey bar for what was planned and a bar over it for what has been spent, red when spent is over plan.
private struct ProgressRow: View {
    let name: String
    let planned: Money
    let spent: Money
    let text: (Money) -> String

    private var over: Bool { spent > planned }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                Spacer()
                Text("\(text(spent)) of \(text(planned))").font(.footnote).monospacedDigit().foregroundStyle(over ? Theme.red : Theme.secondary)
            }
            GeometryReader { geometry in
                let scale = CGFloat(max(planned.paise, spent.paise, 1))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.25)).frame(width: geometry.size.width * CGFloat(planned.paise) / scale)
                    Capsule().fill(over ? Theme.red : Theme.blue).frame(width: geometry.size.width * CGFloat(spent.paise) / scale)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("planProgressRow")
    }
}
