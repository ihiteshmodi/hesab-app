import Foundation
import GRDB

final class CurrencyRepository: Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func all() throws -> [Currency] {
        try database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT code, name, symbol, decimals FROM currency ORDER BY code").map {
                Currency(code: $0["code"], name: $0["name"], symbol: $0["symbol"], decimals: $0["decimals"])
            }
        }
    }

    func add(_ currency: Currency) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "INSERT INTO currency (code, name, symbol, decimals) VALUES (?, ?, ?, ?)",
                arguments: [currency.code, currency.name, currency.symbol, currency.decimals]
            )
        }
    }
}

public struct GetCurrencies: Sendable {
    let currencies: CurrencyRepository

    public func callAsFunction() throws -> [Currency] {
        try currencies.all()
    }
}

public struct AddCurrency: Sendable {
    let currencies: CurrencyRepository

    public func callAsFunction(_ new: Currency) throws {
        let code = new.code.trimmed.uppercased()
        guard !code.isEmpty else { throw CurrencyError.codeMissing }
        guard !(try currencies.all()).contains(where: { $0.code == code }) else { throw CurrencyError.codeTaken(code) }
        try currencies.add(Currency(
            code: code, name: new.name.trimmed, symbol: new.symbol?.trimmed.nilIfEmpty, decimals: new.decimals
        ))
    }
}

public struct GetLastRate: Sendable {
    let expenses: ExpenseRepository

    /// The rate of the most recent expense in `currency`, to offer again.
    public func callAsFunction(for currency: String) throws -> Decimal? {
        try expenses.all()
            .filter { $0.foreign?.currency == currency }
            .max { ($0.date, $0.id ?? 0) < ($1.date, $1.id ?? 0) }?.foreign?.rate
    }
}

public struct SetHomeCurrency: Sendable {
    let expenses: ExpenseRepository
    let income: IncomeRepository
    let settings: SettingsRepository

    /// Allowed only while there are no records, so every total keeps meaning one currency.
    public func callAsFunction(_ code: String) throws {
        let preferences = Preferences(stored: try settings.all())
        let hasRecords = try !expenses.all().isEmpty || !income.all().isEmpty
        guard !hasRecords || code == preferences.homeCurrency else { throw CurrencyError.homeLocked(preferences.homeCurrency) }
        var updated = preferences
        updated.homeCurrency = code
        try settings.save(updated.stored)
    }
}
