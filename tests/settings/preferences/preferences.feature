Feature: Preferences
  As someone who wants the app to behave my way
  I want a settings area for currency display, privacy, bills and totals
  So that the app fits how I use it

  Background:
    Given today is 2026-10-30

  Scenario: Priya opens Settings from the menu
    When she taps her profile button and chooses Settings
    Then she sees Currency, Hide Balances, App Lock, Income & Expense Settings, Due Date Settings and Upcoming Bill Filters

  # Currency
  Scenario: A fresh install asks for the home currency once
    Given Priya has just installed the app
    Then the home currency is INR unless she picks another before adding her first entry

  # See foreign-currency-spending.feature for what the home currency means and when it can change.

  # Privacy
  Scenario: Hiding balances masks every balance
    Given "Left to spend" shows ₹15,226.42 and the savings bank balance shows ₹3,05,134.63
    When she turns on "Hide Balances"
    Then those figures show "₹ ••••"
    When she taps the eye on the Activity screen
    Then the figures show until she leaves the screen
    # Income in the summary card is hidden even with Hide Balances off; see month-budget.feature.

  Scenario: The savings bank balance is hidden until she asks
    Given she opens Activity and chooses the Savings tab
    Then the savings bank balance shows "₹ ••••••" with a crossed-out eye
    And ledgers, cash in hand, amount to repay, income, expenses and cash flow show "₹ ••••"
    And ledgers, cash in hand and amount to repay cannot be opened
    When she taps the eye and authenticates with Face ID
    Then every figure on the pane shows until she leaves the screen

  Scenario: Portfolio is hidden until she asks
    When she opens the Portfolio tab
    Then net worth, available to allocate, investments and every row show "••••" with a crossed-out eye
    When she taps the eye and authenticates with Face ID
    Then the Portfolio figures show until she leaves the tab

  Scenario: Opening Portfolio never asks for Face ID by itself
    When she opens the Portfolio tab
    Then no Face ID prompt appears
    And the figures are hidden until she presses the eye or "Show with Face ID"

  Scenario Outline: Portfolio hides again whenever she leaves
    Given the Portfolio figures are shown
    When she <leaves>
    And comes back to the Portfolio tab
    Then the figures are hidden again and no Face ID prompt appears

    Examples:
      | leaves                       |
      | switches to another tab      |
      | opens a screen from Portfolio and goes back |
      | sends the app to the background |

  Scenario: Failed authentication keeps the figures hidden
    Given the Portfolio tab is hidden
    When she taps the eye and Face ID does not match
    Then the figures stay hidden and she sees "Try Again"

  Scenario: Without biometrics the device passcode is asked instead
    Given the device has no Face ID or Touch ID but has a passcode
    When she taps the eye on the Portfolio tab
    Then she is asked for the device passcode

  Scenario: App Lock asks for Face ID or Touch ID when the app opens
    Given "App Lock" is on
    When the app is opened
    Then nothing is shown until she authenticates
    When authentication fails
    Then she sees "Try Again" and the data stays hidden

  Scenario: App Lock is unavailable on a device without biometrics
    Given the device has no Face ID or Touch ID
    When she opens "App Lock"
    Then she sees "Face ID or Touch ID is not available on this device."

  # Totals
  Scenario Outline: Income & Expense Settings decide what counts in totals
    Given the setting "<setting>" is <state>
    Then <effect>

    Examples:
      | setting                                              | state | effect                                                         |
      | Count money received as income                       | on    | "Money Received" entries add to "Income this month"            |
      | Count money received as income                       | off   | they are left out of "Income this month"                       |
      | Count borrowed money as income                       | off   | "Borrowed" entries are left out of "Income this month"         |
      | Include cash and ledger spending in Spent this month | off   | "Spent this month" covers bank, card and withdrawal spending only |
      | Include cash and ledger spending in Spent this month | on    | "Spent this month" also covers cash and ledger spending        |

  # Bills
  Scenario Outline: Due Date Settings
    Given "Payment date" is "<payment date>" and "Show exact days" is <exact>
    When a bill is due 2026-11-01
    Then adding it starts with the date <start> and the label reads "<label>"

    Examples:
      | payment date  | exact | start                | label         |
      | Use due date  | off   | 2026-11-01           | Due in 2 days |
      | Use today     | on    | 2026-10-30           | Due 1 Nov     |
      | Ask each time | off   | an empty date        | Due in 2 days |

  Scenario Outline: The payout alert decides when expected income counts on the Bills tab
    Given "Payout alert" is <days> days before and a payout is expected on 2026-11-04
    When today is <today>
    Then the Bills tab counts it: <counted>

    Examples:
      | days | today      | counted |
      | 5    | 2026-10-30 | no      |
      | 5    | 2026-10-31 | yes     |
      | 5    | 2026-11-04 | yes     |
      | 0    | 2026-11-03 | no      |
      | 0    | 2026-11-04 | yes     |

  Scenario Outline: Upcoming Bill Filters
    Given the upcoming window is "<window>" and "Include past due" is <past due>
    Then Upcoming lists bills due from <from> to <to>

    Examples:
      | window               | past due | from                | to         |
      | Due today            | off      | 2026-10-30          | 2026-10-30 |
      | Due within 2 days    | on       | the earliest unpaid | 2026-11-01 |
      | Due within 1 week    | off      | 2026-10-30          | 2026-11-06 |
      | Due within 2 weeks   | off      | 2026-10-30          | 2026-11-13 |
      | Due within 30 days   | off      | 2026-10-30          | 2026-11-29 |

  Scenario: Settings are kept in the database file
    Given she changed several settings and exported a backup
    When she restores that backup on another phone
    Then the settings are the same
