import Testing
@testable import HisaabCore

/// Scenarios from tests/budget/bills/bills.feature
struct BillTests {
    /// The feature's background bills, with today as 2026-10-30.
    private struct Setup {
        let app: BudgetApp
        let rent: Bill
        let insurance: Bill
        let society: Bill
        let internet: Bill
        let propertyTax: Bill
    }

    private func newBill(
        _ name: String, _ rupees: Int, due: String, repeats: BillRepeat = .monthly, ends: String? = nil,
        automatic: Bool = false, alert: BillAlert = .none, entity: String = "", method: PaymentMethod = .upi,
        autoDebit: Bool = false
    ) -> NewBill {
        NewBill(
            name: name, amount: .rupees(rupees), category: "Home & Utilities", entity: entity, paymentMethod: method,
            dueDate: day(due), repeats: repeats, endsOn: ends.map(day), addAutomatically: automatic, alert: alert,
            autoDebit: autoDebit
        )
    }

    private func background(today: String = "2026-10-30") throws -> Setup {
        let app = try makeApp(today: today)
        return Setup(
            app: app,
            rent: try app.addBill(newBill("Rent", 20_000, due: "2026-11-01")),
            insurance: try app.addBill(newBill("Insurance premium", 1_500, due: "2026-11-10")),
            society: try app.addBill(newBill("Society maintenance", 6_000, due: "2026-11-12", repeats: .every3Months)),
            internet: try app.addBill(newBill("Internet", 800, due: "2026-11-16", automatic: true)),
            propertyTax: try app.addBill(newBill("Property tax", 3_000, due: "2027-04-02", repeats: .yearly))
        )
    }

    private func nextDue(_ app: BudgetApp, _ bill: Bill) throws -> CalendarDate? {
        try #require(try app.bills().first { $0.bill.id == bill.id }).nextDue
    }

    private func addOccurrence(_ app: BudgetApp, _ bill: Bill) throws -> Expense {
        try app.addBillOccurrence(bill.id, try app.billDraft(bill.id))
    }

    // MARK: creating and listing

    @Test func aRepeatingBillAppearsWithItsNextDueDate() throws {
        let app = try makeApp()

        let gym = try app.addBill(newBill("Gym", 2_000, due: "2026-11-05"))

        #expect(try nextDue(app, gym) == day("2026-11-05"))
    }

    @Test func upcomingListsWhatIsDueWithinTheWindowInDueOrder() throws {
        let s = try background()

        let upcoming = try s.app.upcoming()

        #expect(upcoming.items.map(\.bill.name) == ["Rent", "Insurance premium", "Society maintenance"])
        #expect(upcoming.items.map(\.label) == ["Due in 2 days", "Due in 11 days", "Due in 13 days"])
        #expect(!upcoming.items.contains { $0.bill.name == "Internet" })
    }

    @Test func labelsCanShowTheExactDateInstead() throws {
        let s = try background()
        try s.app.updatePreferences { $0.showExactDays = true }

        #expect(try s.app.upcoming().items.first?.label == "Due 1 Nov")
    }

    @Test func aBillDueTodayOrTomorrowReadsNaturally() throws {
        let app = try makeApp()
        try app.addBill(newBill("Today", 100, due: "2026-10-30"))
        try app.addBill(newBill("Tomorrow", 100, due: "2026-10-31"))

        #expect(try app.upcoming().items.map(\.label) == ["Due today", "Due in 1 day"])
    }

    @Test func aWiderWindowListsMore() throws {
        let s = try background()
        try s.app.addBill(newBill("Gym", 2_000, due: "2026-11-16"))
        #expect(try !s.app.upcoming().items.map(\.bill.name).contains("Gym"))

        try s.app.updatePreferences { $0.upcomingWindowDays = 20 }

        #expect(try s.app.upcoming().items.map(\.bill.name).contains("Gym"))
    }

    @Test func aBillThatWasNotAddedIsPastDueWhenTheSettingIsOn() throws {
        let s = try background(today: "2026-11-03")

        let upcoming = try s.app.upcoming()
        #expect(upcoming.items.first?.bill.name == "Rent")
        #expect(upcoming.items.first?.label == "Past due by 2 days")

        try s.app.updatePreferences { $0.includePastDue = false }
        #expect(try s.app.upcoming().items.contains { $0.bill.name == "Rent" } == false)
    }

    // MARK: adding to the budget

    @Test func addingABillCreatesAnExpenseAndMovesTheBillOn() throws {
        let s = try background()

        let draft = try s.app.billDraft(s.rent.id)
        #expect(draft.amount == .rupees(20_000))
        #expect(draft.category == "Home & Utilities")
        #expect(draft.paymentMethod == .upi)
        #expect(draft.date == day("2026-11-01"))

        let expense = try s.app.addBillOccurrence(s.rent.id, draft)

        #expect(expense.amount == .rupees(20_000))
        #expect(expense.date == day("2026-11-01"))
        #expect(try s.app.monthBudget().leftToSpend == .rupees(-20_000))
        #expect(try nextDue(s.app, s.rent) == day("2026-12-01"))
        let line = try #require(try s.app.bills().first { $0.bill.id == s.rent.id })
        #expect(line.lastAddedMonth == .init(year: 2026, month: 11))
        #expect(line.addedLabel == "Added for Nov")
    }

    @Test func theDateAndAmountCanBeChangedWhileAddingWithoutChangingTheBill() throws {
        let s = try background()
        var draft = try s.app.billDraft(s.rent.id)
        draft.date = day("2026-11-03")
        draft.amount = .rupees(21_000)

        let expense = try s.app.addBillOccurrence(s.rent.id, draft)

        #expect(expense.amount == .rupees(21_000))
        #expect(expense.date == day("2026-11-03"))
        #expect(try s.app.bills().first { $0.bill.id == s.rent.id }?.bill.amount == .rupees(20_000))
    }

    @Test func aBillWhoseAmountChangesStartsFromWhatWasPaidLastTime() throws {
        let s = try background()
        var november = try s.app.billDraft(s.rent.id)
        november.amount = .rupees(21_000)
        try s.app.addBillOccurrence(s.rent.id, november)

        #expect(try s.app.billDraft(s.rent.id).amount == .rupees(21_000))
        #expect(try s.app.bills().first { $0.bill.id == s.rent.id }?.bill.amount == .rupees(20_000))
    }

    @Test func notSavingTheFormChangesNothing() throws {
        let s = try background()

        _ = try s.app.billDraft(s.rent.id)

        #expect(try s.app.monthBudget().expenses.isEmpty)
        #expect(try nextDue(s.app, s.rent) == day("2026-11-01"))
    }

    @Test(arguments: [
        (Preferences.PaymentDate.useDueDate, "2026-11-01" as String?),
        (.useToday, "2026-10-30"),
        (.askEachTime, nil),
    ])
    func thePaymentDateSettingDecidesTheDateOnTheForm(setting: Preferences.PaymentDate, shown: String?) throws {
        let s = try background()
        try s.app.updatePreferences { $0.paymentDate = setting }

        #expect(try s.app.billDraft(s.rent.id).date == shown.map(day))
    }

    @Test func aBillCarriesItsEntityAndPaymentIntoTheExpense() throws {
        let app = try makeApp()
        let internet = try app.addBill(newBill("Internet", 800, due: "2026-11-16", entity: "Fibre Co", method: .bank("Credit Card")))

        let expense = try addOccurrence(app, internet)

        #expect(expense.entity == "Fibre Co")
        #expect(expense.paymentMethod == .bank("Credit Card"))
    }

    @Test func addSeveralOffersTheBillsDueThatMonthAndNotTheAutomaticOnes() throws {
        let s = try background()

        let choices = try s.app.billsToAdd(for: .init(year: 2026, month: 11))

        #expect(choices.map(\.bill.name) == ["Rent", "Insurance premium", "Society maintenance"])
        #expect(choices.allSatisfy { !$0.alreadyAdded })
    }

    @Test func addingSeveralCreatesAnExpenseForEachOnItsDueDate() throws {
        let s = try background()
        let month = CalendarDate.YearMonth(year: 2026, month: 11)
        let chosen = try s.app.billsToAdd(for: month).map(\.bill.id)

        let added = try s.app.addSeveralBills(chosen, for: month)

        #expect(added.map(\.amount) == [.rupees(20_000), .rupees(1_500), .rupees(6_000)])
        #expect(added.map(\.date) == [day("2026-11-01"), day("2026-11-10"), day("2026-11-12")])
        #expect(try s.app.monthBudget().leftToSpend == .rupees(-27_500))
    }

    @Test func addingSeveralWithTheTodaySettingDatesThemToday() throws {
        let s = try background()
        try s.app.updatePreferences { $0.paymentDate = .useToday }
        let month = CalendarDate.YearMonth(year: 2026, month: 11)

        let added = try s.app.addSeveralBills(try s.app.billsToAdd(for: month).map(\.bill.id), for: month)

        #expect(added.allSatisfy { $0.date == day("2026-10-30") })
    }

    @Test func askEachTimeFallsBackToTheDueDateWhenAddingSeveral() throws {
        let s = try background()
        try s.app.updatePreferences { $0.paymentDate = .askEachTime }
        let month = CalendarDate.YearMonth(year: 2026, month: 11)

        let added = try s.app.addSeveralBills([s.rent.id], for: month)

        #expect(added.first?.date == day("2026-11-01"))
    }

    @Test func aBillIsNeverAddedTwiceForTheSameMonth() throws {
        let s = try background()
        let month = CalendarDate.YearMonth(year: 2026, month: 11)
        _ = try addOccurrence(s.app, s.rent)

        let choices = try s.app.billsToAdd(for: month)

        #expect(choices.first { $0.bill.name == "Rent" }?.alreadyAdded == true)
        let again = try s.app.addSeveralBills(choices.map(\.bill.id), for: month)
        #expect(!again.contains { $0.description == "Rent" })
        #expect(try s.app.monthBudget(for: month).expenses.filter { $0.description == "Rent" }.count == 1)
    }

    @Test func aBillNotDueThatMonthIsNotOffered() throws {
        let s = try background()

        let choices = try s.app.billsToAdd(for: .init(year: 2026, month: 11))

        #expect(!choices.contains { $0.bill.name == "Property tax" })
    }

    // MARK: repeats

    @Test(arguments: [
        ("2026-11-01", BillRepeat.daily, "2026-11-02"),
        ("2026-11-01", .weekly, "2026-11-08"),
        ("2026-11-01", .biweekly, "2026-11-15"),
        ("2026-11-01", .every3Weeks, "2026-11-22"),
        ("2026-11-01", .every4Weeks, "2026-11-29"),
        ("2026-11-01", .monthly, "2026-12-01"),
        ("2026-01-31", .monthly, "2026-02-28"),
        ("2026-10-31", .lastDayOfMonth, "2026-11-30"),
        ("2026-11-12", .bimonthly, "2027-01-12"),
        ("2026-11-12", .every3Months, "2027-02-12"),
        ("2026-11-12", .twiceAYear, "2027-05-12"),
        ("2026-04-02", .yearly, "2027-04-02"),
        ("2026-11-01", .never, nil),
    ] as [(String, BillRepeat, String?)])
    func theNextDueDateFollowsTheRepeatChoice(due: String, repeats: BillRepeat, next: String?) throws {
        let app = try makeApp(today: "2026-01-01")
        let bill = try app.addBill(newBill("Bill", 100, due: due, repeats: repeats))

        _ = try addOccurrence(app, bill)

        #expect(try nextDue(app, bill) == next.map(day))
    }

    @Test func aMonthlyBillOnTheThirtyFirstKeepsItsDayAfterAShortMonth() throws {
        let app = try makeApp(today: "2026-01-01")
        let bill = try app.addBill(newBill("Bill", 100, due: "2026-01-31"))

        _ = try addOccurrence(app, bill)
        _ = try addOccurrence(app, bill)

        #expect(try nextDue(app, bill) == day("2026-03-31"))
    }

    // MARK: ending and editing

    @Test func aBillWithAnEndDateStopsRepeating() throws {
        let app = try makeApp()
        let rent = try app.addBill(newBill("Rent", 20_000, due: "2026-11-01", ends: "2026-12-31"))

        _ = try addOccurrence(app, rent)
        _ = try addOccurrence(app, rent)

        let line = try #require(try app.bills().first)
        #expect(line.nextDue == nil)
        #expect(line.isEnded)
    }

    @Test func anEndDateCanBeSetAndRemovedLater() throws {
        let app = try makeApp(today: "2026-11-01")
        let internet = try app.addBill(newBill("Internet", 800, due: "2026-11-16"))
        _ = try addOccurrence(app, internet)
        _ = try addOccurrence(app, internet)
        #expect(try nextDue(app, internet) == day("2027-01-16"))

        try app.updateBill(internet.id, newBill("Internet", 800, due: "2026-11-16", ends: "2026-12-16"))
        #expect(try nextDue(app, internet) == nil)

        try app.updateBill(internet.id, newBill("Internet", 800, due: "2026-11-16"))
        #expect(try nextDue(app, internet) == day("2027-01-16"))
    }

    @Test func anOccurrenceOnTheEndDateItselfIsStillDue() throws {
        let app = try makeApp()
        let internet = try app.addBill(newBill("Internet", 800, due: "2026-11-16", ends: "2026-12-16"))
        _ = try addOccurrence(app, internet)

        #expect(try nextDue(app, internet) == day("2026-12-16"))
    }

    @Test func anEndDateBeforeTheDueDateIsRefused() throws {
        let app = try makeApp()

        let error = #expect(throws: BillError.self) {
            try app.addBill(newBill("Gym", 2_000, due: "2026-11-05", ends: "2026-11-01"))
        }

        #expect(error?.message == "The end date must be on or after the due date")
        #expect(try app.bills().isEmpty)
    }

    @Test func changingPlanEndsTheOldBillAndStartsANewOne() throws {
        let s = try background()

        let replacement = try s.app.changeBillPlan(
            s.internet.id, endsOn: day("2026-11-16"), startingWith: newBill("Internet (new plan)", 1_000, due: "2026-12-16")
        )

        #expect(try nextDue(s.app, s.internet) == day("2026-11-16"))
        _ = try addOccurrence(s.app, s.internet)
        #expect(try nextDue(s.app, s.internet) == nil)
        #expect(try nextDue(s.app, replacement) == day("2026-12-16"))
    }

    @Test(arguments: [
        ("", Money.rupees(100) as Money?, "Enter a name"),
        ("Gym", nil, "Enter an amount above 0"),
        ("Gym", Money.zero, "Enter an amount above 0"),
    ] as [(String, Money?, String)])
    func anIncompleteBillIsRefused(name: String, amount: Money?, message: String) throws {
        let app = try makeApp()
        var bill = newBill("Gym", 100, due: "2026-11-05")
        bill.name = name
        bill.amount = amount

        let error = #expect(throws: BillError.self) { try app.addBill(bill) }

        #expect(error?.message == message)
    }

    @Test func aBillNeedsACategory() throws {
        let app = try makeApp()
        var bill = newBill("Gym", 100, due: "2026-11-05")
        bill.category = ""

        #expect(throws: BillError.categoryMissing) { try app.addBill(bill) }
        #expect(BillError.categoryMissing.message == "Choose a category")
    }

    @Test func deletingABillKeepsTheExpensesAlreadyAdded() throws {
        let app = try makeApp()
        let rent = try app.addBill(newBill("Rent", 20_000, due: "2026-11-01"))
        _ = try addOccurrence(app, rent)

        try app.deleteBill(rent.id)

        #expect(try app.bills().isEmpty)
        #expect(try app.monthBudget(for: .init(year: 2026, month: 11)).expenses.count == 1)
        #expect(throws: BillError.notFound(rent.id)) { try app.deleteBill(rent.id) }
        #expect(BillError.notFound(1).message == "That bill no longer exists.")
    }

    @Test func deletingTheExpenseOfAnAddedBillMakesItDueAgain() throws {
        let app = try makeApp()
        let rent = try app.addBill(newBill("Rent", 20_000, due: "2026-11-01"))
        let expense = try addOccurrence(app, rent)

        try app.deleteExpense(expense.id!)

        #expect(try nextDue(app, rent) == day("2026-11-01"))
    }

    // MARK: automatic bills

    @Test func oneOffBillsCannotBeAutomatic() throws {
        let app = try makeApp()

        let passport = try app.addBill(newBill("Passport fee", 1_500, due: "2026-11-05", repeats: .never, automatic: true))

        #expect(!passport.addAutomatically)
    }

    @Test func anAutomaticBillAddsItselfOnItsDueDate() throws {
        let s = try background(today: "2026-11-16")

        let notices = try s.app.runAutomaticBills()

        #expect(notices == ["Added automatically: Internet 800"])
        let internet = try #require(try s.app.monthBudget().expenses.first { $0.description == "Internet" })
        #expect(internet.amount == .rupees(800))
        #expect(internet.date == day("2026-11-16"))
        #expect(try nextDue(s.app, s.internet) == day("2026-12-16"))
    }

    @Test func daysTheAppWasNotOpenedAreCaughtUp() throws {
        let app = try makeApp(today: "2026-12-18")
        let internet = try app.addBill(newBill("Internet", 800, due: "2026-11-16", automatic: true))

        let notices = try app.runAutomaticBills()

        #expect(notices.count == 2)
        let dates = try app.monthBudget(for: .init(year: 2026, month: 11)).expenses.map(\.date)
            + (try app.monthBudget(for: .init(year: 2026, month: 12)).expenses.map(\.date))
        #expect(Set(dates) == [day("2026-11-16"), day("2026-12-16")])
        #expect(try nextDue(app, internet) == day("2027-01-16"))
    }

    @Test func aBillThatIsNotAutomaticIsNeverAddedByItself() throws {
        let s = try background(today: "2026-11-01")

        let notices = try s.app.runAutomaticBills()

        #expect(notices.isEmpty)
        #expect(!(try s.app.monthBudget().expenses.contains { $0.description == "Rent" }))
        #expect(try s.app.upcoming().items.first?.bill.name == "Rent")
    }

    @Test func runningItAgainDoesNotAddAgain() throws {
        let s = try background(today: "2026-11-16")
        _ = try s.app.runAutomaticBills()

        #expect(try s.app.runAutomaticBills().isEmpty)
        #expect(try s.app.monthBudget().expenses.filter { $0.description == "Internet" }.count == 1)
    }

    @Test func anAutomaticBillIgnoresAskEachTimeAndUsesItsDueDate() throws {
        let s = try background(today: "2026-11-17")
        try s.app.updatePreferences { $0.paymentDate = .askEachTime }

        _ = try s.app.runAutomaticBills()

        #expect(try s.app.monthBudget().expenses.first { $0.description == "Internet" }?.date == day("2026-11-16"))
    }

    @Test func undoingAnAutomaticAddRemovesTheExpenseAndMakesTheBillDueAgainButNotAutomatic() throws {
        let s = try background(today: "2026-11-16")
        _ = try s.app.runAutomaticBills()
        let added = try #require(try s.app.autoAdded().first)

        try s.app.undoAutoAdded(added.occurrenceID)

        #expect(!(try s.app.monthBudget().expenses.contains { $0.description == "Internet" }))
        #expect(try nextDue(s.app, s.internet) == day("2026-11-16"))
        #expect(try s.app.runAutomaticBills().isEmpty)
        #expect(try s.app.autoAdded().isEmpty)
    }

    @Test func theNextOccurrenceIsAutomaticAgainAfterAnUndo() throws {
        let database = try AppDatabase.inMemory()
        let november = BudgetApp(database: database, clock: FixedDayClock(date: day("2026-11-16")))
        let internet = try november.addBill(newBill("Internet", 800, due: "2026-11-16", automatic: true))
        _ = try november.runAutomaticBills()
        try november.undoAutoAdded(try #require(try november.autoAdded().first).occurrenceID)
        _ = try addOccurrence(november, internet)

        let december = BudgetApp(database: database, clock: FixedDayClock(date: day("2026-12-16")))

        #expect(try december.runAutomaticBills() == ["Added automatically: Internet 800"])
    }

    @Test func theNoticeStaysUntilTheAutoAddedListIsOpened() throws {
        let s = try background(today: "2026-11-16")
        _ = try s.app.runAutomaticBills()
        #expect(try s.app.billsAttention().autoAddedUnseen == 1)
        #expect(try s.app.billsAttention().badge == 1)

        try s.app.markAutoAddedSeen()

        #expect(try s.app.billsAttention().autoAddedUnseen == 0)
        #expect(try s.app.billsAttention().badge == 0)
        #expect(try s.app.autoAdded().count == 1)
    }

    // MARK: alerts and attention

    @Test(arguments: [
        (BillAlert.dayBefore, "2026-10-31", 1),
        (.dayBefore, "2026-10-30", 0),
        (.onDueDate, "2026-11-01", 1),
        (.onDueDate, "2026-10-31", 0),
        (.none, "2026-11-01", 0),
    ])
    func theAlertDecidesWhenABillCountsOnTheBillsTab(alert: BillAlert, today: String, badge: Int) throws {
        let app = try makeApp(today: today)
        try app.addBill(newBill("Rent", 20_000, due: "2026-11-01", alert: alert))

        #expect(try app.billsAttention().badge == badge)
    }

    @Test func aBillStillNotAddedAfterItsDueDateKeepsCounting() throws {
        let app = try makeApp(today: "2026-11-05")
        try app.addBill(newBill("Rent", 20_000, due: "2026-11-01", alert: .onDueDate))

        #expect(try app.billsAttention().badge == 1)
    }

    @Test func anAddedBillStopsCounting() throws {
        let app = try makeApp(today: "2026-11-01")
        // Auto-debit, so adding it leaves nothing to send and only the due alert is being tested.
        let rent = try app.addBill(newBill("Rent", 20_000, due: "2026-11-01", alert: .onDueDate, autoDebit: true))
        _ = try addOccurrence(app, rent)

        #expect(try app.billsAttention().badge == 0)
    }

    @Test func theMenuCountsBillsDueTodayThatAreNotAdded() throws {
        let app = try makeApp(today: "2026-11-01")
        try app.addBill(newBill("Rent", 20_000, due: "2026-11-01"))
        try app.addBill(newBill("Insurance", 1_500, due: "2026-11-01", repeats: .never))
        try app.addBill(newBill("Later", 1_500, due: "2026-11-09"))

        #expect(try app.billsAttention().menuCount == 2)
    }

    // MARK: to send

    @Test func aBillSheMustPayHerselfWaitsToBeSentAfterItIsAdded() throws {
        let s = try background()
        let expense = try addOccurrence(s.app, s.rent)

        let waiting = try s.app.billsToSend()

        #expect(waiting.map(\.billName) == ["Rent"])
        #expect(waiting.first?.amount == expense.amount)
        #expect(waiting.first?.dueDate == day("2026-11-01"))
        #expect(try s.app.billsAttention().badge == 1)
    }

    @Test func anAutoDebitBillNeverWaitsToBeSent() throws {
        let app = try makeApp()
        let premium = try app.addBill(newBill("Premium", 1_415, due: "2026-11-10", autoDebit: true))

        _ = try addOccurrence(app, premium)

        #expect(try app.billsToSend().isEmpty)
        #expect(try app.billsAttention().badge == 0)
    }

    @Test func tickingABillAsSentTakesItOffTheListAndTheBadge() throws {
        let s = try background()
        _ = try addOccurrence(s.app, s.rent)
        let waiting = try #require(try s.app.billsToSend().first)

        try s.app.markBillSent(waiting.occurrenceID, on: day("2026-11-02"))

        #expect(try s.app.billsToSend().isEmpty)
        #expect(try s.app.billsAttention().badge == 0)
    }

    @Test func aSentTickCanBeTakenBack() throws {
        let s = try background()
        _ = try addOccurrence(s.app, s.rent)
        let waiting = try #require(try s.app.billsToSend().first)
        try s.app.markBillSent(waiting.occurrenceID, on: day("2026-11-02"))

        try s.app.unmarkBillSent(waiting.occurrenceID)

        #expect(try s.app.billsToSend().map(\.billName) == ["Rent"])
    }

    @Test func switchingABillToAutoDebitClearsWhatWaitsToBeSent() throws {
        let s = try background()
        _ = try addOccurrence(s.app, s.rent)

        try s.app.updateBill(s.rent.id, newBill("Rent", 20_000, due: "2026-11-01", autoDebit: true))

        #expect(try s.app.billsToSend().isEmpty)
    }

    @Test func aMarkOnSomethingThatIsNotWaitingIsRefused() throws {
        let s = try background()

        #expect(throws: BillError.occurrenceNotFound(999)) { try s.app.markBillSent(999, on: day("2026-11-02")) }
    }
}
