Feature: Record income, savings, money received and borrowing
  As someone paid once a month
  I want to log what comes in and what I move to savings
  So that "left to spend" reflects my real spending money

  Background:
    Given today is 2026-10-30

  Scenario: Priya records her salary
    When Priya adds income of type "Salary" for 150,000 dated 2026-10-30
    Then "Left to spend" rises by 150,000
    And October income shows salary 150,000

  Scenario: Priya moves money to savings
    When Priya adds "Savings" of 100,000
    Then "Left to spend" drops by 100,000

  Scenario: Investment payouts are income
    When Priya adds "Investment Income" of 800 with note "Bond A"
    Then "Left to spend" rises by 800

  Scenario: A friend pays back their share
    When Priya adds "Money Received" of 1,125 with note "Ben paid his share"
    Then "Left to spend" rises by 1,125
    And no expense is changed

  Scenario: Borrowing from savings is not income
    When Priya adds "Borrowed" of 10,000 from "Savings"
    Then "Left to spend" rises by 10,000
    And October income does not include the 10,000
    And "Amount to repay" shows 10,000

  Scenario Outline: Priya cannot save incomplete income
    When Priya tries to save income with amount <amount> and type <type>
    Then she sees "<message>"

    Examples:
      | amount | type   | message                 |
      | empty  | Salary | Enter an amount above 0 |
      | 0      | Salary | Enter an amount above 0 |
      | 5000   | empty  | Choose a type           |

  Scenario: Priya deletes an income entry
    Given a salary entry of 150,000
    When she chooses "Delete Entry" and confirms
    Then "Left to spend" drops by 150,000

  Scenario: Priya changes an income entry
    Given a salary entry of 150,000 on 2026-10-30
    When she opens it and changes the amount to 160,000, the type to "Money Received", the note to "bonus" and the date to 2026-10-31
    Then "Left to spend" shows 160,000
    And the entry shows those new details

  Scenario: A changed income entry is checked like a new one
    Given a salary entry of 150,000
    When she changes the amount to 0
    Then she sees "Enter an amount above 0"
    And the entry is unchanged

