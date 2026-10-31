import Foundation
import GRDB
import Testing
@testable import HisaabCore

/// Scenarios from tests/data/backup-and-restore/backup-and-restore.feature
struct BackupTests {
    /// A scratch folder that disappears with the test.
    private final class Folder {
        let url: URL

        init() throws {
            url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: url) }

        func file(_ name: String) -> URL { url.appendingPathComponent(name) }
    }

    private func app(_ database: AppDatabase, today: String = "2026-10-30") -> BudgetApp {
        BudgetApp(database: database, clock: FixedDayClock(date: day(today)))
    }

    private func record(_ app: BudgetApp, _ descriptions: [String]) throws {
        for description in descriptions {
            try app.addExpense(NewExpense(
                date: day("2026-10-12"), description: description, amount: .rupees(100), category: "Groceries"
            ))
        }
    }

    private func descriptions(_ app: BudgetApp) throws -> Set<String> {
        Set(try app.monthBudget(for: .init(year: 2026, month: 10)).expenses.map(\.description))
    }

    /// An exported file holding the given expenses.
    private func backup(_ folder: Folder, containing items: [String]) throws -> URL {
        let source = app(try AppDatabase.inMemory())
        try record(source, items)
        return try source.exportData(into: folder.url)
    }

    @Test func exportingWritesOneFileNamedAfterToday() throws {
        let folder = try Folder()
        let source = app(try AppDatabase.inMemory())
        try record(source, ["Milk"])

        let file = try source.exportData(into: folder.url)

        #expect(file.lastPathComponent == "budget-2026-10-30.sqlite")
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func anExportedFileRestoresTheSameEntries() throws {
        let folder = try Folder()
        let file = try backup(folder, containing: ["Milk", "Bread"])
        let target = app(try AppDatabase.inMemory())

        let preview = try target.prepareImport(file)
        try target.confirmImport(preview, keepingPreviousIn: folder.url)

        #expect(try descriptions(target) == ["Milk", "Bread"])
    }

    @Test func anImportIsSeenEvenRightAfterTheOldEntriesWereRead() throws {
        let folder = try Folder()
        let file = try backup(folder, containing: ["Milk", "Bread"])
        let target = app(try AppDatabase.inMemory())
        try record(target, ["Tea"])
        _ = try descriptions(target)

        try target.confirmImport(try target.prepareImport(file), keepingPreviousIn: folder.url)

        #expect(try descriptions(target) == ["Milk", "Bread"])
    }

    @Test func exportingTwiceOnTheSameDayReplacesTheEarlierFile() throws {
        let folder = try Folder()
        let source = app(try AppDatabase.inMemory())
        try record(source, ["Milk"])
        try source.exportData(into: folder.url)
        try record(source, ["Bread"])

        let file = try source.exportData(into: folder.url)

        let reopened = app(try AppDatabase.file(at: file))
        #expect(try descriptions(reopened) == ["Milk", "Bread"])
    }

    @Test func importAnnouncesWhatItReplaces() throws {
        let folder = try Folder()
        let file = try backup(folder, containing: ["Milk", "Bread", "Eggs"])
        let target = app(try AppDatabase.inMemory())
        try record(target, ["Rice", "Dal"])

        let preview = try target.prepareImport(file)

        #expect(preview.currentEntries == 2)
        #expect(preview.backupEntries == 3)
        #expect(preview.message == "This replaces 2 entries with 3 entries.")
    }

    @Test func importCountsIncomeAsEntriesAndSaysEntryForOne() throws {
        let folder = try Folder()
        let source = app(try AppDatabase.inMemory())
        try source.addIncome(NewIncome(date: day("2026-10-01"), kind: .salary, amount: .rupees(1_000)))
        let file = try source.exportData(into: folder.url)
        let target = app(try AppDatabase.inMemory())
        try record(target, ["Rice"])

        let preview = try target.prepareImport(file)

        #expect(preview.message == "This replaces 1 entry with 1 entry.")
    }

    @Test func choosingABackupButNotConfirmingChangesNothing() throws {
        let folder = try Folder()
        let file = try backup(folder, containing: ["Milk"])
        let target = app(try AppDatabase.inMemory())
        try record(target, ["Rice"])

        _ = try target.prepareImport(file)

        #expect(try descriptions(target) == ["Rice"])
    }

    @Test func confirmingKeepsACopyOfThePreviousDataFirst() throws {
        let folder = try Folder()
        let file = try backup(folder, containing: ["Milk"])
        let target = app(try AppDatabase.inMemory())
        try record(target, ["Rice"])

        try target.confirmImport(try target.prepareImport(file), keepingPreviousIn: folder.url)

        let kept = folder.file("before-import-2026-10-30.sqlite")
        #expect(try descriptions(app(try AppDatabase.file(at: kept))) == ["Rice"])
    }

    @Test func aFileThatIsNotADatabaseIsRefusedAndNothingChanges() throws {
        let folder = try Folder()
        let photo = folder.file("photo.jpg")
        try Data("not a database at all, just some bytes".utf8).write(to: photo)
        let target = app(try AppDatabase.inMemory())
        try record(target, ["Rice"])

        #expect(throws: BackupError.notABackup) { try target.prepareImport(photo) }
        #expect(try descriptions(target) == ["Rice"])
    }

    @Test func aDatabaseFromAnotherAppIsRefused() throws {
        let folder = try Folder()
        let other = folder.file("other.sqlite")
        let queue = try DatabaseQueue(path: other.path)
        try queue.write { try $0.execute(sql: "CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)") }
        let target = app(try AppDatabase.inMemory())

        #expect(throws: BackupError.notABackup) { try target.prepareImport(other) }
    }

    @Test func aDatabaseWithSomeoneElsesMigrationsIsRefusedAsNotABackup() throws {
        let folder = try Folder()
        let other = folder.file("other.sqlite")
        try DatabaseQueue(path: other.path).write {
            try $0.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
            try $0.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES ('create-notes')")
        }
        let target = app(try AppDatabase.inMemory())

        #expect(throws: BackupError.notABackup) { try target.prepareImport(other) }
    }

    @Test func aFileThatStopsBeingABackupBeforeConfirmingChangesNothing() throws {
        let folder = try Folder()
        let file = try backup(folder, containing: ["Milk"])
        let target = app(try AppDatabase.inMemory())
        try record(target, ["Rice"])
        let preview = try target.prepareImport(file)
        try Data("overwritten".utf8).write(to: file)

        #expect(throws: BackupError.notABackup) { try target.confirmImport(preview, keepingPreviousIn: folder.url) }
        #expect(try descriptions(target) == ["Rice"])
        #expect(!FileManager.default.fileExists(atPath: folder.file("before-import-2026-10-30.sqlite").path))
    }

    @Test func aBackupFromANewerVersionIsRefused() throws {
        let folder = try Folder()
        let file = try backup(folder, containing: ["Milk"])
        try DatabaseQueue(path: file.path).write {
            try $0.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES ('v999-from-the-future')")
        }
        let target = app(try AppDatabase.inMemory())
        try record(target, ["Rice"])

        #expect(throws: BackupError.newerVersion) { try target.prepareImport(file) }
        #expect(try descriptions(target) == ["Rice"])
    }

    @Test func aBackupFromAnOlderVersionIsUpgradedWithAllItsEntries() throws {
        let folder = try Folder()
        let old = folder.file("old.sqlite")
        let queue = try DatabaseQueue(path: old.path)
        try AppDatabase.migrator.migrate(queue, upTo: "v3-income")
        try queue.write {
            try $0.execute(sql: """
                INSERT INTO expense (date, description, amount_paise, category)
                VALUES ('2026-10-12', 'Old milk', 6000, 'Groceries')
                """)
        }
        let target = app(try AppDatabase.inMemory())

        let preview = try target.prepareImport(old)
        try target.confirmImport(preview, keepingPreviousIn: folder.url)

        #expect(preview.backupEntries == 1)
        #expect(try descriptions(target) == ["Old milk"])
        #expect(try target.cards().map(\.name) == ["Credit Card"])
    }

    @Test func errorsReadInPlainWords() {
        #expect(BackupError.notABackup.message == "This isn't a budget backup. Choose a file exported from this app.")
        #expect(BackupError.newerVersion.message
            == "This backup is from a newer version of the app. Update the app first.")
    }
}
