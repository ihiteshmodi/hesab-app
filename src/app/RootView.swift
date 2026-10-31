import SwiftUI

private enum AppTab: String, CaseIterable {
    case activity = "Activity"
    case bills = "Bills"
    case portfolio = "Portfolio"
    case reports = "Reports"
    case trips = "Trips"
    case search = "Search"

    var icon: String {
        switch self {
        case .activity: "list.bullet.rectangle"
        case .bills: "calendar"
        case .portfolio: "chart.pie.fill"
        case .reports: "chart.bar.fill"
        case .trips: "suitcase.fill"
        case .search: "magnifyingglass"
        }
    }
}

/// iOS folds a sixth tab into "More", so the bar is drawn here and the system one is hidden.
struct RootView: View {
    let model: BudgetViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = AppTab.activity
    @State private var locked: Bool
    @State private var lockMessage: String?
    @State private var drawerOpen = false
    @State private var drawerRoute: DrawerItem?

    init(model: BudgetViewModel) {
        self.model = model
        _locked = State(initialValue: model.preferences.appLock)
    }

    var body: some View {
        Group { if locked { lockScreen } else { content } }
            .onChange(of: scenePhase) {
                if scenePhase == .background, model.preferences.appLock { locked = true }
                if scenePhase == .active, locked, !PrivacyGate.isUITesting { Task { await unlock() } }
            }
            .task { if locked, !PrivacyGate.isUITesting { await unlock() } }
    }

    private var content: some View {
        TabView(selection: $tab) {
            BudgetScreen(model: model, route: $drawerRoute) { withAnimation(.easeOut(duration: 0.25)) { drawerOpen = true } }
                .tag(AppTab.activity).toolbar(.hidden, for: .tabBar)
            BillsScreen(model: model).tag(AppTab.bills).toolbar(.hidden, for: .tabBar)
            PortfolioScreen(model: model).tag(AppTab.portfolio).toolbar(.hidden, for: .tabBar)
            ReportsScreen(model: model).tag(AppTab.reports).toolbar(.hidden, for: .tabBar)
            TripsScreen(model: model).tag(AppTab.trips).toolbar(.hidden, for: .tabBar)
            SearchScreen(model: model).tag(AppTab.search).toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bar }
        .overlay {
            if drawerOpen {
                MenuDrawer { item in
                    drawerOpen = false
                    drawerRoute = item
                } close: {
                    withAnimation(.easeOut(duration: 0.2)) { drawerOpen = false }
                }
                .transition(.move(edge: .leading))
            }
        }
    }

    private func unlock() async {
        if await PrivacyGate.authenticate(reason: "Unlock Hisaab") {
            locked = false
            lockMessage = nil
        } else {
            lockMessage = "Try Again"
        }
    }

    private var lockScreen: some View {
        ZStack {
            Rectangle().fill(Color(.systemBackground)).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44))
                Text("Hisaab is locked").font(.title2.weight(.semibold))
                if let lockMessage { Text(lockMessage).foregroundStyle(.red).accessibilityIdentifier("lockMessage") }
                Button("Unlock") { Task { await unlock() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("unlockButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lockScreen")
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.icon).font(.system(size: 20))
                        Text(item.rawValue).font(.system(size: 10, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(tab == item ? Color.blue : Color.primary)
                    .background(RoundedRectangle(cornerRadius: 24).fill(tab == item ? Color.gray.opacity(0.15) : .clear))
                    .overlay(alignment: .topTrailing) {
                        if item == .bills, model.attention.badge > 0 {
                            Text("\(model.attention.badge)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                                .background(Capsule().fill(.red)).offset(x: -4, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item == .bills && model.attention.badge > 0 ? "\(item.rawValue), \(model.attention.badge)" : item.rawValue)
                .accessibilityAddTraits(tab == item ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("tab-\(item.rawValue)")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 12).padding(.bottom, 4)
    }
}
