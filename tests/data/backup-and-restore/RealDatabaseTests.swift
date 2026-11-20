import Foundation
import GRDB
import Testing
@testable import HisaabCore

/// The owner's own export, kept in the git-ignored output/ folder. These run only where that file exists,
/// so every schema change is proved against real data before it ships.
struct RealDatabaseTests {
    private static let export: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("output/budget-2026-11-20.sqlite")

    private static var present: Bool { FileManager.default.fileExists(atPath: export.path) }

    @Test(.enabled(if: RealDatabaseTests.present))
    func theRealExportRestoresIntoTheCurrentSchemaWithEveryEntryKept() throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("real-\(UUID().uuidString).sqlite")
        try FileManager.default.copyItem(at: Self.export, to: scratch)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let app = BudgetApp(database: try AppDatabase.inMemory(), clock: FixedDayClock(date: day("2026-11-20")))

        let source = try DatabaseQueue(path: scratch.path)
        let expenseRows = try source.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM expense") ?? 0 }
        let incomeRows = try source.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM income_entry") ?? 0 }

        let preview = try app.prepareImport(scratch)
        try app.confirmImport(preview, keepingPreviousIn: FileManager.default.temporaryDirectory)

        #expect(preview.backupEntries == expenseRows + incomeRows)
        #expect(try app.spendingBreakdown(.allTime, by: .category).expenses.count == expenseRows)
        // Every screen's data loads on the migrated file.
        _ = try app.monthBudget()
        _ = try app.trips()
        _ = try app.payoutSchemes().sorted(by: .maturity)
        _ = try app.upcomingIncome()
        _ = try app.searchIncome("a")
    }
}
