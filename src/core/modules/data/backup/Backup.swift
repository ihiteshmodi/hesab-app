import Foundation
import GRDB

public enum BackupError: Error, Equatable, Sendable {
    case notABackup
    case newerVersion
    case couldNotWrite

    public var message: String {
        switch self {
        case .notABackup: "This isn't a budget backup. Choose a file exported from this app."
        case .newerVersion: "This backup is from a newer version of the app. Update the app first."
        case .couldNotWrite: "Could not write the file. Try again."
        }
    }
}

/// What a restore is about to do, shown to the person before anything changes.
public struct ImportPreview: Equatable, Sendable {
    public let file: URL
    public let currentEntries: Int
    public let backupEntries: Int

    public var message: String {
        "This replaces \(Self.entries(currentEntries)) with \(Self.entries(backupEntries))."
    }

    private static func entries(_ count: Int) -> String {
        "\(count) \(count == 1 ? "entry" : "entries")"
    }
}

public struct ExportData: Sendable {
    let database: AppDatabase
    let clock: any DayClock

    /// Writes a consistent copy of everything into `directory` and returns the file.
    public func callAsFunction(into directory: URL) throws -> URL {
        let file = directory.appendingPathComponent("budget-\(clock.today().isoString).sqlite")
        try BackupFile.copy(database, to: file)
        return file
    }
}

public struct PrepareImport: Sendable {
    let database: AppDatabase

    /// Checks the file without touching the current data.
    public func callAsFunction(_ file: URL) throws -> ImportPreview {
        ImportPreview(
            file: file, currentEntries: try BackupFile.entryCount(of: database.writer),
            backupEntries: try BackupFile.inspect(file)
        )
    }
}

public struct ConfirmImport: Sendable {
    let database: AppDatabase
    let clock: any DayClock

    /// Keeps the previous data as "before-import-<date>.sqlite" in `directory`, then replaces it.
    public func callAsFunction(_ preview: ImportPreview, keepingPreviousIn directory: URL) throws {
        _ = try BackupFile.inspect(preview.file)
        try BackupFile.copy(database, to: directory.appendingPathComponent("before-import-\(clock.today().isoString).sqlite"))
        try BackupFile.restore(preview.file, into: database)
    }
}

/// The SQLite-level work behind export and restore.
enum BackupFile {
    static func copy(_ database: AppDatabase, to file: URL) throws {
        do {
            let destination = try DatabaseQueue(path: file.path)
            try database.writer.backup(to: destination)
        } catch {
            throw BackupError.couldNotWrite
        }
    }

    /// Returns how many entries the file holds, or throws why it cannot be used.
    static func inspect(_ file: URL) throws -> Int {
        do {
            var configuration = Configuration()
            configuration.readonly = true
            let queue = try DatabaseQueue(path: file.path, configuration: configuration)
            return try queue.read { db in
                guard try db.tableExists("grdb_migrations") else { throw BackupError.notABackup }
                let applied = Set(try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations"))
                guard applied.contains("v1-expenses") else { throw BackupError.notABackup }
                guard applied.isSubset(of: Set(AppDatabase.migrator.migrations)) else { throw BackupError.newerVersion }
                return try entryCount(db)
            }
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.notABackup
        }
    }

    static func entryCount(of writer: any DatabaseWriter) throws -> Int {
        try writer.read { try entryCount($0) }
    }

    private static func entryCount(_ db: Database) throws -> Int {
        var total = 0
        for table in ["expense", "income_entry"] where try db.tableExists(table) {
            total += try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
        }
        return total
    }

    /// Replaces the open database's contents in place, then brings an older file up to the current schema.
    static func restore(_ file: URL, into database: AppDatabase) throws {
        var configuration = Configuration()
        configuration.readonly = true
        let source = try DatabaseQueue(path: file.path, configuration: configuration)
        try source.backup(to: database.writer)
        try AppDatabase.migrator.migrate(database.writer)
    }
}
