import Foundation
import HisaabCore

/// Environment checks and wiring live here and nowhere else.
enum CompositionRoot {
    static func makeApp() -> BudgetApp {
        do {
            let arguments = ProcessInfo.processInfo.arguments
            let database = arguments.contains("-ui-testing")
                ? try AppDatabase.inMemory()
                : try AppDatabase.file(at: try databaseFileURL())
            let app = BudgetApp(database: database, clock: SystemDayClock())
            // The in-memory test database starts empty, so a test asks for the lock to be on from the first screen.
            if arguments.contains("-ui-testing"), arguments.contains("-ui-app-lock") { try app.updatePreferences { $0.appLock = true } }
            return app
        } catch {
            // Without its database the app has nothing to show, so stop rather than run on empty data.
            fatalError("Could not open the Hisaab database: \(error)")
        }
    }

    private static func databaseFileURL() throws -> URL {
        try dataFolder().appendingPathComponent("hisaab.sqlite")
    }

    /// Where the copy of the previous data goes before a restore.
    static func backupsFolder() throws -> URL {
        let folder = try dataFolder().appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func dataFolder() throws -> URL {
        let folder = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Hisaab", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
