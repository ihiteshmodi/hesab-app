Feature: Record an expense
  As someone tracking daily spending
  I want to add an expense in a few taps
  So that the budget stays correct without opening a spreadsheet

  Background:
    Given today is 2026-10-30

  Scenario: Priya adds an expense
    When Priya adds an expense
      | date       | description      | amount | category         | sub-category | payment method |
      | 2026-10-30 | Weekly groceries | 1,250  | Groceries        | Ration       | UPI            |
    Then the expense appears in the October list
    And "Left to spend" drops by 1,250

  Scenario Outline: Priya cannot save an incomplete expense
    When Priya tries to save an expense with <field> <problem>
    Then she sees "<message>"
    And no expense is saved

    Examples:
      | field         | problem  | message                 |
      | amount        | empty    | Enter an amount above 0 |
      | amount        | 0        | Enter an amount above 0 |
      | amount        | -50      | Enter an amount above 0. To record money received, add it under Income. |
      | description   | empty    | Enter a description     |
      | category       | empty    | Choose a category       |

  Scenario: Sub-categories are suggested so spellings do not drift
    Given a "Milk" sub-category already exists under "Groceries"
    When Priya types "milk" as the sub-category
    Then she is offered the existing "Milk" and no near-duplicate is created

  Scenario: Priya adds an expense with a future date
    When Priya adds an expense dated 2026-11-10
    Then it counts in "Left to spend" immediately
    And it appears in November, not October

  Scenario: Priya edits an expense
    Given an expense of 1,250 exists
    When she changes the amount to 1,350
    Then "Left to spend" drops by a further 100

  Scenario: Priya deletes an expense
    Given an expense of 1,250 exists
    When she chooses "Delete Expense" and confirms
    Then the expense is gone
    And "Left to spend" rises by 1,250

  Scenario: Priya changes her mind about deleting
    Given an expense of 1,250 exists
    When she chooses "Delete Expense" and cancels
    Then the expense is still there

  Scenario Outline: The payment method decides what the expense touches
    Given "Left to spend" shows 20,000, cash in hand shows 5,000 and Mom's ledger shows 40,000
    When Priya adds a 1,000 expense paid with "<method>"
    Then "Left to spend" shows <left to spend>
    And cash in hand shows <cash>
    And Mom's ledger shows <ledger>

    Examples:
      | method          | left to spend | cash  | ledger |
      | UPI             | 19,000        | 5,000 | 40,000 |
      | Visa Card       | 19,000        | 5,000 | 40,000 |
      | Cash Withdrawal | 19,000        | 5,000 | 40,000 |
      | Cash            | 20,000        | 4,000 | 40,000 |
      | Mom             | 20,000        | 5,000 | 39,000 |

  Scenario: A new ledger can be chosen as a payment method
    When Priya adds the ledger "Aunt"
    Then "Aunt" appears in the payment methods list

  Scenario: Editing an expense paid from a ledger updates that ledger
    Given a 4,000 expense paid from the Neighbor ledger which showed 28,000
    When Priya changes the amount to 4,500
    Then the Neighbor ledger shows 23,500
    When she deletes the expense and confirms
    Then the Neighbor ledger shows 28,000

  Scenario: A ledger with expenses paid from it cannot be deleted
    Given 3 expenses were paid from "Aunt"
    When Priya tries to delete the ledger "Aunt"
    Then she sees "Aunt has 3 expenses paid from it. Change their payment method first."

  Scenario: Priya adds her own payment method
    When Priya adds the payment method "Rewards Card" and marks it as a card
    Then "Rewards Card" can be chosen on new expenses
    And it appears in Card Bills
