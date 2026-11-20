import HisaabCore
import SwiftUI

/// One investment: what it is worth, whether it is up or down since it was bought, and the money added over time.
struct HoldingDetailScreen: View {
    let model: BudgetViewModel
    let holdingID: Int64
    let hidden: Bool
    @State private var editing: Holding?
    @State private var addingMoney: Holding?
    @State private var updatingWorth: Holding?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let detail = model.holdingDetail(holdingID) {
                CardScreen {
                    summary(detail)
                    instalment(detail)
                    facts(detail)
                    HoldingHistoryChart(points: detail.history)
                    additions(detail)
                    Button("Update Worth") { updatingWorth = detail.holding }
                        .buttonStyle(GreyButtonStyle()).accessibilityIdentifier("holdingUpdateWorthButton")
                    if detail.holding.invested != nil {
                        Button(detail.holding.kind == .sip ? "Add Instalment" : "Add Money") { addingMoney = detail.holding }
                            .buttonStyle(GreyButtonStyle()).accessibilityIdentifier("holdingAddMoneyButton")
                    }
                }
                .cardNavigation(detail.holding.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { editing = detail.holding }.accessibilityIdentifier("holdingEditButton")
                    }
                }
                .sheet(item: $editing) { HoldingSheet(model: model, editing: $0) }
                .sheet(item: $addingMoney) { AddMoneySheet(model: model, holding: $0) }
                .sheet(item: $updatingWorth) { UpdateWorthSheet(model: model, holding: $0) }
            } else {
                Text("That investment no longer exists.").foregroundStyle(Theme.secondary)
            }
        }
    }

    private func amount(_ money: Money, _ holding: Holding) -> String {
        if hidden { return "••••••" }
        return holding.currency.map { "\($0) \(IndianMoneyFormat.plain(money))" } ?? IndianMoneyFormat.string(money)
    }

    private func signed(_ money: Money, _ holding: Holding) -> String {
        (money > .zero ? "+" : money < .zero ? "−" : "") + amount(money < .zero ? .zero - money : money, holding)
    }

    @ViewBuilder private func summary(_ detail: HoldingDetail) -> some View {
        let holding = detail.holding
        CardPanel {
            CardCaption("Worth today")
            Text(amount(holding.amount, holding)).font(.system(size: 34, weight: .bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6).accessibilityIdentifier("holdingWorth")
            if holding.currency != nil, !hidden {
                Text("≈ \(IndianMoneyFormat.string(detail.line.valueInHome))").font(.footnote).foregroundStyle(Theme.secondary)
            }
            if let gain = holding.gain {
                let colour = gainColour(gain)
                HStack(spacing: 8) {
                    Image(systemName: gain > .zero ? "arrow.up.right" : gain < .zero ? "arrow.down.right" : "equal")
                    Text(gain > .zero ? "Up" : gain < .zero ? "Down" : "Level")
                    Text(signed(gain, holding)).monospacedDigit()
                    if let tenths = holding.gainPercentTenths { Text("· \(percentText(tenths: tenths))") }
                }
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(colour)
                .padding(.vertical, 6).padding(.horizontal, 12)
                .background(colour.opacity(0.12), in: Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("holdingGainPill")
            } else {
                Text("Fill in what you paid (Edit) to see whether it is up or down.").font(.footnote).foregroundStyle(Theme.secondary)
            }
        }
    }

    /// For a SIP: what goes out and when, and a one-tap add once this month's instalment is due.
    @ViewBuilder private func instalment(_ detail: HoldingDetail) -> some View {
        let holding = detail.holding
        if holding.kind == .sip, let instalment = holding.sipAmount, let day = holding.sipDay, let next = detail.nextInstalment {
            CardGroup(header: "SIP") {
                CardRow(title: "Monthly instalment", subtitle: "goes out on the \(day)\(Self.ordinal(day))") {
                    Text(amount(instalment, holding)).monospacedDigit()
                }
                if detail.instalmentDue {
                    Button { errorMessage = model.addToHolding(holding.id, amountText: IndianMoneyFormat.plain(instalment), on: next) } label: {
                        Text("Add \(amount(instalment, holding)) for \(next.monthName)").foregroundStyle(Theme.blue).rowPadding()
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("addInstalmentButton")
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding() }
                } else {
                    CardRow(title: "Next instalment") { Text(next.shortTitleWithYear).foregroundStyle(Theme.secondary) }
                }
            }
        }
    }

    static func ordinal(_ day: Int) -> String {
        (11...13).contains(day % 100) ? "th" : ["th", "st", "nd", "rd"][day % 10 < 4 ? day % 10 : 0]
    }

    @ViewBuilder private func facts(_ detail: HoldingDetail) -> some View {
        let holding = detail.holding
        CardGroup(header: "Details") {
            if let invested = holding.invested { CardRow(title: "You paid") { Text(amount(invested, holding)).monospacedDigit() } }
            CardRow(title: "Bought on") {
                Text(holding.investedOn.map(\.shortTitleWithYear) ?? "Not set").foregroundStyle(Theme.secondary)
            }
            if let days = detail.daysHeld { CardRow(title: "Held for") { Text(Self.heldText(days)).foregroundStyle(Theme.secondary) } }
            if let yearly = detail.yearlyGrowthTenths {
                CardRow(title: "Grows about", subtitle: "a year, on average") {
                    Text(percentText(tenths: yearly)).foregroundStyle(yearly >= 0 ? Theme.green : Theme.red).monospacedDigit()
                }
            }
        }
    }

    @ViewBuilder private func additions(_ detail: HoldingDetail) -> some View {
        let holding = detail.holding
        if let bought = detail.boughtAmount {
            CardGroup(header: "Money in", footer: detail.contributions.isEmpty ? "Add Money records a SIP instalment or a top-up." : nil) {
                CardRow(title: "Bought", subtitle: holding.investedOn?.shortTitleWithYear) {
                    Text(amount(bought, holding)).monospacedDigit()
                }
                ForEach(detail.contributions, id: \.id) { contribution in
                    CardRow(title: "Added", subtitle: contribution.date.shortTitleWithYear) {
                        Text(amount(contribution.amount, holding)).monospacedDigit()
                    }
                }
            }
        }
    }

    /// "2 years 3 months", "5 months", "12 days".
    static func heldText(_ days: Int) -> String {
        let years = days / 365
        let months = (days % 365) / 30
        if years > 0 { return "\(years) year\(years == 1 ? "" : "s")" + (months > 0 ? " \(months) month\(months == 1 ? "" : "s")" : "") }
        if months > 0 { return "\(months) month\(months == 1 ? "" : "s")" }
        return "\(days) day\(days == 1 ? "" : "s")"
    }
}

/// The quick update: type what it is worth today.
struct UpdateWorthSheet: View {
    let model: BudgetViewModel
    let holding: Holding
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "Only what it is worth changes. The new value is added to the line on the page.") {
                    CardRow(title: holding.name) { Text(IndianMoneyFormat.plain(holding.amount)).foregroundStyle(Theme.secondary) }
                    TextField("Worth today", text: $amountText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("updateWorthField")
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding() }
                }
            }
            .cardNavigation("Update Worth")
            .onAppear { if amountText.isEmpty { amountText = IndianMoneyFormat.plain(holding.amount) } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.updateHoldingWorth(holding.id, amountText: amountText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveWorthButton")
                }
            }
        }
    }
}

extension CalendarDate {
    /// "November".
    var monthName: String {
        ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][month - 1]
    }

    /// "20 Nov 2025".
    var shortTitleWithYear: String { "\(shortTitle) \(year)" }
}
