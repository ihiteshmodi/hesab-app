Feature: Spending in another currency
  As someone who travels
  I want to record what I paid in the local currency and the exchange rate I actually got
  So that my budget stays in my home currency and reflects what really left my account

  # Home currency (INR here) is the currency of every total, budget and report.
  # A foreign expense stores the foreign amount, its currency, and the home amount.
  # Rate = home amount per one unit of the foreign currency; it is typed by hand (no network).
  # The last rate used for a currency is offered next time.

  Background:
    Given the home currency is INR
    And today is 2026-10-30

  Scenario: Priya records an expense in Indonesian rupiah
    When she adds an expense of IDR 150,000 at the rate ₹5.30 per 1,000 IDR
    Then the home amount is ₹795.00
    And the row shows "₹795.00" with "IDR 150,000" beneath it
    And "Left to spend" drops by 795

  Scenario: The last rate for a currency is offered next time
    Given she last used ₹5.30 per 1,000 IDR
    When she starts another expense in IDR
    Then the rate ₹5.30 per 1,000 IDR is filled in and can be changed

  Scenario: The first time a currency is used she must give a rate
    When she saves an expense in IDR with no rate
    Then she sees "Enter the exchange rate"

  Scenario: Priya enters what her card actually charged
    When she adds IDR 150,000 and enters "I paid ₹812.40"
    Then the home amount is ₹812.40
    And the rate shows ₹5.416 per 1,000 IDR

  Scenario: Home-currency expenses need no rate
    When she adds an expense of ₹1,000 in the home currency
    Then no rate is asked for

  Scenario: Totals are always in the home currency
    Given an expense of IDR 150,000 at ₹5.30 per 1,000 IDR and an expense of ₹1,000
    Then "Spent this month" shows ₹1,795.00

  Scenario: Correcting the rate later changes that expense's home amount
    Given an expense of IDR 150,000 at ₹5.30 per 1,000 IDR
    When she changes its rate to ₹5.40 per 1,000 IDR
    Then its home amount is ₹810.00
    And "Left to spend" drops by a further 15

  Scenario: A refund is received in the home currency
    Given a pending expense of IDR 150,000 whose home amount is ₹795.00
    When she records 795 received
    Then the expense is settled with net amount 0
    When she tries to record 900 received on it
    Then she sees "Received can't be more than ₹795.00"

  Scenario Outline: Invalid foreign amounts are refused
    When she saves an expense of IDR <amount> at the rate <rate>
    Then she sees "<message>"

    Examples:
      | amount  | rate               | message                       |
      | 0       | ₹5.30 per 1,000 IDR | Enter an amount above 0       |
      | 150,000 | 0                  | Enter an exchange rate above 0 |

  Scenario Outline: Amounts are shown in each currency's own style
    Then <amount> in <currency> is shown as "<text>"

    Examples:
      | amount      | currency | text           |
      | 123456789   | INR      | ₹12,34,567.89  |
      | 123456789   | USD      | $1,234,567.89  |
      | 150,000 IDR | IDR      | IDR 150,000    |

  Scenario: Travel mode keeps new expenses in the local currency
    When she turns on "Spending in" and picks IDR
    Then new expenses start in IDR with the last IDR rate
    When she turns it off
    Then new expenses start in INR again

  Scenario: Priya adds a currency that is not in the short list
    When she adds the currency "VND" named "Vietnamese Dong" with symbol "₫" and no decimals
    Then "VND" can be chosen on a new expense

  Scenario: The home currency cannot be changed once there are records
    Given there are expenses in INR
    When she tries to change the home currency to USD
    Then she sees "Your records are in INR. Export a backup and start a new file to use another home currency."
