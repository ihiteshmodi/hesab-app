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

  # D6: planned against what was really spent, per category
  Scenario: Planned against paid, by category
    Given the trip has started with Transport planned at IDR 6,500,000 and Stay at IDR 8,000,000
    And IDR 6,500,000 of Transport and IDR 4,000,000 of Stay are paid
    Then Transport reads paid 6,500,000 of 6,500,000 and Stay reads 4,000,000 of 8,000,000

  Scenario: Spending in a category that was never planned shows against a plan of zero
    Given a trip expense in "Food & Dining" and nothing planned there
    Then "Food & Dining" reads paid against a plan of 0

  # Feedback round: start date, notes, paying in parts with due dates, reminders, and travel legs.
  Scenario: A trip can have a start date as well as an end date
    When I make a trip from 2026-12-10 to 2026-12-18
    Then both dates are kept
    And a trip cannot end before it starts

  Scenario: A plan item keeps a note, and the note follows it to the expense
    Given "Flights" is planned with the note "Window seat, 2 bags"
    When I tick it as paid
    Then the trip expense has the same note

  Scenario: A plan item can be paid in parts, each with its own due date
    Given "Group tour" is planned in two parts: "Advance" 20,000 due 2026-11-25 and "Balance" 60,000 due 2027-01-10
    Then the item totals 80,000 and nothing is paid
    And the parts are listed by due date

  Scenario: Each part is ticked on its own
    When I tick "Advance" as paid
    Then the trip expense "Group tour · Advance" of 20,000 exists
    And 60,000 is still to pay
    When I tick "Balance" as well
    Then the item shows as paid

  Scenario: An item paid in parts cannot be ticked as a whole
    When I tick "Group tour" as a whole
    Then I see "This item is paid in parts. Tick each part instead."

  Scenario: A paid part cannot be changed or removed
    Given "Advance" is paid
    When I remove it
    Then I see "A part that is paid can't be changed. Untick it first."

  Scenario: An item already paid cannot be split into parts
    Given "Flights" was ticked as paid
    When I add a part to it
    Then I see "Flights is already paid, so it can't be split into parts."

  Scenario: Removing every part puts the item back to one amount
    Given "Group tour" has two unpaid parts
    When I remove both
    Then it is one item again, tickable as a whole

  Scenario: A payment due soon shows a red count
    Given the trip has started and "Advance" is due in 3 days and "Balance" in 60 days
    Then the trip shows a red 1, on its row, on its Plan tab and on the Trips tab
    And the advance reads "Due in 3 days"
    And a payment past its date reads "Overdue by 2 days"

  Scenario: Only unpaid payments of started trips remind her
    Given a paid advance, and a payment on a trip still being planned
    Then neither shows a red count

  Scenario: Trip payments due soon count against the 30-day look at Left to spend
    Given an unpaid trip payment of IDR 1,000,000 due in 10 days at rate 0.0053
    Then 5,300 comes off Left to spend on day 10

  Scenario: A travel leg keeps mode, route, carrier, number and times
    Given "Flights" is planned
    When I add a leg: flight, Delhi to Denpasar, IndiGo 6E 1175, leaves 2026-12-10 at 06:40, arrives 15:05
    Then the leg is kept, marked planned until she marks it booked

  Scenario: The trip lists every leg in date order
    Given an onward train and flight, and a return flight
    Then the itinerary lists them by date and time, with the item each belongs to
    And a leg with no date comes last

  Scenario Outline: A leg must make sense
    When I save a leg that <problem>
    Then I see "<message>"

    Examples:
      | problem                       | message                                  |
      | arrives before it leaves      | The leg can't arrive before it leaves.   |
      | leaves at 25:00               | Enter a time between 00:00 and 23:59     |

