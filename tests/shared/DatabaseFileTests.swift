import Foundation
import Testing
@testable import HisaabCore

/// The database is a single file the owner exports and restores, so it must persist across launches.
struct DatabaseFileTests {
    @Test func anExpenseSurvivesClosingAndReopeningTheDatabaseFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("hisaab.sqlite")

        let firstLaunch = BudgetApp(database: try AppDatabase.file(at: file), clock: FixedDayClock(date: day("2026-10-30")))
        try firstLaunch.addExpense(NewExpense(
            description: "Weekly groceries", amount: .rupees(1250, paise: 50), category: "Home & Utilities"
        ))

        let secondLaunch = BudgetApp(database: try AppDatabase.file(at: file), clock: FixedDayClock(date: day("2026-10-30")))

        let october = try secondLaunch.monthBudget()
        #expect(october.expenses.map(\.description) == ["Weekly groceries"])
        #expect(october.spentThisMonth == .rupees(1250, paise: 50))
    }

    @Test func openingAnExistingFileTwiceDoesNotRepeatMigrations() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("hisaab.sqlite")

        _ = try AppDatabase.file(at: file)

        #expect(throws: Never.self) { _ = try AppDatabase.file(at: file) }
    }
}
