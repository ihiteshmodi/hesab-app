Feature: One-time import of a reviewed expense list (Mac tool)
  As someone moving from a spreadsheet to the app
  I want my reviewed history converted into an app database file
  So that the app starts with my real numbers and I can check them against the spreadsheet

  # Runs on the Mac, outside the app. Reads a reviewed CSV and, optionally, a personal
  # entity-aliases CSV and a list of card names, all kept in an ignored folder.
  # Writes a database file I then import in the app under Backup. Tests use made-up data only.
  # Columns: date, description, amount, payment, category are required; new_description,
  # sub_category, entity, spent_for, tags, route and my_note are optional; others are ignored.

  Background:
    Given a CSV with these rows
      | date       | description  | new_description | amount | payment    | category         | sub_category | entity       | spent_for | tags     | route   | my_note |
      | 2026-10-01 | milk         | Milk            | 50.50  | UPI        | Groceries        | Milk         | Dairy Co     | -         | -        | expense | -       |
      | 2026-10-02 | Fibre bill   | -               | 1,060  | Visa Card  | Home & Utilities | Internet     | Netco        | -         | -        | expense | monthly |
      | 2026-10-03 | Cab for mom  | -               | 300    | UPI        | Transport        | Ride share   | -            | Mom       | a;b      | expense | -       |
      | 2026-10-04 | Friend share | -               | -1,125 | UPI        | Miscellaneous    | -            | -            | -         | -        | expense | -       |
      | 2026-10-05 | Old salary   | -               | 150,000| UPI        | Miscellaneous    | -            | -            | -         | -        | income  | -       |
      | 2026-10-06 | Free sample  | -               | 0      | UPI        | Groceries        | -            | -            | -         | -        | expense | -       |
    And "Visa Card" is named as a card
    And "Netco" is aliased to "Net Company"

  Scenario: A dry run changes nothing and shows what would happen
    When Priya runs the tool with "--dry-run"
    Then it reports the counts and the totals
    And no database file is written

  Scenario: Rows become expenses with every detail kept
    When Priya runs the tool
    Then "Milk" is an expense of 50.50 with entity "Dairy Co" and sub-category "Milk"
    And the new description is used when there is one and the old one otherwise
    And "Cab for mom" is spent for "Mom" with the tags "a" and "b"
    And "Fibre bill" carries the note "monthly"

  Scenario: Cards, UPI and other payments are mapped
    When Priya runs the tool
    Then "Fibre bill" is paid with the card "Visa Card" and appears in Card Bills
    And "Milk" is paid with UPI

  Scenario: The aliases file renames entities
    When Priya runs the tool
    Then "Fibre bill" has the entity "Net Company"

  Scenario: Negative amounts and income rows become money received
    When Priya runs the tool
    Then "Friend share" is a "Money Received" entry of 1,125
    And "Old salary" is a "Money Received" entry of 150,000
    And no expense has a negative amount

  Scenario: A zero amount row is skipped and reported
    When Priya runs the tool
    Then "Free sample" is not imported
    And the report lists it as skipped

  Scenario: Totals can be checked against the spreadsheet
    When Priya runs the tool
    Then the report shows the total of the imported expenses
    And the report shows "Left to spend"

  Scenario: The tool refuses to overwrite an existing database
    Given the output file already exists
    When Priya runs the tool
    Then it stops with "Output file already exists. Choose a new name or remove it."
    And the existing file is unchanged

  Scenario: A row that cannot be read stops the import and is named
    Given one row has the date "2026-13-45"
    When Priya runs the tool
    Then it stops and names the row
    And no database file is written

  Scenario: The personal files never reach the repository
    Then the CSV, the aliases and the card list live in an ignored folder
    And the tool's tests use made-up data only

  # Everything the spreadsheet holds, not only expenses. Each extra file is optional.
  # income.csv: date, amount, kind (salary, savings, investment_income, money_received, borrowed), note
  # bills.csv: name, amount, category, sub_category, entity, payment, next_due, repeat, ends, automatic, alert, notes
  # planned.csv: description, amount
  # ledgers.csv: name, counts_towards_net_worth; ledger_entries.csv: ledger, date, description, amount
  # portfolio.csv: kind (bank_balance, holding, allocation, scheme), name, amount, currency, rate, date, payout, payout_day, maturity, closed
  # expenses.csv gains refundable and reimbursed (Yes or No).

  Scenario: Refund flags become refund states
    Given an expense "Train ticket" of 1,200 that is refundable and reimbursed
    And an expense "Online order" of 600 that is refundable and not reimbursed
    And an expense "Milk" of 50 that is neither
    When Priya runs the tool
    Then "Train ticket" is settled with 1,200 received
    And "Online order" is pending with nothing received
    And "Milk" is not refundable

  Scenario: Income rows keep their kind
    Given income rows for salary, investment income and savings
    When Priya runs the tool
    Then each is saved with its kind and note
    And "Left to spend" counts salary and investment income and subtracts savings

  Scenario: Zero-amount income rows are skipped and reported
    Given a savings row of 0 with the note "no investment this month"
    When Priya runs the tool
    Then it is not imported
    And the report lists it with its note

  Scenario: Bills start on the date given and an automatic bill adds nothing on the first launch
    Given an automatic monthly bill whose next due date is in the future
    When Priya runs the tool
    Then the bill exists with that due date
    And running the automatic bills on the import day adds no expense

  Scenario: Planned items keep their total
    Given two planned items of 600 and 2,000
    When Priya runs the tool
    Then the planned total is 2,600

  Scenario: Ledgers come with their entries and net-worth flag
    Given a ledger "Aunty" that counts towards net worth with entries 5,000 and -1,200
    And a ledger "Friend" that does not count
    When Priya runs the tool
    Then "Aunty" holds 3,800 and counts towards net worth
    And "Friend" does not count

  Scenario: The portfolio is rebuilt
    Given a bank balance, a rupee holding, a 10 USD holding at 80 rupees, an allocation and a scheme with a maturity date
    When Priya runs the tool
    Then the bank balance, holdings, allocation and scheme are in the app
    And net worth equals bank balance minus ledgers and allocations plus investments plus counted ledgers

  Scenario: The report shows every figure to check against the spreadsheet
    When Priya runs the tool
    Then it shows refunds settled and pending, the planned total, each ledger balance, investments and net worth
