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
    @State private var editingHolding: Holding?
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
                    CardGroup(header: "Investments", footer: portfolio.holdings.isEmpty ? nil : "Tap an investment to change it. Touch and hold to delete it.") {
                        ForEach(portfolio.holdings, id: \.holding.id) { line in
                            Button { editingHolding = line.holding } label: {
                                CardRow(title: line.holding.name,
                                        subtitle: line.holding.currency.map { "\($0) \(IndianMoneyFormat.plain(line.holding.amount))" }) {
                                    Text(money(line.valueInHome)).monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
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
                                    Text("\(rate.rate) (set \(rate.setOn.shortTitle))").foregroundStyle(Theme.secondary)
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
            .sheet(item: $editingHolding) { HoldingSheet(model: model, editing: $0) }
            .sheet(item: $editingFund) { FundSheet(model: model, editing: $0) }
        }
        // On the stack, not the root: pushing Payout Schemes must not hide the amounts again.
        .onDisappear { revealed = false }
        .onChange(of: scenePhase) { if scenePhase != .active { revealed = false } }
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

private struct HoldingSheet: View {
    let model: BudgetViewModel
    var editing: Holding?
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
                    CurrencyField(model: model, selection: $currency, identifier: "holdingCurrencyPicker")
                    if !currency.isEmpty {
                        TextField("Rate (\(model.preferences.homeCurrency) per 1 \(currency))", text: $rateText).keyboardType(.decimalPad)
                            .rowPadding()
                            .accessibilityIdentifier("holdingRateField")
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red).rowPadding() }
                }
            }
            .cardNavigation(editing == nil ? "Add Investment" : "Edit Investment")
            .onAppear {
                guard let editing, name.isEmpty else { return }
                name = editing.name
                amountText = IndianMoneyFormat.plain(editing.amount)
                currency = editing.currency ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let chosen = currency.isEmpty ? nil : currency
                        errorMessage = editing.map {
                            model.updateHolding($0.id, name: name, amountText: amountText, currency: chosen, rateText: rateText)
                        } ?? model.addHolding(name: name, amountText: amountText, currency: chosen, rateText: rateText)
                        if errorMessage == nil { dismiss() }
                    }
                    .accessibilityIdentifier("saveHoldingButton")
                }
            }
        }
    }
}
