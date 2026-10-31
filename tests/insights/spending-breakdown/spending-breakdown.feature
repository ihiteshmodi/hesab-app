Feature: Where the money went
  As someone who wants to understand my spending
  I want to see spending by category and by payment method
  So that I can see which habits cost me the most

  # Figures use net amounts. Cash-paid and ledger-paid expenses are included here even though
  # they are not part of "Left to spend"; they are labelled by their payment method.

  Background:
    Given October 2026 net spending
      | main category    | payment method | net   |
      | Food & Dining    | UPI            | 2,000 |
      | Food & Dining    | Cash           | 1,000 |
      | Home & Utilities | Visa Card      | 5,000 |
      | Transport        | UPI            | 2,000 |

  Scenario: Priya sees spending by main category
    When she opens Insights for October
    Then the categories are listed largest first
      | category         | amount | share |
      | Home & Utilities | 5,000  | 50%   |
      | Food & Dining    | 3,000  | 30%   |
      | Transport        | 2,000  | 20%   |
    And the total shows 10,000

  Scenario: Priya sees spending by payment method
    When she switches to "Payment Method"
    Then the methods are listed
      | method    | amount |
      | Visa Card | 5,000  |
      | UPI       | 4,000  |
      | Cash      | 1,000  |

  Scenario: Priya drills into a category
    Given "Food & Dining" has sub-categories "Online food order" 1,800 and no sub-category 1,200
    When she taps "Food & Dining"
    Then she sees the sub-categories with their amounts
    And the expenses behind them

  Scenario: Refunds lower the figures
    Given a 1,200 ticket under Transport with 900 received
    Then Transport counts 300 for that ticket

  Scenario: A month with no spending
    When she opens Insights for September
    Then she sees "No spending in September."

  Scenario: Every chart has a list with the same figures
    When she opens Insights for October
    Then the same categories and amounts are available as a list below the chart

  Scenario: Priya looks at all time
    When she chooses "All Time"
    Then the categories add up every month's net spending

  # Reports show spending only. Income is never part of these totals.

  Scenario Outline: Priya groups spending in other ways
    Given expenses with entities, spent-for names, sub-categories and tags
    When she groups by "<grouping>"
    Then the rows are "<rows>"

    Examples:
      | grouping     | rows                                                        |
      | Spent for    | Me, Mom                                                     |
      | Sub-category | Restaurant (Food & Dining), Food & Dining (no sub-category) |
      | Tag          | Dubai trip, No tag                                          |

  Scenario: An expense with two tags is counted under each tag but once in the total
    Given a 1,000 expense tagged "Avenger" and "Dominar"
    When she groups by "Tag"
    Then "Avenger" and "Dominar" each show 1,000
    And the total is 1,000

  Scenario: Priya opens any row, not only a category
    When she taps "No entity" in the entity view
    Then she sees the expenses with no entity, newest first
    And their split by category

  Scenario: Priya keeps only the rows that make up most of her spending
    Given categories of 5,000, 3,000, 1,000 and 1,000
    When she sets the slider to 80%
    Then she sees the first two rows, which make 80%
    And one "Everything else" row of 2,000

  Scenario: The same slider keeps the biggest expenses inside a row
    Given expenses of 600, 300 and 100 under Food & Dining
    When she opens it with the slider at 80%
    Then she sees the 600 and 300 expenses
