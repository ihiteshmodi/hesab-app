import Charts
import HisaabCore
import SwiftUI

/// The Trends side of Reports: this month against last, income against spent, and what differs from usual.
struct TrendsPane: View {
    let model: BudgetViewModel

    private var hideAmounts: Bool { model.preferences.hideBalances }

    var body: some View {
        if let pace = model.spendingPace { PaceCard(pace: pace) }
        IncomeVersusSpentCard(trend: model.monthlyTrend, hideAmounts: hideAmounts)
        VersusNormalCard(normal: model.vsNormal)
    }
}

private struct PaceCard: View {
    let pace: SpendingPace

    private var difference: Money { pace.difference }

    var body: some View {
        CardPanel {
            CardCaption("Spent so far · \(pace.month.title)")
            Text(IndianMoneyFormat.string(pace.thisMonth.last ?? .zero)).font(.system(size: 30, weight: .bold)).monospacedDigit()
                .accessibilityIdentifier("paceTotal")
            if pace.upToDay > 0 {
                Text(sentence).font(.footnote).foregroundStyle(difference > .zero ? Theme.red : Theme.green)
                    .accessibilityIdentifier("paceSentence")
            }
            HStack(spacing: 14) {
                legend(Theme.blue, pace.month.title.split(separator: " ").first.map(String.init) ?? "This month")
                legend(.gray, pace.month.shifted(by: -1).title.split(separator: " ").first.map(String.init) ?? "Last month")
            }
            .font(.caption).foregroundStyle(Theme.secondary)
            Chart {
                ForEach(Array(pace.lastMonth.enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("Day", index + 1), y: .value("Spent", chartValue(value)), series: .value("Month", "Last"))
                        .foregroundStyle(.gray.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
                ForEach(Array(pace.thisMonth.enumerated()), id: \.offset) { index, value in
                    LineMark(x: .value("Day", index + 1), y: .value("Spent", chartValue(value)), series: .value("Month", "This"))
                        .foregroundStyle(Theme.blue).lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .chartXScale(domain: 1...31)
            .chartXAxis { AxisMarks(values: [1, 10, 20, 31]) }
            .moneyYAxis()
            .frame(height: 160)
            .accessibilityIdentifier("paceChart")
        }
    }

    private var sentence: String {
        let amount = IndianMoneyFormat.string(difference < .zero ? .zero - difference : difference)
        if difference == .zero { return "The same as last month at this point" }
        return "\(amount) \(difference > .zero ? "more" : "less") than last month by day \(pace.upToDay)"
    }

    private func legend(_ colour: Color, _ text: String) -> some View {
        HStack(spacing: 5) { Circle().fill(colour).frame(width: 8, height: 8); Text(text) }
    }
}

private struct IncomeVersusSpentCard: View {
    let trend: [MonthTrend]
    let hideAmounts: Bool

    private func name(_ month: MonthTrend) -> String { String(month.month.title.split(separator: " ").first?.prefix(3) ?? "") }

    var body: some View {
        CardPanel {
            CardCaption("Income and spending, 6 months")
            HStack(spacing: 14) {
                dot(Theme.green, "Income")
                dot(Theme.red, "Spent")
            }
            .font(.caption).foregroundStyle(Theme.secondary)
            Chart {
                ForEach(trend, id: \.month) { month in
                    BarMark(x: .value("Month", name(month)), y: .value("Amount", chartValue(month.income)))
                        .position(by: .value("Kind", "Income")).foregroundStyle(Theme.green.opacity(month.isInProgress ? 0.45 : 1))
                    BarMark(x: .value("Month", name(month)), y: .value("Amount", chartValue(month.spent)))
                        .position(by: .value("Kind", "Spent")).foregroundStyle(Theme.red.opacity(month.isInProgress ? 0.45 : 1))
                }
            }
            .moneyYAxis(hidden: hideAmounts)
            .frame(height: 170)
            .accessibilityIdentifier("incomeSpentChart")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), alignment: .leading, spacing: 6) {
                ForEach(trend, id: \.month) { month in
                    HStack(spacing: 4) {
                        Text(name(month)).foregroundStyle(Theme.secondary)
                        if let rate = month.savingsRatePercent {
                            Text("\(rate)%").fontWeight(.semibold).foregroundStyle(rate >= 0 ? Theme.green : Theme.red)
                        } else {
                            Text(month.isInProgress ? "running" : "–").foregroundStyle(Theme.secondary)
                        }
                    }
                    .font(.footnote)
                }
            }
            Text("The percentage is the share of income kept.").font(.caption).foregroundStyle(Theme.secondary)
        }
    }

    private func dot(_ colour: Color, _ text: String) -> some View {
        HStack(spacing: 5) { Circle().fill(colour).frame(width: 8, height: 8); Text(text) }
    }
}

private struct VersusNormalCard: View {
    let normal: SpendingVsNormal

    var body: some View {
        CardPanel {
            CardCaption("Different from usual")
            if !normal.hasHistory {
                Text("Not enough history yet. This needs at least 3 earlier months.").foregroundStyle(Theme.secondary)
                    .accessibilityIdentifier("normalNoHistory")
            } else if normal.changes.isEmpty {
                Text("Nothing stands out this month.").foregroundStyle(Theme.secondary)
            } else {
                let biggest = normal.changes.map { max($0.thisMonth.paise, $0.usual.paise) }.max() ?? 1
                ForEach(normal.changes, id: \.category) { change in
                    let colour = change.difference > .zero ? Theme.red : Theme.green
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(change.category)
                            Spacer()
                            Text(signed(change.difference)).fontWeight(.semibold).foregroundStyle(colour).monospacedDigit()
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.25)).frame(width: geometry.size.width * share(change.usual, biggest))
                                Capsule().fill(colour).frame(width: geometry.size.width * share(change.thisMonth, biggest)).opacity(0.85)
                            }
                        }
                        .frame(height: 8)
                        Text("\(IndianMoneyFormat.string(change.thisMonth)) so far · usual \(IndianMoneyFormat.string(change.usual))")
                            .font(.caption).foregroundStyle(Theme.secondary)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("normalRow")
                }
                Text("Usual is your average for the same days in the 3 months before.").font(.caption).foregroundStyle(Theme.secondary)
            }
        }
    }

    private func share(_ money: Money, _ biggest: Int) -> CGFloat { CGFloat(money.paise) / CGFloat(max(biggest, 1)) }

    private func signed(_ money: Money) -> String {
        (money > .zero ? "+" : "") + IndianMoneyFormat.string(money)
    }
}

/// A tiny line for the last six months, red when this month is well above usual.
struct SparkLine: View {
    let trend: CategoryTrend

    var body: some View {
        let colour = trend.isRising ? Theme.red : Color.gray
        Chart {
            ForEach(Array(trend.values.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("Month", index), y: .value("Spent", chartValue(value))).foregroundStyle(colour)
            }
            if let last = trend.values.last {
                PointMark(x: .value("Month", trend.values.count - 1), y: .value("Spent", chartValue(last))).foregroundStyle(colour)
                    .symbolSize(24)
            }
        }
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .frame(width: 64, height: 22)
        .accessibilityHidden(true)
    }
}
