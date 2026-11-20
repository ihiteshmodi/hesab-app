import Charts
import HisaabCore
import SwiftUI

struct PortfolioScreen: View {
    let model: BudgetViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var revealed = false
    @State private var authMessage: String?
    @State private var settingBank = false
    @State private var addingHolding = false
    @State private var addingFund = false
    @State private var addingLedger = false
    @State private var editingHolding: Holding?
    @State private var addingMoneyTo: Holding?
    @State private var editingFund: AllocatedFund?
    @State private var errorMessage: String?

    private var hidden: Bool { model.preferences.hideBalances && !revealed }

    private func money(_ value: Money) -> String { hidden ? "••••••" : IndianMoneyFormat.string(value) }

    var body: some View {
        NavigationStack {
            CardScreen {
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal, 18) }
                if let authMessage {
                    Text(authMessage).foregroundStyle(Theme.red).padding(.horizontal, 18).accessibilityIdentifier("portfolioAuthMessage")
                }
                if let portfolio = model.portfolio {
                    CardPanel {
                        CardCaption("Net worth")
                        Text(money(portfolio.netWorth)).font(.system(size: 42, weight: .bold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .accessibilityIdentifier("netWorth")
                        if let warning = portfolio.warning, !hidden {
                            Text(warning).font(.footnote).foregroundStyle(Theme.orange).accessibilityIdentifier("portfolioWarning")
                        }
                        NetWorthChart(history: model.netWorthHistory, hidden: hidden)
                    }
                    CardGroup {
                        Button { settingBank = true } label: {
                            CardRow(title: "Bank balance",
                                    subtitle: portfolio.bankBalanceAsOf.map { "as of \($0.shortTitle) · tap to update" } ?? "tap to set") {
                                Text(money(portfolio.bankBalance)).monospacedDigit().accessibilityIdentifier("bankBalance")
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("setBankBalanceButton")
                        ForEach(model.ledgers?.ledgers ?? [], id: \.ledger.id) { summary in
                            LinkRow(
                                title: summary.ledger.name,
                                subtitle: summary.ledger.countsTowardsNetWorth ? "Counted in net worth" : "Not counted",
                                value: money(summary.balance), identifier: "ledgerRow-\(summary.ledger.name)"
                            ) { LedgerDetailScreen(model: model, ledgerID: summary.ledger.id, hidden: hidden) }
                        }
                        addButton("Add Person", identifier: "addLedgerButton") { addingLedger = true }
                        CardRow(title: "Free to allocate") {
                            Text(money(portfolio.availableForAllocation)).monospacedDigit().fontWeight(.semibold)
                                .accessibilityIdentifier("freeToAllocate")
                        }
                    }
                    CardGroup(header: "Allocated", footer: portfolio.allocatedFunds.isEmpty ? nil : "Tap an allocation to change it. Touch and hold to delete it.") {
                        ForEach(portfolio.allocatedFunds, id: \.id) { fund in
                            Button { editingFund = fund } label: {
                                CardRow(title: fund.name) { Text(money(fund.amount)).monospacedDigit() }
                            }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Edit", systemImage: "pencil") { editingFund = fund }
                                    Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteAllocatedFund(fund.id) }
                                }
                        }
                        addButton("Add Allocation", identifier: "addFundButton") { addingFund = true }
                    }
                    CardGroup(header: "Investments", footer: portfolio.holdings.isEmpty ? nil : "Tap an investment to see it. Touch and hold to change or delete it.") {
                        if let performance = portfolio.performance {
                            CardRow(title: "Up or down", subtitle: "Holdings with an amount invested") {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(hidden ? "••••••" : signed(performance.gain)).monospacedDigit().fontWeight(.semibold)
                                    if let tenths = performance.gainPercentTenths { Text(percentText(tenths: tenths)).font(.footnote) }
                                }
                                .foregroundStyle(gainColour(performance.gain))
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("investmentPerformance")
                        }
                        ForEach(portfolio.holdings, id: \.holding.id) { line in
                            NavigationLink {
                                HoldingDetailScreen(model: model, holdingID: line.holding.id, hidden: hidden)
                            } label: {
                                CardRow(title: line.holding.name, subtitle: holdingSubtitle(line)) {
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(money(line.valueInHome)).monospacedDigit()
                                        if let gain = line.gainInHome, let tenths = line.holding.gainPercentTenths {
                                            Text("\(hidden ? "" : signed(gain) + " · ")\(percentText(tenths: tenths))").font(.footnote)
                                                .foregroundStyle(gainColour(gain)).monospacedDigit()
                                        }
                                    }
                                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("holdingRow")
                            .contextMenu {
                                if line.holding.invested != nil {
                                    Button("Add Money", systemImage: "plus.circle") { addingMoneyTo = line.holding }
                                }
                                Button("Edit", systemImage: "pencil") { editingHolding = line.holding }
                                Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteHolding(line.holding.id) }
                            }
                        }
                        LinkRow(title: "Payout schemes", value: money(model.payouts.investedTotal), identifier: "payoutSchemesLink") {
                            PayoutSchemesScreen(model: model, hidden: hidden, toggleHidden: toggle)
                        }
                        addButton("Add Investment", identifier: "addHoldingButton") { addingHolding = true }
                    }
                    if !portfolio.rates.isEmpty {
                        CardGroup(header: "Exchange rates") {
                            ForEach(portfolio.rates, id: \.currency) { rate in
                                CardRow(title: "1 \(rate.currency)") {
                                    Text(verbatim: "\(rate.rate) (set \(rate.setOn.shortTitle))").foregroundStyle(Theme.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .cardNavigation("Portfolio", large: true)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if model.preferences.hideBalances {
                        Button(hidden ? "Show" : "Hide", systemImage: hidden ? "eye" : "eye.slash") { toggle() }
                            .accessibilityIdentifier("eyeButton")
                    }
                }
            }
            .sheet(isPresented: $settingBank) { BankBalanceSheet(model: model) }
            .sheet(isPresented: $addingHolding) { HoldingSheet(model: model) }
            .sheet(isPresented: $addingFund) { FundSheet(model: model) }
            .sheet(isPresented: $addingLedger) { NewLedgerSheet(model: model) }
            .sheet(item: $editingHolding) { HoldingSheet(model: model, editing: $0) }
            .sheet(item: $addingMoneyTo) { AddMoneySheet(model: model, holding: $0) }
            .sheet(item: $editingFund) { FundSheet(model: model, editing: $0) }
        }
        // On the stack, not the root: pushing Payout Schemes must not hide the amounts again.
        .onDisappear { revealed = false }
        .onChange(of: scenePhase) { if scenePhase != .active { revealed = false } }
    }

    private func signed(_ money: Money) -> String { (money > .zero ? "+" : "") + IndianMoneyFormat.string(money) }

    private func holdingSubtitle(_ line: HoldingLine) -> String? {
        let holding = line.holding
        var parts: [String] = []
        if let code = holding.currency { parts.append("\(code) \(IndianMoneyFormat.plain(holding.amount))") }
        if let invested = holding.invested, !hidden {
            parts.append("paid \(holding.currency.map { "\($0) " } ?? "")\(IndianMoneyFormat.plain(invested))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func addButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).foregroundStyle(Theme.blue).rowPadding() }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
    }

    private func toggle() {
        guard hidden else { revealed = false; return }
        Task {
            if await PrivacyGate.authenticate(reason: "Show your amounts") {
                revealed = true
                authMessage = nil
            } else {
                authMessage = "Try Again"
            }
        }
    }
}

private struct BankBalanceSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Bank balance", text: $text).keyboardType(.decimalPad).rowPadding().accessibilityIdentifier("bankBalanceField")
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding() }
                }
            }
            .cardNavigation("Bank Balance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.setBankBalance(text)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveBankBalanceButton")
                }
            }
        }
    }
}

extension Holding: @retroactive Identifiable {}
extension AllocatedFund: @retroactive Identifiable {}

private struct FundSheet: View {
    let model: BudgetViewModel
    var editing: AllocatedFund?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Name", text: $name).rowPadding().accessibilityIdentifier("fundNameField")
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad).rowPadding().accessibilityIdentifier("fundAmountField")
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding() }
                }
            }
            .cardNavigation(editing == nil ? "Add Allocation" : "Edit Allocation")
            .onAppear {
                guard let editing, name.isEmpty else { return }
                name = editing.name
                amountText = IndianMoneyFormat.plain(editing.amount)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = editing.map { model.updateAllocatedFund($0.id, name: name, amountText: amountText) }
                            ?? model.addAllocatedFund(name: name, amountText: amountText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveFundButton")
                }
            }
        }
    }
}

struct HoldingSheet: View {
    let model: BudgetViewModel
    var editing: Holding?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var investedText = ""
    @State private var hasBoughtOn = false
    @State private var boughtOn = Date()
    @State private var currency = ""
    @State private var rateText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "Fill in what you paid to see whether it is up or down. Update what it is worth whenever you like.") {
                    TextField("Name", text: $name).rowPadding().accessibilityIdentifier("holdingNameField")
                    TextField("Worth today", text: $amountText).keyboardType(.decimalPad).rowPadding().accessibilityIdentifier("holdingAmountField")
                    TextField("Amount invested (what you paid, optional)", text: $investedText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("holdingInvestedField")
                    Toggle("I know the day I bought it", isOn: $hasBoughtOn).rowPadding().accessibilityIdentifier("holdingDateToggle")
                    if hasBoughtOn {
                        FieldRow("Bought on") {
                            DatePicker("Bought on", selection: $boughtOn, in: ...Date(), displayedComponents: .date).labelsHidden()
                        }
                    }
                    CurrencyField(model: model, selection: $currency, identifier: "holdingCurrencyPicker")
                    if !currency.isEmpty {
                        TextField("Rate (\(model.preferences.homeCurrency) per 1 \(currency))", text: $rateText).keyboardType(.decimalPad)
                            .rowPadding()
                            .accessibilityIdentifier("holdingRateField")
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding() }
                }
                if let editing { HoldingHistoryChart(points: model.holdingHistory(editing.id)) }
            }
            .cardNavigation(editing == nil ? "Add Investment" : "Edit Investment")
            .onAppear {
                guard let editing, name.isEmpty else { return }
                name = editing.name
                amountText = IndianMoneyFormat.plain(editing.amount)
                investedText = editing.invested.map { IndianMoneyFormat.plain($0) } ?? ""
                hasBoughtOn = editing.investedOn != nil
                boughtOn = editing.investedOn?.instant() ?? Date()
                currency = editing.currency ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let chosen = currency.isEmpty ? nil : currency
                        errorMessage = editing.map {
                            model.updateHolding(
                                $0.id, name: name, amountText: amountText, investedText: investedText,
                                investedOn: hasBoughtOn ? CalendarDate(boughtOn) : nil, currency: chosen, rateText: rateText
                            )
                        } ?? model.addHolding(
                            name: name, amountText: amountText, investedText: investedText,
                            investedOn: hasBoughtOn ? CalendarDate(boughtOn) : nil, currency: chosen, rateText: rateText
                        )
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveHoldingButton")
                }
            }
        }
    }
}

/// A SIP instalment or a top-up: what was paid and what it is worth both go up.
struct AddMoneySheet: View {
    let model: BudgetViewModel
    let holding: Holding
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var date = Date()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup(footer: "Adds to what you paid and to what it is worth. Update the worth afterwards if it has moved.") {
                    CardRow(title: holding.name) { Text(IndianMoneyFormat.plain(holding.amount)).foregroundStyle(Theme.secondary) }
                    TextField("Amount added", text: $amountText).keyboardType(.decimalPad).rowPadding()
                        .accessibilityIdentifier("addMoneyField")
                    FieldRow("Date") { DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date).labelsHidden() }
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding() }
                }
            }
            .cardNavigation("Add Money")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        errorMessage = model.addToHolding(holding.id, amountText: amountText, on: CalendarDate(date))
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("confirmAddMoneyButton")
                }
            }
        }
    }
}

/// The values she has noted for one holding, against what she paid.
struct HoldingHistoryChart: View {
    let points: [HoldingPoint]

    var body: some View {
        if points.count > 1 {
            CardPanel {
                CardCaption("Worth over time")
                Chart {
                    ForEach(points, id: \.date) { point in
                        LineMark(x: .value("Date", point.date.instant()), y: .value("Worth", chartValue(point.value)), series: .value("Line", "Worth"))
                            .foregroundStyle(Theme.blue)
                        if let invested = point.invested {
                            LineMark(x: .value("Date", point.date.instant()), y: .value("Paid", chartValue(invested)), series: .value("Line", "Paid"))
                                .foregroundStyle(.gray).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        }
                    }
                }
                .moneyYAxis()
                .frame(height: 130)
                .accessibilityIdentifier("holdingHistoryChart")
                HStack(spacing: 14) {
                    Label("Worth", systemImage: "circle.fill").foregroundStyle(Theme.blue)
                    Label("Paid", systemImage: "circle.fill").foregroundStyle(.gray)
                }
                .font(.caption).labelStyle(.titleAndIcon)
            }
        }
    }
}

/// The line of net worth since the app began remembering it; it needs two points before it says anything.
private struct NetWorthChart: View {
    let history: NetWorthHistory
    let hidden: Bool

    var body: some View {
        if history.points.count > 1, let change = history.change, let first = history.points.first {
            VStack(alignment: .leading, spacing: 4) {
                Text(hidden ? "Since \(first.date.shortTitle)" : "\(change >= .zero ? "+" : "")\(IndianMoneyFormat.string(change)) since \(first.date.shortTitle)")
                    .font(.footnote).foregroundStyle(hidden ? Theme.secondary : gainColour(change))
                    .accessibilityIdentifier("netWorthChange")
                Chart(history.points, id: \.date) { point in
                    LineMark(x: .value("Date", point.date.instant()), y: .value("Net worth", chartValue(point.amount)))
                        .foregroundStyle(Theme.blue).interpolationMethod(.monotone)
                    AreaMark(x: .value("Date", point.date.instant()), y: .value("Net worth", chartValue(point.amount)))
                        .foregroundStyle(Theme.blue.opacity(0.08)).interpolationMethod(.monotone)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .moneyYAxis(hidden: hidden)
                .frame(height: 120)
                .accessibilityIdentifier("netWorthChart")
            }
        }
    }
}
