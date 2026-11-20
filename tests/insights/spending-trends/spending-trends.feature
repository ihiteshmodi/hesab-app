Feature: Spending trends on the Reports tab
  As someone who wants to catch overspending while it is happening
  I want to see this month against last month, my usual and the months before
  So that I notice what is different without working it out myself

  # "Spent" is the same as on the rest of Reports: every expense after refunds.
  # Income is what Settings already counts as income; moves into savings are not income.

  Background:
    Given today is 2026-11-20

  # D1: this month vs last month
  Scenario: Running spend this month against last month
    Given October had 100 on the 5th and 200 on the 25th, and November has 150 on the 3rd and 50 on the 18th
    When she opens Reports
    Then the November line runs from day 1 to day 20 and ends at 200
    And the October line runs for all 31 days
    And it says November is 100 more than October at this point (200 against 100)

  Scenario: An earlier month is compared over its whole length
    When she steps back to October
    Then the line runs for all 31 days and is compared with September's last day

  Scenario: Refunded money does not count as spent
    Given a 600 order that was fully refunded
    Then it adds nothing to the lines

  # D2: income vs spent, with savings rate
  Scenario: Six months of income against spending, with the share kept
    Given June to November with salary and investment income and expenses
    When she opens Reports
    Then each month shows income, spent and the percentage kept
    And a month with 100,000 income and 40,000 spent reads 60%
    And the month still running shows no percentage

  Scenario: Moves into savings are not income, income added to savings is
    Given a 10,000 move to Savings and 800 of investment income added to savings
    Then only the 800 counts as income

  Scenario: A month with no income has no percentage
    Given a month with spending and no income
    Then it shows no percentage

  # D3: spending vs normal
  Scenario: Categories that moved most against her usual
    Given Food is 5,000 by the 20th of November and 2,000 by the 20th in each of August, September and October
    When she opens Reports
    Then Food reads 3,000 above usual
    And money spent after the 20th in earlier months is not part of the usual

  Scenario: A category she did not spend on this month shows below usual
    Given Fuel was 1,000 by the 20th in each of the last 3 months and nothing this month
    Then Fuel reads 1,000 below usual

  Scenario: Only the biggest changes are listed
    Given eight categories that moved
    Then six are listed, the biggest moves first

  Scenario: Not enough history
    Given her first expense is from October
    Then the card says there is not enough history yet and lists nothing

  # D4: trend on each category row
  Scenario: Six months on each category row
    Given Food spending in June to November
    Then the Food row shows the six monthly amounts oldest first
    And the line is marked rising when this month is 25% or more above her usual

  Scenario: A new category is not called rising
    Given a category with no spending in earlier months
    Then it is not marked rising
