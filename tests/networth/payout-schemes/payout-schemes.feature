Feature: Payout schemes and maturity reminders
  As someone with bonds, fixed deposits and monthly-income schemes
  I want to see what pays out and when each one matures
  So that I never miss a maturity and my monthly income is easy to record

  # Payout amounts are approximate (month length changes them),
  # so recording a payout always lets me edit the amount.

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

  Scenario: A maturity within 90 days appears in Reminders
    Given today is 2026-12-15
    When she opens the Reminders tab
    Then she sees "Bond A matures in 53 days"
    And "Bank FD" is not listed
    And "Post scheme" is not listed because it has no maturity date

  Scenario: A payout expected within 7 days is listed
    Given today is 2026-11-20
    When she opens the Reminders tab
    Then she sees "Bond A payout expected 24 Nov, about 800"
    And "Bank FD" is not listed because its payout is 8 days away

  Scenario: Priya records a payout with the actual amount
    Given today is 2026-11-24
    When she chooses "Record Payout" on Bond A and changes the amount to 790
    Then an "Investment Income" entry of 790 dated 2026-11-24 is created with note "Bond A"
    And the November payout for Bond A no longer shows as expected

  Scenario: A matured scheme asks to be closed
    Given today is 2027-02-07
    When she opens the Reminders tab
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

  Scenario Outline: The Reminders tab shows a count of what needs attention
    Given today is 2026-11-24
    And Bond A's November payout is <bond status>
    And <matured> scheme(s) have matured and are not closed
    Then the Reminders tab shows <badge>

    Examples:
      | bond status    | matured | badge |
      | not yet recorded | 0     | 1     |
      | recorded       | 0       | none  |
      | not yet recorded | 1     | 2     |

  Scenario: Payouts that are not due yet do not add to the count
    Given today is 2026-11-20
    And Bond A's payout is expected on 2026-11-24
    Then the Reminders tab shows no count

  Scenario: Nothing to remind
    Given no scheme matures within 90 days and no payout is expected
    Then she sees "Nothing coming up. Maturities and expected payouts appear here."
