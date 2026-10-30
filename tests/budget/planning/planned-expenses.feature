Feature: Planned expenses (no date yet)
  As someone who knows some expenses are coming but not when
  I want a list of them
  So that nothing surprises me, without touching the budget until I commit

  # Anything with a date or a repeat is a Bill (see bills.feature).
  # Planned items have no date. They never change "Left to spend"; turning one into an expense does.

  Background:
    Given today is 2026-10-30
    And these planned items
      | description    | amount |
      | Dental checkup | 3,000  |
      | Helmet         | 2,000  |

  Scenario: Priya sees what is planned
    When she opens Upcoming and scrolls to "Planned"
    Then she sees both items
    And "Planned total" shows 5,000
    And "Left to spend" is unchanged

  Scenario: Priya turns an item into an expense with one tap
    When she taps Add on "Dental checkup"
    Then the New Expense form opens with 3,000, the description and today's date
    And it previews "Left to spend" dropping by 3,000
    When she saves it
    Then an expense of 3,000 dated 2026-10-30 is created
    And the item leaves the Planned list
    And "Left to spend" drops by 3,000
    And "Planned total" shows 2,000

  Scenario: Priya adjusts the amount or date while adding
    When she taps Add on "Helmet" and changes the amount to 2,400 and the date to 2026-11-03
    And saves it
    Then the expense is 2,400 dated 2026-11-03

  Scenario: Priya cancels the form
    When she taps Add on "Helmet" and cancels
    Then "Helmet" is still planned
    And no expense is created

  Scenario: Priya gives a planned item a date and it becomes a bill
    When she opens "Helmet" and sets the due date 2026-11-20
    Then "Helmet" leaves Planned and appears in Upcoming as a bill due 2026-11-20

  Scenario: Priya adds a planned item
    When she adds "Gift" for 1,500
    Then "Planned total" shows 6,500

  Scenario Outline: Priya cannot save an incomplete item
    When she tries to save a planned item with description "<description>" and amount <amount>
    Then she sees "<message>"

    Examples:
      | description | amount | message                 |
      |             | 1000   | Enter a description     |
      | Gift        | 0      | Enter an amount above 0 |

  Scenario: Priya deletes an item
    When she chooses "Delete Item" on "Helmet" and confirms
    Then "Planned total" shows 3,000

  Scenario: Nothing is planned
    Given there are no planned items
    Then she sees "Nothing planned yet. Add an expense you know is coming."
