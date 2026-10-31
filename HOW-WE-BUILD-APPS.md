# How we build apps together: the playbook

Read this first. It describes the working method that produced two finished, tested, personal iPhone apps with one person and one AI agent: a fitness tracker (workouts, body metrics, calories, diet) and a budget app (expenses, bills with a calendar, net worth, trips split with friends, Face ID privacy). It is **not specific to either app**. Follow it for the next one.

The short version:

1. **Understand the person and the job before any code.** Who is it for, why, what changes for them.
2. **Show it before you build it.** Concrete examples, then an HTML mockup with the person's real data. Get a yes. Then build **what the mockup shows**, including its look.
3. **Write the tests from the agreed examples first.** See each fail once, then make it pass.
4. **Keep the logic in a plain, testable core.** The screens stay thin.
5. **One feature per commit, only when green.** Never push without being asked.
6. **Keep personal data out of the repository.** Always.
7. **Never leave a gap unannounced.** Anything not built, or built differently from the mockup, is reported before the person has to ask.

---

## 1. The working agreement

### Who decides what

| The person decides | The agent decides |
|---|---|
| What the app is for, who uses it, what "done" looks like | Structure, naming, libraries within the agreed architecture |
| The examples and the mockups (they approve them) | How to test, how to split the work into commits |
| Hard-to-reverse choices (storage, platform, anything hard to undo) | Everything reversible: refactors, file layout, helper code |
| When to push, release, publish | When to commit locally (on green) |

### When to stop and ask (do not guess)

- A requirement is ambiguous or two requirements contradict.
- A choice would be hard to reverse (database, platform, what leaves the device).
- A test can only pass by changing an agreed example.
- The same failure survives two different fixes. Stop, zoom out, report.
- Anything that would send data off the device, publish, push, or delete.

Otherwise keep going. Do not ask permission for routine work.

### How to ask well

Use short forms with a few concrete options and a sensible default marked. Group related questions in one go. Ask about **behaviour** ("should an untick count for one day or forever?"), not about implementation. If the person already said it in the conversation, do not ask again.

### How to talk to the person

- Plain, short, no jargon. Lead with the result, then the detail.
- Say what you are about to do and why, in one or two lines, before slow work.
- After a result, say what it means and what comes next.
- Report honestly: what passed, what failed, what you skipped, what you assumed.
- Link to files and name exact commands. Give step-by-step instructions for anything the person must do themselves (merging a PR, installing a build), with where to click.
- When the person changes their mind or adds a requirement mid-way, **pause, restate the change, update the mockups/specs, get a yes, then continue**. Do not quietly absorb it.
- **Keep a running "not built yet / differs from the mockup" list** and put it in every end-of-session report, unasked. Finding a missing feature (or a screen that looks nothing like the approved mockup) on their own costs the person's trust far more than the gap itself. Say "this is a best-effort list" rather than promising it is complete.
- **Stay with long-running work until it finishes.** Do not end a turn with "I'll check later" while a build or test run is still going; wait in the same turn and report the result.
- **Show progress as numbers.** For anything that takes minutes, print `done/total`, a percentage, passes, failures and what is running now (see the heartbeat in section 4). "How many are there in total?" should never need asking.
- **When the machine struggles** (heat, fans, the person says "stop everything"): stop every build and test run at once, then run one thing at a time on one simulator.

---

## 2. The phases

```
Discover  ->  Design  ->  Build (loops)  ->  Review  ->  Ship
 who/why/what   mockups     tests first      checklist     only when asked
 examples       architecture one feature      then commit
                            per commit
```

### Phase 1: Discover (theoretical guesses before physical ones)

Never start with code, schemas or libraries. Start with:

- **Role:** who uses it? Where, on what device, online or offline?
- **Goal:** what do they get? (time back, a better result, fewer mistakes)
- **Capabilities:** the 3 to 8 things it must do.
- **Concrete examples** for each capability, in Given / When / Then form, with real numbers. Examples expose misunderstandings that descriptions hide.
- **What exists today:** the person's current process, spreadsheets, notes, scripts. Read them. Learn the rules that are already in there (formulas, thresholds, naming). Port the **behaviour**, not the file format.
- **Out of scope:** write down what you are deliberately not doing now (for example "order planning comes in step 2").

Deliverables (in the repo, in plain language, free of personal data):

- `docs/design/<feature>/impact-map.md`: why, who, goal, features, rules decided with the person.
- `tests/<capability>/<feature>/<feature>.feature`: the acceptance scenarios, as examples.

Gate: **the person approves the examples.** Humans own the spec.

### Phase 2: Design

- **Mockups first.** Build a clickable-looking HTML page of the screens with the person's real foods/exercises/numbers, render it, screenshot it, check it yourself, then show it. Keep it out of the repository if it holds personal data. Iterate until they say it looks good. This is far cheaper than changing an app. Show every screen and every state that matters (empty, normal, changed, error, an edge case).
- **Show the whole screen when you change part of it.** The person worries that unchanged parts were removed; draw the full screen and say what stays.
- **Write the assumptions down** next to the mockup and ask them to confirm each ("plan starts on the 26th", "editing a food recalculates past days"). Unconfirmed assumptions become bugs.
- **Number every mockup screen** ("mockup 43: Settings"). The person and the agent can then point at exactly one screen, and the gap list can say "mockup 6 (Bills calendar) not built yet".
- **The mockup's look is part of the spec.** If it shows white rounded cards on a grey page, the app shows that, not the platform's default list and form style. Before building screens, turn the mockup's CSS (colours, corner radii, spacing, button shapes) into a small design-system file in the app (page, card, card group, row, form row, pill buttons, status pills) and build every screen from those pieces. Retrofitting the look onto thirty finished screens later is a large, risky job.
- **When an approved mockup contradicts an existing test or scenario**, update the `.feature` file and the old test openly (and say so), rather than leaving both.
- **Architecture:** broad strokes only (see section 3). Decide storage, platform, offline or not, how tests plug in. Hard-to-reverse choices need the person's approval.
- **Slice the work** into features that each deliver something visible and testable. Order them so each commit leaves the app working.

### Phase 3: Build, in loops

For each feature (this is the heart of the method):

1. **Specify:** turn the approved scenarios into tests. Write the **assert first** (the result you expect), then the call, then the setup. If a scenario is awkward to test, the design is awkward; fix the design.
2. **See it fail** for the right reason (the behaviour is missing), not because of a typo or a missing import.
3. **Make it pass** with the simplest honest code.
4. **Prove the test can fail** (a quick mutation check): break the code on purpose, watch the tests go red, restore. Do this at least once per feature. A test that cannot fail proves nothing. Apply mutations with an exact string replace (a few lines of Python), not `sed`/`perl` regexes: regex characters like `$0`, `?.`, `[` silently fail to match, the code is unchanged, and the mutant falsely "survives". A mutant that truly survives often means the code it removed was redundant; delete that code.
5. **Refactor** only when the same thing has appeared three times. Never mix refactoring and new behaviour in one commit.
6. **Commit** on green, one feature per commit.

Work from the inside out: pure logic first (maths, rules, state), then storage, then the services that combine them, then the screens, then UI tests. The core is where about 90% of the testing happens. The UI is thin.

**Splitting a big UI job across helper agents.** When many files need the same mechanical change (for example moving thirty screens onto the design system), give each helper a disjoint set of files and a precise brief: the design-system API, the conversion rules, every accessibility identifier and visible label the UI tests rely on, "do not build, do not run tests, do not touch other files, do not use git". Then build once yourself. Helpers editing in parallel have left half-replaced code behind (`NaviCardScreen {`, an unclosed `.navigationTitle("x"`); fix it by comparing with `git show HEAD:<file>`, and read the helpers' reports for anything they restructured.

### Phase 4: Review (before every commit that matters)

A short checklist, in this order:

1. Do comments explain **why**, not what? Remove the rest.
2. Did every new behaviour get a test, seen failing once?
3. Do layers respect their boundaries (no storage or UI code in the rules)?
4. No interface or abstraction that has only one implementation and no reason to exist.
5. Every fake has a contract test (see section 5).
6. UI changed? Is logic in a view model or the core, not in the view?
7. Backend/config/data changed? Failure modes, defaults, migrations, backups?
8. Personal data not in the diff (`git show --stat`, check file names). Grep the staged diff for the person's names, places and amounts from their real data before every push.
9. Gap list updated: anything still missing or different from the mockups is written down for the report.

### Phase 5: Ship (only when asked)

- Commit locally as you go; **push only when the person asks**, and never force-push or rewrite shared history.
- Before a push, list the commits and the files in them and check for data files.
- Give the person the link or the exact steps; they merge and publish themselves unless they say otherwise.
- Update the README (features list, screenshots, how to build) when a feature ships. Write it for **other people** who have never heard of the person's old process.
- Final report after a build session: scenarios and the tests that cover them, anything skipped and why, decisions made, open questions.

---

## 3. Architecture rules that worked

These keep the code easy to change and easy to test. They fit any app with logic worth protecting.

### A pure core, thin edges

```
screen (view)  ->  view model  ->  service (use case)  ->  repository / store  ->  database
                                         |
                                  pure rules and maths (no IO, no clock, no randomness)
```

- **Core library** (no UI imports): models, rules, maths, services, repositories. Tested with plain unit tests, in memory.
- **App target**: screens, view models, formatting, wiring. As little logic as possible.
- **Composition root**: one place builds every service and hands them to the screens. Environment checks and wiring live only there.
- **Controllers/screens do three things:** parse input, call **one** use case, map the result. No rules, no storage calls in a view.
- **Inject the roles that change:** the clock (`today()`), randomness, IO, files. Never call `Date()` or a database inside rules. Tests then control time.
- **Fakes only where needed**, hand-written, and each fake passes the same contract test as the real thing. Prefer a real in-memory database to mocks.

### Organise by feature, not by technology

```
src/modules/<capability>/<feature>/   the code for one feature (what the user can do)
src/shared/                           what many features use (database, dates, settings)
tests/<capability>/<feature>/         mirrors src, holds the .feature file and the tests
docs/design/<feature>/                impact map, mockups, decisions
tools/<tool>/                         one-off scripts (importers, seed builders) with their own tests
```

A reader should see **what the app does** from the folder tree, not "controllers, services, models".

### Data and storage patterns worth reusing

- **One schema file** is the single source of truth, plus a **migration ladder**: each version has an idempotent step that checks what already exists. Test every old version upgrading, and that a user's data survives.
- **Validate at the edge of the domain** with small value types that throw a clear message ("Enter an amount above 0"). Keep error messages in the tests as part of the spec.
- **Dated defaults and versioned plans.** Anything that "applies from a date onward" (a calorie target, a diet plan, a price list) is stored as rows with `effective_from`. The value on a day is the newest row at or before it. A change starts on a chosen date and **never rewrites earlier days**. This one pattern solved several problems.
- **Per-day overrides beat edits.** Let the person change one day without touching the plan (untick, replace, add an extra). Store the override, not a copy of the day.
- **Compute, do not copy.** Totals, costs and recipe nutrition are worked out from current data every time, so correcting one input fixes history. Say this in the design and get it approved, because it also means history changes.
- **Explicit "unknown" instead of zero** (a missing price must not look free). Carry a "complete?" flag through the sums.
- **Money as whole minor units** (paise, cents) in integers, never floating point. Splitting a total among people uses largest-remainder distribution so the parts always add back up to the total.
- **Dates as calendar days**, not instants, for anything a person thinks of as "on the 1st". Repeating things (bills, payouts) keep their anchor day (the 31st becomes the 28th in February, then the 31st again).
- **A migration ladder edited in place only while unreleased.** Once a build with that schema is on the person's phone, add a new step instead.
- **Pure presentation logic in the core** when it has real rules (cycle descriptions, calendar rows, which input modes a food offers). Plain string formatting can stay in the app.
- **Model states and forbidden transitions** when something has a lifecycle ("only after", "never again"). One test per allowed arrow and per forbidden arrow.
- **Time-based features** ("after X do Y", reminders, retries): model them as events with handlers; never append awaited side effects to a command.
- **Anything that calls out** (network, third party): timeout, bounded retries, a visible fallback, off the request path.
- **Config and secrets:** missing required config stops startup; never log secrets; no placeholder auth beyond local development.

### Offline-first personal apps

When the app is for one person on one phone: local SQLite, no backend, no accounts. Add **export and import of the database file** early; it is the backup, the migration path, and how the person moves data between builds. Make import safe (validate, back up the current file first).

**Privacy on the phone itself** (money, health): offer "hide balances" (figures show `₹ ••••` until an eye is tapped), put the most sensitive figures behind Face ID on every visit (they hide again when the person leaves the screen or the app), and an app lock that asks for Face ID when the app opens or comes back. Only allow turning the lock on after Face ID has succeeded once, so nobody locks themselves out. While locked, **replace** the screens with the lock screen; an overlay on top still leaves the figures readable to accessibility tools. Put the biometric call behind one small gate type so UI tests can make it succeed or fail with a launch argument. Sideloaded builds (LiveContainer, AltStore) still need a real-device check of Face ID and the camera.

---

## 4. Testing approach

### Levels

| Level | What it proves | Share |
|---|---|---|
| Pure functions and state machines | The rules and maths | many, fast |
| **Use-case tests** with an in-memory database | A whole behaviour from the agreed examples | the bulk (~80%) |
| Adapter/contract tests | Fakes match reality; files and migrations work | few |
| UI tests on a simulator | The screens are wired to the behaviour | a handful of high-value flows |
| One end-to-end smoke | The built app launches with real data | 1 |

Test **behaviour through the public API**, not private helpers. One behaviour per test. Names say what the thing *does or knows*: `testUntickingAnItemRemovesItForThatDayOnly`.

### Habits

- **Tests come from the approved examples**, not from the code. Tests written after the code only confirm what the code does.
- **Arithmetic in examples must be checked by hand.** Twice we caught a wrong expected number in our own spec (4×12 + 4×68 + 9×8 is 392, not 372). When the code disagrees with a spec, check the maths before changing either, and fix the spec openly, never silently weaken a test.
- **Table-driven tests** after the third similar example.
- **Builders** for fixtures with names from the domain ("a plan from the 26th with two meals").
- **Mutation check** (above) per feature.
- **Round displayed numbers deliberately.** UI tests that compare shown values need a tolerance equal to the rounding.
- **Neutral, made-up data** in tests and demos. A small demo-data generator (neutral foods, plan, history) serves UI tests and README screenshots and keeps real data out of the repo.
- **Never weaken or delete a failing test to get green.**

### UI testing notes (iOS, SwiftUI)

- Give every interactive or asserted element a stable `accessibilityIdentifier`.
- Prefer finding elements by identifier on `descendants(matching: .any)`; combined accessibility elements do not appear as plain labels.
- Scroll to an element before tapping it.
- If a simulator layout routes tab taps wrongly, add a launch argument that starts on the needed tab instead of tapping.
- The simulator cannot read files on `~/Desktop` (a privacy prompt hangs the app). Stage the test database in a shared folder (`/Users/Shared`) and delete it afterwards.
- Shut simulators down when finished. Large simulators eat disk; a person may not want a particular device.
- A simulator's own system daemons (for example the wallpaper process) can crash in the background. That is noise, not an app bug.
- Run a long test run in the background and keep doing useful work, but come back to it in the same turn (see the heartbeat below).
- **Switches in a row:** tap the switch itself (`coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))`); tapping the middle of the row hits the label and does nothing.
- **Back navigation:** the system back button is `app.buttons["BackButton"]`.
- **Coordinate taps do not scroll** and the keyboard covers the bottom of a form. The number pad has no return key, so give number fields a keyboard toolbar "Done" with its own identifier, and tap it before reaching for controls lower down.
- **Lazy stacks and grids do not create off-screen rows**, so a test cannot find them. Use a plain (non-lazy) layout for small things a test checks, such as a month calendar.
- **`ForEach` ids must be unique within one container.** Blank calendar cells numbered 0, 1, 2 collided with days 1, 2, 3 and those days silently disappeared.
- **Swipe actions only exist inside `List`.** With custom card layouts use a touch-and-hold context menu and test it with `press(forDuration:)`.
- **Critical buttons belong in the content**, not only in a sheet's toolbar: on some simulator layouts toolbar items vanished from the accessibility tree. A Save button pinned to the bottom (`safeAreaInset(edge: .bottom)`) is always reachable.
- **Launch arguments set up state** the test cannot reach by tapping: an in-memory database (`-ui-testing`), a preference already on (`-ui-app-lock`), Face ID failing (`-ui-auth-fail`). Read them only in the composition root.
- **Visual check with screenshots:** a temporary UI test that walks the main screens and writes `XCUIScreen.main.screenshot()` PNGs to `/tmp`; combine them into a few contact sheets (Pillow) and compare with the mockups. Delete the temporary test before committing.
- **Run new and changed tests first** (`-only-testing:`), fix them, then run the **whole suite once** at the end on the final build.
- **Never overlap runs.** Check `pgrep -f "[x]codebuild"` before starting; a new run started while the last one is still tearing down fails with "Mach error -308 (ipc/mig) server died". Wait a few seconds and start again.
- **After Xcode updates itself** (it can happen overnight), the simulator may stop with "CoreSimulator is out of date". `xcodebuild -checkFirstLaunchStatus` exits 69 when this is the cause. The fix needs admin rights, so ask the person to run `sudo xcodebuild -runFirstLaunch`, then continue.

#### The heartbeat for long test runs

A full UI suite can take twenty minutes. Run it through a small script that prints one line every 20 seconds, so the person always knows it is alive and how far it got:

```text
[07:04:48] 5/33 done (15%) · 5 passed · 0 failed · 7m04s · now: ActivityAndBillsUITests.testThePlannedFilter…
[07:18:12] 33/33 done (100%) · 33 passed · 0 failed · 20m28s · now: TripsUITests.testTheTripsTabSitsFifth…
---- finished ----
```

```zsh
#!/bin/zsh
# ui-heartbeat.sh: run the UI suite once, print progress every 20 seconds.
log=/tmp/ui-full.log
total=$(grep -h "func test" tests/e2e/*.swift | wc -l | tr -d ' ')
rm -f $log
(xcodebuild test-without-building -project App.xcodeproj -scheme App \
   -destination "platform=iOS Simulator,id=$SIM_ID" -derivedDataPath build/DerivedData > $log 2>&1
 echo "RUN-ENDED exit=$?" >> $log) &
start=$(date +%s)
while ! grep -q "RUN-ENDED" $log 2>/dev/null; do
  sleep 20
  done_count=$(grep -cE "^Test Case .*(passed|failed) \(" $log)
  passed=$(grep -cE "^Test Case .* passed \(" $log)
  failed=$(grep -cE "^Test Case .* failed \(" $log)
  now=$(grep -E "^Test Case .* started" $log | tail -1 | sed -E 's/.*\.([A-Za-z]+) (test[A-Za-z]+)\]. started.*/\1.\2/')
  elapsed=$(( $(date +%s) - start ))
  printf "[%s] %d/%d done (%d%%) · %d passed · %d failed · %dm%02ds · now: %s\n" "$(date +%H:%M:%S)" \
    $done_count $total $(( done_count * 100 / total )) $passed $failed $(( elapsed / 60 )) $(( elapsed % 60 )) "$now"
done
echo "---- finished ----"
grep -E "error:|Executed .* tests" $log | sort -u | tail -20
```

Build once with `xcodebuild build-for-testing`, then run this. Use the same idea (a counter and a percentage) for any loop that takes minutes: imports, mutation runs, migrations.

---

## 5. Test doubles, briefly

A fake (an in-memory repository, a fixed clock) is only trustworthy if the **same contract spec** runs against the fake and the real implementation. Library mock soup (verifying call counts) tests the wiring, not behaviour. Prefer real in-memory implementations; use hand-written fakes for the outside world (time, network); give each fake a contract test.

---

## 6. Commit discipline

- **Only commit on green** (all tests pass).
- **One feature, or one refactor, per commit.** Never both.
- Message prefix by what changed: `feat(scope):` for behaviour, `fix(scope):` for a bug, `refactor(scope):` for structure only, plain message for docs/config/tooling.
- First line says what the person gets, not how.
- Add the agent co-author trailer if the project asks for it.
- **Never commit:** databases, spreadsheets, notebooks, builds/binaries, `.env`/secrets, the person's real data. Add them to `.gitignore` on day one and check `git show --stat` before pushing.
- **Stage explicit paths** (`git add src tests README.md project.yml`), never `git add -A`. Editor and tool integrations add folders (`.vscode/`, `.github/instructions/`) and touch `.gitignore`; leave those alone unless the person asks.
- When the project keeps a code knowledge graph (for example code-review-graph), update it after each push so the next session starts from the current code.
- Never push, force-push or rewrite shared history unless asked. After a push, say exactly which branch and give the compare/PR link.
- A feature branch per piece of work; the person merges.

---

## 7. Personal data and privacy

- The repository may be public. Treat the person's numbers (weights, diet, prices, health notes, finances) as private by default.
- Keep source spreadsheets and exports in an ignored folder (`current_artifacts/`, `output/`).
- **Importers are generic; the personal mapping is a config file in the ignored folder.** Tests use made-up data.
- Private mockups with real data live outside the repo (the agent's session folder).
- Public text (README, docs, commit messages) never mentions the person's private routine or old tooling. Write it for strangers.
- Releases: never upload a build that embeds personal data. If the person wants a build with their data, hand it to them locally.

---

## 8. Environment and tooling lessons

- **Use the proper file tools to create and edit files.** Writing file contents through shell heredocs or one-liners caused quoting bugs more than once (nested quotes, unescaped `$`, accidental no-ops). Use shell only to run things.
- **Do not run dependent steps in parallel.** Viewing an image in the same batch that creates it fails; run them in order.
- **Read before you write.** Read the files you are about to change, and the tests that cover them. Follow the existing patterns.
- **Verify, do not assume.** After a build, run it. After starting a server, hit it. After a migration, open a copy of the real data and check the totals against the person's own numbers (we matched a spreadsheet to the cent and the one difference was a deliberate correction).
- **Work on copies** of the person's real database when trying imports; back up before the real run.
- **Generate project files from a spec** (for example XcodeGen) and keep the generated project out of git.
- **Make builds tolerate missing private files** (the build must succeed on a fresh clone with no data).
- **Track work in a todo list** with dependencies; mark one item in progress at a time.
- **Delegate** only work that needs a large separate context. Do not hand a single continuous investigation to a helper.
- Quick progress notes between phases; avoid silent long gaps.
- Clean up temporary files and shut down what you started.
- **Name app types so they never clash with core types.** A view called `Card` collided with the core's credit-card model `Card`, and Swift reported "generic parameter could not be inferred" at an unrelated line. Prefer specific names (`CardPanel`).
- **Observable view models:** a method that computes from the store (for example "the calendar for this month") must first read the observed properties it depends on, or the screen will not refresh after a change.
- **Swift 6 strict concurrency:** a main-actor view helper used inside a closure the system calls off the main actor (for example a photo picker's label) does not compile; apply the helper outside the closure.
- **Keep a short session notes file** while working (what is done, what is next, what is blocked). Long sessions get summarised, and the notes are what survives.
- **Remember lessons across projects** in a personal notes file (environment fixes, tool quirks), so the same problem is solved once.

---

## 9. Reading someone's existing system (spreadsheet, notebook, script)

1. Read every sheet/cell/formula, including the hidden logic (lookups, thresholds, magic numbers). Write a small reader if the format is awkward (an `.ods` file is a zip of XML; the standard library can read it).
2. Explain back what you understood, in the person's words, and **list inconsistencies and assumptions** (duplicates, typos, stale notes, drift between sheets). Ask about each.
3. Port behaviour with tests that reproduce **their own numbers** from their own inputs.
4. Write a one-time import tool for the data, with a dry run, a refusal to overwrite, and a transaction.
5. Keep the old file for reference only unless told otherwise.

---

## 10. Pitfalls we hit (and the fix)

| Pitfall | Fix |
|---|---|
| Person assumes part of a screen was deleted because the mockup showed only the changed part | Draw the whole screen; say what stays |
| Spec arithmetic wrong | Recompute by hand; fix the spec openly |
| A test that passed on the first run proved nothing | Mutation check |
| A mutation that did not compile looked like "no failures" | Confirm the run actually produced results |
| Shell quoting corrupted a file edit | Use the edit/create tools |
| A free item (water) showed "price unknown" everywhere | Treat price 0 as free; unknown as a distinct state |
| UI test off by one from rounding | Tolerance equal to the displayed rounding |
| UI tests could not see the database | Stage it in a shared folder; launch args to import it |
| Simulator wanted a huge device the person did not want | Ask; use the device they care about; keep their disk in mind |
| A third-party editor integration modified `.gitignore`/added folders | Do not commit changes you did not make; mention them |
| New requirement arrived mid-build | Pause, update examples and mockups, get a yes, continue |
| Old process leaked into public README | Write README for strangers; keep private history out |
| Screens shipped in the platform's default list style while the approved mockups showed cards | Build a design-system file from the mockup CSS before the first screen; check screenshots against the mockups |
| Missing features discovered by the person, not reported | Keep a gap list and report it every session, unasked |
| Agent ended a turn saying "I'll check the run later"; overlapping runs piled up and slowed the machine | Wait in the same turn; one run at a time; heartbeat with a percentage |
| A lock-screen overlay still let tests (and screen readers) read the balances underneath | Replace the content while locked |
| Calendar showed days 4 to 31 only | `ForEach` id collision between blank cells and day numbers; give blanks their own ids |
| UI test could not find a calendar day further down the page | Lazy grid never created it; use a non-lazy layout |
| Toggle near the bottom of a form never flipped in a test | The keyboard covered it; add a keyboard Done button and tap it first |
| Simulator unusable one morning | Xcode had updated itself; the person runs `sudo xcodebuild -runFirstLaunch` |
| Mutation "survived" because the sed pattern never matched | Exact string replacement in Python; confirm the file actually changed |
| Parallel helper edits left broken half-replaced code | Disjoint files per helper, build afterwards, diff against `HEAD` to repair |

---

## 11. Starting a new app: the first hour

1. Ask the person (as a short form): who uses it, why, what are the 3 to 8 things it must do, what exists today, device/platform, online or offline, anything private.
2. Read everything they point you to. Report what you understood and the inconsistencies.
3. Draft `docs/design/<app>/impact-map.md` and the first `.feature` files with concrete examples. **Get approval.**
4. Choose the architecture in broad strokes (platform, storage, layers, folder layout). Note the hard-to-reverse choices; get approval.
5. Create the repo skeleton: `.gitignore` (private folders, builds), `AGENTS.md` (the rules below), `README.md`, folder layout, test target, a "hello" test that runs, the build command, and the schema with a version number.
6. **Walking skeleton:** the thinnest slice that goes through every layer and launches on the target device, with one end-to-end check. Do this **before** feature work so build problems show up on day one.
7. Mockups for the first feature with the person's real data, approval, then loops.
8. **Before the first screen**, write the design-system file from the approved mockups (colours, cards, rows, buttons) so every screen starts with the right look.

### Repo rules file (put in `AGENTS.md`)

Copy these into the new repo so any agent follows them:

- Value first: who, why, what before how. Examples before code.
- Specs and mockups are approved by the human before building.
- Tests come from the approved examples, before the code they verify; each seen failing once.
- Pure core, thin screens, one composition root, injected clock.
- Feature-first folders; tests mirror features.
- Commit only on green; one feature per commit; prefix `feat`/`fix`/`refactor`.
- Never push, force-push or rewrite shared history without explicit approval.
- Never commit personal data, secrets, builds, databases, spreadsheets.
- Every outgoing call has a timeout; retries bounded; fallbacks visible.
- Missing required config stops startup; never log secrets.
- New requirement mid-build: pause, update specs and mockups, get approval, resume.
- Build what the approved mockups show, including their look; report every gap, unasked.
- Long runs: wait in the same turn, never overlap them, print a heartbeat with a percentage.

### Optional: reusable skills

The fitness app keeps its method as small "skills" (short instruction files the agent loads when a situation matches): clarify requirements, architecture decisions, feature-first structure, layering and composition, TDD test writing, test doubles and contracts, test strategy, frontend architecture and testing, state machines, event-driven decoupling, operational resilience, observability and config, security baseline, walking skeleton, code review, commit discipline. They live under `.agents/skills/` in that repository, with a routing table in `AGENTS.md` saying which skill to load for which signal. Copy that folder and the table into the new repo if you want the same behaviour.

---

## 12. Definition of done for a feature

- [ ] Examples agreed with the person; mockup approved.
- [ ] The screens match the approved mockup (checked on screenshots), or the differences are listed.
- [ ] Every scenario has a test, each seen failing once; mutation check done.
- [ ] All tests pass (core, tool tests, and the relevant UI tests), and the whole UI suite once on the final build.
- [ ] Anything that only a real device can prove (Face ID, camera) is named for the person to check.
- [ ] The app builds for the real device target and launches.
- [ ] Checked against the person's real data where relevant, and the numbers match.
- [ ] Review checklist passed; no personal data in the diff.
- [ ] Committed locally, one feature per commit; README updated if user-visible.
- [ ] Summary delivered: what was built, how it was tested, what was skipped, what is still missing or different from the mockups, decisions, open questions, next steps.
