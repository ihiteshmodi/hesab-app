import HisaabCore
import SwiftUI

/// Mockup 43: currency, the two privacy switches, and the three settings pages.
struct SettingsScreen: View {
    let model: BudgetViewModel
    @State private var lockMessage: String?

    var body: some View {
        CardScreen {
            CardGroup {
                LinkRow(title: "Currency & Rates", subtitle: "Home currency \(model.preferences.homeCurrency)", identifier: "currencyLink") {
                    CurrencyRatesScreen(model: model)
                }
            }
            CardGroup(footer: PrivacyGate.biometricsAvailable ? nil : "Face ID or Touch ID is not available on this device.") {
                Toggle(isOn: Binding(
                    get: { model.preferences.hideBalances }, set: { value in model.updatePreferences { $0.hideBalances = value } }
                )) {
                    rowLabel("Hide Balances", "Shows ₹ •••• until you tap the eye")
                }
                .rowPadding()
                .accessibilityIdentifier("hideBalancesToggle")
                Toggle(isOn: Binding(get: { model.preferences.appLock }, set: setAppLock)) {
                    rowLabel("App Lock", "Face ID or Touch ID when opening")
                }
                .disabled(!PrivacyGate.biometricsAvailable)
                .rowPadding()
                .accessibilityIdentifier("appLockToggle")
                if let lockMessage {
                    Text(lockMessage).foregroundStyle(Theme.red).rowPadding().accessibilityIdentifier("appLockMessage")
                }
            }
            CardGroup {
                LinkRow(title: "Income & Expense Settings", identifier: "incomeExpenseSettingsLink") {
                    IncomeExpenseSettingsScreen(model: model)
                }
                LinkRow(title: "Due Date Settings", identifier: "dueDateSettingsLink") { DueDateSettingsScreen(model: model) }
                LinkRow(title: "Upcoming Bill Filters", value: UpcomingWindow.title(model.preferences.upcomingWindowDays),
                        identifier: "upcomingFiltersLink") {
                    UpcomingFiltersForm(model: model).cardNavigation("Upcoming Bill Filters")
                }
            }
        }
        .cardNavigation("Settings")
    }

    private func rowLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
            Text(subtitle).font(.footnote).foregroundStyle(Theme.secondary)
        }
    }

    private func setAppLock(_ on: Bool) {
        guard on else {
            lockMessage = nil
            model.updatePreferences { $0.appLock = false }
            return
        }
        Task {
            if await PrivacyGate.authenticate(reason: "Turn on App Lock") {
                lockMessage = nil
                model.updatePreferences { $0.appLock = true }
            } else {
                lockMessage = "Try Again"
            }
        }
    }
}

/// A switch row bound to one preference.
struct PreferenceToggle: View {
    let model: BudgetViewModel
    let title: String
    let keyPath: WritableKeyPath<Preferences, Bool>

    var body: some View {
        Toggle(title, isOn: Binding(
            get: { model.preferences[keyPath: keyPath] }, set: { value in model.updatePreferences { $0[keyPath: keyPath] = value } }
        ))
        .rowPadding()
    }
}

/// Mockup 44: home currency, the currency new expenses start in, and the currencies she has used.
struct CurrencyRatesScreen: View {
    let model: BudgetViewModel
    @State private var addingCurrency = false
    @State private var errorMessage: String?

    var body: some View {
        CardScreen {
            CardGroup(footer: "Each expense keeps the rate you actually got. The app never goes online, so rates are typed by hand.") {
                FieldRow("Home currency") {
                    Picker("Home currency", selection: Binding(
                        get: { model.preferences.homeCurrency }, set: { errorMessage = model.setHomeCurrency($0) }
                    )) {
                        ForEach(model.currencies, id: \.code) { Text($0.code).tag($0.code) }
                    }
                    .labelsHidden()
                }
                FieldRow("Spending in") {
                    Picker("Spending in", selection: Binding(
                        get: { model.preferences.spendingIn ?? "" },
                        set: { value in model.updatePreferences { $0.spendingIn = value.isEmpty ? nil : value } }
                    )) {
                        Text("Home currency").tag("")
                        ForEach(model.currencies.filter { $0.code != model.preferences.homeCurrency }, id: \.code) {
                            Text($0.code).tag($0.code)
                        }
                    }
                    .labelsHidden()
                    .accessibilityIdentifier("spendingInPicker")
                }
            }
            CardGroup(header: "Currencies") {
                ForEach(model.currencies, id: \.code) { currency in
                    CardRow(title: "\(currency.code) · \(currency.name)", subtitle: rateText(currency.code)) {
                        if currency.code == model.preferences.homeCurrency { StatusPill(text: "Home", tone: .blue) }
                    }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
            Button("Add Currency") { addingCurrency = true }.buttonStyle(GreyButtonStyle())
        }
        .cardNavigation("Currency & Rates")
        .sheet(isPresented: $addingCurrency) { NewCurrencySheet(model: model) }
    }

    private func rateText(_ code: String) -> String? {
        guard code != model.preferences.homeCurrency, let rate = model.lastRate(for: code) else { return nil }
        return "Last rate: 1 \(code) = \(rate) \(model.preferences.homeCurrency)"
    }
}

/// Mockup 45.
private struct IncomeExpenseSettingsScreen: View {
    let model: BudgetViewModel

    var body: some View {
        CardScreen {
            CardGroup {
                PreferenceToggle(model: model, title: "Count money received as income", keyPath: \.countMoneyReceivedAsIncome)
                PreferenceToggle(model: model, title: "Count borrowed money as income", keyPath: \.countBorrowedAsIncome)
                PreferenceToggle(model: model, title: "Include cash and ledger spending in Spent this month",
                                 keyPath: \.includeCashAndLedgerInSpent)
            }
        }
        .cardNavigation("Income & Expense Settings")
    }
}

/// Mockup 46.
private struct DueDateSettingsScreen: View {
    let model: BudgetViewModel

    var body: some View {
        CardScreen {
            CardGroup(header: "Payment date", footer: "The date a bill's expense gets when you add it.") {
                ForEach([
                    (Preferences.PaymentDate.useDueDate, "Use due date"), (.useToday, "Use today"), (.askEachTime, "Ask each time"),
                ], id: \.0) { value, title in
                    tickRow(title, model.preferences.paymentDate == value) { model.updatePreferences { $0.paymentDate = value } }
                }
            }
            CardGroup {
                PreferenceToggle(model: model, title: "Show exact days", keyPath: \.showExactDays)
            }
            CardGroup(header: "Expected payouts", footer: "How many days ahead a payout starts to count on the Bills tab.") {
                ForEach([0, 1, 2, 3, 5, 7], id: \.self) { days in
                    tickRow(days == 0 ? "On the day" : "\(days) day\(days == 1 ? "" : "s") before",
                            model.preferences.payoutAlertDays == days) { model.updatePreferences { $0.payoutAlertDays = days } }
                }
            }
        }
        .cardNavigation("Due Date Settings")
    }
}

/// Mockup 47: how far ahead Activity > Upcoming looks.
struct UpcomingFiltersForm: View {
    let model: BudgetViewModel

    var body: some View {
        CardScreen {
            CardGroup(header: "Show bills that are") {
                ForEach(UpcomingWindow.choices, id: \.self) { days in
                    tickRow(UpcomingWindow.title(days), model.preferences.upcomingWindowDays == days) {
                        model.updatePreferences { $0.upcomingWindowDays = days }
                    }
                    .accessibilityIdentifier("window-\(days)")
                }
            }
            CardGroup {
                PreferenceToggle(model: model, title: "Include past due", keyPath: \.includePastDue)
            }
        }
    }
}

/// Opened from Activity > Upcoming.
struct UpcomingFiltersSheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            UpcomingFiltersForm(model: model)
                .cardNavigation("Upcoming Bill Filters")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.accessibilityIdentifier("doneFiltersButton")
                    }
                }
        }
    }
}

/// A choice in a list with a tick on the chosen one.
@MainActor
func tickRow(_ title: String, _ chosen: Bool, choose: @escaping () -> Void) -> some View {
    Button(action: choose) {
        CardRow(title: title) {
            if chosen { Image(systemName: "checkmark").font(.body.weight(.bold)) }
        }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(chosen ? .isSelected : [])
}

struct NewCurrencySheet: View {
    let model: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var name = ""
    @State private var symbol = ""
    @State private var decimals = 2
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            CardScreen {
                CardGroup {
                    TextField("Code, for example VND", text: $code).textInputAutocapitalization(.characters).rowPadding()
                    TextField("Name", text: $name).rowPadding()
                    TextField("Symbol (optional)", text: $symbol).rowPadding()
                    FieldRow("Decimals") {
                        Picker("Decimals", selection: $decimals) {
                            Text("None").tag(0)
                            Text("2").tag(2)
                        }
                        .labelsHidden()
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
            }
            .cardNavigation("New Currency")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        errorMessage = model.addCurrency(code: code, name: name, symbol: symbol, decimals: decimals)
                        if errorMessage == nil { dismiss() }
                    }
                }
            }
        }
    }
}
