import Charts
import HisaabCore
import SwiftUI

struct ReportsScreen: View {
    let model: BudgetViewModel
    /// Keep only the rows (and, inside a row, the expenses) that make up this share of the spending.
    @State private var topPercent = 100.0

    var body: some View {
        NavigationStack {
            let report = model.report
            let top = report.top(percent: Int(topPercent))
            CardScreen {
                CardPanel {
                    FieldRow("Group by") {
                        Picker("Group by", selection: Binding(
                            get: { model.reportGrouping },
                            set: { model.showReport(grouping: $0, month: model.reportMonth, allTime: model.reportAllTime) }
                        )) {
                            ForEach(BreakdownGrouping.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                    }
                    .accessibilityIdentifier("groupingPicker")
                    HStack {
                        Button("Previous Month", systemImage: "chevron.left") { move(-1) }
                            .labelStyle(.iconOnly).disabled(model.reportAllTime)
                            .accessibilityIdentifier("previousReportMonth")
                        Spacer()
                        Text(model.reportAllTime ? "All Time" : model.reportMonth.title).font(.headline)
                        Spacer()
                        Button("Next Month", systemImage: "chevron.right") { move(1) }
                            .labelStyle(.iconOnly).disabled(model.reportAllTime)
                            .accessibilityIdentifier("nextReportMonth")
                    }
                    .buttonStyle(.borderless)
                    .padding(.vertical, 6)
                    Toggle("All Time", isOn: Binding(
                        get: { model.reportAllTime },
                        set: { model.showReport(grouping: model.reportGrouping, month: model.reportMonth, allTime: $0) }
                    ))
                    .accessibilityIdentifier("allTimeToggle")
                    if report.isEmpty {
                        Text("No spending in \(model.reportAllTime ? "this period" : monthName).")
                            .foregroundStyle(Theme.secondary)
                            .padding(.top, 6)
                            .accessibilityIdentifier("noSpending")
                    } else {
                        // The list below names every slice, so the chart carries no legend of its own.
                        Chart(top.rows, id: \.name) { row in
                            SectorMark(angle: .value("Amount", Double(row.amount.paise) / 100), innerRadius: .ratio(0.6))
                                .foregroundStyle(by: .value("Name", row.name))
                        }
                        .chartLegend(.hidden)
                        .frame(height: 200)
                        .padding(.vertical, 8)
                        TopShareSlider(percent: $topPercent)
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Total spent").fontWeight(.semibold)
                                Text("Expenses after refunds. Income is not included.")
                                    .font(.footnote).foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            Text(IndianMoneyFormat.string(report.total)).monospacedDigit().fontWeight(.semibold)
                                .accessibilityIdentifier("reportTotal")
                        }
                    }
                }
                if !report.isEmpty {
                    CardGroup(footer: model.reportGrouping == .tag
                              ? "An expense with two tags is counted under both, so the rows can add up to more than the total." : nil) {
                        ForEach(top.rows, id: \.name) { row in
                            NavigationLink {
                                GroupReportScreen(model: model, grouping: model.reportGrouping, name: row.name, topPercent: $topPercent)
                            } label: { ReportLine(name: row.name, share: row.sharePercent, amount: row.amount, chevron: true) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("reportRow")
                        }
                        if top.rest > .zero {
                            ReportLine(name: "Everything else", share: nil, amount: top.rest, chevron: false)
                                .foregroundStyle(Theme.secondary)
                                .accessibilityIdentifier("reportRestRow")
                        }
                    }
                }
            }
            .cardNavigation("Reports")
        }
    }

    private var monthName: String { String(model.reportMonth.title.split(separator: " ").first ?? "") }

    private func move(_ delta: Int) {
        model.showReport(grouping: model.reportGrouping, month: model.reportMonth.shifted(by: delta), allTime: false)
    }
}

private struct TopShareSlider: View {
    @Binding var percent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(percent >= 100 ? "Showing everything" : "Showing what makes up the top \(Int(percent))% of spending")
                .font(.footnote).foregroundStyle(Theme.secondary)
            Slider(value: $percent, in: 10...100, step: 10)
                .accessibilityLabel("Top share")
                .accessibilityValue("\(Int(percent)) percent")
                .accessibilityIdentifier("topShareSlider")
        }
    }
}

private struct ReportLine: View {
    let name: String
    let share: Int?
    let amount: Money
    let chevron: Bool

    var body: some View {
        CardRow(title: name) {
            if let share { Text("\(share)%").foregroundStyle(Theme.secondary) }
            Text(IndianMoneyFormat.string(amount)).monospacedDigit()
            if chevron { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
        }
    }
}

/// One row of a report opened: its split (sub-categories, or categories) and the expenses behind it, each one editable.
struct GroupReportScreen: View {
    let model: BudgetViewModel
    let grouping: BreakdownGrouping
    let name: String
    @Binding var topPercent: Double
    @State private var openedExpense: Int64?

    var body: some View {
        CardScreen {
            if let detail = model.groupBreakdown(grouping, name) {
                CardPanel {
                    TopShareSlider(percent: $topPercent)
                    HStack {
                        Text("Total spent").fontWeight(.semibold)
                        Spacer()
                        Text(IndianMoneyFormat.string(detail.total)).monospacedDigit().fontWeight(.semibold)
                    }
                }
                CardGroup(header: grouping == .category ? "Sub-categories" : "Categories") {
                    ForEach(detail.rows, id: \.name) { row in
                        ReportLine(name: row.name, share: row.sharePercent, amount: row.amount, chevron: false)
                    }
                }
                let shown = detail.topExpenses(percent: Int(topPercent))
                CardGroup(header: topPercent >= 100 ? "Expenses, newest first" : "Biggest expenses making up \(Int(topPercent))%",
                          footer: "Tap an expense to see or change it.") {
                    ForEach(shown.sorted { ($0.date, $0.id ?? 0) > ($1.date, $1.id ?? 0) }, id: \.id) { expense in
                        Button { openedExpense = expense.id } label: {
                            CardRow(title: expense.description, subtitle: subtitle(expense)) {
                                Text(IndianMoneyFormat.string(expense.netAmount)).monospacedDigit()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("reportExpenseRow")
                    }
                }
            }
        }
        .cardNavigation(name)
        .sheet(item: $openedExpense) { id in ExpenseDetailSheet(model: model, expenseID: id) }
    }

    private func subtitle(_ expense: Expense) -> String {
        var parts = [expense.date.shortTitle]
        if grouping != .category { parts.append(expense.category) }
        if grouping != .entity, let entity = expense.entity { parts.append(entity) }
        return parts.joined(separator: " · ")
    }
}
