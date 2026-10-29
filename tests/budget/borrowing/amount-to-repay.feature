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
