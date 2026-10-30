import HisaabCore
import SwiftUI

struct BudgetScreen: View {
    let model: BudgetViewModel
    @State private var addingExpense = false
    @State private var addingIncome = false
    @State private var openedExpense: Int64?
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            List {
                if let loadError = model.loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                if let budget = model.budget {
                    if !model.notices.isEmpty {
                        Section {
                            ForEach(model.notices, id: \.self) { notice in
                                Text(notice).accessibilityIdentifier("autoNotice")
                            }
                            Button("Dismiss") { model.dismissNotices() }
                        }
                    }
                    Section {
                        LeftToSpendCard(budget: budget)
                        HStack {
                            Button("Previous Month", systemImage: "chevron.left") {
                                model.showMonth(budget.month.shifted(by: -1))
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("previousMonthButton")
                            Spacer()
                            Text(budget.month.title).font(.headline)
                                .accessibilityIdentifier("monthTitle")
                            Spacer()
                            Button("Next Month", systemImage: "chevron.right") {
                                model.showMonth(budget.month.shifted(by: 1))
                            }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("nextMonthButton")
                        }
                        .buttonStyle(.borderless)
                    }
                    if budget.hasNoEntriesAtAll {
                        Text("No entries yet. Add your first expense or income.")
                            .foregroundStyle(.secondary)
                    }
                    if !budget.incomeEntries.isEmpty {
                        Section("Income") {
                            ForEach(budget.incomeEntries, id: \.id) { entry in
                                IncomeRow(entry: entry)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityIdentifier("incomeRow")
                                    .swipeActions {
                                        Button("Delete", role: .destructive) { errorMessage = model.deleteIncome(entry.id) }
                                    }
                            }
                        }
                    }
                    Section("Expenses") {
                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                        ForEach(budget.expenses, id: \.id) { expense in
                            Button { openedExpense = expense.id } label: { ExpenseRow(expense: expense, foreignText: expense.foreign.map(model.text)) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("expenseRow")
                        }
                    }
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        MoreScreen(model: model)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
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
                    .accessibilityIdentifier("addMenu")
                }
            }
            .sheet(isPresented: $addingExpense) {
                NewExpenseSheet(model: model)
            }
            .sheet(isPresented: $addingIncome) {
                NewIncomeSheet(model: model)
            }
            .sheet(item: $openedExpense) { id in
                ExpenseDetailSheet(model: model, expenseID: id)
            }
        }
    }
}

private struct LeftToSpendCard: View {
    let budget: MonthBudget

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Left to spend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IndianMoneyFormat.string(budget.leftToSpend))
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(budget.leftToSpend < .zero ? Color.red : Color.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityIdentifier("leftToSpend")
            Divider()
            Text("Spent this month")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(IndianMoneyFormat.string(budget.spentThisMonth))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("spentThisMonth")
            Text("Income this month")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(IndianMoneyFormat.string(budget.incomeThisMonth))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier("incomeThisMonth")
        }
        .padding(.vertical, 6)
    }
}

private struct IncomeRow: View {
    let entry: IncomeEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind.title)
                Text([entry.note.nilIfEmpty, entry.date.shortTitle].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(IndianMoneyFormat.string(entry.amount)).monospacedDigit()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private struct ExpenseRow: View {
    let expense: Expense
    var foreignText: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                Text([expense.subCategory ?? expense.category, expense.entity, expense.date.shortTitle]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(IndianMoneyFormat.string(expense.amount))
                    .monospacedDigit()
                if let foreignText {
                    Text(foreignText).font(.footnote).foregroundStyle(.secondary)
                }
                switch expense.refund {
                case .notRefundable: EmptyView()
                case .pending: Text("Pending refund").font(.footnote).foregroundStyle(.orange)
                case .settled: Text("Net \(IndianMoneyFormat.string(expense.netAmount))").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

extension Int64: @retroactive Identifiable {
    public var id: Int64 { self }
}
