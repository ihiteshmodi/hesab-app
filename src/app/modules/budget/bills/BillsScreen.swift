import HisaabCore
import SwiftUI

struct BillsScreen: View {
    let model: BudgetViewModel
    @State private var addingBill = false
    @State private var addingPlanned = false
    @State private var addingSeveral = false
    @State private var billToAdd: Int64?
    @State private var plannedToAdd: Int64?
    @State private var plannedToSchedule: PlannedItem?
    @State private var editingBill: Int64?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("billsError")
                }
                Section("Upcoming") {
                    if model.upcoming.items.isEmpty {
                        Text("Nothing due soon.").foregroundStyle(.secondary)
                    }
                    ForEach(model.upcoming.items, id: \.bill.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.bill.name)
                                Text(item.label).font(.footnote)
                                    .foregroundStyle(item.label.hasPrefix("Past") ? Color.red : Color.secondary)
                            }
                            Spacer()
                            Text(IndianMoneyFormat.string(item.bill.amount)).monospacedDigit()
                            Button("Add") { billToAdd = item.bill.id }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("addUpcomingBillButton")
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("upcomingRow")
                    }
                    Button("Add Several at Once") { addingSeveral = true }
                        .accessibilityIdentifier("addSeveralButton")
                }
                Section {
                    if model.planned.items.isEmpty {
                        Text("Nothing planned yet. Add an expense you know is coming.").foregroundStyle(.secondary)
                    }
                    ForEach(model.planned.items, id: \.id) { item in
                        HStack {
                            Text(item.description)
                            Spacer()
                            Text(IndianMoneyFormat.string(item.amount)).monospacedDigit()
                            Button("Add") { plannedToAdd = item.id }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("addPlannedButton")
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { errorMessage = model.deletePlanned(item.id) }
                            Button("Give a Date") { plannedToSchedule = item }.tint(.blue)
                        }
                    }
                    if !model.planned.items.isEmpty {
                        HStack {
                            Text("Planned total")
                            Spacer()
                            Text(IndianMoneyFormat.string(model.planned.total)).monospacedDigit()
                                .accessibilityIdentifier("plannedTotal")
                        }
                    }
                } header: {
                    Text("Planned")
                }
                Section("All bills") {
                    ForEach(model.bills, id: \.bill.id) { summary in
                        Button { editingBill = summary.bill.id } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(summary.bill.name)
                                    Text(detail(summary)).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(IndianMoneyFormat.string(summary.bill.amount)).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("billRow")
                    }
                }
                Section {
                    NavigationLink {
                        AutoAddedScreen(model: model)
                    } label: {
                        HStack {
                            Text("Auto-added")
                            Spacer()
                            if model.attention.autoAddedUnseen > 0 {
                                Text("\(model.attention.autoAddedUnseen)").foregroundStyle(.red)
                            }
                        }
                    }
                    .accessibilityIdentifier("autoAddedLink")
                }
            }
            .navigationTitle("Bills")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Bill", systemImage: "calendar.badge.plus") { addingBill = true }
                            .accessibilityIdentifier("newBillButton")
                        Button("New Planned Item", systemImage: "list.bullet.clipboard") { addingPlanned = true }
                            .accessibilityIdentifier("newPlannedButton")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("billsAddMenu")
                }
            }
            .sheet(isPresented: $addingBill) { NewBillSheet(model: model) }
            .sheet(isPresented: $addingPlanned) { NewPlannedSheet(model: model) }
            .sheet(isPresented: $addingSeveral) { AddSeveralSheet(model: model) }
            .sheet(item: $editingBill) { id in NewBillSheet(model: model, editing: id) }
            .sheet(item: $plannedToSchedule) { item in
                NewBillSheet(model: model, startingFrom: item)
            }
            .sheet(item: $billToAdd) { id in
                if let draft = model.billDraft(id) {
                    NewExpenseSheet(model: model, draft: draft) { model.addBillOccurrence(id, $0) }
                }
            }
            .sheet(item: $plannedToAdd) { id in
                if let item = model.planned.items.first(where: { $0.id == id }) {
                    NewExpenseSheet(
                        model: model,
                        draft: NewExpense(date: nil, description: item.description, amount: item.amount, category: "")
                    ) { model.addPlannedAsExpense(id, $0) }
                }
            }
        }
    }

    private func detail(_ summary: BillSummary) -> String {
        var parts = [summary.bill.repeats.title]
        if let due = summary.nextDue { parts.append("Next due \(due.shortTitle)") } else { parts.append("Ended") }
        if let added = summary.addedLabel { parts.append(added) }
        return parts.joined(separator: " · ")
    }
}

private struct NewPlannedSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var amountText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("What is coming", text: $description).accessibilityIdentifier("plannedDescriptionField")
                TextField("Amount", text: $amountText).keyboardType(.decimalPad).accessibilityIdentifier("plannedAmountField")
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("plannedError")
                }
            }
            .navigationTitle("New Planned Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addPlanned(description: description, amountText: amountText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("savePlannedButton")
                }
            }
        }
    }
}

private struct AddSeveralSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var month: CalendarDate.YearMonth
    @State private var ticked: Set<Int64> = []
    @State private var errorMessage: String?

    init(model: BudgetViewModel) {
        self.model = model
        let start = CalendarDate(Date()).yearMonth
        _month = State(initialValue: start)
        _ticked = State(initialValue: Set(model.billsToAdd(for: start).filter { !$0.alreadyAdded }.map(\.bill.id)))
    }

    var body: some View {
        NavigationStack {
            let choices = model.billsToAdd(for: month)
            List {
                Section {
                    HStack {
                        Button("Previous Month", systemImage: "chevron.left") { move(-1) }.labelStyle(.iconOnly)
                        Spacer()
                        Text(month.title).font(.headline)
                        Spacer()
                        Button("Next Month", systemImage: "chevron.right") { move(1) }.labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                }
                Section {
                    if choices.isEmpty { Text("Nothing to add for this month.").foregroundStyle(.secondary) }
                    ForEach(choices, id: \.bill.id) { choice in
                        Button {
                            if ticked.contains(choice.bill.id) { ticked.remove(choice.bill.id) } else { ticked.insert(choice.bill.id) }
                        } label: {
                            HStack {
                                Image(systemName: choice.alreadyAdded ? "checkmark.circle.fill"
                                      : ticked.contains(choice.bill.id) ? "checkmark.square.fill" : "square")
                                VStack(alignment: .leading) {
                                    Text(choice.bill.name)
                                    Text(choice.alreadyAdded ? "Added" : choice.dueDate.shortTitle)
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(IndianMoneyFormat.string(choice.bill.amount)).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(choice.alreadyAdded)
                        .accessibilityIdentifier("severalRow")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Add Several")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected") {
                        let ids = choices.filter { ticked.contains($0.bill.id) && !$0.alreadyAdded }.map(\.bill.id)
                        errorMessage = model.addSeveralBills(ids, for: month)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("confirmSeveralButton")
                }
            }
        }
    }

    private func move(_ delta: Int) {
        month = month.shifted(by: delta)
        ticked = Set(model.billsToAdd(for: month).filter { !$0.alreadyAdded }.map(\.bill.id))
    }
}

struct AutoAddedScreen: View {
    let model: BudgetViewModel
    @State private var errorMessage: String?

    var body: some View {
        List {
            if model.autoAdded.isEmpty {
                Text("Nothing was added automatically yet.").foregroundStyle(.secondary)
            }
            ForEach(model.autoAdded, id: \.occurrenceID) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.billName)
                        Text("Due \(entry.dueDate.shortTitle)").font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(IndianMoneyFormat.string(entry.amount)).monospacedDigit()
                    Button("Undo") { errorMessage = model.undoAutoAdded(entry.occurrenceID) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("undoAutoAddedButton")
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle("Auto-added")
        .onAppear { model.markAutoAddedSeen() }
    }
}
