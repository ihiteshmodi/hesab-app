import SwiftUI

@main
struct HisaabApp: App {
    @State private var budget = BudgetViewModel(app: CompositionRoot.makeApp())

    var body: some Scene {
        WindowGroup {
            RootView(model: budget)
        }
    }
}
