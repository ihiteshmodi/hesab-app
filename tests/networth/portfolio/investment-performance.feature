Feature: Is this investment up or down?
  As someone who holds stocks and index funds, and may start SIPs
  I want to note what I paid and update what it is worth now
  So that I can see whether each one, and all together, are up or down

  # Everything is typed in by hand: what was paid, and later what it is worth today. No prices are fetched.
  # Only holdings with "Amount invested" filled in are counted in the up-or-down totals.

  Background:
    Given the home currency is INR

  Scenario: A holding that gained
    Given "Index fund" was bought for 10,000 and is worth 12,500
    Then it is up 2,500, which is 25.0%

  Scenario: A holding that lost
    Given "Stock A" was bought for 10,000 and is worth 9,000
    Then it is down 1,000, which is 10.0%

  Scenario: A holding without what she paid shows no gain or loss
    Given "Gold" is worth 50,000 and has no amount invested
    Then it shows no gain or loss
    And it is left out of the totals

  Scenario: All tracked holdings together
    Given "Index fund" 10,000 paid and 12,500 now, "Stock A" 10,000 paid and 9,000 now, and untracked "Gold" 50,000
    Then the totals read paid 20,000, worth 21,500, up 1,500, 7.5%

  Scenario: Nothing tracked yet
    Given no holding has an amount invested
    Then there is no up-or-down total

  Scenario: A holding in another currency is up or down in that currency and in rupees
    Given "US stocks" was bought for 400 USD and is worth 440 USD, with USD at 90
    Then it is up 40 USD, 10.0%, which is 3,600 in rupees

  Scenario: Updating what it is worth today
    Given "Index fund" is worth 12,500
    When she updates it to 13,000
    Then it is up 3,000, 30.0%
    And the new value is remembered with today's date

  Scenario: Updating twice on one day keeps the last value of the day
    When she updates a holding twice on the same day
    Then that day has one point with the latest value

  Scenario: A SIP instalment adds to what she paid and to what it is worth
    Given "Index fund" was bought for 10,000 and is worth 12,000
    When she adds 5,000
    Then she has paid 15,000 and it is worth 17,000, still up 2,000

  Scenario: Adding money needs an amount invested first
    Given "Gold" has no amount invested
    When she adds 5,000
    Then she sees "Enter what you paid for it first."

  Scenario: What she paid cannot be negative
    When she saves a holding with -100 invested
    Then she sees "Enter an amount of 0 or more"

  Scenario: Net worth is not changed by noting what she paid
    Given a holding worth 12,500
    When she fills in 10,000 invested
    Then net worth is unchanged

  # Dates and the detail page: tapping an investment opens it.
  Scenario: An investment remembers the day it was bought
    Given "Index fund" was bought on 2025-11-20 for 100,000 and is worth 121,000
    When she opens it on 2027-11-20
    Then it shows "Since 20 Nov 2025" and "Held for 2 years"

  Scenario: A lump sum shows how much it grows a year
    Given "Index fund" was bought for 100,000 two years ago and is worth 121,000
    Then it shows about 10.0% a year

  Scenario: A short holding shows no yearly figure
    Given "Stock A" was bought 3 months ago
    Then it shows the gain and percent but no yearly figure

  Scenario: A holding that has had money added shows no yearly figure
    Given "Index fund" has had a SIP instalment added
    Then the yearly figure is left out, because the money was not all in for the same time

  Scenario: Money added is listed with its date
    Given "Index fund" was bought for 10,000 and 5,000 was added on 2026-10-05 and 2,000 on 2026-11-05
    Then the page lists "Bought 10,000" and the two additions in date order
    And what she paid is 17,000

  Scenario: The date cannot be in the future
    When she saves a holding bought tomorrow
    Then she sees "The date can't be in the future."

  Scenario: A holding without a date still opens
    Given "Gold" has no date and no amount invested
    Then the page shows its worth and offers to fill in what she paid

