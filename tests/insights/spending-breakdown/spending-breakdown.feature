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
