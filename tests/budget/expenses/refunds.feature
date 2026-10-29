Feature: Track refunds and reimbursements
  As someone who sometimes pays first and gets money back later
  I want to record how much actually came back
  So that I see my true spend without extra "loss" entries

  # Net amount = amount - received.
  # States: not refundable, pending, settled (received 0 up to amount).

  Background:
    Given today is 2026-10-30

  Scenario: Priya marks an order as refundable
    Given Priya added a 600 order
    When she marks it as refundable
    Then it is pending
    And its net amount is 600
    And "Pending refunds" shows 1 expense for 600

  Scenario: Priya marks an old expense as refundable weeks later
    Given a normal 1,250 expense from three weeks ago
    When she opens it and chooses "Mark as Refundable"
    Then it is pending
    And she can then record the amount received

  Scenario: A full refund brings the net to zero
    Given a pending 2,000 order
    When Priya records 2,000 received
    Then the order is settled
    And its net amount is 0

  Scenario: A partial refund leaves the difference as the cost
    Given a pending 1,200 train ticket
    When Priya records 900 received
    Then the ticket is settled
    And its net amount is 300
    And "Left to spend" rises by 900
    And no separate loss entry is needed

  Scenario: A refund that never comes is closed with nothing received
    Given a pending 600 order
    When Priya records 0 received
    Then the order is settled
    And its net amount is 600

  Scenario: Summary across several refundable expenses
    Given these refundable expenses this month
      | description  | amount | received |
      | Train ticket | 1,200  | 900      |
      | Order A      | 2,000  | 2,000    |
      | Order B      | 600    | -        |
    When Priya opens the refunds summary
    Then pending shows 1 expense with 600 still to come back
    And settled shows 2 expenses with 2,900 received
    And "Spent this month" for these three is 900

  Scenario: A pending refund from an earlier month stays visible
    Given a pending 600 order from September
    When Priya views October
    Then "Pending refunds" still includes it

  Scenario: Priya views only the pending refunds, across all months
    Given pending refunds of 600 from September and 300 from October
    When she opens "Pending Refunds"
    Then she sees both, oldest first
    And the total still to come back shows 900
    And she can record the received amount from that list

  Scenario: Nothing is pending
    Given no refunds are pending
    When she opens "Pending Refunds"
    Then she sees "Nothing pending. Refunds you are waiting for appear here."

  Scenario: Cash expenses cannot be refundable
    Given a 500 expense paid with "Cash"
    When Priya tries to mark it as refundable
    Then she sees "Cash expenses can't be refunded."

  Scenario: A refundable expense cannot be switched to cash
    Given a pending 500 expense paid by "UPI"
    When Priya changes its payment method to "Cash"
    Then she sees "Unmark it as refundable first. Cash expenses can't be refunded."
    And the payment method stays "UPI"

  Scenario: A refund on a ledger-paid expense goes back to that ledger
    Given a pending 500 expense paid from the Neighbor ledger which shows 27,500
    When Priya records 500 received
    Then the Neighbor ledger shows 28,000

  Scenario: Priya corrects the amount received
    Given a settled 1,200 ticket with 900 received
    When she changes the received amount to 1,000
    Then its net amount is 200

  Scenario: Priya undoes a settlement
    Given a settled 1,200 ticket with 900 received
    When she undoes the settlement
    Then the ticket is pending
    And its net amount is 1,200

  Scenario: Priya unmarks a pending expense
    Given a pending 600 order
    When she unmarks it as refundable
    Then it is a normal expense with net amount 600

  Scenario: Received money cannot exceed the amount
    Given a pending 1,200 ticket
    When Priya records 1,300 received
    Then she sees "Received can't be more than 1,200"
    And the ticket stays pending

  Scenario: Received money cannot be negative
    Given a pending 1,200 ticket
    When Priya records -100 received
    Then she sees "Enter an amount of 0 or more"

  Scenario: Money cannot be received on a normal expense
    Given a 1,200 ticket that is not marked refundable
    Then she cannot record received money on it
    And she is offered "Mark as refundable"
