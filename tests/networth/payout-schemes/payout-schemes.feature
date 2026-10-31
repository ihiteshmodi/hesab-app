Feature: Payout schemes and maturity reminders
  As someone with bonds, fixed deposits and monthly-income schemes
  I want to see what pays out and when each one matures
  So that I never miss a maturity and my monthly income is easy to record

  # Expected payouts show on the Bills tab as "Upcoming Income"; maturities show there too.
  # There is no separate Reminders tab.
  # Payout amounts are approximate (month length changes them),
  # so recording a payout always shows a confirmation where the date and amount can be changed.
  # A payout counts on the Bills tab from "Payout alert" days before its date (default 5).

  Background:
    Given these payout schemes
      | name       | invested | monthly payout | payout day | maturity   |
      | Bond A     | 100,000  | 800            | 24         | 2027-02-06 |
      | Post scheme| 300,000  | 1,850          | 3          | -          |
      | Bank FD    | 500,000  | 3,100          | 28         | 2027-08-23 |

  Scenario: Priya sees the totals
    When she opens Payout Schemes
    Then "Invested" shows 900,000
    And "Monthly payout" shows 5,750

  Scenario: A maturity within 90 days appears on the Bills tab
    Given today is 2026-12-15
    When she opens the Bills tab filtered to "Upcoming Income"
    Then she sees "Bond A matures in 53 days"
    And "Bank FD" is not listed
    And "Post scheme" is not listed because it has no maturity date

  Scenario: A payout expected inside the alert window is listed
    Given "Payout alert" is 5 days before
    And today is 2026-11-20
    When she opens the Bills tab filtered to "Upcoming Income"
    Then she sees "Bond A payout expected 24 Nov, about 800"
    And "Bank FD" is not listed because its payout is 8 days away

  Scenario: Priya records a payout with the actual amount
    Given today is 2026-11-24
    When she chooses "Record" on Bond A
    Then a confirmation shows the date 2026-11-24, the amount 800 and the bank it lands in
    When she changes the amount to 790 and confirms
    Then an "Investment Income" entry of 790 dated 2026-11-24 is created with note "Bond A"
    And the November payout for Bond A no longer shows as expected

  Scenario Outline: A payout can arrive a day early or late
    Given Bond A's payout is expected on 2026-11-24
    And today is <today>
    When she chooses "Record" on Bond A
    Then the confirmation shows the date <today> and says "<note>"

    Examples:
      | today      | note                    |
      | 2026-11-23 | 1 day earlier than expected |
      | 2026-11-24 | on the expected date    |
      | 2026-11-25 | 1 day later than expected   |

  Scenario: The confirmation can change the date
    Given today is 2026-11-25 and Bond A's payout was expected on 2026-11-24
    When she chooses "Record" on Bond A, sets the date to 2026-11-24 and confirms
    Then the entry is dated 2026-11-24

  Scenario: Cancelling the confirmation records nothing
    Given today is 2026-11-24
    When she chooses "Record" on Bond A and cancels
    Then no entry is created
    And Bond A's payout still shows as expected

  Scenario: A confirmation amount must be above zero
    When she chooses "Record" on Bond A, clears the amount and confirms
    Then she sees "Enter an amount above 0"

  Scenario: A matured scheme asks to be closed
    Given today is 2027-02-07
    When she opens the Bills tab filtered to "Upcoming Income"
    Then she sees "Bond A matured 1 day ago"
    When she chooses "Close Scheme"
    Then "Invested" shows 800,000
    And "Monthly payout" shows 4,950
    And the scheme stays in her history
    And she is reminded to update her bank balance

  Scenario: Priya adds a scheme
    When she adds "Bond B" investing 50,000 paying 410 with maturity 2028-08-26
    Then "Invested" shows 950,000
    And "Monthly payout" shows 6,160

  Scenario Outline: Invalid schemes are rejected
    When she saves a scheme with name "<name>", invested <invested> and payout <payout>
    Then she sees "<message>"

    Examples:
      | name   | invested | payout | message                          |
      |        | 1000     | 10     | Enter a name                     |
      | Bond C | 0        | 10     | Enter an amount above 0          |
      | Bond C | 1000     | -1     | Enter a payout of 0 or more      |

  Scenario Outline: The Bills tab shows a count of what needs attention
    Given today is 2026-11-24
    And Bond A's November payout is <bond status>
    And <matured> scheme(s) have matured and are not closed
    Then the Bills tab shows <badge>

    Examples:
      | bond status    | matured | badge |
      | not yet recorded | 0     | 1     |
      | recorded       | 0       | none  |
      | not yet recorded | 1     | 2     |

  Scenario: Payouts outside the alert window do not add to the count
    Given "Payout alert" is 5 days before
    And today is 2026-11-17
    And Bond A's payout is expected on 2026-11-24
    Then the Bills tab shows no count

  Scenario: Nothing to remind
    Given no scheme matures within 90 days and no payout is expected
    Then she sees "Nothing coming up. Maturities and expected payouts appear here."

  Scenario: Priya edits a scheme
    Given the scheme "Bond A" matures on 2027-02-06
    When Priya changes its maturity to 2027-03-10, its payout to 850 and its payout day to 26
    Then "Bond A" matures on 2027-03-10, pays 850 on the 26th
    And its recorded payouts are kept

  Scenario: An edited scheme is checked like a new one
    When Priya edits "Bond A" to have an invested amount of 0
    Then she sees "Enter an amount above 0"
    And "Bond A" is unchanged
