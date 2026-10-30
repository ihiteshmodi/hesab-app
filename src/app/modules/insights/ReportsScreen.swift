import Charts
import HisaabCore
import SwiftUI

struct ReportsScreen: View {
    let model: BudgetViewModel

    var body: some View {
        NavigationStack {
            let report = model.report
            List {
                Section {
                    Picker("Group by", selection: Binding(
                        get: { model.reportGrouping },
                        set: { model.showReport(grouping: $0, month: model.reportMonth, allTime: model.reportAllTime) }
                    )) {
                        Text("Category").tag(BreakdownGrouping.category)
                        Text("Payment Method").tag(BreakdownGrouping.paymentMethod)
                        Text("Entity").tag(BreakdownGrouping.entity)
                    }
                    .pickerStyle(.segmented)
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
                    Toggle("All Time", isOn: Binding(
                        get: { model.reportAllTime },
                        set: { model.showReport(grouping: model.reportGrouping, month: model.reportMonth, allTime: $0) }
                    ))
                    .accessibilityIdentifier("allTimeToggle")
                }
                if report.isEmpty {
                    Text("No spending in \(model.reportAllTime ? "this period" : monthName).")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("noSpending")
                } else {
                    Section {
                        Chart(report.rows, id: \.name) { row in
                            SectorMark(angle: .value("Amount", Double(row.amount.paise) / 100), innerRadius: .ratio(0.6))
                                .foregroundStyle(by: .value("Name", row.name))
                        }
                        .frame(height: 200)
                        HStack {
                            Text("Total")
                            Spacer()
                            Text(IndianMoneyFormat.string(report.total)).monospacedDigit()
                                .accessibilityIdentifier("reportTotal")
                        }
                    }
                    Section {
                        ForEach(report.rows, id: \.name) { row in
                            if model.reportGrouping == .category {
                                NavigationLink {
                                    CategoryReportScreen(model: model, category: row.name)
                                } label: { line(row) }
                                .accessibilityIdentifier("reportRow")
                            } else {
                                line(row).accessibilityIdentifier("reportRow")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reports")
        }
    }

    private var monthName: String { String(model.reportMonth.title.split(separator: " ").first ?? "") }

    private func line(_ row: BreakdownRow) -> some View {
        HStack {
            Text(row.name)
            Spacer()
            Text("\(row.sharePercent)%").foregroundStyle(.secondary)
            Text(IndianMoneyFormat.string(row.amount)).monospacedDigit()
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
        List {
            if let detail = model.categoryBreakdown(category) {
                Section("Sub-categories") {
                    ForEach(detail.rows, id: \.name) { row in
                        HStack {
                            Text(row.name)
                            Spacer()
                            Text(IndianMoneyFormat.string(row.amount)).monospacedDigit()
                        }
                    }
                }
                Section("Expenses") {
                    ForEach(detail.expenses, id: \.id) { expense in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(expense.description)
                                Text(expense.date.shortTitle).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(IndianMoneyFormat.string(expense.netAmount)).monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle(category)
    }
}
