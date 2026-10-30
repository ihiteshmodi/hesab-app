Feature: One-time spreadsheet import (Mac tool)
  As someone moving from a spreadsheet to the app
  I want my history converted into an app database file
  So that the app starts with my real numbers and I can check them against the spreadsheet

  # Runs on the Mac, outside the app. Reads a .ods file and a personal mapping file
  # that lives in an ignored folder. Writes a database file I then import in the app.
  # Tests use made-up data only.

  Background:
    Given a spreadsheet with these expense rows
      | description         | amount | sub category | main category        | refundable | refunded |
      | Train ticket        | 1,200  | -            | Transport            | Yes        | Yes      |
      | Online order        | 600    | -            | Shopping - Needs     | Yes        | No       |
      | Fibre bill          | 1,060  | Internet Bill | Shopping - Wants    | No         | No       |
      | Milk                | 50     | Ration - milk | Home & Utilities    | No         | No       |
      | Milk                | 50     | Ration - Milk | Home & Utilities    | No         | No       |
      | Friend paid share   | -1,125 | -            | Miscellaneous        | No         | No       |
    And income rows for salary 150,000, investment income 800 and savings 100,000
    And a personal mapping file

  Scenario: A dry run changes nothing and shows what would happen
    When Priya runs the tool with "--dry-run"
    Then it prints counts per sheet and the totals
    And no database file is written

  Scenario: Totals match the spreadsheet's own numbers
    When Priya runs the tool
    Then the database's "Left to spend" equals the spreadsheet's "Amount Remaining for Spending"
    And the database's total net spend equals the sum of the spreadsheet's Net Amount column

  Scenario: Refund flags become refund states
    When Priya runs the tool
    Then "Train ticket" is settled with 1,200 received
    And "Online order" is pending with nothing received
    And every other expense is not refundable

  Scenario: A negative amount becomes money received
    When Priya runs the tool
    Then "Friend paid share" is a "Money Received" entry of 1,125
    And no expense has a negative amount

  Scenario: The mapping file cleans categories
    Given the mapping merges "Ration - milk" into "Ration - Milk"
    And moves "Internet Bill" to "Home & Utilities"
    When Priya runs the tool
    Then both milk rows share one sub-category
    And "Fibre bill" is under "Home & Utilities"

  Scenario: The mapping file splits an old main category by what the row is
    Given the mapping says rows of the old main category "Transport & Vehicle" with the sub category "Repairs & Maintenance" belong to the parent "Vehicle"
    When Priya runs the tool
    Then those rows are under "Vehicle"
    And no expense is left without a parent category

  Scenario: Entity prefixes in descriptions are split off using the mapping file
    Given a row described "HIGHWAY DHABA - sev bhaji"
    And the mapping lists "HIGHWAY DHABA" as an entity named "Highway Dhaba"
    When Priya runs the tool
    Then the expense is described "Sev bhaji" with the entity "Highway Dhaba"
    And "Highway Dhaba" is saved in the entities list

  Scenario: Rows without a listed entity are imported unchanged
    Given a row described "Weekly groceries"
    When Priya runs the tool
    Then the expense is described "Weekly groceries" with no entity

  Scenario: The mapping file fixes known wrong rows
    Given the mapping re-dates an income row to 2026-04-30
    When Priya runs the tool
    Then that row carries the new date

  Scenario: The tool refuses to overwrite an existing database
    Given the output file already exists
    When Priya runs the tool
    Then it stops with "Output file already exists. Choose a new name or remove it."
    And the existing file is unchanged

  Scenario: A failure part-way leaves no half-written database
    Given one row has an unreadable date
    When Priya runs the tool
    Then it stops and names the row
    And no database file is written

  Scenario: The personal mapping never reaches the repository
    Then the mapping file lives in an ignored folder
    And the tool's tests use made-up data only
