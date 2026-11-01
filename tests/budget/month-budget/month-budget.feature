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

  # Below the summary card a switch chooses what the Spending pane lists, so nobody scrolls past one list to reach the other.
  Scenario: A switch under the summary card chooses between expenses, income and the calendar
    Given Priya recorded an expense "Weekly groceries" and a salary this month
    When she opens Activity
    Then she sees the switch "Expenses", "Income" and "Calendar" with "Expenses" chosen
    And she sees "Weekly groceries" but not the salary
    When she chooses "Income"
    Then she sees the salary but not "Weekly groceries"
    When she chooses "Calendar"
    Then she sees the month calendar but neither list

  # Hide Balances (Settings) decides what is masked. Off: every figure shows and there is no eye.
  Scenario: With Hide Balances off every figure shows
    Given Hide Balances is off and Priya recorded a salary of 1,50,000 this month
    When she opens Activity
    Then "Left to spend", "Spent in October" and "Income in October" show their amounts
    And there is no eye on the screen

  Scenario: With Hide Balances on, Left to spend and Spent still show
    Given Hide Balances is on and Priya recorded a salary of 1,50,000 this month
    When she opens Activity
    Then "Left to spend" and "Spent in October" show their amounts while "Income in October" shows "₹ ••••"

  Scenario: With Hide Balances on, income stays hidden until she taps the eye
    Given Hide Balances is on and Priya recorded a salary of 1,50,000 this month
    When she opens Activity
    Then "Income in October" shows "₹ ••••"
    When she taps the eye on the Activity screen
    Then "Income in October" shows "₹1,50,000.00"
    When she leaves the screen and comes back
    Then "Income in October" shows "₹ ••••" again

  Scenario: The eye on the Activity screen asks for Face ID before showing
    Given Hide Balances is on and Priya recorded a salary of 1,50,000 this month
    When she taps the eye and Face ID fails
    Then "Income in October" still shows "₹ ••••" and she sees "Try Again"
    When she taps the eye and Face ID succeeds
    Then "Income in October" shows "₹1,50,000.00"
    When she taps the eye again
    Then the amounts hide at once without asking

  # Mockup 1: the month calendar shows what was spent (red minus) and earned (green plus) each day.
  Scenario: The month calendar shows what was earned each day
    Given Priya recorded a salary of 1,50,000 on 2026-10-01, savings of 10,000 on 2026-10-02 and spent 200 on 2026-10-01
    When she views October
    Then 1 Oct shows "+1.5L" in green and "-200" in red
    And 2 Oct shows nothing because savings are not income
    And with Hide Balances on and the eye not used, the green amount shows "••••"

  Scenario: The month calendar shows what was spent each day
    Given Priya spent in October
      | date       | amount | paid with |
      | 2026-10-01 | 9,000  | UPI       |
      | 2026-10-01 | 200    | UPI       |
      | 2026-10-02 | 261    | UPI       |
      | 2026-10-03 | 300    | Cash      |
    When she views October
    Then the calendar shows 9,200 on 1 Oct and 261 on 2 Oct, each in red with a minus
    And 3 Oct shows nothing because cash does not count in "Spent this month"
    And the days add up to "Spent this month"

  Scenario: The calendar starts the month on its weekday
    When she views November 2026
    Then the calendar has 30 days and 1 Nov sits under Sunday
