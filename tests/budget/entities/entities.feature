Feature: Entities (shops, services and people I pay)
  As someone who buys the same things from the same places
  I want to record where each purchase was made, separately from what it was
  So that my lists stay short and I can see how much I spend with each place

  # An expense has a short description ("Sev bhaji") and an optional entity ("Highway Dhaba").
  # The list shows the description; the entity is seen when the expense is opened.
  # Entities are saved as they are created and offered again next time.

  Background:
    Given today is 2026-10-30
    And these saved entities: "Amazon", "Meesho", "Highway Dhaba"

  Scenario: Priya adds an expense with an entity
    When she adds an expense "Sev bhaji" for 116 in "Food & Dining" with the entity "Highway Dhaba"
    Then the list row reads "Sev bhaji" without the entity
    When she opens it
    Then she sees the entity "Highway Dhaba"

  Scenario: Saved entities are suggested as she types
    When she types "high" in the Entity field
    Then she is offered "Highway Dhaba"

  Scenario: A new entity is saved on the spot
    When she adds an expense with the entity "Metro Dairy"
    Then "Metro Dairy" is saved
    And she is offered "Metro Dairy" the next time she types "met"

  Scenario: An entity remembers how it was last used
    Given her last expense with "Highway Dhaba" was in "Food & Dining" paid by "Visa Card"
    When she chooses "Highway Dhaba" on a new expense
    Then the category "Food & Dining" and the payment method "Visa Card" are suggested
    And she can change either

  Scenario: An expense can have no entity
    When she adds an expense without an entity
    Then it saves normally

  Scenario: Entity names are unique
    When she creates the entity "amazon"
    Then she sees "An entity called Amazon already exists"

  Scenario: Spending by entity for a month
    Given October expenses
      | description  | entity        | amount |
      | Fuel additive| Amazon        | 300    |
      | Candles      | Amazon        | 200    |
      | Strainer     | Meesho        | 300    |
      | Sev bhaji    | Highway Dhaba | 150    |
      | Bread        |               | 50     |
    When she opens Insights and chooses "Entity" for October
    Then she sees
      | entity        | amount | share |
      | Amazon        | 500    | 50%   |
      | Meesho        | 300    | 30%   |
      | Highway Dhaba | 150    | 15%   |
      | No entity     | 50     | 5%    |
    And the total shows 1,000

  Scenario: One entity's spending month by month
    Given "Amazon" expenses of 1,200 in September and 450 in October
    When she opens the entity "Amazon"
    Then she sees September 1,200 and October 450
    And the total shows 1,650
    And she sees the expenses behind each month

  Scenario: Renaming an entity updates every expense
    Given 5 expenses use "Amazon"
    When she renames it to "Amazon India"
    Then those 5 expenses show "Amazon India"

  Scenario: Merging two entities that are the same place
    Given "Amazon" and "Amazon.in" both exist
    When she merges "Amazon.in" into "Amazon"
    Then every expense of "Amazon.in" now belongs to "Amazon"

  Scenario: An entity in use cannot simply be deleted
    Given 5 expenses use "Amazon"
    When she tries to delete "Amazon"
    Then she sees "5 expenses use Amazon. Merge it into another entity first."

  Scenario: Search finds expenses by entity
    When she searches for "highway"
    Then she sees the expenses of "Highway Dhaba"

  Scenario: A bill carries its entity into the expense
    Given the bill "Internet" with the entity "Fibre Co" due 2026-11-16
    When she adds it to the budget
    Then the expense has the entity "Fibre Co"
