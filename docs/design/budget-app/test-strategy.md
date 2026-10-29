# Test strategy (draft)

Principle: tests come from the approved `.feature` scenarios, before the code. Each new test is seen failing once. Every feature gets one mutation check.

| Level | Subject | Verification | What | Share |
|---|---|---|---|---|
| 1 Pure domain | Refund state machine, budget and net-worth calculators, `Money`, `CalendarDate`, due-date rules (day 31 in short months), recurring due list | Result | Example tables (`it.each` style) from the feature files | many |
| 2 Presenters | Insight breakdown and shares, reminder wording, warnings | Result | Plain function tests | some |
| 3 Use cases (outer loop per feature) | One test per scenario: add expense, record received, add all due, record payout, pay from ledger, import backup | State and result | Real in-memory GRDB database, fixed clock, no mocks | the bulk |
| 4 Adapters | Migrations from every older schema version keep data; export then import round trip; file validation (not a database, newer version) | State | Real files in a temp folder | few |
| 5 Importer tool | Made-up ODS fixture to database: totals equal the sheet's own numbers, mapping applied, dry run, refuse overwrite, rollback | State | Fixture ODS generated from made-up rows | few |
| 6 UI and smoke | Add expense then see left to spend; mark refundable and record received; switch month; export and import | Result | XCUITest on the simulator with a seeded database and stable accessibility identifiers | a handful, plus 1 smoke on the built app |

Doubles:
- **Real in-memory database instead of repository fakes.** There is no fake repository, so no contract tests for repositories.
- **Hand-written `FixedClock`** is the only fake. Its tiny contract: it returns the date it was given and never changes.
- Library mock frameworks are not used.

Execution:
- `swift test` runs levels 1 to 5 on the Mac without a simulator.
- Simulator UI tests run less often (before a commit that changes screens, and in the final pass).
- Real-data check: the importer output is compared with the owner's own sheet totals before trusting the app.
- Fixtures use made-up names and numbers only.

Outer loop per feature: the scenario list in its `.feature` file, each as a level 3 test that fails first and passes at the end.
