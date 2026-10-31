import HisaabCore
import SwiftUI
import UniformTypeIdentifiers

struct BackupScreen: View {
    let model: BudgetViewModel
    @State private var exportedFile: SQLiteDocument?
    @State private var exportFileName = "budget.sqlite"
    @State private var exporting = false
    @State private var choosingFile = false
    @State private var pendingImport: ImportPreview?
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        CardScreen {
            CardGroup(footer: "Your data lives only on this phone. Export it to keep your own copy; nothing leaves the phone unless you share the file.") {
                Button { export() } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up").foregroundStyle(Theme.blue).rowPadding()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exportDataButton")
                Button { choosingFile = true } label: {
                    Label("Import Data", systemImage: "square.and.arrow.down").foregroundStyle(Theme.blue).rowPadding()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("importDataButton")
            }
            if let message {
                CardPanel {
                    Text(message)
                        .foregroundStyle(messageIsError ? Theme.red : Theme.green)
                        .accessibilityIdentifier("backupMessage")
                }
            }
        }
        .cardNavigation("Backup")
        .fileExporter(
            isPresented: $exporting, document: exportedFile, contentType: SQLiteDocument.sqlite,
            defaultFilename: exportFileName
        ) { result in
            if case .failure = result { show("Could not save the file. Try again.", isError: true) }
            else { show("Exported \(exportFileName).", isError: false) }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.data]) { result in
            choose(result)
        }
        .confirmationDialog(
            pendingImport?.message ?? "", isPresented: Binding(
                get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }
            ), titleVisibility: .visible
        ) {
            Button("Replace My Data", role: .destructive) { confirm() }
                .accessibilityIdentifier("confirmImportButton")
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            Text("A copy of your current data is kept first.")
        }
    }

    private func export() {
        let result = model.exportData()
        guard let file = result.file, let data = try? Data(contentsOf: file) else {
            show(result.error ?? "Could not export. Try again.", isError: true)
            return
        }
        exportFileName = file.lastPathComponent
        exportedFile = SQLiteDocument(data: data)
        exporting = true
    }

    private func choose(_ result: Result<URL, any Error>) {
        guard case .success(let picked) = result else { return }
        let granted = picked.startAccessingSecurityScopedResource()
        defer { if granted { picked.stopAccessingSecurityScopedResource() } }
        // Copy first: the picked file may live in a place the app can only read while access is open.
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString).sqlite")
        do {
            try FileManager.default.copyItem(at: picked, to: copy)
        } catch {
            show("Could not read that file. Try again.", isError: true)
            return
        }
        let outcome = model.prepareImport(copy)
        if let preview = outcome.preview {
            pendingImport = preview
        } else {
            show(outcome.error ?? "Could not read that file.", isError: true)
        }
    }

    private func confirm() {
        guard let preview = pendingImport else { return }
        pendingImport = nil
        if let error = model.confirmImport(preview) {
            show(error, isError: true)
        } else {
            show("Imported \(preview.backupEntries) entries.", isError: false)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}

struct SQLiteDocument: FileDocument {
    static let sqlite = UTType(filenameExtension: "sqlite") ?? .data
    static let readableContentTypes: [UTType] = [.data]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
