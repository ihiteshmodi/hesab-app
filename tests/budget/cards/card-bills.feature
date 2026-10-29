Feature: Card bills with a paid tick
  As someone who pays card bills once a month
  I want to see what each card will cost me and tick it off when paid
  So that I never lose track of what is due

  # Bill per card and calendar month = sum of (amount - received) on that card.
  # Paying a bill never changes "Left to spend": the money was counted when spent.

  Background:
    Given October 2026 expenses on cards
      | card         | description  | amount | received |
      | Visa Card    | Groceries    | 2,000  | -        |
      | Visa Card    | Train ticket | 1,200  | 900      |
      | Family Card  | Pharmacy     | 400    | -        |
      | Family Card  | Fuel         | 600    | -        |
    And an expense paid by "UPI" of 700

  Scenario: Priya sees each card's bill
    When she views Card Bills for October
    Then "Visa Card" shows 2,300
    And "Family Card" shows 1,000
    And the total due shows 3,300
    And UPI has no bill

  Scenario: Priya ticks a bill as paid
    When she ticks "Visa Card" as paid
    Then "Visa Card" shows 2,300 paid and 0 due
    And the total due shows 1,000
    And "Left to spend" is unchanged

  Scenario: A charge added after paying shows as still due
    Given "Visa Card" is ticked as paid
    When Priya adds a 150 expense on "Visa Card" dated in October
    Then "Visa Card" shows 150 due

  Scenario: Priya unticks a bill
    Given "Visa Card" is ticked as paid
    When she unticks it
    Then "Visa Card" shows 2,300 due

  Scenario: A larger refund lowers the bill
    Given "Visa Card" shows 2,300
    When Priya changes the received amount on the train ticket to 1,200
    Then "Visa Card" shows 2,000

  Scenario: A month with no card spending
    When she views Card Bills for September
    Then she sees "No card spending in September."
