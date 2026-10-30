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
