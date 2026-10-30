import Foundation
import HisaabCore
import HisaabImport

// hisaab-import <expenses.csv> <output.sqlite> [--aliases file.csv] [--card NAME]... [--dry-run]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

var arguments = Array(CommandLine.arguments.dropFirst())
var options = ImportOptions()
var dryRun = false
var positional: [String] = []

while !arguments.isEmpty {
    let argument = arguments.removeFirst()
    switch argument {
    case "--dry-run": dryRun = true
    case "--card":
        guard !arguments.isEmpty else { fail("--card needs a name") }
        options.cards.append(arguments.removeFirst())
    case "--aliases":
        guard !arguments.isEmpty else { fail("--aliases needs a file") }
        let path = arguments.removeFirst()
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fail("Cannot read \(path)") }
        options.entityAliases = CSVImporter.aliases(from: text)
    default: positional.append(argument)
    }
}

guard positional.count == (dryRun ? 1 : 2) || positional.count == 2 else {
    fail("Usage: hisaab-import <expenses.csv> <output.sqlite> [--aliases file.csv] [--card NAME]... [--dry-run]")
}
guard var text = try? String(contentsOfFile: positional[0], encoding: .utf8) else { fail("Cannot read \(positional[0])") }
if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

do {
    let report = try CSVImporter.run(
        csv: text, options: options, output: dryRun ? nil : URL(fileURLWithPath: positional[1])
    )
    print(dryRun ? "Dry run, nothing written." : "Wrote \(positional[1]).")
    print("Expenses: \(report.expenses), total \(IndianMoneyFormat.string(report.expenseTotal))")
    print("Money received entries: \(report.moneyReceived)")
    print("Left to spend: \(IndianMoneyFormat.string(report.leftToSpend))")
    for line in report.skipped { print("Skipped: \(line)") }
} catch let error as ImportError {
    fail(error.message)
} catch {
    fail("Import failed: \(error)")
}
