import HisaabCore

struct FixedDayClock: DayClock {
    let date: CalendarDate

    func today() -> CalendarDate { date }
}

func day(_ iso: String) -> CalendarDate {
    try! CalendarDate(isoString: iso)
}

func makeApp(today: String = "2026-10-30") throws -> BudgetApp {
    BudgetApp(database: try AppDatabase.inMemory(), clock: FixedDayClock(date: day(today)))
}
