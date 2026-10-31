# Hisaab: a private, offline budget app for iPhone

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![Data](https://img.shields.io/badge/data-stays%20on%20your%20phone-green)

> Track what is left to spend, where your money went and what you own, in one native app that never goes online. Your data lives in a single SQLite file on your phone.

**Status: in daily use.** Every screen in the approved mockups is built: Activity (Spending, Upcoming, Savings and a month calendar of daily spending), Bills (a calendar of bills and expected payouts with a filter menu, or a list), Portfolio, Reports, Trips and Search, plus a menu drawer for everything else. New requirements are specified in [`tests/`](tests) as Gherkin scenarios first (see [Roadmap](#roadmap)).

## Why it exists

Budget apps want accounts, sync and subscriptions. Hisaab is for one person on one phone: no account, no server, no tracking. You can export the database file whenever you like and keep it wherever you choose.

## Quick Start

You need a Mac with Xcode 16 or later (built and tested with Xcode 27) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/ihiteshmodi/hesab-app.git
cd hesab-app
swift test                # runs the core tests, no simulator needed
./scripts/build-ipa.sh    # builds an unsigned IPA for sideloading
```

Expected output:

```text
✔ Test run with 410 tests in 33 suites passed after 1.5 seconds.
...
Built build/Hisaab.ipa
```

Install `build/Hisaab.ipa` with any sideloading tool (for example LiveContainer or AltStore). The app starts empty: no data is shipped with the source.

To run the simulator UI tests as well:

```bash
SIMULATOR_NAME="iPhone 16" ./scripts/test.sh --ui
```

## Usage

The core is a Swift package (`HisaabCore`) with no UI code. The app talks to it only through `BudgetApp`.

### Add an expense and read the month

```swift
import HisaabCore

let database = try AppDatabase.inMemory()   // or AppDatabase.file(at: someURL)
let app = BudgetApp(database: database, clock: SystemDayClock())

try app.addExpense(NewExpense(
    description: "Weekly groceries",
    amount: .rupees(1250),
    category: "Home & Utilities"
))

let month = try app.monthBudget()
print(month.expenses.map(\.description))            // ["Weekly groceries"]
print(IndianMoneyFormat.string(month.spentThisMonth)) // ₹1,250.00
print(IndianMoneyFormat.string(month.leftToSpend))    // −₹1,250.00 (income comes in a later slice)
```

### Incomplete input is refused with a message you can show

```swift
do {
    try app.addExpense(NewExpense(description: "Tea", amount: nil, category: "Food & Dining"))
} catch let error as ExpenseValidationError {
    print(error.message)   // Enter an amount above 0
}
```

### Read an amount as typed

```swift
MoneyInput.parse("₹ 1,23,456.78")   // Money(paise: 12_345_678)
MoneyInput.parse("12.345")          // nil: more than two decimals
```

### Back up and restore

In the app, open the menu (the round button on Activity) and choose **Export Data** or **Import Data**: Export saves `budget-<date>.sqlite`, and Import replaces the current data with a file exported from the app (a copy of the previous data is kept first as `before-import-<date>.sqlite`). The same from code:

```swift
let file = try app.exportData(into: folderURL)                  // budget-2026-10-30.sqlite
let preview = try app.prepareImport(file)                       // preview.message: "This replaces 2 entries with 3 entries."
try app.confirmImport(preview, keepingPreviousIn: folderURL)
```

### Convert a spreadsheet export into a database (Mac, one time)

```bash
swift run hisaab-import expenses.csv hisaab.sqlite --aliases aliases.csv --card "Visa Card" [--dry-run]
```

`expenses.csv` needs the columns `date` (YYYY-MM-DD), `description`, `amount`, `payment`, `category`; `new_description`, `sub_category`, `entity`, `spent_for`, `tags`, `route` and `my_note` are optional. Negative amounts and `route=income` rows become Money Received entries, zero rows are skipped and listed. The tool prints the expense total and Left to spend so you can check them against the sheet, and refuses to overwrite an existing file. Keep your CSV, aliases and the resulting database outside the repository, then import the database in the app under Backup.

## Configuration

Hisaab needs no environment variables, keys or accounts.

| Setting | Description | Default | Required |
|---|---|---|---|
| Database file | `Application Support/Hisaab/hisaab.sqlite` inside the app's own storage | created on first launch | No |
| Launch argument `-ui-testing` | Uses an empty in-memory database (used by the UI tests) | off | No |
| Launch arguments `-ui-app-lock`, `-ui-auth-fail` | UI tests only: start with App Lock on, or make Face ID fail | off | No |
| Bundle identifier | Set in `project.yml` (`app.hisaab.Hisaab`); change it if you sign the app yourself | `app.hisaab.Hisaab` | No |
| Minimum iOS | Set in `project.yml` and `Package.swift` | 17.0 | No |

If the database cannot be opened the app stops at launch instead of running on empty data.

## Core API

### `BudgetApp.addExpense(_ new: NewExpense) throws -> Expense`

| Field | Meaning |
|---|---|
| `date` | Day of the expense; defaults to today |
| `description` | Required, trimmed |
| `amount` | `Money?`; must be above 0 |
| `category` | Required |

Errors (`ExpenseValidationError`, each with a human-readable `message`):

- `amountMissingOrZero`: "Enter an amount above 0"
- `amountNegative`: "Enter an amount above 0. To record money received, add it under Income."
- `descriptionMissing`: "Enter a description"
- `categoryMissing`: "Choose a category"

### `BudgetApp.monthBudget(for:) throws -> MonthBudget`

Defaults to the month containing today. Returns `leftToSpend` (everything ever recorded), `spentThisMonth`, and that month's `expenses`, newest first.

## Privacy

- No network code and no network permission.
- No analytics, accounts or secrets.
- The repository contains no personal data. A fresh install is empty.
- Backup and restore is one file you control (Export Data and Import Data in the menu).
- **Hide Balances** (Settings) shows ₹ •••• until you tap the eye. The savings bank balance and the Portfolio tab always stay hidden until Face ID (or the passcode) confirms, and hide again when you leave.
- **App Lock** (Settings) asks for Face ID when the app opens or comes back from the background. It can only be turned on after Face ID succeeds once.

## How it is built

- SwiftUI app, a pure Swift core, SQLite through [GRDB](https://github.com/groue/GRDB.swift).
- Amounts are whole paise (integers), dates are calendar days, and totals are computed from entries rather than stored.
- Feature-first folders: code in `src/core/modules/<capability>/<feature>`, specs and tests in `tests/<capability>/<feature>`.

```text
src/core/        domain rules, use cases, SQLite repositories (Swift package, no UI)
src/app/         SwiftUI screens and the composition root; src/app/design has the card look from the mockups
tests/           Gherkin specs (.feature) beside the Swift tests; tests/e2e has simulator UI tests
docs/design/     impact map, architecture, test strategy
scripts/         test and IPA build scripts
```

Design notes: [impact map](docs/design/budget-app/impact-map.md), [architecture](docs/design/budget-app/architecture.md), [test strategy](docs/design/budget-app/test-strategy.md).

## Roadmap

Built: expenses, income, refunds, planned expenses and bills (with a calendar and filter menu), Activity's Upcoming list and month calendar, categories and entities, search and reports, ledgers, cash in hand, card bills, amount to repay, foreign currencies, backup and restore, a one-time spreadsheet importer, portfolio and net worth, payout schemes with reminders, Hide Balances and App Lock, and trips (split expenses with friends, in any currency, with the main ledger following bank and card money only).

Specified next (see the `.feature` files): spending insights polish and anything you add as a new requirement.
