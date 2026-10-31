import Charts
import HisaabCore
import SwiftUI
import UIKit

struct TripExpenseDetailScreen: View {
    let model: BudgetViewModel
    let tripID: Int64
    let expenseID: Int64
    let onEdit: (TripExpense) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let summary = model.tripSummary(tripID), let expense = summary.expenses.first(where: { $0.id == expenseID }) {
            let trip = summary.trip
            CardScreen {
                CardPanel {
                    VStack(alignment: .leading, spacing: 4) {
                        CardCaption(expense.paidBy == .me ? "Paid by me" : "Paid by \(name(expense.paidBy, summary))")
                        Text(model.tripText(expense.amount, trip)).font(.title.bold()).monospacedDigit()
                        if let charge = expense.paidInHome {
                            Text("card charged \(IndianMoneyFormat.string(charge))").foregroundStyle(Theme.secondary)
                        } else if trip.currency != nil {
                            Text(expense.paidWith == .cash ? "paid in cash" : "≈ \(IndianMoneyFormat.string(TripValue.home(expense.amount, trip)))")
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    Chart(shares(expense), id: \.who) { item in
                        BarMark(x: .value("Share", item.paise)).foregroundStyle(by: .value("Person", item.name))
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 36)
                }
                CardGroup(header: "Who owes what") {
                    ForEach(shares(expense), id: \.who) { item in
                        CardRow(title: item.name) {
                            VStack(alignment: .trailing) {
                                Text(model.tripText(Money(paise: item.paise), trip)).monospacedDigit()
                                if trip.currency != nil {
                                    Text("≈ \(IndianMoneyFormat.string(TripValue.home(Money(paise: item.paise), trip, charge: expense)))")
                                        .font(.footnote).foregroundStyle(Theme.secondary)
                                }
                            }
                        }
                    }
                }
                if !expense.tag.isEmpty || !expense.note.isEmpty {
                    CardGroup(header: "Details") {
                        if !expense.tag.isEmpty {
                            CardRow(title: "Tag") { Text(expense.tag).foregroundStyle(Theme.secondary) }
                        }
                        if !expense.note.isEmpty { Text(expense.note).rowPadding() }
                    }
                }
                if expense.hasReceipt, let data = model.tripReceipt(expense.id), let image = UIImage(data: data) {
                    CardGroup(header: "Receipt") {
                        Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier("receiptImage")
                    }
                }
            }
            .cardNavigation(expense.description)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { onEdit(expense); dismiss() }.accessibilityIdentifier("editTripExpenseButton")
                }
            }
        } else {
            Text("That expense no longer exists.").foregroundStyle(Theme.secondary)
        }
    }

    private struct ShareItem { let who: Participant; let name: String; let paise: Int }

    private func shares(_ expense: TripExpense) -> [ShareItem] {
        guard let summary = model.tripSummary(tripID) else { return [] }
        return expense.shares.map { ShareItem(who: $0.key, name: name($0.key, summary), paise: $0.value.paise) }
            .sorted { $0.who.hashValue < $1.who.hashValue }
            .sorted { ($0.name == "Me" ? 0 : 1, $0.name) < ($1.name == "Me" ? 0 : 1, $1.name) }
    }

    private func name(_ who: Participant, _ summary: TripSummary) -> String {
        switch who {
        case .me: "Me"
        case .person(let id): summary.members.first { $0.id == id }?.name ?? "Someone"
        }
    }
}

/// What a trip-currency amount is worth in rupees at the trip rate, or at the expense's own card charge.
enum TripValue {
    static func home(_ money: Money, _ trip: Trip, charge expense: TripExpense? = nil) -> Money {
        guard let rate = trip.rate else { return money }
        var exact: Decimal
        if let expense, let paid = expense.paidInHome, expense.amount > .zero {
            exact = Decimal(money.paise) * Decimal(paid.paise) / Decimal(expense.amount.paise)
        } else {
            exact = Decimal(money.paise) * rate
        }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &exact, 0, .plain)
        return Money(paise: NSDecimalNumber(decimal: rounded).intValue)
    }
}

struct PersonStatementScreen: View {
    let model: BudgetViewModel
    let tripID: Int64
    let personID: Int64
    let onSettle: (Int64) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        if let summary = model.tripSummary(tripID), let page = model.tripStatement(tripID, personID) {
            let trip = summary.trip
            CardScreen {
                CardPanel {
                    HStack {
                        Text(page.owesMe >= .zero ? "Still owes me" : "I still owe").font(.headline)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(model.tripText(page.owesMe < .zero ? .zero - page.owesMe : page.owesMe, trip)).font(.headline).monospacedDigit()
                                .foregroundStyle(page.owesMe > .zero ? Theme.green : page.owesMe < .zero ? Theme.red : Theme.secondary)
                                .accessibilityIdentifier("statementBalance")
                            if trip.currency != nil {
                                Text("≈ \(IndianMoneyFormat.string(page.owesMeHome < .zero ? .zero - page.owesMeHome : page.owesMeHome))")
                                    .font(.footnote).foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
                section("Entries they owe me for", page.lines.filter { $0.kind == .iPaid }, trip)
                section("What I owe them for", page.lines.filter { $0.kind == .theyPaid }, trip)
                section("Payments", page.lines.filter { $0.kind == .payment }, trip, deletable: true)
            }
            .cardNavigation(page.person.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Settle") { onSettle(personID); dismiss() }.accessibilityIdentifier("statementSettleButton")
                }
            }
        } else {
            Text("That person is no longer in this trip.").foregroundStyle(Theme.secondary)
        }
    }

    @ViewBuilder private func section(_ title: String, _ lines: [StatementLine], _ trip: Trip, deletable: Bool = false) -> some View {
        if !lines.isEmpty {
            CardGroup(header: title, footer: deletable ? "Touch and hold a payment to undo it." : nil) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    CardRow(title: line.title, subtitle: line.date.shortTitle) {
                        Text((line.amount > .zero ? "+ " : "− ") + model.tripText(line.amount < .zero ? .zero - line.amount : line.amount, trip))
                            .monospacedDigit()
                    }
                    .contextMenu {
                        if deletable, let id = line.settlementID {
                            Button("Undo", systemImage: "arrow.uturn.backward", role: .destructive) {
                                errorMessage = model.deleteTripSettlement(id)
                            }
                        }
                    }
                    .accessibilityIdentifier("statementLine")
                }
            }
        }
    }
}

struct TripCashScreen: View {
    let model: BudgetViewModel
    let tripID: Int64
    @State private var setting = false

    var body: some View {
        if let summary = model.tripSummary(tripID) {
            let trip = summary.trip
            CardScreen {
                CardPanel {
                    VStack(alignment: .center, spacing: 4) {
                        CardCaption("Cash in hand (\(trip.currency ?? ""))")
                        Text(model.tripText(summary.cash.balance, trip)).font(.largeTitle.bold()).monospacedDigit()
                            .accessibilityIdentifier("tripCashScreenBalance")
                        Text("≈ \(IndianMoneyFormat.string(TripValue.home(summary.cash.balance, trip))) at the trip rate").foregroundStyle(Theme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    if let warning = summary.cash.warning { Text(warning).foregroundStyle(Theme.orange) }
                }
                CardGroup(header: "Where it went") {
                    if summary.cash.lines.isEmpty {
                        Text("Nothing yet. Set what you are holding, or take cash from a friend.").foregroundStyle(Theme.secondary).rowPadding()
                    }
                    ForEach(Array(summary.cash.lines.enumerated()), id: \.offset) { _, line in
                        CardRow(title: line.description, subtitle: line.date.shortTitle) {
                            VStack(alignment: .trailing) {
                                Text((line.amount >= .zero ? "+ " : "− ") + model.tripText(line.amount < .zero ? .zero - line.amount : line.amount, trip))
                                    .monospacedDigit()
                                Text(model.tripText(line.runningBalance, trip)).font(.footnote).foregroundStyle(Theme.secondary).monospacedDigit()
                            }
                        }
                    }
                }
            }
            .cardNavigation("Trip Cash")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Set Cash", systemImage: "pencil") { setting = true }.accessibilityIdentifier("setTripCashButton")
                }
            }
            .sheet(isPresented: $setting) { SetTripCashSheet(model: model, tripID: tripID) }
        }
    }
}

private struct SetTripCashSheet: View {
    let model: BudgetViewModel
    let tripID: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Cash you are holding", text: $text).keyboardType(.decimalPad).accessibilityIdentifier("setTripCashField")
                        .rowPadding()
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
            }
            .cardNavigation("Set Trip Cash")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.setTripCash(tripID, text: text)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveTripCashButton")
                }
            }
        }
    }
}

struct TripInsightsScreen: View {
    let model: BudgetViewModel
    let tripID: Int64

    private struct Owed: Identifiable { let id: Int64; let name: String; let paise: Int }

    var body: some View {
        if let summary = model.tripSummary(tripID) {
            let trip = summary.trip
            CardScreen {
                CardGroup(header: "Who owes me") {
                    let owed = summary.balances.filter { $0.owesMe > .zero }.map { Owed(id: $0.person.id, name: $0.person.name, paise: $0.owesMe.paise) }
                    if owed.isEmpty { Text("Nobody owes you anything.").foregroundStyle(Theme.secondary).rowPadding() }
                    Chart(owed) { item in
                        BarMark(x: .value("Owes", item.paise), y: .value("Person", item.name)).foregroundStyle(Theme.green)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: CGFloat(max(owed.count, 1)) * 36)
                    .padding(18)
                    ForEach(owed) { item in
                        CardRow(title: item.name) { Text(model.tripText(Money(paise: item.paise), trip)).monospacedDigit() }
                    }
                }
                CardGroup(header: "Spend by tag") {
                    if summary.spendByTag.isEmpty { Text("No expenses yet.").foregroundStyle(Theme.secondary).rowPadding() }
                    Chart(summary.spendByTag, id: \.tag) { item in
                        SectorMark(angle: .value("Spend", item.amount.paise), innerRadius: .ratio(0.55))
                            .foregroundStyle(by: .value("Tag", item.tag.isEmpty ? "Untagged" : item.tag))
                    }
                    .frame(height: 180)
                    .padding(18)
                    ForEach(summary.spendByTag, id: \.tag) { item in
                        CardRow(title: item.tag.isEmpty ? "Untagged" : item.tag) {
                            Text(model.tripText(item.amount, trip)).monospacedDigit()
                        }
                    }
                }
                CardGroup(header: "Paid vs share") {
                    ForEach(summary.totals, id: \.participant) { total in
                        CardRow(
                            title: name(total.participant, summary),
                            subtitle: "paid \(model.tripText(total.paid, trip)) · share \(model.tripText(total.share, trip))"
                        )
                    }
                }
            }
            .cardNavigation("Insights")
        }
    }

    private func name(_ who: Participant, _ summary: TripSummary) -> String {
        switch who {
        case .me: "Me"
        case .person(let id): summary.members.first { $0.id == id }?.name ?? "Someone"
        }
    }
}

struct TripPeopleScreen: View {
    let model: BudgetViewModel
    let tripID: Int64
    @State private var adding = false
    @State private var newName = ""
    @State private var editingGroup: GroupDraft?
    @State private var errorMessage: String?

    var body: some View {
        if let summary = model.tripSummary(tripID) {
            CardScreen {
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).accessibilityIdentifier("peopleError") }
                CardGroup(header: "In this trip", footer: summary.members.isEmpty ? nil : "Touch and hold a person to remove them.") {
                    ForEach(summary.members, id: \.id) { person in
                        Text(person.name)
                            .rowPadding()
                            .contextMenu {
                                Button("Remove", systemImage: "person.badge.minus", role: .destructive) {
                                    errorMessage = model.deletePerson(tripID, person.id)
                                }
                            }
                            .accessibilityIdentifier("personRow")
                    }
                    Button { adding = true } label: { Text("Add Person").rowPadding() }.accessibilityIdentifier("addPersonButton")
                }
                CardGroup(
                    header: "Groups",
                    footer: "A group only saves taps in the split. It never changes who owes what."
                        + (summary.groups.isEmpty ? "" : " Touch and hold a group to delete it.")
                ) {
                    ForEach(summary.groups, id: \.id) { group in
                        Button { editingGroup = GroupDraft(group) } label: {
                            CardRow(title: group.name, subtitle: names(group.members, summary))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteTripGroup(group.id) }
                        }
                        .accessibilityIdentifier("groupRow")
                    }
                    Button { editingGroup = GroupDraft(nil) } label: { Text("New Group").rowPadding() }.accessibilityIdentifier("newGroupButton")
                }
            }
            .cardNavigation("People")
            .alert("Add Person", isPresented: $adding) {
                TextField("Name", text: $newName).accessibilityIdentifier("newPersonField")
                Button("Add") {
                    errorMessage = model.addPerson(tripID, newName)
                    newName = ""
                }
                .accessibilityIdentifier("confirmAddPersonButton")
                Button("Cancel", role: .cancel) { newName = "" }
            }
            .sheet(item: $editingGroup) { GroupSheet(model: model, summary: summary, draft: $0) }
        }
    }

    private func names(_ members: Set<Participant>, _ summary: TripSummary) -> String {
        let order = [Participant.me] + summary.members.map { Participant.person($0.id) }
        return order.filter { members.contains($0) }.map { who in
            switch who {
            case .me: "Me"
            case .person(let id): summary.members.first { $0.id == id }?.name ?? "Someone"
            }
        }.joined(separator: ", ")
    }
}

struct GroupDraft: Identifiable {
    let id: Int64
    let name: String
    let members: Set<Participant>

    init(_ group: TripGroup?) {
        id = group?.id ?? 0
        name = group?.name ?? ""
        members = group?.members ?? []
    }
}

private struct GroupSheet: View {
    let model: BudgetViewModel
    let summary: TripSummary
    let draft: GroupDraft
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var members: Set<Participant> = []
    @State private var errorMessage: String?

    private var participants: [Participant] { [.me] + summary.members.map { Participant.person($0.id) } }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Group name", text: $name).accessibilityIdentifier("groupNameField").rowPadding()
                }
                CardGroup(header: "Who is in it") {
                    ForEach(participants, id: \.self) { who in
                        let title: String = {
                            switch who {
                            case .me: "Me"
                            case .person(let id): summary.members.first { $0.id == id }?.name ?? "Someone"
                            }
                        }()
                        Button {
                            if members.contains(who) { members.remove(who) } else { members.insert(who) }
                        } label: {
                            CardRow(title: title) {
                                if members.contains(who) { Image(systemName: "checkmark").foregroundStyle(Theme.blue) }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("groupMember-\(title)")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).accessibilityIdentifier("groupError") }
            }
            .cardNavigation(draft.id == 0 ? "New Group" : "Edit Group")
            .onAppear {
                name = draft.name
                members = draft.members
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.saveTripGroup(summary.trip.id, id: draft.id == 0 ? nil : draft.id, name: name, members: members)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveGroupButton")
                }
            }
        }
    }
}
