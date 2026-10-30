Feature: Categories with sub-categories
  As someone who groups spending
  I want parent categories with sub-categories that I can add to and tidy
  So that my spending is grouped the way I think about it

  # Every category has a name, a colour and an icon. Sub-categories belong to one parent.
  # Expenses refer to categories, so renaming a category renames it everywhere.

  Background:
    Given these categories
      | parent           | sub-categories                       |
      | Home & Utilities | Rent, Electricity, Internet, Repairs |
      | Food & Dining    | Groceries, Restaurant, Coffee        |
      | Transport        | Fuel, Train Tickets, Repairs         |

  Scenario: A fresh install starts with a sensible default set
    Given Priya has just installed the app
    When she opens Categories
    Then she sees these parent categories, each with its sub-categories
      | parent               | sub-categories                                                                                         |
      | Home & Utilities     | Insurance, Electric, Gas, Internet, Mortgage, Rent, Home maintenance, Utilities, Cell phone, Ration, Milk |
      | Food & Dining        | Restaurant, Food delivery, Groceries, Special occasions, Coffee, Alcohol                               |
      | Health & Medical     | Vision, Health insurance, Therapy, Wellness, Fitness, Pharmacy, Dental, Personal care, Medical, Blood tests, Supplements |
      | Transport & Vehicle  | Fuel, Car insurance, Train tickets, Rickshaw fare, Cab, Vehicle repairs, Parking                       |
      | Lifestyle            | Subscriptions, Vacation, Concerts, Movies, Charity, Clothing, Gifts, Child care, Night life, Pets, Personal & Family |
      | Shopping             | Needs, Wants                                                                                           |
      | Technology & Gadgets |                                                                                                        |
      | Insurance & Financial |                                                                                                       |
      | Fixed Expenses       | Monthly, Annual                                                                                        |
      | Savings              | Investment, Vacation savings, Down payment savings                                                     |
      | Miscellaneous        | Miscellaneous, Loan payment, Credit card payment                                                       |
    And she can add, rename and delete any of them

  # The default set is the reference app's categories merged with the spreadsheet's:
  # spreadsheet parents keep their names so an import maps one to one; where both have the
  # same idea, one sub-category is kept (Recharge into Cell phone, Gas Cylinder into Gas,
  # Dining out into Restaurant, Online food order into Food delivery,
  # Repairs & Maintenance into Home maintenance, Entertainment & Movies into Lifestyle > Movies).
  # More Transport & Vehicle sub-categories from the reference app are still to be added.

  Scenario Outline: Spreadsheet categories land in the merged set on import
    When a spreadsheet row has the category "<sheet category>"
    Then it is imported as "<parent>" and "<sub-category>"

    Examples:
      | sheet category         | parent               | sub-category      |
      | Home & Utilities       | Home & Utilities     |                   |
      | Fuel                   | Transport & Vehicle  | Fuel              |
      | Shopping – Needs       | Shopping             | Needs             |
      | Shopping – Wants       | Shopping             | Wants             |
      | Personal & Family      | Lifestyle            | Personal & Family |
      | Entertainment & Movies | Lifestyle            | Movies            |
      | Monthly Fixed Expenses | Fixed Expenses       | Monthly           |
      | Annual Fixed Expenses  | Fixed Expenses       | Annual            |
      | Miscellaneous          | Miscellaneous        | Miscellaneous     |

  Scenario: Priya adds a parent category
    When she adds the parent category "Pets" with the colour orange and the paw icon
    Then "Pets" appears with no sub-categories
    And "Pets" can be chosen on a new expense

  Scenario: Priya adds a sub-category
    When she adds "Insurance" under "Home & Utilities"
    Then "Insurance" appears under "Home & Utilities"

  Scenario: The same sub-category name can exist under different parents
    When she adds "Fuel" under "Home & Utilities"
    Then both "Fuel" under "Transport" and "Fuel" under "Home & Utilities" exist

  Scenario Outline: Duplicate or empty names are refused
    When she adds <kind> "<name>" <where>
    Then she sees "<message>"

    Examples:
      | kind         | name            | where                     | message                                             |
      | parent       | home & utilities |                          | A category called home & utilities already exists   |
      | sub-category | internet        | under "Home & Utilities"  | Home & Utilities already has an Internet            |
      | parent       |                 |                           | Enter a name                                        |

  Scenario: Renaming a category updates every expense
    Given 12 expenses are under "Home & Utilities" / "Internet"
    When she renames "Internet" to "Broadband"
    Then those 12 expenses show "Broadband"

  Scenario: Priya picks a parent, then a sub-category, when adding an expense
    When she adds an expense and chooses "Food & Dining"
    Then she is offered Groceries, Restaurant and Coffee
    And she may leave the sub-category empty

  Scenario: Priya merges two sub-categories that mean the same thing
    Given "Ration - milk" and "Ration - Milk" both exist under "Home & Utilities"
    When she merges "Ration - milk" into "Ration - Milk"
    Then every expense that used the first now uses the second
    And "Ration - milk" is gone

  Scenario: A category in use cannot simply be deleted
    Given 12 expenses are under "Home & Utilities" / "Internet"
    When she tries to delete "Internet"
    Then she sees "12 expenses use Internet. Move them to another sub-category first."
    And nothing is deleted

  Scenario: Priya deletes a category nobody uses
    When she deletes the unused sub-category "Coffee" and confirms
    Then "Coffee" is gone

  Scenario: Priya finds a category by searching
    When she types "rep" in the category search
    Then she sees "Repairs" under "Home & Utilities" and "Repairs" under "Transport"
