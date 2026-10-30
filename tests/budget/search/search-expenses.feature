Feature: Search expenses
  As someone with a long history
  I want to find an entry by typing a few letters
  So that I can check what I paid, to whom, and when

  Background:
    Given these expenses
      | description     | entity        | category         | notes             | amount | date       |
      | Weekly groceries| Metro Dairy   | Home & Utilities |                   | 1,250  | 2026-10-29 |
      | Sev bhaji       | Highway Dhaba | Food & Dining    |                   | 116    | 2026-10-24 |
      | Fuel additive   | Amazon        | Shopping – Needs | for the scooter   | 145    | 2026-10-27 |
      | Water tax       |               | Annual Fixed     |                   | 3,120  | 2026-04-19 |

  Scenario Outline: Text matches description, entity, category, notes or amount
    When she searches for "<text>"
    Then she sees <results>

    Examples:
      | text    | results                           |
      | sev     | "Sev bhaji"                       |
      | HIGHWAY | "Sev bhaji"                       |
      | scooter | "Fuel additive"                   |
      | food    | "Sev bhaji"                       |
      | 1250    | "Weekly groceries"                |
      | tax     | "Water tax"                       |

  Scenario: Results are grouped by month, newest first, with a total
    When she searches for "a"
    Then the results are grouped under "October 2026" and "April 2026"
    And within a month the newest comes first
    And the total of the results is shown

  Scenario: Nothing matches
    When she searches for "xyz"
    Then she sees "No expenses match "xyz"."

  Scenario: Opening a result shows the whole expense
    When she taps "Sev bhaji" in the results
    Then she sees its amount, entity, category, payment method, date and refund state
