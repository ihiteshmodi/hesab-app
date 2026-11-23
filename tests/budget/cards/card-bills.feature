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

  # Per-card monthly due days, paid-up-to cutoff dates, carryover and unpaid badge count.

  Scenario: Each card follows its own monthly due day
    Given "Travel Card" has due day 20
    And expenses on "Travel Card" of 462 on 2026-11-15 and 800 on 2026-11-22
    When Priya views Card Bills for November 2026 on 2026-11-23
    Then "Travel Card" shows a November cycle bill of 462 due on 2026-11-20 and 800 new since 2026-11-20

  Scenario: Marking paid up to a cutoff date settles through that date and keeps newer charges for next month
    Given "Travel Card" has due day 20
    And expenses on "Travel Card" of 462 on 2026-11-15 and 800 on 2026-11-22
    When Priya marks "Travel Card" paid for November 2026 up to 2026-11-20
    Then "Travel Card" shows 462 paid up to 2026-11-20, 0 due for November, and 800 new since 2026-11-20
    When she switches Card Bills to December 2026
    Then "Travel Card" shows 800 due for December

  Scenario: Paying early with a custom cutoff date moves later charges into the new counter and next month
    Given "Travel Card" has due day 20
    And expenses on "Travel Card" of 462 on 2026-11-15, 300 on 2026-11-19 and 500 on 2026-11-22
    When Priya marks "Travel Card" paid for November 2026 up to 2026-11-18
    Then "Travel Card" shows 462 paid up to 2026-11-18, 0 due for November, and 800 new since 2026-11-18
    When she switches Card Bills to December 2026
    Then "Travel Card" shows 800 due for December

  Scenario: An unpaid card bill carries over into the next month until settled
    Given "Travel Card" has due day 20
    And expenses on "Travel Card" of 462 on 2026-11-15 and 800 on 2026-11-22
    When Priya switches Card Bills to December 2026 without paying November
    Then "Travel Card" shows 462 carried over, an 800 December bill, and 1,262 total due
    When she marks "Travel Card" paid for December 2026 up to 2026-12-20
    Then both November and December show 0 due on "Travel Card"

  Scenario: Unpaid card bills in the current cycle are counted for the red badge
    Given today is 2026-11-23
    And "Travel Card" (due day 20) has 462 on 2026-11-15 and 800 on 2026-11-22
    And "Shopping Card" (due day 25) has 3,697 on 2026-11-11
    Then the unpaid card bills count is 2
    When Priya marks "Travel Card" paid for November 2026 up to 2026-11-20
    Then the unpaid card bills count is 1 even though "Travel Card" has 800 accruing for December

  Scenario: A card can be edited or deleted when unused, and renaming moves its expenses with it
    Given "Old Card" has a 500 expense and "Unused Card" has none
    When Priya renames "Old Card" to "Everyday Card" with due day 15
    Then "Everyday Card" has due day 15 and still holds the 500 expense
    And she can delete "Unused Card"
    And deleting "Everyday Card" is refused because it has expenses on it
