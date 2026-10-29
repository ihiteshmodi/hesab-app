Feature: What is left to spend, and what was spent this month
  As someone who budgets from one salary to the next
  I want to see how much I can still spend and how much I spent this month
  So that I know what is safe to spend before I spend it

  # "Left to spend" is what is left in the bank for bank, card and withdrawal spending.
  # Cash in hand and ledger-paid expenses are not part of it.
  # Left to spend is all-time:
  #   salary + investment income + money received + borrowed - savings - repaid - net expenses
  # "Spent this month" covers only the calendar month being viewed.

  Background:
    Given today is 2026-10-30

  Scenario: Priya sees what is left to spend
    Given Priya has recorded
      | kind              | amount  |
      | salary            | 150000  |
      | investment income | 20000   |
      | savings           | 100000  |
    And her net expenses add up to 35000
    When she opens the Budget tab
    Then "Left to spend" shows 35,000

  Scenario: Priya sees only the viewed month in "Spent this month"
    Given Priya spent a net 23,000 in September and 12,000 in October
    When she views October
    Then "Spent this month" shows 12,000
    And "Left to spend" still includes both months

  Scenario: Priya switches to a different month
    Given Priya spent a net 23,000 in September
    When she switches the month to September
    Then "Spent this month" shows 23,000

  Scenario: Salary day adds money and next month's expenses lower it straight away
    Given "Left to spend" shows 5,000
    When Priya records a salary of 150,000 and savings of 100,000
    And adds rent of 20,000 dated 2026-11-01 and a bill of 2,000 dated 2026-11-10
    Then "Left to spend" shows 33,000
    And viewing November shows "Spent this month" 22,000

  Scenario: An expense paid from cash in hand does not change left to spend
    Given "Left to spend" shows 35,000
    When Priya adds an expense of 500 paid with "Cash"
    Then "Left to spend" still shows 35,000

  Scenario: An expense paid from a ledger does not change left to spend
    Given "Left to spend" shows 35,000
    When Priya adds a 4,000 expense paid from the Neighbor ledger
    Then "Left to spend" still shows 35,000

  Scenario: A cash withdrawal does lower left to spend
    Given "Left to spend" shows 35,000
    When Priya adds a 10,000 "Cash Withdrawal" expense
    Then "Left to spend" shows 25,000

  Scenario: A pending refund still counts as spent until money arrives
    Given Priya added a 600 order marked refundable
    When no refund has been received
    Then the order counts 600 in "Spent this month"

  Scenario: Nothing recorded yet
    Given Priya has recorded nothing
    When she opens the Budget tab
    Then "Left to spend" shows 0
    And she sees "No entries yet. Add your first expense or income."
