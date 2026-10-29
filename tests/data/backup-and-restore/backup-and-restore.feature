Feature: Fresh install, backup and restore
  As someone whose money history lives only on my phone
  I want to export and restore it as one file
  So that I can keep my own backups wherever I choose, and nobody else ever receives my data

  # The app is fully offline. The single database file is the backup,
  # the way to move to a new phone, and the way to hand data to the app.

  Background:
    Given today is 2026-10-29

  Scenario: A fresh install is empty
    When Priya opens the app for the first time
    Then she has no expenses, income, ledgers, holdings or schemes
    And she can choose from the default categories and payment methods
    And each tab shows an empty state with one clear action

  Scenario: Priya exports her data
    Given she has recorded entries
    When she chooses "Export Data"
    Then she can share one file named "budget-2026-10-29.sqlite"
    And nothing leaves the phone unless she shares it

  Scenario: Priya restores from a backup
    Given she has 12 entries and a backup file with 1,186 entries
    When she chooses "Import Data" and picks the backup
    Then she is told "This replaces 12 entries with 1,186 entries."
    When she confirms
    Then the app shows the 1,186 entries
    And a copy of her previous data was kept as "before-import-2026-10-29"

  Scenario: Priya cancels a restore
    When she picks a backup and cancels at the confirmation
    Then her data is unchanged

  Scenario: A file that is not a backup is refused
    When she picks a photo
    Then she sees "This isn't a budget backup. Choose a file exported from this app."
    And her data is unchanged

  Scenario: A backup from a newer app version is refused
    When she picks a backup made by a newer version
    Then she sees "This backup is from a newer version of the app. Update the app first."
    And her data is unchanged

  Scenario: A backup from an older version is upgraded
    When she picks a backup made by an older version
    Then it opens with all its entries intact

  Scenario: Someone else builds the app from the public source
    When another person builds and installs the app
    Then it starts as a fresh install with no data from the source repository
