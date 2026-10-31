import SwiftUI

/// Everything that is not a daily screen, opened from the round profile button on Activity.
enum DrawerItem: String, CaseIterable, Hashable, Identifiable {
    case categories, entities, ledgers, cardBills, cashInHand, amountToRepay, pendingRefunds, exportData, importData, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categories: "Categories"
        case .entities: "Entities"
        case .ledgers: "Ledgers"
        case .cardBills: "Card Bills"
        case .cashInHand: "Cash in Hand"
        case .amountToRepay: "Amount to Repay"
        case .pendingRefunds: "Pending Refunds"
        case .exportData: "Export Data"
        case .importData: "Import Data"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .categories: "square.grid.2x2.fill"
        case .entities: "storefront.fill"
        case .ledgers: "person.2.fill"
        case .cardBills: "creditcard.fill"
        case .cashInHand: "banknote.fill"
        case .amountToRepay: "arrow.uturn.backward.circle.fill"
        case .pendingRefunds: "arrow.counterclockwise.circle.fill"
        case .exportData: "square.and.arrow.up.fill"
        case .importData: "square.and.arrow.down.fill"
        case .settings: "gearshape.fill"
        }
    }

    /// Kept from the old More list so the links keep their names.
    var identifier: String {
        switch self {
        case .categories: "categoriesLink"
        case .entities: "entitiesLink"
        case .ledgers: "ledgersLink"
        case .cardBills: "cardBillsLink"
        case .cashInHand: "cashInHandLink"
        case .amountToRepay: "amountToRepayLink"
        case .pendingRefunds: "pendingRefundsLink"
        case .exportData: "backupLink"
        case .importData: "importLink"
        case .settings: "settingsLink"
        }
    }

    @MainActor @ViewBuilder
    func screen(_ model: BudgetViewModel) -> some View {
        switch self {
        case .categories: CategoriesScreen(model: model)
        case .entities: EntitiesScreen(model: model)
        case .ledgers: LedgersScreen(model: model)
        case .cardBills: CardBillsScreen(model: model)
        case .cashInHand: CashInHandScreen(model: model)
        case .amountToRepay: AmountToRepayScreen(model: model)
        case .pendingRefunds: PendingRefundsScreen(model: model)
        case .exportData, .importData: BackupScreen(model: model)
        case .settings: SettingsScreen(model: model)
        }
    }
}

/// The drawer that slides in from the left over a dimmed screen.
struct MenuDrawer: View {
    let choose: (DrawerItem) -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Hisaab").font(.title2.weight(.bold)).padding(.horizontal, 4).padding(.bottom, 12)
                ForEach(DrawerItem.allCases) { item in
                    Button { choose(item) } label: {
                        HStack(spacing: 16) {
                            Image(systemName: item.icon).font(.system(size: 20)).frame(width: 30)
                            Text(item.title).font(.system(size: 18))
                            Spacer()
                        }
                        .padding(.vertical, 12).padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(item.identifier)
                }
                Spacer()
            }
            .padding(.top, 70).padding(.horizontal, 20)
            .frame(width: 300)
            .frame(maxHeight: .infinity)
            .background(Theme.tile.ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("menuDrawer")
            Color.black.opacity(0.25).ignoresSafeArea()
                .onTapGesture(perform: close)
                .accessibilityLabel("Close menu")
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("closeMenuButton")
        }
    }
}
