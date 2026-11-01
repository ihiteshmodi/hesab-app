Feature: Amount to repay
  As someone who sometimes borrows from my own savings or from a person
  I want to see what I still owe back
  So that borrowed money is never mistaken for income

  # Borrowing raises "Left to spend"; repaying lowers it, like a savings transfer.
  # Borrowing never changes any people ledger.

  Background:
    Given today is 2026-10-30
    And "Left to spend" shows 20,000
    And Mom's ledger shows 40,000

  Scenario: Priya borrows from her savings
    When Priya adds "Borrowed" of 10,000 from "Savings"
    Then "Amount to repay" shows 10,000
    And "Left to spend" shows 30,000
    And Mom's ledger still shows 40,000

  Scenario: Priya repays part of it
    Given she borrowed 10,000 from "Savings"
    When she records a repayment of 4,000
    Then "Amount to repay" shows 6,000
    And "Left to spend" shows 26,000

  Scenario: Priya repays the rest
    Given she borrowed 10,000 and repaid 4,000
    When she records a repayment of 6,000
    Then the borrowing is marked "Repaid"
    And "Amount to repay" shows 0

  Scenario: Priya cannot repay more than is owed
    Given she borrowed 10,000 and repaid 4,000
    When she records a repayment of 7,000
    Then she sees "Repayment can't be more than the 6,000 still to repay"

  Scenario: Several lenders are shown together
    Given Priya owes 6,000 to "Savings" and 2,500 to "Ben"
    Then "Amount to repay" shows 8,500
    And each lender is listed with what is still owed

  Scenario: Priya deletes a borrowing that has repayments
    Given she borrowed 10,000 and repaid 4,000
    When she chooses "Delete Borrowing" and confirms
    Then the borrowing and its repayments are removed
    And "Left to spend" returns to what it was before borrowing

  # A borrowing arrives either as cash or in the bank; so does each repayment (it starts as the same way).
  # Cash moves "Cash in hand"; the bank moves "Left to spend". Never both.
  Scenario: Borrowing in cash raises cash in hand but not left to spend
    When Priya borrows 3,000 from "Ben" in cash
    Then "Cash in hand" rises by 3,000
    And "Left to spend" stays 20,000
    And "Amount to repay" shows 3,000

  Scenario: Borrowing into the bank raises left to spend but not cash in hand
    When Priya borrows 3,000 from "Ben" into the bank
    Then "Left to spend" shows 23,000
    And "Cash in hand" stays 0

  Scenario: Repaying from cash lowers cash in hand but not left to spend
    Given she borrowed 3,000 from "Ben" in cash
    When she repays 1,000 from cash
    Then "Cash in hand" drops by 1,000 and "Left to spend" does not change

  Scenario: A repayment can come from a different pocket than the borrowing
    Given she borrowed 3,000 from "Ben" in cash
    When she repays 1,000 from the bank
    Then "Left to spend" drops by 1,000 and "Cash in hand" does not change

  Scenario: Cash borrowings and repayments appear in the cash list with their titles
    Given she borrowed 3,000 from "Ben" in cash and repaid 1,000 from cash
    When she opens Cash in Hand
    Then she sees "Borrowed from Ben" +3,000 and "Repaid Ben" -1,000 with the running balance

  # The Amount to repay screen has two lists: what is still owed and what is fully paid back.
  Scenario: The Amount to repay screen separates active and repaid borrowings
    Given Priya owes 6,000 to "Savings" and repaid "Ben" in full
    When she opens Amount to repay
    Then "Active" lists the Savings borrowing and "Repaid" lists Ben's

  Scenario: Priya adds a borrowing from the Amount to repay screen
    When she chooses "Add Borrowing", enters "Ben", 3,000 and "Cash"
    Then the borrowing is listed under "Active" and "Amount to repay" shows 3,000

  Scenario: Priya changes a borrowing or a repayment
    Given she borrowed 10,000 from "Ben" in cash and repaid 4,000
    When she opens the borrowing and chooses "Edit Borrowing" to change the amount or lender
    Then the owed amount follows
    When she taps the repayment and changes its amount, date or pocket
    Then the owed amount and the pocket totals follow, and it cannot exceed what was owed
