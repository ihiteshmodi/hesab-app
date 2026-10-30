Feature: Trips and shared expenses
  As someone who pays for a group trip and is paid back later
  I want each trip to track who owes me what, in the trip's currency
  So that my main ledger shows only what really left or came back to my bank and card

  Background:
    Given the home currency is INR
    And a trip "Bali trip" in IDR at rate 0.0053 with people Ana, Raj and Mira

  # People and groups

  Scenario: People belong to one trip
    Given Ana is in "Bali trip"
    When I create another trip "Goa weekend"
    Then "Goa weekend" has no people

  Scenario: A group selects everyone in it at once
    Given the group "Daily people" is Me, Ana, Raj, Mira
    When I split an expense using that group and untick Mira
    Then only Me, Ana and Raj share it

  Scenario: A person who is in an expense cannot be removed
    Given Ana shared an expense
    When I remove Ana
    Then I see "Ana has expenses or payments in this trip."

  # Splitting

  Scenario: Equal split gives the odd paise to the first people
    When I split IDR 100,000.01 equally between Me, Ana and Raj
    Then the shares add up to the amount

  Scenario: Shares, exact amounts, percentages and items all add up to the amount
    When I split by 2 shares and 1 share
    Then the larger share is twice the smaller
    When I split by items with tax and service
    Then tax and service follow what each person ordered

  Scenario: Items that do not add up to the bill are refused
    When the items and extra do not add up to the amount
    Then I see "The items and extra must add up to 400,000.00"

  # The main ledger follows bank and card money only

  Scenario: What I pay by card goes to the ledger at once
    When I pay IDR 400,000 by card and the card charges 2,150
    Then the ledger entry "Bali trip expenses" holds 2,150

  Scenario: The entry name can be chosen
    When I name the trip's ledger entry "Bali holiday"
    Then the ledger entry is called "Bali holiday"

  Scenario: Money paid back by bank lowers the ledger entry
    Given the ledger entry holds 6,075
    When Ana pays me 530 by bank
    Then the ledger entry holds 5,545

  Scenario: Cash from a friend does not change the ledger
    When Raj gives me IDR 150,000 in cash
    Then the ledger entry is unchanged
    And the trip cash is IDR 150,000

  Scenario: Cash I pay a friend does not change the ledger
    When I pay Ana IDR 100,000 in cash
    Then the ledger entry is unchanged
    And the trip cash goes down by 100,000

  Scenario: Paying a friend by bank raises the ledger entry
    When I pay Ana 530 by bank
    Then the ledger entry goes up by 530

  Scenario: Rupee notes move the main Cash in Hand
    When Mira hands me 265 in rupee notes
    Then my Cash in Hand goes up by 265
    And the ledger entry is unchanged

  Scenario: An expense I pay in cash does not touch the ledger
    When I pay an expense with trip cash
    Then the trip cash goes down and the ledger entry is unchanged

  # Balances

  Scenario: Debts are kept in the trip currency
    When Ana owes me IDR 200,000
    Then her balance is IDR 200,000, shown as about 1,060 in rupees

  Scenario: Rupees clear the balance at an editable rate
    When Ana pays 530 at the trip rate
    Then her balance falls by IDR 100,000
    And my records keep "received 530"

  Scenario: Settling in full for a little less is a cost
    When Raj owes IDR 100,000 and pays 529 settled in full
    Then he is square and IDR 189 is written off as a cost

  Scenario: Settling in full for a little more is a gain
    When Dev owes 1,005 and pays 1,009 settled in full
    Then he is square and 4 is recorded as extra received

  Scenario: Settling in full with nothing owed is refused
    When I settle in full with nobody owing anything
    Then I see "There is nothing to settle with Raj."

  # Net cost inside the trip

  Scenario: The trip's net cost counts cash as well
    When I pay in cash and friends pay me back in cash
    Then the trip's net cost includes the cash, and the ledger does not

  # Trip cash

  Scenario: Setting trip cash records an adjustment
    When I set the trip cash to IDR 50,000
    Then the balance is IDR 50,000 with an adjustment line

  Scenario: A home-currency trip has no trip cash
    When I set cash on a trip in INR
    Then I see "This trip is in your home currency, so it uses your main Cash in Hand."

  # Notes, receipts and tags

  Scenario: An expense keeps a note, a receipt photo and a tag
    When I add an expense with a note, a photo and the tag "Food"
    Then they are kept with it

  Scenario: A new tag is remembered for every trip
    When I type the tag "Massage"
    Then it is offered after the eight defaults in every trip

  # Settled and insights

  Scenario: A trip can be marked settled and undone
    When I mark "Bali trip" settled
    Then it is listed after the open trips
    When I mark it open again
    Then it is listed with the open trips

  Scenario: One person's page lists every entry behind the balance
    Then Ana's page lists what I paid for her, what she paid for me, and her payments

  Scenario: Insights show spend by tag and who paid versus who used
    Then I see spend by tag and each person's paid and share
