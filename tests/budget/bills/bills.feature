Feature: Bills, one-off or repeating, added to the budget with a tap
  As someone with bills that fall on known dates
  I want to set a bill up once, with how often it repeats and when it ends
  So that I see what is coming and put each one into the budget without retyping

  # A bill remembers: name, amount, category (parent and sub), paid with, due date,
  # repeat, when it ends, an alert, and notes.
  # Each due date is an occurrence. Adding an occurrence creates a normal expense
  # (dated by the "Payment date" setting) that counts at once; the bill then moves on.
  # Repeat choices: Never, Daily, Weekly, Biweekly, Every 3 Weeks, Every 4 Weeks,
  # Every Month, Last Day of Every Month, Bimonthly (every 2 months), Every 3 Months,
  # Twice a Year, Yearly. Monthly repeats keep the original day, clamped to short months.
  # Ends: never, or on a date.
  # A repeating bill can be set to "Add automatically" (on by default for repeating bills).
  # An automatic bill is added by the app itself on its due date, when the app is opened,
  # and she is told. Bills that are not automatic wait in Upcoming for her to add them.
  # One-off bills (Repeat: Never) are never automatic.

  Background:
    Given today is 2026-10-30
    And the setting "Upcoming window" is "Due within 2 weeks" and "Payment date" is "Use due date"
    And these bills
      | name                | amount | due date   | repeat         | ends  | add automatically |
      | Rent                | 20,000 | 2026-11-01 | Every Month    | never | no                |
      | Insurance premium   | 1,500  | 2026-11-10 | Every Month    | never | no                |
      | Society maintenance | 6,000  | 2026-11-12 | Every 3 Months | never | no                |
      | Internet            | 800    | 2026-11-16 | Every Month    | never | yes               |
      | Property tax        | 3,000  | 2027-04-02 | Yearly         | never | no                |

  Scenario: Priya creates a repeating bill
    When she creates a bill "Gym" of 2,000 due 2026-11-05 repeating "Every Month" that never ends
    Then "Gym" appears with its next due date 2026-11-05

  Scenario: Priya sees what is due within her chosen window
    When she opens Upcoming
    Then she sees in this order
      | name                | due        | label       |
      | Rent                | 2026-11-01 | Due in 2 days |
      | Insurance premium   | 2026-11-10 | Due in 11 days |
      | Society maintenance | 2026-11-12 | Due in 13 days |
    And "Internet" is not listed because it is due in 17 days

  Scenario: Labels can show the exact date instead
    Given the setting "Show exact days" is on
    When she opens Upcoming
    Then "Rent" shows "Due 1 Nov"

  Scenario: Priya adds one bill to the budget
    When she taps Add on "Rent"
    Then the New Expense form opens with 20,000, "Home", "UPI" and the date 2026-11-01
    When she saves it
    Then an expense of 20,000 dated 2026-11-01 exists
    And "Left to spend" drops by 20,000
    And "Rent" shows "Added for Nov" and its next due date becomes 2026-12-01

  Scenario: Priya changes the date or amount while adding
    When she taps Add on "Rent" and changes the date to 2026-11-03 and the amount to 21,000
    And saves it
    Then the expense is 21,000 dated 2026-11-03
    And "Rent" still says 20,000

  Scenario: A bill whose amount changes starts from what was paid last time
    Given "Rent" was added for November at 21,000
    When she taps Add on "Rent" for December
    Then the New Expense form starts at 21,000
    And "Rent" still says 20,000

  Scenario: Priya cancels the form
    When she taps Add on "Rent" and cancels
    Then no expense is created
    And "Rent" is still due 2026-11-01

  Scenario Outline: The payment date setting decides the expense date
    Given the setting "Payment date" is "<setting>"
    When she taps Add on "Rent"
    Then the form shows the date <shown>

    Examples:
      | setting       | shown                              |
      | Use due date  | 2026-11-01                         |
      | Use today     | 2026-10-30                         |
      | Ask each time | no date filled in; she must pick one |

  Scenario: Priya adds several at once
    When she chooses "Add Several at Once" for November 2026
    Then Rent, Insurance premium and Society maintenance are ticked
    And Internet is not offered because it adds itself
    And Property tax is not offered because it is not due in November
    When she confirms
    Then expenses of 20,000 (Nov 1), 1,500 (Nov 10) and 6,000 (Nov 12) are created
    And "Left to spend" drops by 27,500

  Scenario: A bill is never added twice for the same due date
    Given Rent is already added for November
    When she chooses "Add Several at Once" for November 2026
    Then Rent shows "Added" and is not ticked

  Scenario: A bill that was not added is shown as past due
    Given today is 2026-11-03
    And "Rent" for 2026-11-01 was never added
    When she opens Upcoming with "Include past due" on
    Then she sees "Rent" with the label "Past due by 2 days"
    When "Include past due" is off
    Then "Rent" is not listed

  Scenario Outline: The next due date follows the repeat choice
    Given a bill due <due> repeating "<repeat>" whose occurrence was just added
    Then its next due date is <next>

    Examples:
      | due        | repeat                  | next       |
      | 2026-11-01 | Daily                   | 2026-11-02 |
      | 2026-11-01 | Weekly                  | 2026-11-08 |
      | 2026-11-01 | Biweekly                | 2026-11-15 |
      | 2026-11-01 | Every 3 Weeks           | 2026-11-22 |
      | 2026-11-01 | Every 4 Weeks           | 2026-11-29 |
      | 2026-11-01 | Every Month             | 2026-12-01 |
      | 2026-01-31 | Every Month             | 2026-02-28 |
      | 2026-10-31 | Last Day of Every Month | 2026-11-30 |
      | 2026-11-12 | Bimonthly               | 2027-01-12 |
      | 2026-11-12 | Every 3 Months          | 2027-02-12 |
      | 2026-11-12 | Twice a Year            | 2027-05-12 |
      | 2026-04-02 | Yearly                  | 2027-04-02 |
      | 2026-11-01 | Never                   | none       |

  Scenario: A monthly bill on day 31 keeps its day after a short month
    Given a bill due 2026-01-31 repeating "Every Month" with January and February added
    Then its next due date is 2026-03-31

  Scenario: A bill with an end date stops repeating
    Given "Rent" ends on 2026-12-31
    When she adds the Rent occurrences for November and December
    Then "Rent" shows "Ended" and has no next due date

  Scenario: Priya sets or removes an end date later
    When she edits "Internet" and sets it to end on 2026-12-16
    Then the Internet occurrences on 2026-11-16 and 2026-12-16 are still due
    And there is none on 2027-01-16
    When she edits it again and chooses "Never ends"
    Then the 2027-01-16 occurrence is due again

  Scenario: An end date before the due date is refused
    When she saves "Gym" due 2026-11-05 with the end date 2026-11-01
    Then she sees "The end date must be on or after the due date"

  Scenario: Priya changes plan, for example a new internet plan
    Given "Internet" of 800 due 2026-11-16 repeating every month
    When she chooses "Change Plan", sets the old plan to end on 2026-11-16 and starts a new bill "Internet (new plan)" of 1,000 from 2026-12-16
    Then "Internet" has no occurrence after 2026-11-16
    And "Internet (new plan)" is due 2026-12-16 and every month after
    And expenses already added for "Internet" are untouched

  Scenario Outline: The alert shows a count on the Bills tab
    Given a bill due 2026-11-01 with the alert "<alert>"
    And today is <today>
    Then the Bills tab shows <badge>

    Examples:
      | alert               | today      | badge |
      | Day before due date | 2026-10-31 | 1     |
      | Day before due date | 2026-10-30 | none  |
      | On due date         | 2026-11-01 | 1     |
      | None                | 2026-11-01 | none  |

  Scenario: An automatic bill adds itself on its due date
    Given today is 2026-11-16 and the app is opened
    Then an expense of 800 dated 2026-11-16 exists for "Internet"
    And "Internet" next falls due on 2026-12-16
    And she sees the notice "Added automatically: Internet 800"

  Scenario: Days the app was not opened are caught up
    Given the app was last opened on 2026-11-15
    And today is 2026-11-18
    When the app is opened
    Then an expense of 800 dated 2026-11-16 exists for "Internet"
    And she sees the notice "Added automatically: Internet 800"

  Scenario: A bill that is not automatic is never added by itself
    Given today is 2026-11-01 and the app is opened
    Then no expense exists for "Rent"
    And "Rent" is listed in Upcoming with an Add button

  Scenario: One-off bills cannot be automatic
    When she creates a bill "Passport fee" of 1,500 due 2026-11-05 repeating "Never"
    Then "Add automatically" is off and cannot be turned on

  Scenario: An automatic bill never uses Ask each time
    Given the setting "Payment date" is "Ask each time"
    When "Internet" is added automatically
    Then the expense is dated on its due date

  Scenario: Priya undoes an automatic add
    Given "Internet" was added automatically for 2026-11-16
    When she opens the Auto-added list and chooses Undo on "Internet"
    Then that expense is removed
    And "Internet" is due 2026-11-16 again, no longer automatic for that date

  Scenario: The notice stays until she has seen it
    Given "Internet" was added automatically
    Then the Bills tab counts it and Activity shows the notice
    When she opens the Auto-added list
    Then the count clears and the notice goes

  Scenario: The bills menu shows what needs attention
    Given 2 bills are due today and not added, and 1 payout is inside its alert window
    Then the menu button on the Bills tab shows 3
    And in the menu "Bills" shows 2, "Upcoming Income" shows 1, "Auto-added" shows 0 and "Planned" shows no count

  Scenario: Priya deletes a bill
    When she deletes "Insurance premium" and confirms
    Then it no longer appears in Upcoming or on the calendar
    And expenses already created from it stay

  # Mockup 2: Activity > Upcoming lists only the bills she adds herself.
  Scenario: A bill that adds itself does not wait in Upcoming
    Given the setting "Upcoming window" is "Due within 30 days"
    When she opens Upcoming
    Then "Internet" is not listed because it adds itself
    And Rent, Insurance premium and Society maintenance are listed

  Scenario: An automatic add that was undone waits in Upcoming
    Given today is 2026-11-16 and "Internet" was added automatically
    When she undoes that add
    Then "Internet" is listed in Upcoming with the label "Due today"

  # Mockups 6 and 7: the Bills calendar and its filter menu.
  Scenario: The Bills calendar puts every bill on its day
    When she opens the Bills calendar for November 2026
    Then she sees
      | day | name                | detail                    | shows |
      | 1   | Rent                | Every Month               | Add   |
      | 10  | Insurance premium   | Every Month               | Add   |
      | 12  | Society maintenance | Every 3 Months            | Add   |
      | 16  | Internet            | Every Month · adds itself | Auto  |

  Scenario: Later repeats appear in later months, but only the next one can be added
    When she opens the Bills calendar for December 2026
    Then Rent is on 1 Dec, Insurance premium on 10 Dec and Internet on 16 Dec
    And none of them has an Add button because November comes first
    And Society maintenance is not there because it is next due in February

  Scenario: Added and automatic bills stay on their day
    Given today is 2026-11-16 and "Internet" was added automatically
    And Rent was added for 2026-11-01
    When she opens the Bills calendar for November 2026
    Then Rent shows "Added" on 1 Nov and Internet shows "Auto-added" on 16 Nov

  Scenario: A bill that has ended leaves the calendar
    Given "Rent" ends on 2026-11-30
    When she opens the Bills calendar for December 2026
    Then Rent is not there

  Scenario Outline: The filter menu narrows the calendar
    Given today is 2026-11-16 and "Internet" was added automatically
    And Rent was added for 2026-11-01
    And the scheme "RBI bond" pays 2,000 on the 20th
    And a salary of 1,50,000 was received on 2026-11-01
    When she chooses "<filter>" for November 2026
    Then she sees <shown>

    Examples:
      | filter           | shown                                                                     |
      | All Transactions | every bill, the RBI bond payout and the salary                            |
      | Bills            | Rent, Insurance premium, Society maintenance and Internet                 |
      | Not Added        | Insurance premium and Society maintenance                                 |
      | Added            | Rent                                                                      |
      | Auto-added       | Internet                                                                  |
      | Income           | the RBI bond payout and the salary                                        |
      | Upcoming Income  | the RBI bond payout on 20 Nov, with a Record button                       |
      | Received Income  | the salary on 1 Nov                                                       |

  Scenario Outline: A bill needs the essentials
    When she saves a bill with name "<name>" and amount <amount>
    Then she sees "<message>"

    Examples:
      | name | amount | message                 |
      |      | 1000   | Enter a name            |
      | Gym  | 0      | Enter an amount above 0 |

  # A bill is either paid by the bank by itself ("auto-debit") or paid by Priya ("I pay it myself").
  # Adding a bill puts it in the budget; a bill she pays herself then waits in "To send" until she says she sent it.
  Scenario: A bill she pays herself waits to be sent after it is added
    Given "Rent" is a bill she pays herself
    When she adds "Rent" for November
    Then "Rent" is listed as to send with its amount and due date
    And the Bills badge counts it

  Scenario: An auto-debit bill never waits to be sent
    Given "Insurance premium" is an auto-debit bill
    When she adds "Insurance premium" for November
    Then nothing is listed as to send

  Scenario: Priya ticks a bill as sent with the date
    Given "Rent" for November was added and waits to be sent
    When she marks it sent on 2026-11-02
    Then it leaves the to send list and the badge drops

  Scenario: Priya takes back a sent tick
    Given "Rent" for November was marked sent
    When she unmarks it
    Then it is listed as to send again

  Scenario: Switching a bill to auto-debit clears what waits to be sent
    Given "Rent" for November was added and waits to be sent
    When she changes "Rent" to auto-debit
    Then nothing is listed as to send

  # Editing a bill happens only on the Bills tab (All bills). Activity > Upcoming only adds.
  Scenario: Tapping a bill in Upcoming does not open the editor
    Given "Rent" is listed in Upcoming
    When she taps the bill, not its Add button
    Then nothing opens

  Scenario: Priya taps a bill in All bills to change it
    Given "Rent" is listed under All bills on the Bills tab
    When she taps it
    Then the Edit Bill form opens with a "Debits by itself" switch

  # Like Pending refunds: a tile in the Activity summary card that opens a list.
  Scenario: Pending to send is a tile that opens the list
    Given "Rent" and "Society" wait to be sent
    When she opens Activity
    Then a tile under Left to spend reads the count and total and "Pending to send"
    When she taps the tile
    Then she sees "Still to send" with the total and one row per bill with its due date and amount
    When she taps "Rent" and saves the date it was sent
    Then "Rent" leaves the list and the tile count drops

  Scenario: The tile is hidden when nothing waits to be sent
    Given nothing waits to be sent
    When she opens Activity
    Then there is no "Pending to send" tile

  Scenario: The Upcoming tab shows how many things are coming
    Given 2 bills are due soon and 1 payout is expected
    When she opens Activity
    Then the Upcoming tab shows a red count of 3

  Scenario: Upcoming has an Expenses side and an Income side
    When she opens Activity > Upcoming
    Then she can choose Expenses or Income
    And Expenses lists the bills she adds herself with Add, Create Bill, Add Several at Once and the filter button
    And Income lists expected payouts and maturities, each with its date, and a Record button for payouts
    And Income also has Create Income (a new payout scheme), Add Several at Once (record ticked payouts with their expected amounts) and the filter button

  Scenario: The Bills tab holds only the calendar and All bills
    When she opens the Bills tab
    Then she sees the calendar and All bills
    And there is no Due to add list, no list of the selected day under the calendar and no payout list
    And each row in All bills shows the name, when it is next due and its amount, and opens the editor when tapped
    And each row has an Add button that puts that month's bill in Activity

