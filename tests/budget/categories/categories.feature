Feature: Categories with sub-categories
  As someone who groups spending
  I want parent categories with sub-categories that I can add to and tidy
  So that my spending is grouped the way I think about it

  # Every category has a name, a colour and an icon. Sub-categories belong to one parent.
  # Expenses refer to categories, so renaming a category renames it everywhere.

  Background:
    Given these categories
      | parent           | sub-categories                       |
      | Home & Utilities | Rent, Electric, Internet, Home maintenance |
      | Food & Dining    | Restaurant, Food delivery, Coffee    |
      | Vehicle          | Vehicle service, Vehicle repairs, Parking |
      | Transport        | Ride share, Cab                      |

  Scenario: A fresh install starts with a sensible default set
    Given Priya has just installed the app
    When she opens Categories
    Then she sees these parent categories, each with its sub-categories
      | parent                 | sub-categories                                                              |
      | Home & Utilities       | Electric, Gas, Internet, Mortgage, Rent, Home maintenance, Utilities, Cell phone |
      | Food & Dining          | Restaurant, Food delivery, Coffee, Alcohol                                  |
      | Groceries              | Ration, Milk, Biscuits                                                      |
      | Health & Medical       | Medical, Blood tests, Skin & face, Dental, Personal care, Fitness, Supplements, Vision, Therapy, Pharmacy, Courses |
      | Transport              | Ride share, Train tickets, Travel, Flight tickets                           |
      | Vehicle                | Vehicle service, Vehicle repairs, Vehicle loan, Parking                     |
      | Fuel                   |                                                                             |
      | Insurance              | Health insurance - Me, Health insurance - Mom, Term life, Vehicle insurance, Home insurance, Travel insurance |
      | Entertainment & Movies |                                                                             |
      | Personal & Family      | Family cash gifts                                                           |
      | Lifestyle              | Subscriptions, Vacation, Concerts, Charity, Clothing, Gifts, Child care, Night life, Pets |
      | Shopping - Needs       |                                                                             |
      | Shopping - Wants       | Perfumes                                                                    |
      | Technology & Gadgets   | Courses                                                                     |
      | Monthly Fixed Expenses |                                                                             |
      | Annual Fixed Expenses  |                                                                             |
      | Miscellaneous          | Special occasions, Loan payment, Credit card payment, Bad expenses |
    And she can add, rename and delete any of them

  # The default set is the reference app's categories merged with the spreadsheet's.
  # Parents keep the spreadsheet's names, and Needs and Wants stay separate parents so
  # reports show them side by side. Savings is not a category: saving happens in Portfolio.
  # Where both lists had the same idea one name is kept: Electric (not Light Bill),
  # Internet (not Internet Bill), Cell phone (not Recharge), Home maintenance (not Repairs & Maintenance),
  # Ride share (Cab, Rickshaw Fare), Vehicle service, Vehicle repairs, Vehicle insurance,
  # Supplements (not Wellness), Skin & face (the old Orthoderma), Special occasions under Miscellaneous.

  Scenario Outline: Spreadsheet main categories keep their names on import
    When a spreadsheet row has the main category "<sheet category>"
    Then it is imported under the parent "<parent>"

    Examples:
      | sheet category         | parent                 |
      | Home & Utilities       | Home & Utilities       |
      | Food & Dining          | Food & Dining          |
      | Health & Medical       | Health & Medical       |
      | Fuel                   | Fuel                   |
      | Entertainment & Movies | Entertainment & Movies |
      | Personal & Family      | Personal & Family      |
      | Shopping - Needs       | Shopping - Needs       |
      | Shopping - Wants       | Shopping - Wants       |
      | Technology & Gadgets   | Technology & Gadgets   |
      | Monthly Fixed Expenses | Monthly Fixed Expenses |
      | Annual Fixed Expenses  | Annual Fixed Expenses  |
      | Miscellaneous          | Miscellaneous          |

  Scenario Outline: The old Transport & Vehicle category is split by what the row is
    Given a spreadsheet row with the main category "Transport & Vehicle" and the sub category "<sub category>"
    When Priya runs the import
    Then it is imported under "<parent>" and "<sub-category>"

    Examples:
      | sub category          | parent    | sub-category    |
      | Train Tickets         | Transport | Train tickets   |
      | Rickshaw Fare         | Transport | Ride share      |
      | Cab                   | Transport | Ride share      |
      | Personal Travel       | Transport | Travel          |
      | Repairs & Maintenance | Vehicle   | Vehicle repairs |
      | Parking Charges       | Vehicle   | Parking         |

  Scenario Outline: Known sub-category spellings are merged on import
    Given a spreadsheet row with the sub category "<sheet sub category>"
    When Priya runs the import
    Then its sub-category is "<sub-category>"

    Examples:
      | sheet sub category | sub-category |
      | Light Bill         | Electric     |
      | Internet Bill      | Internet     |
      | Recharge           | Cell phone   |
      | Gas Cylinder       | Gas          |
      | Bloodtest          | Blood tests  |
      | Suppliments        | Supplements  |
      | Ration - milk      | Milk         |
      | Ration - Milk      | Milk         |

  Scenario: Names of people in the sub category column become entities
    Given a spreadsheet row with the sub category "Aunt Rita"
    And the mapping lists "Aunt Rita" as a person
    When Priya runs the import
    Then the expense has the entity "Aunt Rita"
    And "Aunt Rita" is not created as a sub-category

  Scenario: Priya adds a parent category
    When she adds the parent category "Pets" with the colour orange and the paw icon
    Then "Pets" appears with no sub-categories
    And "Pets" can be chosen on a new expense

  Scenario: Priya adds a sub-category
    When she adds "Water tax" under "Home & Utilities"
    Then "Water tax" appears under "Home & Utilities"

  Scenario: The same sub-category name can exist under different parents
    When she adds "Parking" under "Home & Utilities"
    Then both "Parking" under "Vehicle" and "Parking" under "Home & Utilities" exist

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
    Then she is offered Restaurant, Food delivery and Coffee
    And she may leave the sub-category empty

  Scenario: The picker puts recently used sub-categories first
    Given she has used these sub-categories, most recent first: "Ride share", "Internet", "Coffee"
    When she opens the category picker
    Then a "Recently used" section lists "Ride share", "Internet" and "Coffee" with their parents
    And below it the full list of parents and sub-categories

  Scenario: Typing a description she used before suggests the category it had
    Given she has an expense "Milk" under "Groceries" / "Milk"
    When she types "Milk" as the description of a new expense
    Then she is offered "Used before: Groceries > Milk"
    When she taps it
    Then the category and sub-category are filled in

  Scenario: An entity she used before suggests its usual category
    Given most expenses for the entity "Fibre Co" are under "Home & Utilities" / "Internet"
    When she picks the entity "Fibre Co" on a new expense
    Then she is offered "Used before: Home & Utilities > Internet"

  Scenario: Nothing is suggested for something new
    When she types a description she has never used
    Then no "Used before" suggestion appears

  Scenario: Priya merges two sub-categories that mean the same thing
    Given "Cab" and "Ride share" both exist under "Transport"
    When she merges "Cab" into "Ride share"
    Then every expense that used the first now uses the second
    And "Cab" is gone

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
    Then she sees "Vehicle repairs" under "Vehicle"
