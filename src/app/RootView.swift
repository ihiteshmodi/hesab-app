import SwiftUI

struct RootView: View {
    let model: BudgetViewModel

    var body: some View {
        TabView {
            BudgetScreen(model: model)
                .tabItem { Label("Activity", systemImage: "list.bullet") }
            BillsScreen(model: model)
                .tabItem { Label("Bills", systemImage: "calendar") }
                .badge(model.attention.badge)
            ReportsScreen(model: model)
                .tabItem { Label("Reports", systemImage: "chart.pie") }
            SearchScreen(model: model)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
    }
}
