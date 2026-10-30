import HisaabCore
import SwiftUI

/// Everything that is not the month itself: the lists and tools behind the profile button.
struct MoreScreen: View {
    let model: BudgetViewModel

    var body: some View {
        List {
            link("Categories", "categoriesLink", detail: "") {
                CategoriesScreen(model: model)
            }
            link("Entities", "entitiesLink", detail: "\(model.entities.count)") {
                EntitiesScreen(model: model)
            }
            link("Settings", "settingsLink", detail: "") {
                SettingsScreen(model: model)
            }
            link("Pending refunds", "pendingRefundsLink",
                 detail: "\(model.budget?.pendingRefundsEverywhere.count ?? 0) · \(IndianMoneyFormat.string(model.budget?.pendingRefundsEverywhere.stillToCome ?? .zero))") {
                PendingRefundsScreen(model: model)
            }
            link("Cash in hand", "cashInHandLink", detail: IndianMoneyFormat.string(model.cash?.balance ?? .zero)) {
                CashInHandScreen(model: model)
            }
            link("Ledgers", "ledgersLink", detail: IndianMoneyFormat.string(model.ledgers?.total ?? .zero)) {
                LedgersScreen(model: model)
            }
            link("Card bills", "cardBillsLink", detail: IndianMoneyFormat.string(model.cardBills?.totalDue ?? .zero)) {
                CardBillsScreen(model: model)
            }
            link("Amount to repay", "amountToRepayLink", detail: IndianMoneyFormat.string(model.amountToRepay?.total ?? .zero)) {
                AmountToRepayScreen(model: model)
            }
            link("Backup", "backupLink", detail: "") {
                BackupScreen(model: model)
            }
        }
        .navigationTitle("More")
    }

    private func link<Destination: View>(
        _ title: String, _ identifier: String, detail: String, @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(detail).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .accessibilityIdentifier(identifier)
    }
}
