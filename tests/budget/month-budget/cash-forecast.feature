Feature: Next 30 days: will I run short?
  As someone who pays bills on fixed days
  I want to see where Left to spend is heading over the next 30 days
  So that I can see a short spell coming and act before it arrives

  # The line starts at today's Left to spend. Each bill she pays from the bank comes off on its due date.
  # Each expected payout goes on its date, unless her last payout from that scheme went to savings.
  # Her usual daily spending (the last 3 full months, bills left out) comes off every day.

  Background:
    Given today is 2026-11-20 and she has 100,000 of Left to spend

  Scenario: A bill comes off on its due date
    Given "Rent" of 10,000 is due on 2026-11-25
    Then the line holds 100,000 until day 5, then 90,000
    And "Bills out" reads 10,000
    And the lowest point is 90,000 on day 5

  Scenario: Only bills inside the 30 days count
    Given "Rent" repeats monthly from 2026-11-25
    Then 2026-12-25 is outside the window and not counted

  Scenario: A repeating bill that falls twice in the window counts twice
    Given "Gym" of 1,000 repeats weekly from 2026-11-21
    Then it comes off on days 1, 8, 15, 22 and 29

  Scenario: A bill that is past due and not added yet comes off today
    Given "Internet" of 800 was due on 2026-11-15 and is not added
    Then 800 comes off on day 0

  Scenario: Bills paid in cash or from a ledger do not change Left to spend
    Given "Maid" of 800 is paid in cash
    Then the line is unchanged

  Scenario: Usual daily spending comes off every day
    Given she spent 9,200 from the bank over August, September and October
    Then 100 comes off every day

  Scenario: Spending that came from bills is not counted as usual daily spending
    Given October's only expense was the bill "Rent" of 5,000
    Then usual daily spending is 0

  Scenario: An expected payout goes on its date
    Given "Post office" pays 1,850 on the 25th
    Then 1,850 is added on day 5 and "Payouts in" reads 1,850

  Scenario: A payout that her last one sent to savings is left out
    Given the last "Post office" payout was recorded with Add to savings
    Then the next payout is not added

  Scenario: The line can go below zero
    Given a bill bigger than Left to spend is due in a week
    Then the lowest point is below zero and says so

  Scenario: Nothing set up
    Given no bills, payouts or history
    Then the line is flat at today's Left to spend

  Scenario: Unpaid trip payments come off on their due date
    Given a started trip with a payment of 10,000 due on 2026-11-25
    Then 10,000 comes off on day 5 and counts in "Bills out"

