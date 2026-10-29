import Foundation
import HisaabCore

/// Environment checks and wiring live here and nowhere else.
enum CompositionRoot {
    static func makeApp() -> BudgetApp {
        do {
            let database = ProcessInfo.processInfo.arguments.contains("-ui-testing")
                ? try AppDatabase.inMemory()
                : try AppDatabase.file(at: try databaseFileURL())
            return BudgetApp(database: database, clock: SystemDayClock())
        } catch {
            // Without its database the app has nothing to show, so stop rather than run on empty data.
            fatalError("Could not open the Hisaab database: \(error)")
        }
    }

    private static func databaseFileURL() throws -> URL {
        let folder = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Hisaab", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("hisaab.sqlite")
    }
}
