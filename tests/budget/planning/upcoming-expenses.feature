Feature: Upcoming expenses (heads-up list)
  As someone who knows some bigger expenses are coming
  I want a list that reminds me of them
  So that nothing surprises me, without touching the budget until I commit

  # Upcoming items never change "Left to spend". Turning one into an expense does.

  Background:
    Given today is 2026-10-30
    And these upcoming items
      | description    | amount | target date |
      | Dental checkup | 3,000  | 2026-11-15  |
      | Helmet         | 2,000  | -           |

  Scenario: Priya sees what is coming
    When she opens Upcoming
    Then she sees both items
    And "Upcoming total" shows 5,000
    And "Left to spend" is unchanged

  Scenario: Priya turns an item into an expense with one tap
    When she taps Add on "Dental checkup"
    Then the New Expense form opens pre-filled with 3,000, the description and the date 2026-11-15
    And it previews "Left to spend" dropping by 3,000
    When she saves it
    Then an expense of 3,000 dated 2026-11-15 is created
    And the item leaves the Upcoming list
    And "Left to spend" drops by 3,000
    And "Upcoming total" shows 2,000

  Scenario: An item without a target date is dated today
    When she taps Add on "Helmet" and saves it
    Then an expense of 2,000 dated 2026-10-30 is created

  Scenario: Priya cancels the form
    When she taps Add on "Helmet" and cancels
    Then "Helmet" is still in the Upcoming list
    And no expense is created

  Scenario: Priya adjusts the amount while converting
    When she adds "Helmet" as an expense with the amount 2,400
    Then the expense is 2,400

  Scenario: An item past its target date is flagged
    Given today is 2026-11-20
    Then "Dental checkup" shows "Target date passed"

  Scenario: Priya adds an upcoming item
    When she adds "Gift" for 1,500
    Then "Upcoming total" shows 6,500

  Scenario Outline: Priya cannot save an incomplete item
    When she tries to save an upcoming item with description "<description>" and amount <amount>
    Then she sees "<message>"

    Examples:
      | description | amount | message                 |
      |             | 1000   | Enter a description     |
      | Gift        | 0      | Enter an amount above 0 |

  Scenario: Priya deletes an item
    When she chooses "Delete Item" on "Helmet" and confirms
    Then "Upcoming total" shows 3,000

  Scenario: Nothing is upcoming
    Given there are no upcoming items
    Then she sees "No upcoming expenses yet. Add one to keep it in view."
