import Foundation
import Testing
@testable import HisaabCore

/// Scenarios from tests/networth/portfolio/net-worth-history.feature
struct NetWorthHistoryTests {
    private final class Today: DayClock, @unchecked Sendable {
        var date: CalendarDate
        init(_ iso: String) { date = day(iso) }
        func today() -> CalendarDate { date }
    }

    private func setUp(today: String = "2026-11-10", bank: Int = 1_000_000) throws -> (app: BudgetApp, clock: Today) {
        let clock = Today(today)
        let app = BudgetApp(database: try AppDatabase.inMemory(), clock: clock)
        try app.setBankBalance(.rupees(bank))
        return (app, clock)
    }

    @Test func theFirstSnapshotIsTodaysNetWorth() throws {
        let (app, _) = try setUp()

        try app.recordNetWorth()

        let history = try app.netWorthHistory()
        #expect(history.points == [NetWorthPoint(date: day("2026-11-10"), amount: .rupees(1_000_000))])
        #expect(history.change == nil)
    }

    @Test func nothingNewIsSavedWhileNothingChangedInTheMonth() throws {
        let (app, clock) = try setUp()
        try app.recordNetWorth()

        clock.date = day("2026-11-20")
        try app.recordNetWorth()

        #expect(try app.netWorthHistory().points.count == 1)
    }

    @Test func aChangeIsSavedAsANewPointAndGivesTheChange() throws {
        let (app, clock) = try setUp()
        try app.recordNetWorth()

        clock.date = day("2026-11-20")
        try app.setBankBalance(.rupees(1_050_000))
        try app.recordNetWorth()

        let history = try app.netWorthHistory()
        #expect(history.points.map(\.amount) == [.rupees(1_000_000), .rupees(1_050_000)])
        #expect(history.change == .rupees(50_000))
    }

    @Test func changingItTwiceInOneDayKeepsTheLastValueOfTheDay() throws {
        let (app, _) = try setUp()
        try app.recordNetWorth()
        try app.setBankBalance(.rupees(1_100_000))
        try app.recordNetWorth()
        try app.setBankBalance(.rupees(1_200_000))
        try app.recordNetWorth()

        #expect(try app.netWorthHistory().points.map(\.amount) == [.rupees(1_200_000)])
    }

    @Test func aNewMonthGetsAPointEvenIfNothingChanged() throws {
        let (app, clock) = try setUp(today: "2026-10-28")
        try app.recordNetWorth()

        clock.date = day("2026-11-02")
        try app.recordNetWorth()

        #expect(try app.netWorthHistory().points.map(\.date) == [day("2026-10-28"), day("2026-11-02")])
    }

    @Test func historyComesBackWithARestore() throws {
        let (source, _) = try setUp()
        try source.recordNetWorth()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("nw-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = try source.exportData(into: folder)
        let target = BudgetApp(database: try AppDatabase.inMemory(), clock: Today("2026-11-10"))

        try target.confirmImport(try target.prepareImport(file), keepingPreviousIn: folder)

        #expect(try target.netWorthHistory().points.count == 1)
    }
}
