Feature: Who an expense was for, and tags
  As someone who sometimes pays for other people or wants to find things by topic
  I want to say who an expense was for and to tag it
  So that I can see what I spent on Mom or on one bike without changing the budget

  # "Spent for" names one person. It is a saved person, not free text, so renaming a person
  # renames it everywhere and a later who-owes-whom section can build on it.
  # "Me" is the default and is shown as nothing special.
  # Tags are free labels, as many as wanted, such as "Bike A" or "Course".
  # Neither changes any total: Left to spend counts the expense exactly as before.

  Background:
    Given today is 2026-10-30
    And these people exist: "Mom", "Komal"
    And these tags exist: "Bike A", "Bike B", "Course"

  Scenario: An expense is for me unless said otherwise
    When Priya adds an expense of 500 for "Medicines"
    Then the expense is spent for "Me"

  Scenario: Priya says an expense was for Mom
    When she adds an expense of 1,200 for "Train ticket" spent for "Mom"
    Then the expense shows "For Mom"
    And "Left to spend" drops by 1,200 as for any other expense

  Scenario: A new person is saved when she types one
    When she adds an expense spent for "Aunt Rita" who is not in the list
    Then "Aunt Rita" is saved as a person
    And "Aunt Rita" is offered the next time

  Scenario: Renaming a person renames it on every expense
    Given 5 expenses are spent for "Komal"
    When she renames "Komal" to "Komal S"
    Then those 5 expenses show "For Komal S"

  Scenario: A person in use cannot simply be deleted
    Given 5 expenses are spent for "Komal"
    When she tries to delete "Komal"
    Then she sees "5 expenses are for Komal. Move them to another person first."
    And nothing is deleted

  Scenario: Priya tags an expense
    When she adds an expense of 450 for "Engine oil" with the tags "Bike A" and "Bike B"
    Then the expense shows the tags "Bike A" and "Bike B"

  Scenario: A new tag is created from what she types
    When she adds an expense with the tag "Trek"
    Then "Trek" is saved as a tag

  Scenario Outline: Tag names are unique whatever the case
    When she adds the tag "<typed>"
    Then she sees "<message>"

    Examples:
      | typed  | message                    |
      | course | A tag called Course exists |
      |        | Enter a name               |

  Scenario: Priya finds everything with a tag
    Given 3 expenses of 100, 200 and 400 are tagged "Bike A" this month
    When she opens Reports and chooses Tags
    Then she sees "Bike A" with 700

  Scenario: Priya sees what she spent for each person this month
    Given in October she spent 6,540 for "Mom" and 44,980 for herself
    When she opens Reports and chooses "Spent for"
    Then she sees "Me" with 44,980 and "Mom" with 6,540
    And "Left to spend" is unchanged by the grouping

  Scenario: Search finds by person and by tag
    Given an expense "Dress" spent for "Mom" tagged "Gift"
    When she searches "mom"
    Then she sees "Dress"
    When she searches "gift"
    Then she sees "Dress"

  Scenario: Money received can also be for someone
    When she records money received of 166 spent for "Mom"
    Then the entry shows "For Mom"

  Scenario: Priya changes who an old expense was for
    Given an expense spent for "Me"
    When she edits it and chooses "Mom"
    Then the expense shows "For Mom"

  Scenario: Merging two tags
    Given 2 expenses are tagged "Bike A" and 3 are tagged "Bike B"
    When she merges "Bike B" into "Bike A"
    Then 5 expenses are tagged "Bike A"
    And "Bike B" is gone

  Scenario: Deleting a tag removes it from expenses after she confirms
    Given 3 expenses are tagged "Course"
    When she deletes the tag "Course" and confirms
    Then those 3 expenses stay, without the tag
