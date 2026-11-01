import HisaabCore
import SwiftUI

/// The Bills tab: a month calendar of bills and income, narrowed by the filter menu, or the same as a list.
struct BillsScreen: View {
    let model: BudgetViewModel
    @State private var month = CalendarDate(Date()).yearMonth
    @State private var selectedDay = CalendarDate(Date()).day
    @State private var filter = BillsFilter.allTransactions
    @State private var filterOpen = false
    @State private var showingList = false
    @State private var addingBill = false
    @State private var addingPlanned = false
    @State private var addingSeveral = false
    @State private var billToAdd: Int64?
    @State private var plannedToAdd: Int64?
    @State private var plannedToSchedule: PlannedItem?
    @State private var editingPlanned: PlannedItem?
    @State private var editingBill: Int64?
    @State private var recordingPayout: PayoutScheme?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                HStack(spacing: 10) {
                    Button { withAnimation(.easeOut(duration: 0.15)) { filterOpen.toggle() } } label: {
                        CircleIcon(systemName: "line.3.horizontal", badge: model.attention.badge)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter, \(model.attention.badge)")
                    .accessibilityIdentifier("billsFilterButton")
                    Text(filter == .allTransactions ? "All Transactions" : filter.title)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondary)
                    Spacer()
                    Button { showingList.toggle() } label: {
                        CircleIcon(systemName: showingList ? "calendar" : "list.bullet")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showingList ? "Calendar" : "List")
                    .accessibilityIdentifier("billsViewSwitch")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).accessibilityIdentifier("billsError")
                }
                if filter == .planned {
                    planned
                } else if let calendar = model.billsCalendar(for: month) {
                    if showingList { list(calendar) } else { calendarView(calendar) }
                    if filter != .income, filter != .upcomingIncome, filter != .receivedIncome { allBills }
                }
            }
            .cardNavigation("Bills")
            .overlay(alignment: .topLeading) { if filterOpen { filterMenu } }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Bill", systemImage: "calendar.badge.plus") { addingBill = true }
                            .accessibilityIdentifier("newBillButton")
                        Button("New Planned Item", systemImage: "list.bullet.clipboard") { addingPlanned = true }
                            .accessibilityIdentifier("newPlannedButton")
                        Button("Add Several at Once", systemImage: "checklist") { addingSeveral = true }
                            .accessibilityIdentifier("addSeveralMenuButton")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                    .accessibilityIdentifier("billsAddMenu")
                }
            }
            .sheet(isPresented: $addingBill) { NewBillSheet(model: model) }
            .sheet(isPresented: $addingPlanned) { NewPlannedSheet(model: model) }
            .sheet(item: $editingPlanned) { NewPlannedSheet(model: model, editing: $0) }
            .sheet(isPresented: $addingSeveral) { AddSeveralSheet(model: model) }
            .sheet(item: $editingBill) { id in NewBillSheet(model: model, editing: id) }
            .sheet(item: $recordingPayout) { RecordPayoutSheet(model: model, scheme: $0) }
            .sheet(item: $plannedToSchedule) { item in NewBillSheet(model: model, startingFrom: item) }
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

    // MARK: calendar

    private func calendarView(_ calendar: BillsCalendar) -> some View {
        let counts = calendar.counts(filter)
        let day = min(selectedDay, month.dayCount)
        return Group {
            CardPanel(padding: 14) {
                HStack {
                    Text(month.title).font(.system(size: 22, weight: .bold)).accessibilityIdentifier("billsMonthTitle")
                    Spacer()
                    Button { move(-1) } label: { CircleIcon(systemName: "chevron.left") }
                        .buttonStyle(.plain).accessibilityLabel("Previous Month").accessibilityIdentifier("billsPreviousMonth")
                    Button { move(1) } label: { CircleIcon(systemName: "chevron.right") }
                        .buttonStyle(.plain).accessibilityLabel("Next Month").accessibilityIdentifier("billsNextMonth")
                }
                .padding(.horizontal, 6).padding(.bottom, 4)
                CalendarGrid(month: month) { date in
                    Button { selectedDay = date } label: {
                        VStack(spacing: 2) {
                            Text("\(date)").font(.system(size: 16))
                            HStack(spacing: 3) {
                                ForEach(0..<min(counts[date] ?? 0, 3), id: \.self) { _ in
                                    Circle().fill(date == day ? Color.white : Theme.blue).frame(width: 5, height: 5)
                                }
                            }
                            .frame(height: 6)
                        }
                        .foregroundStyle(date == day ? Color.white : Color.primary)
                        .frame(width: 42, height: 46)
                        .background(date == day ? Theme.blue : .clear, in: Circle())
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(date) \(month.title), \(counts[date] ?? 0) due")
                    .accessibilityAddTraits(date == day ? .isSelected : [])
                    .accessibilityIdentifier("billDay-\(date)")
                }
            }
        }
    }

    private func list(_ calendar: BillsCalendar) -> some View {
        let items = calendar.items(filter)
        let days = Array(Set(items.map(\.date))).sorted()
        return Group {
            HStack {
                Button { move(-1) } label: { CircleIcon(systemName: "chevron.left") }
                    .buttonStyle(.plain).accessibilityLabel("Previous Month").accessibilityIdentifier("billsPreviousMonth")
                Spacer()
                Text(month.title).font(.system(size: 20, weight: .bold)).accessibilityIdentifier("billsMonthTitle")
                Spacer()
                Button { move(1) } label: { CircleIcon(systemName: "chevron.right") }
                    .buttonStyle(.plain).accessibilityLabel("Next Month").accessibilityIdentifier("billsNextMonth")
            }
            if items.isEmpty {
                CardPanel { Text("Nothing this month.").foregroundStyle(Theme.secondary) }
            }
            ForEach(days, id: \.self) { date in
                CardGroup(header: date.dayTitle) {
                    ForEach(Array(items.filter { $0.date == date }.enumerated()), id: \.offset) { _, item in itemRow(item) }
                }
            }
        }
    }

    private func itemRow(_ item: CalendarItem) -> some View {
        let row = CardRow(title: item.name, subtitle: item.detail) {
            Text(IndianMoneyFormat.string(item.amount)).monospacedDigit().font(.system(size: 15.5))
            if item.canAdd, let id = item.billID {
                Button("Add") { billToAdd = id }.buttonStyle(AddPillStyle()).accessibilityIdentifier("addCalendarBillButton")
            } else if item.canRecord, let id = item.schemeID {
                Button("Record") { recordingPayout = model.payouts.schemes.first { $0.scheme.id == id }?.scheme }
                    .buttonStyle(AddPillStyle()).accessibilityIdentifier("recordPayoutButton")
            } else {
                switch item.kind {
                case .billNotAdded where item.isAutomatic: StatusPill(text: "Auto")
                case .billAdded: StatusPill(text: "Added", tone: .green)
                case .billAutoAdded: StatusPill(text: "Auto-added", tone: .green)
                case .receivedIncome: StatusPill(text: "Received", tone: .green)
                default: EmptyView()
                }
            }
        }
        return Group {
            if let id = item.billID {
                row.onTapGesture { editingBill = id }
            } else {
                row
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("billCalendarRow")
    }

    private func move(_ delta: Int) {
        month = month.shifted(by: delta)
        let today = CalendarDate(Date())
        selectedDay = today.yearMonth == month ? today.day : 1
    }

    // MARK: All bills

    @ViewBuilder private var allBills: some View {
        if !model.bills.isEmpty {
            CardGroup(header: "All bills", footer: "Tap a bill to change its usual amount, plan or end date. Use Add to put one month's bill in Activity.") {
                ForEach(model.bills, id: \.bill.id) { summary in
                    HStack(spacing: 8) {
                        Button { editingBill = summary.bill.id } label: {
                            CardRow(title: summary.bill.name, subtitle: detail(summary)) {
                                Text(IndianMoneyFormat.string(summary.bill.amount)).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("billRow")
                        if summary.nextDue != nil {
                            Button("Add") { billToAdd = summary.bill.id }.buttonStyle(AddPillStyle())
                                .padding(.trailing, 14)
                                .accessibilityIdentifier("addBillRowButton")
                        }
                    }
                }
            }
        }
        if !model.autoAdded.isEmpty {
            CardGroup {
                LinkRow(title: "Auto-added", value: model.attention.autoAddedUnseen > 0 ? "\(model.attention.autoAddedUnseen) new" : "",
                        identifier: "autoAddedLink") { AutoAddedScreen(model: model) }
            }
        }
    }

    @ViewBuilder private var planned: some View {
        CardGroup(header: "Planned (no date)", footer: "Expenses you know are coming but cannot date yet. Tap one to change it. Touch and hold to delete it or give it a date.") {
            if model.planned.items.isEmpty {
                Text("Nothing planned yet. Add an expense you know is coming.").foregroundStyle(Theme.secondary).rowPadding()
            }
            ForEach(model.planned.items, id: \.id) { item in
                CardRow(title: item.description) {
                    Text(IndianMoneyFormat.string(item.amount)).monospacedDigit()
                    Button("Add") { plannedToAdd = item.id }.buttonStyle(AddPillStyle()).accessibilityIdentifier("addPlannedButton")
                }
                .contentShape(Rectangle())
                .onTapGesture { editingPlanned = item }
                .contextMenu {
                    Button("Give a Date", systemImage: "calendar") { plannedToSchedule = item }
                    Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deletePlanned(item.id) }
                }
            }
            if !model.planned.items.isEmpty {
                CardRow(title: "Planned total") {
                    Text(IndianMoneyFormat.string(model.planned.total)).monospacedDigit().fontWeight(.semibold)
                        .accessibilityIdentifier("plannedTotal")
                }
            }
        }
        Button("New Planned Item") { addingPlanned = true }.buttonStyle(PrimaryButtonStyle())
    }

    private func detail(_ summary: BillSummary) -> String {
        // Non-breaking spaces keep "Every 3 Months" and "Due 13 Nov" from splitting across lines.
        let glue: (String) -> String = { $0.replacingOccurrences(of: " ", with: "\u{00A0}") }
        let repeats = glue(summary.bill.repeats == .never ? "One-off" : summary.bill.repeats.title)
        guard let due = summary.nextDue else { return "\(repeats) · Ended" }
        return "\(glue("Due \(due.shortTitle)")) · \(repeats)"
    }

    // MARK: the filter menu (mockup 7)

    private var filterMenu: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture { filterOpen = false }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(BillsFilter.allCases, id: \.self) { option in
                    Button {
                        filter = option
                        filterOpen = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                                .opacity(filter == option ? 1 : 0)
                            Text(option.title).font(.system(size: 17))
                            Spacer()
                            count(option)
                        }
                        .padding(.vertical, 10).padding(.horizontal, 14)
                        .padding(.leading, [.notAdded, .added, .autoAdded, .upcomingIncome, .receivedIncome].contains(option) ? 18 : 0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filter-\(option.rawValue)")
                }
            }
            .padding(.vertical, 8)
            .frame(width: 290)
            .background(Theme.card.opacity(0.98), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 14)
            .padding(.leading, 18).padding(.top, 6)
        }
    }

    @ViewBuilder private func count(_ option: BillsFilter) -> some View {
        let hot: Int = switch option {
        case .bills: model.attention.dueBills
        case .autoAdded: model.attention.autoAddedUnseen
        case .upcomingIncome: model.attention.dueIncome
        default: 0
        }
        if hot > 0 {
            Text("\(hot)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 1).background(Theme.red, in: Capsule())
                .accessibilityIdentifier("filterCount-\(option.rawValue)")
        } else if option == .planned, !model.planned.items.isEmpty {
            Text("\(model.planned.items.count)").font(.system(size: 15)).foregroundStyle(Theme.secondary)
        }
    }
}

private extension CalendarDate {
    /// "Sun, 1 Nov".
    var dayTitle: String {
        let weekday = (yearMonth.firstWeekday + day - 1) % 7
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return "\(names[weekday]), \(shortTitle)"
    }
}

private struct NewPlannedSheet: View {
    let model: BudgetViewModel
    var editing: PlannedItem?
    @Environment(\.dismiss) private var dismiss
    @State private var description: String
    @State private var amountText: String
    @State private var errorMessage: String?

    init(model: BudgetViewModel, editing item: PlannedItem? = nil) {
        self.model = model
        editing = item
        _description = State(initialValue: item?.description ?? "")
        _amountText = State(initialValue: item.map { IndianMoneyFormat.plain($0.amount) } ?? "")
    }

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("What is coming", text: $description).rowPadding().accessibilityIdentifier("plannedDescriptionField")
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("plannedAmountField")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("plannedError")
                }
            }
            .cardNavigation(editing == nil ? "New Planned Item" : "Edit Planned Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = editing.map { model.updatePlanned($0.id, description: description, amountText: amountText) }
                            ?? model.addPlanned(description: description, amountText: amountText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("savePlannedButton")
                }
            }
        }
    }
}

/// Mockup 12: tick the bills to add for a month and add them together.
struct AddSeveralSheet: View {
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
            CardScreen {
                HStack {
                    Button { move(-1) } label: { CircleIcon(systemName: "chevron.left") }.buttonStyle(.plain)
                        .accessibilityLabel("Previous Month")
                    Spacer()
                    Text(month.title).font(.headline)
                    Spacer()
                    Button { move(1) } label: { CircleIcon(systemName: "chevron.right") }.buttonStyle(.plain)
                        .accessibilityLabel("Next Month")
                }
                CardGroup {
                    if choices.isEmpty { Text("Nothing to add for this month.").foregroundStyle(Theme.secondary).rowPadding() }
                    ForEach(choices, id: \.bill.id) { choice in
                        Button {
                            if ticked.contains(choice.bill.id) { ticked.remove(choice.bill.id) } else { ticked.insert(choice.bill.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: choice.alreadyAdded ? "checkmark.circle.fill"
                                      : ticked.contains(choice.bill.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(choice.alreadyAdded ? Theme.green : Theme.blue).font(.title3)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(choice.bill.name)
                                    Text(choice.alreadyAdded ? "Added" : choice.dueDate.shortTitle)
                                        .font(.footnote).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                Text(IndianMoneyFormat.string(choice.bill.amount)).monospacedDigit()
                            }
                            .rowPadding()
                        }
                        .buttonStyle(.plain)
                        .disabled(choice.alreadyAdded)
                        .accessibilityIdentifier("severalRow")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
            }
            .cardNavigation("Add Several")
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

/// Mockup 10: every expense the app added by itself, newest first, each with Undo.
struct AutoAddedScreen: View {
    let model: BudgetViewModel
    @State private var errorMessage: String?

    var body: some View {
        CardScreen {
            CardGroup {
                if model.autoAdded.isEmpty {
                    Text("Nothing was added automatically yet.").foregroundStyle(Theme.secondary).rowPadding()
                }
                ForEach(model.autoAdded, id: \.occurrenceID) { entry in
                    CardRow(title: entry.billName, subtitle: "Due \(entry.dueDate.shortTitle)") {
                        Text(IndianMoneyFormat.string(entry.amount)).monospacedDigit()
                        Button("Undo") { errorMessage = model.undoAutoAdded(entry.occurrenceID) }
                            .buttonStyle(AddPillStyle())
                            .accessibilityIdentifier("undoAutoAddedButton")
                    }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
        }
        .cardNavigation("Auto-added")
        .onAppear { model.markAutoAddedSeen() }
    }
}
