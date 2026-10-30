# Delta: reference-inspired redesign, bills, entities, currencies

Date: 2026-10-30. Raised mid-build, after the walking skeleton; build is paused until this is approved.

## What changed and why
The owner studied an app they like and asked to borrow what is better there, keep what is better here, and add three things of their own.

| Area | Before | Now |
|---|---|---|
| Look and feel | Grouped lists, text tab bar | Calm cards, round buttons, floating tab bar, calendar with daily totals |
| Navigation | Budget, Insights, Portfolio, Reminders, More | Activity, Bills, Portfolio, Reports, Search plus a profile menu |
| Recurring and upcoming | Two features (recurring templates, dated upcoming items) | One: **Bills** with 12 repeat choices, optional end date, Change Plan, alert count; undated **Planned** list |
| Reminders tab | Payout and maturity reminders | Gone: expected payouts are "Upcoming Income" on Bills |
| Categories | Flat list | Parents with sub-categories, colour and icon, add and merge |
| Entities | None | Shop or service on each expense, saved list, spending by entity per month |
| Currency | INR only | Home currency plus foreign-currency expenses with the rate actually paid |
| Search | None | Search expenses by text |
| Settings | None | Currency and rates, hide balances, app lock, totals, due date, upcoming filters |

## Specs touched
New: bills, categories, entities, foreign-currency-spending, search-expenses, planned-expenses, preferences.
Edited: payout-schemes (Reminders tab becomes Bills), spreadsheet-import (parent categories, entity prefixes).
Removed: recurring-expenses, upcoming-expenses (replaced by bills and planned-expenses).

## Effect on what is already built
Nothing built is thrown away. The expense table gains entity, category ids and currency columns through new migrations; the Budget screen becomes the Activity screen. Left to spend, refunds and the rest of the approved rules are unchanged.

## Out of scope for this delta
Challenges, tips, partner invites, bank connections and sign-in from the reference app; live exchange rates; a foreign cash balance.
