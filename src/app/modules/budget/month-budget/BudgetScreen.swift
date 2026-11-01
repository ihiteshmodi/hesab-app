import HisaabCore
import SwiftUI

/// The Activity tab: one card with Spending, Upcoming and Savings, then a switch between the month's expenses, income and calendar.
struct BudgetScreen: View {
    let model: BudgetViewModel
    @Binding var route: DrawerItem?
    let openMenu: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var addingExpense = false
    @State private var addingIncome = false
    @State private var addingBill = false
    @State private var addingSeveral = false
    @State private var addingScheme = false
    @State private var addingSeveralPayouts = false
    @State private var editingFilters = false
    @State private var billToAdd: Int64?
    @State private var editingIncome: IncomeEntry?
    @State private var openingToSend = false
    @State private var upcomingKind = UpcomingKind.expenses
    @State private var openedExpense: Int64?
    @State private var reviewingAutoAdded = false
    @State private var errorMessage: String?
    @State private var pane = ActivityPane.spending
    @State private var view = ActivityView.expenses
    @State private var revealed = false
    @State private var savingsRevealed = false
    @State private var authMessage: String?

    private var hidden: Bool { model.preferences.hideBalances && !revealed }
    private var savingsShown: Bool { !model.preferences.hideBalances || savingsRevealed }

    private func shown(_ money: Money) -> String { hidden ? "₹ ••••" : IndianMoneyFormat.string(money) }


    var body: some View {
        NavigationStack {
            CardScreen {
                if let loadError = model.loadError {
                    Text(loadError).foregroundStyle(Theme.red)
                }
                if let budget = model.budget {
                    if !model.notices.isEmpty { notice }
                    CardPanel {
                        PillSegments(selection: $pane, options: ActivityPane.allCases.map { ($0, $0.rawValue) },
                                     badges: [.upcoming: model.upcoming.items.count + model.upcomingIncome.count])
                            .padding(.bottom, 6)
                            .accessibilityIdentifier("activityPanePicker")
                        switch pane {
                        case .spending: spending(budget)
                        case .upcoming: upcomingCard
                        case .savings: savingsCard
                        }
                    }
                    switch pane {
                    case .spending: entries(budget)
                    case .upcoming: upcomingActions
                    case .savings: savingsRest(budget)
                    }
                }
            }
            .cardNavigation("Activity")
            .onDisappear { revealed = false; savingsRevealed = false }
            .onChange(of: pane) { authMessage = nil }
            .onChange(of: scenePhase) {
                if scenePhase != .active { revealed = false; savingsRevealed = false }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Menu", systemImage: "person.crop.circle.fill", action: openMenu)
                        .accessibilityLabel("Account")
                        .accessibilityIdentifier("profileButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add Expense", systemImage: "minus.circle") { addingExpense = true }
                            .accessibilityIdentifier("addExpenseButton")
                        Button("Add Income", systemImage: "plus.circle") { addingIncome = true }
                            .accessibilityIdentifier("addIncomeButton")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                    .accessibilityIdentifier("addMenu")
                }
            }
            .navigationDestination(item: $route) { $0.screen(model) }
            .navigationDestination(isPresented: $reviewingAutoAdded) { AutoAddedScreen(model: model) }
            .navigationDestination(isPresented: $openingToSend) { ToSendScreen(model: model) }
            .sheet(isPresented: $addingExpense) { NewExpenseSheet(model: model) }
            .sheet(isPresented: $addingIncome) { NewIncomeSheet(model: model) }
            .sheet(isPresented: $addingBill) { NewBillSheet(model: model) }
            .sheet(isPresented: $addingSeveral) { AddSeveralSheet(model: model) }
            .sheet(isPresented: $addingScheme) { NewSchemeSheet(model: model) }
            .sheet(isPresented: $addingSeveralPayouts) { AddSeveralPayoutsSheet(model: model) }
            .sheet(isPresented: $editingFilters) { UpcomingFiltersSheet(model: model) }
            .sheet(item: $openedExpense) { id in ExpenseDetailSheet(model: model, expenseID: id) }
            .sheet(item: $editingIncome) { NewIncomeSheet(model: model, editing: $0) }
                        .sheet(item: $billToAdd) { id in
                if let draft = model.billDraft(id) {
                    NewExpenseSheet(model: model, draft: draft) { model.addBillOccurrence(id, $0) }
                }
            }
        }
    }

    /// The green notice for bills the app added by itself.
    private var notice: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Added automatically").font(.system(size: 15, weight: .semibold))
            ForEach(model.notices, id: \.self) { notice in
                Text(notice.replacingOccurrences(of: "Added automatically: ", with: ""))
                    .font(.system(size: 13.5)).foregroundStyle(Theme.secondary)
                    .accessibilityLabel(notice)
                    .accessibilityIdentifier("autoNotice")
            }
            HStack(spacing: 18) {
                Button("Review") { reviewingAutoAdded = true }
                Button("Dismiss") { model.dismissNotices() }
            }
            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.blue).padding(.top, 5)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 13).padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, style: .continuous)
                .fill(Color.green).frame(width: 5)
        }
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
    }

    // MARK: Spending

    @ViewBuilder private func spending(_ budget: MonthBudget) -> some View {
        HStack {
            Button("Previous Month", systemImage: "chevron.left") { model.showMonth(budget.month.shifted(by: -1)) }
                .accessibilityIdentifier("previousMonthButton")
            Spacer()
            Text(budget.month.title).font(.subheadline.weight(.semibold)).accessibilityIdentifier("monthTitle")
            Spacer()
            Button("Next Month", systemImage: "chevron.right") { model.showMonth(budget.month.shifted(by: 1)) }
                .accessibilityIdentifier("nextMonthButton")
        }
        .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(Theme.secondary)
        HStack {
            CardCaption("Left to spend")
            Spacer()
            if model.preferences.hideBalances {
                Button(revealed ? "Hide" : "Show with Face ID", systemImage: revealed ? "eye.slash" : "eye") { toggleRevealed() }
                    .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(Theme.secondary)
                    .accessibilityIdentifier("activityEyeButton")
            }
        }
        if let authMessage, pane == .spending {
            Text(authMessage).font(.footnote).foregroundStyle(Theme.red).accessibilityIdentifier("activityAuthMessage")
        }
        Text(IndianMoneyFormat.string(budget.leftToSpend))
            .font(.system(size: 42, weight: .bold)).monospacedDigit()
            .foregroundStyle(budget.leftToSpend < .zero ? Theme.red : Color.primary)
            .minimumScaleFactor(0.5).lineLimit(1)
            .accessibilityIdentifier("leftToSpend")
        HStack(spacing: 10) {
            tile(IndianMoneyFormat.string(budget.spentThisMonth), "Spent in \(monthName(budget.month))", id: "spentThisMonth")
            tile(shown(budget.incomeThisMonth), "Income in \(monthName(budget.month))", id: "incomeThisMonth")
        }
        let pending = budget.pendingRefundsEverywhere
        if pending.count > 0 {
            Button { route = .pendingRefunds } label: {
                HStack {
                    Text("\(pending.count) · \(IndianMoneyFormat.string(pending.stillToCome))").font(.system(size: 17, weight: .bold)).monospacedDigit()
                    Text("Pending refunds").font(.system(size: 12.5)).foregroundStyle(Theme.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Theme.tile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pendingRefundsTile")
        }
        if !model.billsToSend.isEmpty {
            let total = model.billsToSend.reduce(Money.zero) { $0 + $1.amount }
            Button { openingToSend = true } label: {
                HStack {
                    Text("\(model.billsToSend.count) · \(IndianMoneyFormat.string(total))").font(.system(size: 17, weight: .bold)).monospacedDigit()
                    Text("Pending to send").font(.system(size: 12.5)).foregroundStyle(Theme.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(Theme.tile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pendingToSendTile")
        }
    }

    private func tile(_ value: String, _ caption: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 19, weight: .bold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                .accessibilityIdentifier(id)
            Text(caption).font(.system(size: 12.5)).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(Theme.tile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func monthName(_ month: CalendarDate.YearMonth) -> String {
        String(month.title.split(separator: " ").first ?? "")
    }

    @ViewBuilder private func entries(_ budget: MonthBudget) -> some View {
        CardPanel {
            PillSegments(selection: $view, options: ActivityView.allCases.map { ($0, $0.rawValue) })
                .accessibilityIdentifier("activityViewPicker")
        }
        if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
        if budget.hasNoEntriesAtAll, view == .expenses {
            Text("No entries yet. Add your first expense or income.").foregroundStyle(Theme.secondary).padding(.horizontal, 4)
        }
        switch view {
        case .expenses:
            if !budget.expenses.isEmpty {
                CardGroup {
                    ForEach(budget.expenses, id: \.id) { expense in
                        Button { openedExpense = expense.id } label: {
                            ExpenseRow(expense: expense, foreignText: expense.foreign.map(model.text))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("expenseRow")
                    }
                }
            }
        case .income:
            if budget.incomeEntries.isEmpty {
                Text("No income this month.").foregroundStyle(Theme.secondary).padding(.horizontal, 4)
            } else {
                CardGroup(footer: "Tap an entry to change it. Touch and hold to delete it.") {
                    ForEach(budget.incomeEntries, id: \.id) { entry in
                        Button { editingIncome = entry } label: { IncomeRow(entry: entry) }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("incomeRow")
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteIncome(entry.id) }
                            }
                    }
                }
            }
        case .calendar:
            MonthCalendarCard(budget: budget, hideEarned: hidden)
        }
    }

    // MARK: Upcoming

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            PillSegments(selection: $upcomingKind, options: UpcomingKind.allCases.map { ($0, $0.rawValue) })
                .accessibilityIdentifier("upcomingKindPicker")
            switch upcomingKind {
            case .expenses: upcomingExpensesCard
            case .income: UpcomingIncomeList(model: model)
            }
        }
    }

    private var upcomingExpensesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardCaption("Bills you add yourself · \(UpcomingWindow.caption(model.preferences.upcomingWindowDays))")
                .padding(.bottom, 4)
            if model.upcoming.items.isEmpty {
                Text("Nothing due \(UpcomingWindow.phrase(model.preferences.upcomingWindowDays)).")
                    .foregroundStyle(Theme.secondary).padding(.vertical, 12)
                    .accessibilityIdentifier("upcomingEmpty")
            }
            ForEach(Array(model.upcoming.items.enumerated()), id: \.element.bill.id) { index, item in
                if index > 0 { Rectangle().fill(Theme.separator).frame(height: 1) }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.bill.name)
                        Text("\(item.label) · \(item.bill.repeats == .never ? "One-off" : item.bill.repeats.title)")
                            .font(.footnote)
                            .foregroundStyle(item.label.hasPrefix("Past") ? Theme.red : Theme.secondary)
                    }
                    Spacer(minLength: 6)
                    Text(IndianMoneyFormat.string(item.bill.amount)).monospacedDigit().font(.system(size: 15.5))
                    Button("Add") { billToAdd = item.bill.id }
                        .buttonStyle(AddPillStyle())
                        .accessibilityIdentifier("addUpcomingBillButton")
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("upcomingRow")
            }
        }
    }

    @ViewBuilder private var upcomingActions: some View {
        if upcomingKind == .expenses { upcomingExpenseActions } else { upcomingIncomeActions }
    }

    private var upcomingIncomeActions: some View {
        VStack(spacing: 0) {
            Button("Create Income") { addingScheme = true }.buttonStyle(PrimaryButtonStyle()).padding(.vertical, 8)
                .accessibilityIdentifier("createIncomeButton")
            Button("Add Several at Once") { addingSeveralPayouts = true }.buttonStyle(GreyButtonStyle()).padding(.vertical, 8)
                .accessibilityIdentifier("addSeveralIncomeButton")
            upcomingFilterButton
        }
    }

    private var upcomingFilterButton: some View {
        Button("Edit upcoming bill filters") { editingFilters = true }.buttonStyle(GreyButtonStyle()).padding(.vertical, 8)
            .accessibilityIdentifier("editUpcomingFiltersButton")
    }

    @ViewBuilder private var upcomingExpenseActions: some View {
        let automatic = model.bills.filter { $0.bill.addAutomatically && !$0.isEnded }.map(\.bill.name)
        if !automatic.isEmpty {
            Text("\(ListFormatter.localizedString(byJoining: automatic)) add\(automatic.count == 1 ? "s itself" : " themselves") on \(automatic.count == 1 ? "its" : "their") day, so \(automatic.count == 1 ? "it is" : "they are") not listed here.")
                .font(.footnote).foregroundStyle(Theme.secondary).padding(.horizontal, 10)
                .accessibilityIdentifier("automaticBillsNote")
        }
        VStack(spacing: 0) {
            Button("Create Bill") { addingBill = true }.buttonStyle(PrimaryButtonStyle()).padding(.vertical, 8)
                .accessibilityIdentifier("createBillButton")
            Button("Add Several at Once") { addingSeveral = true }.buttonStyle(GreyButtonStyle()).padding(.vertical, 8)
                .accessibilityIdentifier("addSeveralButton")
            upcomingFilterButton
        }
    }

    // MARK: Savings

    /// The savings bank balance stays hidden until Face ID says otherwise; the rest of this pane follows Hide Balances.
    /// Hiding is instant; showing needs Face ID, like the Portfolio and Savings eyes.
    private func toggleRevealed() {
        guard !revealed else { revealed = false; return }
        Task {
            if await PrivacyGate.authenticate(reason: "Show your amounts") {
                revealed = true
                authMessage = nil
            } else {
                authMessage = "Try Again"
            }
        }
    }

    @ViewBuilder private var savingsCard: some View {
        HStack {
            CardCaption("Savings bank balance")
            Spacer()
            if model.preferences.hideBalances {
            Button(savingsShown ? "Hide" : "Show with Face ID", systemImage: savingsShown ? "eye.slash" : "eye") {
                guard !savingsRevealed else { savingsRevealed = false; return }
                Task {
                    if await PrivacyGate.authenticate(reason: "Show your savings bank balance") {
                        savingsRevealed = true
                        authMessage = nil
                    } else {
                        authMessage = "Try Again"
                    }
                }
            }
            .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(Theme.secondary)
            .accessibilityLabel(savingsShown ? "Hide savings balance" : "Show savings balance")
            .accessibilityIdentifier("savingsEyeButton")
            }
        }
        Text(savingsShown ? IndianMoneyFormat.string(model.portfolio?.bankBalance ?? .zero) : "₹ ••••••")
            .font(.system(size: 42, weight: .bold)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
            .accessibilityIdentifier("savingsBalance")
        if let authMessage { Text(authMessage).foregroundStyle(Theme.red).accessibilityIdentifier("savingsAuthMessage") }
        if savingsShown, let asOf = model.portfolio?.bankBalanceAsOf {
            Text("Set by you · as of \(asOf.shortTitle)").font(.footnote).foregroundStyle(Theme.secondary)
        }
    }

    @ViewBuilder private func savingsRest(_ budget: MonthBudget) -> some View {
        CardGroup {
            if savingsShown {
                LinkRow(title: "Ledgers", subtitle: model.ledgers?.ledgers.map(\.ledger.name).joined(separator: ", "),
                        value: IndianMoneyFormat.string(model.ledgers?.total ?? .zero)) { LedgersScreen(model: model) }
                LinkRow(title: "Cash in hand", value: IndianMoneyFormat.string(model.cash?.balance ?? .zero)) {
                    CashInHandScreen(model: model)
                }
                LinkRow(title: "Amount to repay", value: IndianMoneyFormat.string(model.amountToRepay?.total ?? .zero)) {
                    AmountToRepayScreen(model: model)
                }
            } else {
                // Locked until the eye is used: no figures and no way into the screens behind them.
                ForEach(["Ledgers", "Cash in hand", "Amount to repay"], id: \.self) { title in
                    CardRow(title: title) { Text("₹ ••••").foregroundStyle(Theme.secondary) }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(title)
                }
            }
        }
        CardPanel {
            HStack(alignment: .top) {
                figure("Income", budget.incomeThisMonth, id: "savingsIncome")
                figure("Expenses", budget.spentThisMonth, id: "savingsExpenses")
                figure("Cash flow", budget.incomeThisMonth - budget.spentThisMonth, id: "savingsCashFlow", signed: true)
            }
        }
    }

    private func figure(_ title: String, _ money: Money, id: String, signed: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(savingsShown ? IndianMoneyFormat.string(money) : "₹ ••••")
                .font(.system(size: 19, weight: .bold)).monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                .foregroundStyle(signed && savingsShown && money < .zero ? Theme.red : Color.primary)
                .accessibilityIdentifier(id)
            CardCaption(title)
        }
        .frame(maxWidth: .infinity)
    }
}

enum UpcomingKind: String, CaseIterable {
    case expenses = "Expenses", income = "Income"
}

enum ActivityPane: String, CaseIterable {
    case spending = "Spending"
    case upcoming = "Upcoming"
    case savings = "Savings"
}

/// What the Spending pane lists below its summary card.
enum ActivityView: String, CaseIterable {
    case expenses = "Expenses"
    case income = "Income"
    case calendar = "Calendar"
}

/// How the Upcoming window reads, from its number of days.
enum UpcomingWindow {
    static let choices = [0, 2, 3, 5, 7, 14, 30]

    static func title(_ days: Int) -> String {
        switch days {
        case 0: "Due today"
        case 7: "Due within 1 week"
        case 14: "Due within 2 weeks"
        default: "Due within \(days) days"
        }
    }

    static func caption(_ days: Int) -> String {
        switch days {
        case 0: "today"
        case 7: "next week"
        case 14: "next 2 weeks"
        default: "next \(days) days"
        }
    }

    static func phrase(_ days: Int) -> String {
        switch days {
        case 0: "today"
        case 7: "in the next week"
        case 14: "in the next 2 weeks"
        default: "in the next \(days) days"
        }
    }
}

/// Mockup 1: what was spent on each day of the viewed month.
private struct MonthCalendarCard: View {
    let budget: MonthBudget
    let hideEarned: Bool

    var body: some View {
        CardPanel(padding: 14) {
            Text(budget.month.title).font(.system(size: 20, weight: .bold)).padding(.horizontal, 4)
            Text("Red is spent, green is earned").font(.footnote).foregroundStyle(Theme.secondary).padding(.horizontal, 4)
            CalendarGrid(month: budget.month) { day in
                VStack(spacing: 1) {
                    Text("\(day)").font(.system(size: 13))
                    if let earned = budget.earnedByDay[day] {
                        Text(hideEarned ? "+••••" : "+" + IndianMoneyFormat.compact(earned)).font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.green).minimumScaleFactor(0.6).lineLimit(1)
                    }
                    if let spent = budget.spentByDay[day] {
                        Text("-" + IndianMoneyFormat.compact(spent)).font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.red).minimumScaleFactor(0.6).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.tile, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("spentDay-\(day)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthCalendar")
    }
}

/// Seven columns starting on Sunday, with blanks before day 1. Not lazy, so every day exists for VoiceOver and tests.
struct CalendarGrid<Day: View>: View {
    let month: CalendarDate.YearMonth
    @ViewBuilder let day: (Int) -> Day

    private let names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    var body: some View {
        let cells = Array(repeating: 0, count: month.firstWeekday) + Array(1...month.dayCount)
        let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0 ..< min($0 + 7, cells.count)]) }
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(names, id: \.self) {
                    Text($0).font(.system(size: 11)).foregroundStyle(Theme.secondary).frame(maxWidth: .infinity)
                }
            }
            ForEach(weeks.indices, id: \.self) { week in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { column in
                        let date = column < weeks[week].count ? weeks[week][column] : 0
                        if date == 0 { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) } else { day(date).frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }
}

private struct IncomeRow: View {
    let entry: IncomeEntry

    var body: some View {
        CardRow(title: entry.kind.title, subtitle: [entry.note.isEmpty ? nil : entry.note, entry.date.shortTitle].compactMap { $0 }.joined(separator: " · ")) {
            Text(IndianMoneyFormat.string(entry.amount)).monospacedDigit()
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    var foreignText: String?

    var body: some View {
        CardRow(
            title: expense.description,
            subtitle: [expense.subCategory ?? expense.category, expense.date.shortTitle].compactMap { $0 }.joined(separator: " · ")
        ) {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 0) {
                    if case .pending = expense.refund { StatusPill(text: "Pending", tone: .orange) }
                    Text(IndianMoneyFormat.string(expense.amount)).monospacedDigit().padding(.leading, 6)
                }
                if let foreignText { Text(foreignText).font(.footnote).foregroundStyle(Theme.secondary) }
                if case .settled = expense.refund {
                    Text("Net \(IndianMoneyFormat.string(expense.netAmount))").font(.footnote).foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}

extension IncomeEntry: @retroactive Identifiable {}
extension BillToSend: @retroactive Identifiable {
    public var id: Int64 { occurrenceID }
}

extension Int64: @retroactive Identifiable {
    public var id: Int64 { self }
}
