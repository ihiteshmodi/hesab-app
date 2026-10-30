/// Settings that change how the app behaves; every one has a default, so a fresh install needs none stored.
public struct Preferences: Equatable, Sendable {
    public enum PaymentDate: String, CaseIterable, Sendable {
        case useDueDate, useToday, askEachTime
    }

    public var upcomingWindowDays = 14
    public var paymentDate = PaymentDate.useDueDate
    public var showExactDays = false
    public var includePastDue = true
    public var payoutAlertDays = 5
    public var countMoneyReceivedAsIncome = true
    public var countBorrowedAsIncome = false
    public var includeCashAndLedgerInSpent = false
    public var hideBalances = false
    public var appLock = false
    public var homeCurrency = "INR"
    /// The currency new expenses start in while travelling; nil means the home currency.
    public var spendingIn: String?

    public init() {}

    init(stored: [String: String]) {
        func int(_ key: String, _ fallback: Int) -> Int { stored[key].flatMap(Int.init) ?? fallback }
        func bool(_ key: String, _ fallback: Bool) -> Bool { stored[key].map { $0 == "1" } ?? fallback }
        upcomingWindowDays = int("upcoming_window_days", upcomingWindowDays)
        paymentDate = stored["payment_date"].flatMap(PaymentDate.init(rawValue:)) ?? paymentDate
        showExactDays = bool("show_exact_days", showExactDays)
        includePastDue = bool("include_past_due", includePastDue)
        payoutAlertDays = int("payout_alert_days", payoutAlertDays)
        countMoneyReceivedAsIncome = bool("count_money_received_as_income", countMoneyReceivedAsIncome)
        countBorrowedAsIncome = bool("count_borrowed_as_income", countBorrowedAsIncome)
        includeCashAndLedgerInSpent = bool("include_cash_and_ledger_in_spent", includeCashAndLedgerInSpent)
        hideBalances = bool("hide_balances", hideBalances)
        appLock = bool("app_lock", appLock)
        homeCurrency = stored["home_currency"] ?? homeCurrency
        spendingIn = stored["spending_in"].flatMap { $0.isEmpty ? nil : $0 }
    }

    var stored: [String: String] {
        [
            "upcoming_window_days": String(upcomingWindowDays),
            "payment_date": paymentDate.rawValue,
            "show_exact_days": showExactDays ? "1" : "0",
            "include_past_due": includePastDue ? "1" : "0",
            "payout_alert_days": String(payoutAlertDays),
            "count_money_received_as_income": countMoneyReceivedAsIncome ? "1" : "0",
            "count_borrowed_as_income": countBorrowedAsIncome ? "1" : "0",
            "include_cash_and_ledger_in_spent": includeCashAndLedgerInSpent ? "1" : "0",
            "hide_balances": hideBalances ? "1" : "0",
            "app_lock": appLock ? "1" : "0",
            "home_currency": homeCurrency,
            "spending_in": spendingIn ?? "",
        ]
    }
}

public struct GetPreferences: Sendable {
    let settings: SettingsRepository

    public func callAsFunction() throws -> Preferences {
        Preferences(stored: try settings.all())
    }
}

public struct UpdatePreferences: Sendable {
    let settings: SettingsRepository

    public func callAsFunction(_ change: (inout Preferences) -> Void) throws {
        var preferences = Preferences(stored: try settings.all())
        change(&preferences)
        try settings.save(preferences.stored)
    }
}
