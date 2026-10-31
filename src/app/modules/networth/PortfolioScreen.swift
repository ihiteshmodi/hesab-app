import HisaabCore
import SwiftUI

struct PortfolioScreen: View {
    let model: BudgetViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var hidden = true
    @State private var authMessage: String?
    @State private var settingBank = false
    @State private var addingHolding = false
    @State private var addingFund = false
    @State private var errorMessage: String?

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
                            Toggle(isOn: Binding(
                                get: { summary.ledger.countsTowardsNetWorth },
                                set: { errorMessage = model.setLedgerCountsTowardsNetWorth(summary.ledger.id, $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(summary.ledger.name) (counted)")
                                    Text(money(summary.balance)).font(.footnote).foregroundStyle(Theme.secondary).monospacedDigit()
                                }
                            }
                            .rowPadding()
                            .accessibilityIdentifier("countLedger-\(summary.ledger.name)")
                        }
                        CardRow(title: "Free to allocate") {
                            Text(money(portfolio.availableForAllocation)).monospacedDigit().fontWeight(.semibold)
                                .accessibilityIdentifier("freeToAllocate")
                        }
                    }
                    CardGroup(header: "Allocated", footer: portfolio.allocatedFunds.isEmpty ? nil : "Touch and hold an allocation to delete it.") {
                        ForEach(portfolio.allocatedFunds, id: \.id) { fund in
                            CardRow(title: fund.name) { Text(money(fund.amount)).monospacedDigit() }
                                .contextMenu {
                                    Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteAllocatedFund(fund.id) }
                                }
                        }
                        addButton("Add Allocation", identifier: "addFundButton") { addingFund = true }
                    }
                    CardGroup(header: "Investments", footer: portfolio.holdings.isEmpty ? nil : "Touch and hold an investment to delete it.") {
                        ForEach(portfolio.holdings, id: \.holding.id) { line in
                            CardRow(title: line.holding.name,
                                    subtitle: line.holding.currency.map { "\($0) \(IndianMoneyFormat.plain(line.holding.amount))" }) {
                                Text(money(line.valueInHome)).monospacedDigit()
                            }
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) { errorMessage = model.deleteHolding(line.holding.id) }
                            }
                        }
                        LinkRow(title: "Payout schemes", value: money(model.payouts.investedTotal), identifier: "payoutSchemesLink") {
                            PayoutSchemesScreen(model: model, hidden: hidden)
                        }
                        addButton("Add Investment", identifier: "addHoldingButton") { addingHolding = true }
                    }
                    if !portfolio.rates.isEmpty {
                        CardGroup(header: "Exchange rates") {
                            ForEach(portfolio.rates, id: \.currency) { rate in
                                CardRow(title: "1 \(rate.currency)") {
                                    Text("\(rate.rate) (set \(rate.setOn.shortTitle))").foregroundStyle(Theme.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .cardNavigation("Portfolio", large: true)
            .onDisappear { hidden = true }
            .onChange(of: scenePhase) { if scenePhase != .active { hidden = true } }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(hidden ? "Show" : "Hide", systemImage: hidden ? "eye" : "eye.slash") { toggle() }
                        .accessibilityIdentifier("eyeButton")
                }
            }
            .sheet(isPresented: $settingBank) { BankBalanceSheet(model: model) }
            .sheet(isPresented: $addingHolding) { HoldingSheet(model: model) }
            .sheet(isPresented: $addingFund) { FundSheet(model: model) }
        }
    }

    private func addButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).foregroundStyle(Theme.blue).rowPadding() }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
    }

    private func toggle() {
        guard hidden else { hidden = true; return }
        Task {
            if await PrivacyGate.authenticate(reason: "Show your amounts") {
                hidden = false
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

private struct FundSheet: View {
    let model: BudgetViewModel
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
            .cardNavigation("Add Allocation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addAllocatedFund(name: name, amountText: amountText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveFundButton")
                }
            }
        }
    }
}

private struct HoldingSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var currency = ""
    @State private var rateText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Name", text: $name).rowPadding().accessibilityIdentifier("holdingNameField")
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad).rowPadding().accessibilityIdentifier("holdingAmountField")
                    FieldRow("Currency") {
                        Picker("Currency", selection: $currency) {
                            Text("Home currency").tag("")
                            ForEach(model.currencies.filter { $0.code != model.preferences.homeCurrency }, id: \.code) { Text($0.code).tag($0.code) }
                        }
                        .labelsHidden()
                    }
                    if !currency.isEmpty {
                        TextField("Rate (\(model.preferences.homeCurrency) per 1 \(currency))", text: $rateText).keyboardType(.decimalPad)
                            .rowPadding()
                            .accessibilityIdentifier("holdingRateField")
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding() }
                }
            }
            .cardNavigation("Add Investment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addHolding(name: name, amountText: amountText, currency: currency.isEmpty ? nil : currency, rateText: rateText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveHoldingButton")
                }
            }
        }
    }
}
