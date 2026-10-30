import HisaabCore
import LocalAuthentication
import SwiftUI

struct PortfolioScreen: View {
    let model: BudgetViewModel
    @State private var hidden = true
    @State private var settingBank = false
    @State private var addingHolding = false
    @State private var addingFund = false
    @State private var errorMessage: String?

    private func money(_ value: Money) -> String { hidden ? "••••••" : IndianMoneyFormat.string(value) }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                if let portfolio = model.portfolio {
                    Section {
                        VStack(spacing: 4) {
                            Text("NET WORTH").font(.caption).foregroundStyle(.secondary)
                            Text(money(portfolio.netWorth)).font(.largeTitle.bold()).monospacedDigit()
                                .accessibilityIdentifier("netWorth")
                        }
                        .frame(maxWidth: .infinity)
                        if let warning = portfolio.warning, !hidden {
                            Text(warning).foregroundStyle(.orange).accessibilityIdentifier("portfolioWarning")
                        }
                    }
                    Section {
                        Button { settingBank = true } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Bank balance").foregroundStyle(.primary)
                                    Text(portfolio.bankBalanceAsOf.map { "as of \($0.shortTitle) · tap to update" } ?? "tap to set")
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(money(portfolio.bankBalance)).foregroundStyle(.primary).monospacedDigit()
                                    .accessibilityIdentifier("bankBalance")
                            }
                        }
                        .accessibilityIdentifier("setBankBalanceButton")
                        ForEach(model.ledgers?.ledgers ?? [], id: \.ledger.id) { summary in
                            Toggle(isOn: Binding(
                                get: { summary.ledger.countsTowardsNetWorth },
                                set: { errorMessage = model.setLedgerCountsTowardsNetWorth(summary.ledger.id, $0) }
                            )) {
                                VStack(alignment: .leading) {
                                    Text("\(summary.ledger.name) (counted)")
                                    Text(money(summary.balance)).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("countLedger-\(summary.ledger.name)")
                        }
                        HStack {
                            Text("Free to allocate").fontWeight(.semibold)
                            Spacer()
                            Text(money(portfolio.availableForAllocation)).monospacedDigit().accessibilityIdentifier("freeToAllocate")
                        }
                    }
                    Section("Allocated") {
                        ForEach(portfolio.allocatedFunds, id: \.id) { fund in
                            HStack { Text(fund.name); Spacer(); Text(money(fund.amount)).monospacedDigit() }
                                .swipeActions { Button("Delete", role: .destructive) { errorMessage = model.deleteAllocatedFund(fund.id) } }
                        }
                        Button("Add Allocation") { addingFund = true }.accessibilityIdentifier("addFundButton")
                    }
                    Section("Investments") {
                        ForEach(portfolio.holdings, id: \.holding.id) { line in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(line.holding.name)
                                    if let code = line.holding.currency {
                                        Text("\(code) \(IndianMoneyFormat.plain(line.holding.amount))").font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(money(line.valueInHome)).monospacedDigit()
                            }
                            .swipeActions { Button("Delete", role: .destructive) { errorMessage = model.deleteHolding(line.holding.id) } }
                        }
                        NavigationLink {
                            PayoutSchemesScreen(model: model, hidden: hidden)
                        } label: {
                            HStack {
                                Text("Payout schemes")
                                Spacer()
                                Text(money(model.payouts.investedTotal)).foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                        .accessibilityIdentifier("payoutSchemesLink")
                        Button("Add Investment") { addingHolding = true }.accessibilityIdentifier("addHoldingButton")
                    }
                    if !portfolio.rates.isEmpty {
                        Section("Exchange rates") {
                            ForEach(portfolio.rates, id: \.currency) { rate in
                                HStack {
                                    Text("1 \(rate.currency)")
                                    Spacer()
                                    Text("\(rate.rate) (set \(rate.setOn.shortTitle))").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Portfolio")
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

    private func toggle() {
        guard hidden else { hidden = true; return }
        if CommandLine.arguments.contains("-ui-testing") {
            hidden = false
            return
        }
        let context = LAContext()
        var failure: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &failure) else {
            hidden = false
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Show your amounts") { ok, _ in
            Task { @MainActor in if ok { hidden = false } }
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
            Form {
                TextField("Bank balance", text: $text).keyboardType(.decimalPad).accessibilityIdentifier("bankBalanceField")
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Bank Balance")
            .navigationBarTitleDisplayMode(.inline)
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
            Form {
                TextField("Name", text: $name).accessibilityIdentifier("fundNameField")
                TextField("Amount", text: $amountText).keyboardType(.decimalPad).accessibilityIdentifier("fundAmountField")
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Add Allocation")
            .navigationBarTitleDisplayMode(.inline)
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
            Form {
                TextField("Name", text: $name).accessibilityIdentifier("holdingNameField")
                TextField("Amount", text: $amountText).keyboardType(.decimalPad).accessibilityIdentifier("holdingAmountField")
                Picker("Currency", selection: $currency) {
                    Text("Home currency").tag("")
                    ForEach(model.currencies.filter { $0.code != model.preferences.homeCurrency }, id: \.code) { Text($0.code).tag($0.code) }
                }
                if !currency.isEmpty {
                    TextField("Rate (\(model.preferences.homeCurrency) per 1 \(currency))", text: $rateText).keyboardType(.decimalPad)
                        .accessibilityIdentifier("holdingRateField")
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Add Investment")
            .navigationBarTitleDisplayMode(.inline)
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
