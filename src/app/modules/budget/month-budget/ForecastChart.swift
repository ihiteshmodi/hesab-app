import Charts
import HisaabCore
import SwiftUI

/// Where Left to spend is heading over the next 30 days, from the bills and payouts already set up.
struct ForecastChart: View {
    let forecast: CashForecast

    private var lowestDate: CalendarDate { CalendarDate(Date()).adding(days: forecast.lowestDay) }
    private var goesNegative: Bool { forecast.lowest < .zero }

    var body: some View {
        if forecast.billsOut > .zero || forecast.payoutsIn > .zero || forecast.dailySpend > .zero {
            VStack(alignment: .leading, spacing: 6) {
                CardCaption("Left to spend · next 30 days")
                Text(headline).font(.system(size: 15, weight: .semibold)).foregroundStyle(goesNegative ? Theme.red : Color.primary)
                    .accessibilityIdentifier("forecastHeadline")
                Chart {
                    ForEach(Array(forecast.points.enumerated()), id: \.offset) { day, value in
                        LineMark(x: .value("Day", day), y: .value("Left", chartValue(value)))
                            .foregroundStyle(goesNegative ? Theme.red : Theme.blue).interpolationMethod(.stepEnd)
                    }
                    if goesNegative { RuleMark(y: .value("Zero", 0)).foregroundStyle(Theme.red.opacity(0.5)) }
                    PointMark(x: .value("Day", forecast.lowestDay), y: .value("Left", chartValue(forecast.lowest)))
                        .foregroundStyle(goesNegative ? Theme.red : Theme.blue).symbolSize(40)
                }
                .chartXAxis { AxisMarks(values: [0, 10, 20, 30]) { value in
                    AxisValueLabel { if let day = value.as(Int.self) { Text(day == 0 ? "Today" : "+\(day)d").font(.system(size: 10)) } }
                } }
                .moneyYAxis()
                .frame(height: 140)
                .accessibilityIdentifier("forecastChart")
                Text("Bills out \(IndianMoneyFormat.string(forecast.billsOut)) · Payouts in \(IndianMoneyFormat.string(forecast.payoutsIn))"
                     + (forecast.dailySpend > .zero ? " · usual spending \(IndianMoneyFormat.string(forecast.dailySpend)) a day" : ""))
                    .font(.caption).foregroundStyle(Theme.secondary)
            }
            .padding(.bottom, 10)
        }
    }

    private var headline: String {
        if forecast.lowestDay == 0 { return "It only goes down from here: lowest is today at \(IndianMoneyFormat.string(forecast.lowest))" }
        let when = "around \(lowestDate.shortTitle)"
        return goesNegative
            ? "You could run short: \(IndianMoneyFormat.string(forecast.lowest)) \(when)"
            : "Lowest \(IndianMoneyFormat.string(forecast.lowest)) \(when)"
    }
}
