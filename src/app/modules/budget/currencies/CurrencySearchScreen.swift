import Foundation
import HisaabCore
import SwiftUI

/// Every ISO currency with the countries that use it, so "Indonesia" finds IDR.
private struct WorldCurrency: Identifiable {
    let code: String
    let name: String
    let countries: [String]
    var id: String { code }

    static let all: [WorldCurrency] = {
        let english = Locale(identifier: "en")
        var countries: [String: [String]] = [:]
        for region in Locale.Region.isoRegions where region.subRegions.isEmpty {
            guard let code = Locale(languageComponents: .init(languageCode: "en", region: region)).currency?.identifier,
                  let country = english.localizedString(forRegionCode: region.identifier) else { continue }
            countries[code, default: []].append(country)
        }
        return Locale.commonISOCurrencyCodes.map { code in
            WorldCurrency(code: code, name: english.localizedString(forCurrencyCode: code) ?? code, countries: (countries[code] ?? []).sorted())
        }
    }()

    func matches(_ text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        return code.lowercased().contains(query) || name.lowercased().contains(query)
            || countries.contains { $0.lowercased().contains(query) }
    }

    var decimals: Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.maximumFractionDigits == 0 ? 0 : 2
    }
}

/// A "Currency" row that opens a searchable list of every currency; "" means the home currency.
struct CurrencyField: View {
    let model: BudgetViewModel
    @Binding var selection: String
    let identifier: String

    var body: some View {
        NavigationLink {
            CurrencySearchScreen(model: model, selection: $selection)
        } label: {
            CardRow(title: "Currency") {
                Text(selection.isEmpty ? model.preferences.homeCurrency : selection).foregroundStyle(Theme.secondary)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

struct CurrencySearchScreen: View {
    let model: BudgetViewModel
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var addingOwn = false
    @State private var errorMessage: String?

    private var home: String { model.preferences.homeCurrency }

    var body: some View {
        let mine = Set(model.currencies.map(\.code))
        let saved = model.currencies.filter { $0.code != home }
            .filter { currency in search.isEmpty || WorldCurrency.all.first { $0.code == currency.code }?.matches(search) ?? currency.code.lowercased().contains(search.lowercased()) }
        let others = WorldCurrency.all.filter { !mine.contains($0.code) && $0.code != home && $0.matches(search) }
        List {
            if let errorMessage { Text(errorMessage).foregroundStyle(Theme.red) }
            Section("Yours") {
                if search.isEmpty || home.lowercased().contains(search.lowercased()) { row(code: home, detail: "Home currency", pick: "") }
                ForEach(saved, id: \.code) { currency in row(code: currency.code, detail: currency.name, pick: currency.code) }
            }
            Section("All currencies") {
                ForEach(others) { currency in
                    row(code: currency.code, detail: ([currency.name] + currency.countries.prefix(3)).joined(separator: " · ")) {
                        errorMessage = model.addCurrency(code: currency.code, name: currency.name, symbol: "", decimals: currency.decimals)
                        if errorMessage == nil { choose(currency.code) }
                    }
                }
                if others.isEmpty && saved.isEmpty { Text("No currency matches “\(search)”.").foregroundStyle(Theme.secondary) }
            }
            Section {
                Button("Add a currency that is not listed", systemImage: "plus") { addingOwn = true }
                    .accessibilityIdentifier("addOwnCurrencyButton")
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Country, name or code")
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $addingOwn) { NewCurrencySheet(model: model) }
    }

    private func row(code: String, detail: String, pick: String) -> some View {
        row(code: code, detail: detail) { choose(pick) }
    }

    private func row(code: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(code).font(.headline)
                    Text(detail).font(.footnote).foregroundStyle(Theme.secondary).lineLimit(1)
                }
                Spacer()
                if (selection.isEmpty ? home : selection) == code { Image(systemName: "checkmark").foregroundStyle(Theme.blue) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(code)
    }

    private func choose(_ code: String) {
        selection = code
        dismiss()
    }
}
