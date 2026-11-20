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

  # Activity gets a small search field between the summary card and the Expenses / Income / Calendar card.
  # It searches expenses and income together; the Search tab shows both too.
  Scenario Outline: Income matches note, type or amount
    Given the income entries "Post office" 1,850 (Investment Income), "October pay" 90,000 (Salary) and "Ben paid" 1,125 (Money Received)
    When she searches for "<text>"
    Then she sees income <results>

    Examples:
      | text   | results                     |
      | post   | "Post office"               |
      | SALARY | "October pay"               |
      | 1125   | "Ben paid"                  |

  Scenario: One search finds both expenses and income
    Given an expense "Post office stamps" and the income "Post office"
    When she types "post office" in the Activity search field
    Then she sees the expense under Expenses and the income under Income

  Scenario: Clearing the search brings back the month
    When she clears the Activity search field
    Then she sees the month's expenses, income or calendar again

  Scenario: Opening an income result lets her change it
    When she taps "Post office" in the income results
    Then the Edit Income form opens

  # Activity search follows the tab she is on.
  Scenario: On the Expenses tab only expenses are searched
    Given an expense and an income entry both called "Post office"
    When she types "post office" in the Activity search field on the Expenses tab
    Then she sees the expense and no income

  Scenario: On the Income tab only income is searched
    When she is on the Income tab and types "post office"
    Then she sees the income entry and no expense

  Scenario: The Calendar tab has no search field
    When she opens the Calendar tab
    Then there is no search field
    And going back to Expenses shows the field empty

