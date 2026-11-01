Feature: Cash in hand
  As someone who keeps some cash for personal spending
  I want a separate cash balance
  So that cash spending never mixes with what is left in the bank

  # Cash withdrawn from the bank is an ordinary expense (money left the bank).
  # If kept for myself it also fills cash in hand; if handed to family nothing more is tracked.
  # Spending with the payment method "Cash" lowers cash in hand and never "Left to spend".

  Background:
    Given today is 2026-10-30
    And cash in hand shows 0
    And "Left to spend" shows 20,000

  Scenario: Priya withdraws cash to keep
    When she adds a "Cash Withdrawal" expense of 10,000 and chooses "Keep as cash in hand"
    Then "Left to spend" shows 10,000
    And cash in hand shows 10,000

  Scenario: Priya withdraws cash and hands it to family
    When she adds a "Cash Withdrawal" expense of 10,000 without keeping it
    Then "Left to spend" shows 10,000
    And cash in hand still shows 0

  Scenario: Priya spends from cash in hand
    Given she kept 10,000 as cash in hand
    When she adds expenses of 450 and 1,200 paid with "Cash"
    Then cash in hand shows 8,350
    And "Left to spend" still shows 10,000

  Scenario: Priya corrects the cash she is holding
    Given cash in hand shows 8,350
    When she sets cash in hand to 8,000
    Then an adjustment of -350 is listed
    And cash in hand shows 8,000

  Scenario: Priya spends more cash than recorded
    Given cash in hand shows 100
    When she adds a 450 expense paid with "Cash"
    Then cash in hand shows -350
    And she sees "You have spent 350 more cash than you have recorded."

  Scenario: Deleting a cash expense returns the cash
    Given a 450 expense paid with "Cash" and cash in hand shows 9,550
    When Priya deletes the expense and confirms
    Then cash in hand shows 10,000

  Scenario: Changing a payment method moves the money between pools
    Given a 450 expense paid by "UPI"
    When Priya changes its payment method to "Cash"
    Then "Left to spend" rises by 450
    And cash in hand drops by 450

  Scenario: Deleting the withdrawal removes the cash it added
    Given a 10,000 withdrawal that was kept as cash in hand
    When Priya deletes the withdrawal and confirms
    Then cash in hand drops by 10,000
    And "Left to spend" rises by 10,000

  Scenario: Priya sees where her cash went
    When she opens Cash in Hand
    Then she sees each withdrawal kept, cash expense and adjustment with the running balance

  Scenario: Priya adds cash with a title
    When she chooses "Add Cash" and enters 2,000 with the title "Gift from Dad"
    Then cash in hand rises by 2,000
    And the list shows "Gift from Dad" on today's date with the new running balance
    And "Left to spend" does not change

