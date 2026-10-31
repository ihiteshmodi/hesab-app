import HisaabCore
import SwiftUI

private enum TripPane: String, CaseIterable {
    case expenses = "Expenses"
    case balances = "Balances"
}

private enum TripEntry: Identifiable {
    case expense(TripExpense?)
    case transfer(personID: Int64?)

    var id: String {
        switch self {
        case .expense(let expense): "expense-\(expense?.id ?? 0)"
        case .transfer(let person): "transfer-\(person ?? 0)"
        }
    }
}

struct TripDetailScreen: View {
    let model: BudgetViewModel
    let tripID: Int64
    @State private var pane = TripPane.expenses
    @State private var entry: TripEntry?
    @State private var editingTrip = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let summary = model.tripSummary(tripID) {
                CardScreen {
                    Picker("View", selection: $pane) {
                        ForEach(TripPane.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("tripPanePicker")
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
                    switch pane {
                    case .expenses: expenses(summary)
                    case .balances: balances(summary)
                    }
                }
                .cardNavigation(summary.trip.name)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        NavigationLink {
                            TripInsightsScreen(model: model, tripID: tripID)
                        } label: { Image(systemName: "chart.pie") }
                            .accessibilityLabel("Insights")
                            .accessibilityIdentifier("tripInsightsButton")
                        NavigationLink {
                            TripPeopleScreen(model: model, tripID: tripID)
                        } label: { Image(systemName: "person.2") }
                            .accessibilityLabel("People")
                            .accessibilityIdentifier("tripPeopleButton")
                        Menu {
                            Button("Edit Trip") { editingTrip = true }
                        } label: { Image(systemName: "ellipsis.circle") }
                            .accessibilityLabel("More")
                    }
                }
                .sheet(item: $entry) { entry in
                    switch entry {
                    case .expense(let expense):
                        TripExpenseSheet(model: model, summary: summary, editing: expense) { self.entry = .transfer(personID: nil) }
                    case .transfer(let personID):
                        TripTransferSheet(model: model, summary: summary, personID: personID) { self.entry = .expense(nil) }
                    }
                }
                .sheet(isPresented: $editingTrip) { NewTripSheet(model: model, editing: summary.trip) }
                .overlay(alignment: .bottomTrailing) {
                    if pane == .expenses {
                        Button { entry = .expense(nil) } label: {
                            Image(systemName: "plus").font(.title2.bold()).foregroundStyle(.white)
                                .frame(width: 56, height: 56).background(Circle().fill(Theme.blue))
                        }
                        .padding(20)
                        .accessibilityLabel("Add")
                        .accessibilityIdentifier("addTripEntryButton")
                    }
                }
            } else {
                Text("That trip no longer exists.").foregroundStyle(Theme.secondary)
            }
        }
    }

    // MARK: expenses

    @ViewBuilder private func expenses(_ summary: TripSummary) -> some View {
        let trip = summary.trip
        CardPanel {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    CardCaption("My expenses")
                    Text(model.tripText(summary.myShare, trip)).font(.title2.bold()).monospacedDigit()
                        .accessibilityIdentifier("tripMyExpenses")
                    if trip.currency != nil { Text("≈ \(IndianMoneyFormat.string(summary.myShareHome))").font(.footnote).foregroundStyle(Theme.secondary) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    CardCaption("Total")
                    Text(model.tripText(summary.totalSpent, trip)).font(.title2.bold()).monospacedDigit()
                    if trip.currency != nil { Text("≈ \(IndianMoneyFormat.string(summary.totalSpentHome))").font(.footnote).foregroundStyle(Theme.secondary) }
                }
            }
        }
        CardGroup {
            CardRow(title: "Net cost so far") {
                Text(IndianMoneyFormat.string(summary.netCost)).monospacedDigit().accessibilityIdentifier("tripNetCost")
            }
            CardRow(title: "In the main ledger") {
                Text(IndianMoneyFormat.string(summary.ledgerAmount)).monospacedDigit().foregroundStyle(Theme.secondary)
                    .accessibilityIdentifier("tripLedgerAmount")
            }
        }
        CardGroup(footer: summary.expenses.isEmpty ? nil : "Touch and hold an expense to delete it.") {
            if summary.expenses.isEmpty {
                Text("No expenses yet. Add one with the + button.").foregroundStyle(Theme.secondary).rowPadding()
            }
            ForEach(summary.expenses, id: \.id) { expense in
                NavigationLink {
                    TripExpenseDetailScreen(model: model, tripID: tripID, expenseID: expense.id) { entry = .expense($0) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(expense.description)
                                if expense.hasReceipt { Image(systemName: "paperclip").font(.footnote).foregroundStyle(Theme.secondary) }
                            }
                            Text(subtitle(expense, summary)).font(.footnote).foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(model.tripText(expense.amount, trip)).monospacedDigit()
                            Text("my share \(model.tripText(expense.shares[.me] ?? .zero, trip))").font(.footnote).foregroundStyle(Theme.secondary)
                        }
                    }
                    .rowPadding()
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteTripExpense(expense.id) }
                }
                .accessibilityIdentifier("tripExpenseRow")
            }
        }
    }

    private func subtitle(_ expense: TripExpense, _ summary: TripSummary) -> String {
        let payer: String
        switch expense.paidBy {
        case .me: payer = expense.paidWith == .cash ? "Paid by me in cash" : "Paid by me"
        case .person(let id): payer = "Paid by \(summary.members.first { $0.id == id }?.name ?? "someone")"
        }
        var parts = [expense.date.shortTitle, payer, "\(expense.shares.count) people"]
        if !expense.tag.isEmpty { parts.append(expense.tag) }
        return parts.joined(separator: " · ")
    }

    // MARK: balances

    @ViewBuilder private func balances(_ summary: TripSummary) -> some View {
        let trip = summary.trip
        if trip.currency != nil {
            CardGroup {
                NavigationLink {
                    TripCashScreen(model: model, tripID: tripID)
                } label: {
                    CardRow(title: "Trip cash", subtitle: "\(trip.currency ?? "") held in hand") {
                        Text(model.tripText(summary.cash.balance, trip)).monospacedDigit().accessibilityIdentifier("tripCashBalance")
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("tripCashLink")
            }
        }
        CardGroup {
            if summary.balances.isEmpty {
                Text("Add the people in this trip first (the people button above).").foregroundStyle(Theme.secondary).rowPadding()
            }
            ForEach(summary.balances, id: \.person.id) { balance in
                NavigationLink {
                    PersonStatementScreen(model: model, tripID: tripID, personID: balance.person.id) {
                        entry = .transfer(personID: $0)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(balance.person.name).font(.headline)
                            Text(balance.owesMe == .zero ? "Square" : balance.owesMe > .zero ? "owes me" : "I owe")
                                .font(.footnote).foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(model.tripText(balance.owesMe < .zero ? .zero - balance.owesMe : balance.owesMe, trip)).monospacedDigit()
                                .foregroundStyle(balance.owesMe > .zero ? Theme.green : balance.owesMe < .zero ? Theme.red : Theme.secondary)
                            if trip.currency != nil && balance.owesMe != .zero {
                                Text("≈ \(IndianMoneyFormat.string(balance.owesMeHome < .zero ? .zero - balance.owesMeHome : balance.owesMeHome))")
                                    .font(.footnote).foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    .rowPadding()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tripBalanceRow")
            }
            Button { entry = .transfer(personID: nil) } label: { Text("Settle Up").rowPadding() }
                .accessibilityIdentifier("settleUpButton")
        }
        CardGroup(header: "Money received") {
            line("By bank or UPI", IndianMoneyFormat.string(summary.receivedBankHome))
            line("In rupee notes", IndianMoneyFormat.string(summary.receivedCashHome))
            if trip.currency != nil { line("In \(trip.currency ?? "") cash", model.tripText(summary.receivedCashTrip, trip)) }
            line("Written off (a cost)", IndianMoneyFormat.string(summary.writtenOffHome), id: "tripWrittenOff")
            line("Paid extra (a gain)", IndianMoneyFormat.string(summary.extraReceivedHome), id: "tripExtraReceived")
        }
        Button(trip.isSettled ? "Mark Trip as Open Again" : "Mark Trip as Settled") {
            errorMessage = model.setTripSettled(tripID, !trip.isSettled)
        }
        .buttonStyle(GreyButtonStyle())
        .accessibilityIdentifier("markSettledButton")
    }

    private func line(_ title: String, _ value: String, id: String? = nil) -> some View {
        CardRow(title: title) {
            Text(value).monospacedDigit().foregroundStyle(Theme.secondary).accessibilityIdentifier(id ?? title)
        }
    }
}
