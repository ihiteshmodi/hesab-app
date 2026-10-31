import Charts
import HisaabCore
import SwiftUI

struct ReportsScreen: View {
    let model: BudgetViewModel

    var body: some View {
        NavigationStack {
            let report = model.report
            CardScreen {
                CardPanel {
                    PillSegments(selection: Binding(
                        get: { model.reportGrouping },
                        set: { model.showReport(grouping: $0, month: model.reportMonth, allTime: model.reportAllTime) }
                    ), options: [(BreakdownGrouping.category, "Category"), (.paymentMethod, "Payment"), (.entity, "Entity")])
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
                        Chart(report.rows, id: \.name) { row in
                            SectorMark(angle: .value("Amount", Double(row.amount.paise) / 100), innerRadius: .ratio(0.6))
                                .foregroundStyle(by: .value("Name", row.name))
                        }
                        .frame(height: 200)
                        .padding(.vertical, 8)
                        HStack {
                            Text("Total").fontWeight(.semibold)
                            Spacer()
                            Text(IndianMoneyFormat.string(report.total)).monospacedDigit().fontWeight(.semibold)
                                .accessibilityIdentifier("reportTotal")
                        }
                    }
                }
                if !report.isEmpty {
                    CardGroup {
                        ForEach(report.rows, id: \.name) { row in
                            if model.reportGrouping == .category {
                                NavigationLink {
                                    CategoryReportScreen(model: model, category: row.name)
                                } label: { line(row, chevron: true) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("reportRow")
                            } else {
                                line(row).accessibilityIdentifier("reportRow")
                            }
                        }
                    }
                }
            }
            .cardNavigation("Reports")
        }
    }

    private var monthName: String { String(model.reportMonth.title.split(separator: " ").first ?? "") }

    private func line(_ row: BreakdownRow, chevron: Bool = false) -> some View {
        CardRow(title: row.name) {
            Text("\(row.sharePercent)%").foregroundStyle(Theme.secondary)
            Text(IndianMoneyFormat.string(row.amount)).monospacedDigit()
            if chevron { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
        }
    }

    private func move(_ delta: Int) {
        model.showReport(grouping: model.reportGrouping, month: model.reportMonth.shifted(by: delta), allTime: false)
    }
}

struct CategoryReportScreen: View {
    let model: BudgetViewModel
    let category: String

    var body: some View {
        CardScreen {
            if let detail = model.categoryBreakdown(category) {
                CardGroup(header: "Sub-categories") {
                    ForEach(detail.rows, id: \.name) { row in
                        CardRow(title: row.name) { Text(IndianMoneyFormat.string(row.amount)).monospacedDigit() }
                    }
                }
                CardGroup(header: "Expenses") {
                    ForEach(detail.expenses, id: \.id) { expense in
                        CardRow(title: expense.description, subtitle: expense.date.shortTitle) {
                            Text(IndianMoneyFormat.string(expense.netAmount)).monospacedDigit()
                        }
                    }
                }
            }
        }
        .cardNavigation(category)
    }
}
