Feature: Portfolio and net worth
  As someone who wants to know what I really own
  I want to see my bank balance, investments and net worth in one place
  So that I know what is free to allocate and what I am worth

  # Available for allocation = bank balance - all ledger balances - allocated funds
  # Investments             = manual holdings + payout schemes (not closed) + foreign cash at today's rate
  # Net worth               = available + investments + ledgers marked "counts toward my net worth"

  Background:
    Given the bank balance is 300,000
    And these ledgers
      | person   | balance | counts toward my net worth |
      | Mom      | 40,000  | no                         |
      | Sam      | 40,000  | no                         |
      | Neighbor | 30,000  | yes                        |
    And allocated funds of 20,000 for "Trip"
    And investments
      | name                | amount    |
      | Stocks              | 10,000    |
      | Payout schemes      | 1,000,000 |
    And a holding of 400 USD at a rate of 90.00

  Scenario: Priya sees available for allocation
    When she opens the Portfolio tab
    Then "Available for allocation" shows 170,000

  Scenario: Priya sees her net worth
    When she opens the Portfolio tab
    Then "Investments" shows 1,046,000
    And "Net worth" shows 1,246,000

  Scenario: Priya updates the exchange rate
    When she sets the USD rate to 92.50
    Then the USD holding shows 37,000
    And "Net worth" shows 1,247,000
    And the rate shows the date it was set

  Scenario: Priya updates the bank balance
    When she sets the bank balance to 310,000
    Then "Available for allocation" shows 180,000
    And the balance shows "as of" the date she set it

  Scenario: A ledger not counted toward net worth does not add to it
    When Priya turns off "Counts toward my net worth" for Neighbor
    Then "Net worth" shows 1,216,000

  Scenario: Allocations exceed what the bank holds
    Given the bank balance is 80,000
    When she opens the Portfolio tab
    Then "Available for allocation" shows -50,000
    And she sees a warning that allocations exceed the bank balance by 50,000

  Scenario: Priya allocates money to a goal
    When she adds an allocated fund "Repairs" of 15,000
    Then "Available for allocation" shows 155,000

  Scenario: Priya adds a holding
    When she adds a holding "Gold coin" of 25,000
    Then "Investments" shows 1,071,000

  Scenario Outline: Invalid holdings are rejected
    When she saves a holding with name "<name>" and amount <amount>
    Then she sees "<message>"

    Examples:
      | name  | amount | message                     |
      |       | 100    | Enter a name                |
      | Stock | -5     | Enter an amount of 0 or more |

  Scenario: Priya removes a holding
    When she chooses "Delete Holding" on "Stocks" and confirms
    Then "Investments" shows 1,036,000

  Scenario: Priya edits an investment
    When Priya changes "Stocks" to "Index fund" worth 12,000
    Then the investments list shows "Index fund" at 12,000
    And investments are 1,048,000

  Scenario: Priya edits an allocation
    When Priya changes "Trip" to 25,000
    Then available for allocation is 165,000
