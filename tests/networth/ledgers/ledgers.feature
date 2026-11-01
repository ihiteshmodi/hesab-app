Feature: People ledgers
  As someone whose account also holds other people's money
  I want a ledger for each person
  So that I always know how much of the balance is theirs

  # A ledger balance is the sum of its entries.
  # Positive = money I hold for or from that person; negative = I paid out more than I hold.
  # A flag decides whether the balance counts toward my net worth.
  # Only entries I add and expenses paid from that ledger change it.
  # Borrowing never does.

  Background:
    Given today is 2026-10-30

  Scenario: Priya adds a ledger entry
    Given Mom's ledger has an entry "Carry over" of 60,000
    When Priya adds an entry "Withdrawal" of -10,000
    Then Mom's ledger shows 50,000

  Scenario: Priya records a deposit and payouts for Sam
    Given Sam's ledger shows 0
    When Priya adds
      | item              | value   |
      | Deposit           | 100,000 |
      | Sent to account   | -30,000 |
    Then Sam's ledger shows 70,000

  Scenario: A neighbor's contributions and shares of a bill
    Given the Neighbor ledger is marked as counting toward my net worth
    When Priya adds
      | item                | value   |
      | Carry over          | 30,000  |
      | Monthly share       | 10,000  |
      | Annual tax share    | -12,000 |
    Then the Neighbor ledger shows 28,000

  # People ledgers live in Portfolio: tap a name to open and manage that person's entries.
  Scenario: Priya opens a person's ledger from Portfolio
    Given Mom 50,000 and Sam 70,000
    When she opens Portfolio and taps "Mom"
    Then she sees Mom's balance and entries, and can add or delete entries and delete the ledger
    And she can switch "Counts towards my net worth" on or off there

  Scenario: Priya adds a person from Portfolio
    When she opens Portfolio and chooses "Add Person" and enters "Aunt"
    Then "Aunt" appears in Portfolio with balance 0

  Scenario: Priya sees what is held for others
    Given Mom 50,000, Sam 70,000 and Neighbor 28,000
    When she opens Ledgers
    Then the total shows 148,000

  Scenario: Priya adds a new person
    When she adds the ledger "Aunt"
    Then "Aunt" appears with balance 0
    And she is asked whether it counts toward her net worth

  Scenario: Paying out more than the balance warns but is allowed
    Given Sam's ledger shows 5,000
    When Priya adds an entry of -8,000
    Then Sam's ledger shows -3,000
    And she sees "You have paid out 3,000 more than you hold for Sam."

  Scenario: Priya cannot add an empty entry
    When she adds an entry with value 0
    Then she sees "Enter a value other than 0"

  Scenario: An expense paid from a ledger appears in it
    Given the Neighbor ledger shows 28,000
    When Priya adds a 4,000 expense paid from the Neighbor ledger
    Then the Neighbor ledger shows 24,000
    And its entries include "Paid: <expense description>" of -4,000

  Scenario: Borrowing from savings leaves ledgers alone
    Given Mom's ledger shows 50,000
    When Priya borrows 10,000 from "Savings"
    Then Mom's ledger still shows 50,000

  Scenario: Priya deletes an entry
    Given Sam's ledger shows 70,000 from entries of 100,000 and -30,000
    When she deletes the -30,000 entry and confirms
    Then Sam's ledger shows 100,000

  Scenario: Priya deletes a person's ledger
    When she chooses "Delete Ledger" for "Aunt" and confirms
    Then "Aunt" and all her entries are gone


  # Every entry and every person can be changed, not only added or deleted.
  Scenario: Priya changes an old entry in a person's ledger
    Given Mom's ledger has "Carry over" 60,000 on 2 Sep and "Withdrawal" -10,000
    When she taps "Carry over" and changes it to "Carry over one time" 65,000 on 2 Sep
    Then Mom's balance shows 55,000

  Scenario: Priya renames a person
    When she opens Mom's ledger and renames it to "Mummy"
    Then the ledger is called "Mummy" everywhere
    And a name already used by another person is refused
