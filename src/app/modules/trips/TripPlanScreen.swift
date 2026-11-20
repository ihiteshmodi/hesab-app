import HisaabCore
import SwiftUI

/// What an open sheet on the plan pane is doing.
enum PlanEntry: Identifiable {
    case newItem
    case editItem(TripPlanItem)
    case pay(TripPlanItem)
    case payPart(TripPlanItem, TripPlanPayment)
    case editLeg(TripLeg)

    var id: String {
        switch self {
        case .newItem: "new"
        case .editItem(let item): "edit-\(item.id)"
        case .pay(let item): "pay-\(item.id)"
        case .payPart(_, let part): "pay-part-\(part.id)"
        case .editLeg(let leg): "leg-\(leg.id)"
        }
    }
}

/// What is about to be unticked.
private enum Untick: Identifiable {
    case item(Int64)
    case part(Int64)

    var id: String {
        switch self {
        case .item(let id): "item-\(id)"
        case .part(let id): "part-\(id)"
        }
    }
}

/// "Due in 3 days", "Overdue by 2 days", or the date when it is still far off; red once it is inside the reminder window.
func dueText(_ due: CalendarDate, windowDays: Int) -> (text: String, urgent: Bool) {
    let days = CalendarDate(Date()).days(until: due)
    if days < 0 { return ("Overdue by \(-days) day\(days == -1 ? "" : "s")", true) }
    if days == 0 { return ("Due today", true) }
    if days <= windowDays { return ("Due in \(days) day\(days == 1 ? "" : "s")", true) }
    return ("Due \(due.shortTitleWithYear)", false)
}

/// The Plan pane of a trip: the price list while planning, and the same list with tick marks once the trip has started.
struct TripPlanPane: View {
    let model: BudgetViewModel
    let summary: TripSummary
    @Binding var entry: PlanEntry?
    @Binding var errorMessage: String?
    @State private var unticking: Untick?

    private var trip: Trip { summary.trip }
    private var plan: TripPlan { summary.plan }
    private var windowDays: Int { model.preferences.upcomingWindowDays }

    var body: some View {
        totals
        dueSoon
        if trip.isPlanning {
            Button("Start Trip") { errorMessage = model.startTrip(trip.id) }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("startTripButton")
        }
        items
        itinerary
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
                get: { unticking != nil }, set: { if !$0 { unticking = nil } }
            ), titleVisibility: .visible) {
                Button("Untick and Remove the Expense", role: .destructive) {
                    switch unticking {
                    case .item(let id): errorMessage = model.unmarkTripPlanItemPaid(id)
                    case .part(let id): errorMessage = model.unmarkTripPlanPaymentPaid(id)
                    case nil: break
                    }
                    unticking = nil
                }
            } message: {
                Text("The expense it made is removed from the trip and the main ledger.")
            }
    }

    // MARK: pieces

    private var totals: some View {
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
    }

    /// Payments due soon, with a button to pay each; the red heading is what the red counters on the tabs point at.
    @ViewBuilder private var dueSoon: some View {
        let dues = model.tripDues.filter { $0.tripID == trip.id }
        if !dues.isEmpty {
            CardPanel {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill").foregroundStyle(Theme.red)
                    Text("\(dues.count) payment\(dues.count == 1 ? "" : "s") due soon").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.red).accessibilityIdentifier("tripDueHeading")
                }
                ForEach(dues, id: \.title) { due in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(due.title)
                            Text(dueText(due.dueDate, windowDays: windowDays).text).font(.footnote).foregroundStyle(Theme.red)
                        }
                        Spacer()
                        Text(model.tripText(due.amount, trip)).monospacedDigit().font(.system(size: 15.5))
                        if let item = plan.items.first(where: { $0.id == due.itemID }) {
                            Button("Pay") {
                                if let id = due.paymentID, let part = item.payments.first(where: { $0.id == id }) {
                                    entry = .payPart(item, part)
                                } else {
                                    entry = .pay(item)
                                }
                            }
                            .buttonStyle(AddPillStyle()).accessibilityIdentifier("payDueButton")
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("tripDueRow")
                }
            }
        }
    }

    private var items: some View {
        CardGroup(footer: footer) {
            if plan.items.isEmpty {
                Text("Nothing planned yet. Add flights, stay, clothes and the rest with the + button.")
                    .foregroundStyle(Theme.secondary).rowPadding()
            }
            ForEach(plan.items, id: \.id) { item in
                VStack(alignment: .leading, spacing: 0) {
                    itemRow(item)
                    ForEach(item.payments, id: \.id) { part in partRow(item, part) }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("planItemRow")
            }
        }
    }

    private func itemRow(_ item: TripPlanItem) -> some View {
        HStack(spacing: 12) {
            if !trip.isPlanning, item.payments.isEmpty { tick(isPaid: item.isPaid) { tap(item) } }
            Button { entry = .editItem(item) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description)
                        Text(subtitle(item)).font(.footnote).foregroundStyle(item.isPaid ? Theme.green : Theme.secondary)
                        if item.payments.isEmpty, !item.isPaid, let due = item.dueDate, !trip.isPlanning {
                            let label = dueText(due, windowDays: windowDays)
                            Text(label.text).font(.footnote).foregroundStyle(label.urgent ? Theme.red : Theme.secondary)
                        }
                        if !item.note.isEmpty { Text(item.note).font(.footnote).foregroundStyle(Theme.secondary).lineLimit(2) }
                    }
                    Spacer()
                    Text(model.tripText(item.amount, trip)).monospacedDigit()
                }
            }
            .buttonStyle(.plain)
        }
        .rowPadding()
    }

    private func subtitle(_ item: TripPlanItem) -> String {
        var parts: [String] = [item.categoryText, item.tag.isEmpty ? nil : item.tag].compactMap { $0 }
        if !item.legs.isEmpty { parts.append("\(item.legs.count) leg\(item.legs.count == 1 ? "" : "s")") }
        parts.append(item.isPaid ? "Paid" : item.payments.isEmpty ? "Still to pay" : "\(model.tripText(item.pendingAmount, trip)) to pay")
        return parts.joined(separator: " · ")
    }

    private func partRow(_ item: TripPlanItem, _ part: TripPlanPayment) -> some View {
        HStack(spacing: 12) {
            if !trip.isPlanning { tick(isPaid: part.isPaid) { tapPart(item, part) } }
            Button { entry = .editItem(item) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(part.label.isEmpty ? "Part" : part.label)
                        if part.isPaid {
                            Text("Paid").font(.footnote).foregroundStyle(Theme.green)
                        } else if let due = part.dueDate {
                            let label = dueText(due, windowDays: windowDays)
                            Text(label.text).font(.footnote).foregroundStyle(label.urgent && !trip.isPlanning ? Theme.red : Theme.secondary)
                        } else {
                            Text("No date").font(.footnote).foregroundStyle(Theme.secondary)
                        }
                    }
                    Spacer()
                    Text(model.tripText(part.amount, trip)).monospacedDigit().font(.system(size: 15.5))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, trip.isPlanning ? 16 : 28).padding(.trailing, 16).padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("planPartRow")
    }

    private func tick(isPaid: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isPaid ? "checkmark.circle.fill" : "circle").font(.title3)
                .foregroundStyle(isPaid ? Theme.green : Theme.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaid ? "Paid" : "Not paid")
        .accessibilityIdentifier("planPaidToggle")
    }

    /// Every leg of the journey in date order, across all items.
    @ViewBuilder private var itinerary: some View {
        if !plan.itinerary.isEmpty {
            CardGroup(header: "Travel", footer: "Tap a leg to change it.") {
                ForEach(plan.itinerary, id: \.id) { leg in
                    Button { entry = .editLeg(leg) } label: { LegRow(leg: leg) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("itineraryLeg")
                }
            }
        }
    }

    private var footer: String? {
        if trip.isPlanning { return "Nothing here touches Left to spend until you start the trip and tick things as paid." }
        return plan.items.isEmpty ? nil : "Tick an item or a part when you pay for it. It becomes a trip expense and leaves Left to spend."
    }

    private func tap(_ item: TripPlanItem) {
        if item.isPaid { unticking = .item(item.id) } else { entry = .pay(item) }
    }

    private func tapPart(_ item: TripPlanItem, _ part: TripPlanPayment) {
        if part.isPaid { unticking = .part(part.id) } else { entry = .payPart(item, part) }
    }
}

/// One leg: when, from where to where, and on what.
struct LegRow: View {
    let leg: TripLeg

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: Self.icon(leg.mode)).font(.title3).foregroundStyle(Theme.blue).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(route).font(.system(size: 16, weight: .semibold))
                Text(when).font(.footnote).foregroundStyle(Theme.secondary)
                if !carrier.isEmpty { Text(carrier).font(.footnote).foregroundStyle(Theme.secondary) }
            }
            Spacer()
            StatusPill(text: leg.isBooked ? "Booked" : "Planned", tone: leg.isBooked ? .green : .grey)
        }
        .rowPadding()
        .accessibilityElement(children: .combine)
    }

    static func icon(_ mode: TravelMode) -> String {
        switch mode {
        case .flight: "airplane"
        case .train: "tram.fill"
        case .bus: "bus.fill"
        case .other: "arrow.triangle.turn.up.right.circle"
        }
    }

    private var route: String {
        switch (leg.from.isEmpty, leg.to.isEmpty) {
        case (false, false): "\(leg.from) → \(leg.to)"
        case (false, true): leg.from
        case (true, false): "→ \(leg.to)"
        default: leg.mode.title
        }
    }

    private var carrier: String { [leg.carrier, leg.number].filter { !$0.isEmpty }.joined(separator: " ") }

    private var when: String {
        var text = leg.departure.map { Self.dayFormat.string(from: $0.instant()) } ?? "No date yet"
        if let minutes = leg.departureMinutes { text += " · \(timeText(minutes))" }
        if let arrival = leg.arrivalMinutes {
            let nextDay = leg.arrivalDate.map { $0 != leg.departure } ?? false
            text += " → \(timeText(arrival))" + (nextDay ? " (\(leg.arrivalDate.map(\.shortTitle) ?? ""))" : "")
        }
        return text
    }

    private static let dayFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()
}

/// "06:40".
func timeText(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

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
