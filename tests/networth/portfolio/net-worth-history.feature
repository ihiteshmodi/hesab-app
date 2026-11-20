Feature: Net worth over time
  As someone who wants to know whether she is getting richer
  I want the app to remember her net worth as it changes
  So that Portfolio can draw how it has moved

  # The app only knows today's balances, so history starts the day this ships.
  # A snapshot is saved when the app opens and net worth is different from the last one, and at least once a month.

  Scenario: The first snapshot is today's net worth
    Given her net worth is 1,000,000
    When the app records her net worth
    Then the history has one point: today, 1,000,000

  Scenario: Nothing new is saved while nothing changed in the month
    Given a snapshot of 1,000,000 was saved earlier this month
    When the app records her net worth again with the same value
    Then the history still has one point

  Scenario: A change is saved as a new point
    Given a snapshot of 1,000,000 was saved earlier this month
    When her net worth becomes 1,050,000 and the app records it
    Then the history has two points

  Scenario: Changing it twice in one day keeps the last value of the day
    When her net worth changes twice on the same day
    Then that day has one point with the latest value

  Scenario: A new month gets a point even if nothing changed
    Given a snapshot of 1,000,000 was saved last month
    When the app records her net worth with the same value
    Then the history has two points

  Scenario: The chart needs two points
    Given one snapshot
    Then Portfolio shows no chart yet
    When a second snapshot exists
    Then it shows the line and how much it has changed since the first point

  Scenario: History comes with a restore
    Given a backup that has snapshots
    When she restores it
    Then the snapshots come back with everything else
