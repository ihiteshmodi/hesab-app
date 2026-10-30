// swift-tools-version: 6.0
import PackageDescription

// The Gherkin specs live beside their tests but are documentation, not code;
// e2e holds the simulator UI tests, which only Xcode can run.
let testExclusions = [
    "e2e",
    "budget/borrowing/amount-to-repay.feature",
    "budget/cards/card-bills.feature",
    "budget/cash-in-hand/cash-in-hand.feature",
    "budget/expenses/record-expense.feature",
    "budget/expenses/refunds.feature",
    "budget/expenses/spent-for-and-tags.feature",
    "budget/income/record-income.feature",
    "budget/month-budget/month-budget.feature",
    "budget/bills/bills.feature",
    "budget/categories/categories.feature",
    "budget/currencies/foreign-currency-spending.feature",
    "budget/entities/entities.feature",
    "budget/planning/planned-expenses.feature",
    "budget/search/search-expenses.feature",
    "settings/preferences/preferences.feature",
    "data/backup-and-restore/backup-and-restore.feature",
    "data/csv-import/csv-import.feature",
    "data/spreadsheet-import/spreadsheet-import.feature",
    "insights/spending-breakdown/spending-breakdown.feature",
    "networth/ledgers/ledgers.feature",
    "networth/payout-schemes/payout-schemes.feature",
    "networth/portfolio/portfolio.feature",
    "trips/trips/trips.feature",
]

let package = Package(
    name: "Hisaab",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HisaabCore", targets: ["HisaabCore"]),
        .executable(name: "hisaab-import", targets: ["hisaab-import"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "HisaabCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: "src/core"
        ),
        .target(
            name: "HisaabImport",
            dependencies: ["HisaabCore"],
            path: "src/importer"
        ),
        .executableTarget(
            name: "hisaab-import",
            dependencies: ["HisaabImport", "HisaabCore"],
            path: "tools/hisaab-import"
        ),
        .testTarget(
            name: "HisaabCoreTests",
            dependencies: ["HisaabCore", "HisaabImport", .product(name: "GRDB", package: "GRDB.swift")],
            path: "tests",
            exclude: testExclusions
        ),
    ],
    swiftLanguageModes: [.v6]
)
