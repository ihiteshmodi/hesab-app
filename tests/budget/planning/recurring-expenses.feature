Feature: Recurring expenses added with one tap
  As someone with the same bills every month or quarter
  I want one list of them and an Add button on each
  So that the budget drops by what is about to leave my account, without retyping

  # A recurring item remembers: description, amount, main category, sub category,
  # payment method, notes, how often (monthly, quarterly, annual) and the due day.
  # Add opens the normal New Expense form pre-filled from the item, dated on its next
  # due date. Saving creates a normal expense that counts at once.
  # "Next due" is the earliest due date that has not been added yet.

  Background:
    Given today is 2026-10-30
    And these recurring items, with October's Rent and Insurance premium already added
      | description         | amount | how often | due day | months          | main category         | payment method |
      | Rent                | 20,000 | monthly   | 1       | -               | Home & Utilities      | UPI            |
      | Insurance premium   | 1,500  | monthly   | 10      | -               | Insurance & Financial | Rewards Card   |
      | Society maintenance | 6,000  | quarterly | 12      | Feb May Aug Nov | Home & Utilities      | UPI            |
      | Property tax        | 3,000  | annual    | 2       | Apr             | Annual Fixed Expenses | UPI            |

  Scenario: Priya sees one list sorted by next due date
    When she opens Recurring
    Then she sees in this order
      | description         | next due   |
      | Rent                | 2026-11-01 |
      | Insurance premium   | 2026-11-10 |
      | Society maintenance | 2026-11-12 |
      | Property tax        | 2027-04-02 |

  Scenario: Priya adds one recurring item
    When she taps Add on "Rent"
    Then the New Expense form opens with amount 20,000, "Home & Utilities", "UPI" and the date 2026-11-01
    When she saves it
    Then an expense of 20,000 dated 2026-11-01 exists
    And "Left to spend" drops by 20,000
    And "Rent" shows "Added for Nov" and its next due date becomes 2026-12-01

  Scenario: Priya changes the date or amount while adding
    When she taps Add on "Rent" and changes the date to 2026-11-03 and the amount to 21,000
    And saves it
    Then the expense is 21,000 dated 2026-11-03
    And the Rent item still says 20,000

  Scenario: Priya cancels the form
    When she taps Add on "Rent" and cancels
    Then no expense is created
    And "Rent" still shows next due 2026-11-01

  Scenario: Priya adds several at once
    When she chooses "Add Several at Once" for November 2026
    Then Rent, Insurance premium and Society maintenance are ticked
    And Property tax is not offered because it is due in April
    When she confirms
    Then expenses of 20,000 (Nov 1), 1,500 (Nov 10) and 6,000 (Nov 12) are created
    And "Left to spend" drops by 27,500

  Scenario: Several at once never adds the same item twice
    Given Rent is already added for November
    When she chooses "Add Several at Once" for November 2026
    Then Rent shows "Added" and is not ticked
    And only Insurance premium and Society maintenance can be added

  Scenario: Priya changes an amount while adding several
    Given a monthly "Electricity bill" item of 880
    When she changes it to 910 in "Add Several at Once" and confirms
    Then the expense is 910
    And the Electricity bill item still says 880

  Scenario: A due day that does not exist in a short month moves to the last day
    Given a monthly item due on day 31 whose January is added
    Then its next due date is 2027-02-28

  Scenario Outline: Quarterly and annual items come back in their months
    Given "<item>" was just added for <added>
    Then its next due date is <next due>

    Examples:
      | item                | added      | next due   |
      | Society maintenance | 2026-11-12 | 2027-02-12 |
      | Property tax        | 2027-04-02 | 2028-04-02 |

  Scenario: Priya creates a recurring item
    When she taps + on Recurring and saves "Gym" for 2,000 monthly on day 5
    Then "Gym" appears in the list with its next due date

  Scenario: Priya deletes a recurring item
    When she deletes "Insurance premium" and confirms
    Then it no longer appears in Recurring
    And expenses already created from it stay

  Scenario: A recurring item needs the essentials
    When Priya saves an item with an empty description
    Then she sees "Enter a description"
