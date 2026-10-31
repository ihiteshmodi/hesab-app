import Foundation
import HisaabCore
import HisaabImport

// hisaab-import <expenses.csv | folder> <output.sqlite> [--aliases file.csv] [--card NAME]... [--dry-run]

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
    fail("Usage: hisaab-import <expenses.csv | folder> <output.sqlite> [--aliases file.csv] [--card NAME]... [--dry-run]")
}
func read(_ path: String) -> String? {
    guard var text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
    return text
}

var isFolder: ObjCBool = false
FileManager.default.fileExists(atPath: positional[0], isDirectory: &isFolder)
let source = positional[0]
var bundle: ImportBundle
if isFolder.boolValue {
    guard let expenses = read(source + "/expenses.csv") else { fail("Cannot read \(source)/expenses.csv") }
    bundle = ImportBundle(
        expenses: expenses, income: read(source + "/income.csv"), bills: read(source + "/bills.csv"),
        planned: read(source + "/planned.csv"), ledgers: read(source + "/ledgers.csv"),
        ledgerEntries: read(source + "/ledger_entries.csv"), portfolio: read(source + "/portfolio.csv")
    )
} else {
    guard let expenses = read(source) else { fail("Cannot read \(source)") }
    bundle = ImportBundle(expenses: expenses)
}

do {
    let report = try CSVImporter.run(
        bundle: bundle, options: options, output: dryRun ? nil : URL(fileURLWithPath: positional[1])
    )
    print(dryRun ? "Dry run, nothing written." : "Wrote \(positional[1]).")
    print("Expenses: \(report.expenses), total \(IndianMoneyFormat.string(report.expenseTotal))")
    print("Money received entries: \(report.moneyReceived)")
    print("Total spent after refunds: \(IndianMoneyFormat.string(report.netExpenseTotal))")
    print("Refunds settled: \(report.refundsSettled), pending: \(report.refundsPending)")
    print("Income entries: \(report.incomeEntries), bills: \(report.bills), planned total \(IndianMoneyFormat.string(report.plannedTotal))")
    print("Left to spend: \(IndianMoneyFormat.string(report.leftToSpend))")
    for (name, balance) in report.ledgerBalances.sorted(by: { $0.key < $1.key }) { print("Ledger \(name): \(IndianMoneyFormat.string(balance))") }
    print("Bank balance: \(IndianMoneyFormat.string(report.bankBalance))")
    print("Investments: \(IndianMoneyFormat.string(report.investments))")
    print("Net worth: \(IndianMoneyFormat.string(report.netWorth))")
    for line in report.skipped { print("Skipped: \(line)") }
} catch let error as ImportError {
    fail(error.message)
} catch {
    fail("Import failed: \(error)")
}
