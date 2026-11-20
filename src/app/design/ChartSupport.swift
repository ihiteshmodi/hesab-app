import Charts
import HisaabCore
import SwiftUI

/// Rupees as a plain number for a chart axis.
func chartValue(_ money: Money) -> Double { Double(money.paise) / 100 }

/// "1.2L", "45k", "800": short enough for a chart axis.
func compactRupees(_ value: Double) -> String {
    let magnitude = abs(value)
    let sign = value < 0 ? "−" : ""
    if magnitude >= 10_000_000 { return "\(sign)\(trimmed(magnitude / 10_000_000))Cr" }
    if magnitude >= 100_000 { return "\(sign)\(trimmed(magnitude / 100_000))L" }
    if magnitude >= 1_000 { return "\(sign)\(trimmed(magnitude / 1_000))k" }
    return "\(sign)\(Int(magnitude))"
}

private func trimmed(_ value: Double) -> String {
    let text = String(format: "%.1f", value)
    return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
}

/// "+12.5%" or "−3.0%" from tenths of a percent.
func percentText(tenths: Int, signed: Bool = true) -> String {
    let sign = tenths > 0 && signed ? "+" : tenths < 0 ? "−" : ""
    return "\(sign)\(String(format: "%.1f", Double(abs(tenths)) / 10))%"
}

/// The gain or loss colour: green up, red down, grey when flat.
func gainColour(_ money: Money) -> Color {
    money > .zero ? Theme.green : money < .zero ? Theme.red : Theme.secondary
}

extension View {
    /// The y-axis every chart here uses: faint lines and short labels, or nothing when amounts are hidden.
    func moneyYAxis(hidden: Bool = false) -> some View {
        chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.2))
                if !hidden, let number = value.as(Double.self) {
                    AxisValueLabel { Text(compactRupees(number)).font(.system(size: 10)) }
                }
            }
        }
    }
}
