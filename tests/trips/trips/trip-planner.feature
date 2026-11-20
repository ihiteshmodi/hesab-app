Feature: Trip planner
  As someone who is thinking about a trip
  I want to list everything it would cost before I commit to it
  So that I know the price first, and then see what I have already paid and what is still to pay

  # A trip made in planning mode has a plan: a list of things with an estimated amount and a tag
  # (Flights, Clothes, Stay ...). Tags are the categories inside a trip. Nothing in the plan touches
  # Activity or "Left to spend" until it is marked paid.

  Background:
    Given the home currency is INR
    And a trip "Bali trip" in IDR at rate 0.0053 made in planning mode

  Scenario: A trip can be made as a plan
    Then "Bali trip" is shown as "Planning"
    And its plan is empty

  Scenario: The plan adds up what the trip would cost
    When I plan "Flights" for IDR 6,000,000 tagged "Transport", "Hotel" for IDR 8,000,000 tagged "Stay" and "Shirts" for IDR 1,000,000 tagged "Shopping"
    Then the plan totals IDR 15,000,000, about 79,500 in rupees
    And it shows the totals by tag, largest first

  Scenario: Planning does not touch the main ledger
    When I plan "Flights" for IDR 6,000,000
    Then Left to spend and Activity are unchanged

  Scenario Outline: A plan item needs a name and an amount
    When I plan "<name>" for "<amount>"
    Then I see "<message>"

    Examples:
      | name    | amount | message                |
      |         | 100    | Enter a description    |
      | Flights |        | Enter an amount above 0 |
      | Flights | 0      | Enter an amount above 0 |

  Scenario: I can change or remove a plan item
    Given "Flights" is planned for IDR 6,000,000
    When I change it to IDR 7,000,000
    Then the plan totals IDR 7,000,000
    When I remove it
    Then the plan is empty

  Scenario: Starting the trip turns the plan into a real trip
    When I start the trip
    Then "Bali trip" is no longer "Planning"
    And its plan items can be ticked as paid

  Scenario: Things cannot be ticked as paid before the trip starts
    When I tick "Flights" as paid in planning mode
    Then I see "Start the trip before ticking things as paid."

  Scenario: Ticking an item as paid makes it a real expense
    Given the trip has started and "Flights" is planned for IDR 6,000,000
    When I tick "Flights" as paid and the card charges 31,500
    Then the trip has an expense "Flights" of IDR 6,000,000 that only I share
    And the ledger entry "Bali trip expenses" holds 31,500
    And Left to spend drops by 31,500
    And the plan shows "Flights" as paid and nothing left to pay for it

  Scenario: What was really paid can differ from the estimate
    Given the trip has started and "Flights" is planned for IDR 6,000,000
    When I tick it as paid for IDR 6,500,000 on 12 Oct
    Then the expense is IDR 6,500,000 dated 12 Oct
    And the plan still remembers the estimate of IDR 6,000,000

  Scenario: What is still to pay stays inside the trip
    Given the trip has started with "Flights" 6,000,000 and "Hotel" 8,000,000 planned
    When I tick "Flights" as paid
    Then "Still to pay" reads IDR 8,000,000
    And Left to spend only dropped for the flights

  Scenario: Unticking removes the expense again
    Given "Flights" was ticked as paid
    When I untick it
    Then the expense and the ledger entry are gone
    And "Flights" is still to pay

  Scenario: Deleting the expense from the trip puts the item back to still to pay
    Given "Flights" was ticked as paid
    When I delete the expense "Flights" from the trip
    Then "Flights" is still to pay

  Scenario: Deleting the trip removes its plan
    When I delete the trip
    Then its plan is gone

  Scenario: Plan items use the app's categories and sub-categories
    When I plan "Flights" for IDR 6,000,000 under "Transport" > "Flight"
    Then the plan shows its total by category as well as by tag

  Scenario: Ticking an item as paid keeps its category and sub-category
    Given the trip has started and "Flights" is planned under "Transport" > "Flight"
    When I tick "Flights" as paid
    Then the trip expense "Flights" is under "Transport" > "Flight"
    And the main ledger still holds one entry for the trip

