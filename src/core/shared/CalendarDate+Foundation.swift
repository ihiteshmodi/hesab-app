import Foundation

extension CalendarDate {
    /// The calendar day the instant falls on, as seen in `calendar`.
    public init(_ instant: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        // A Calendar always yields a real day, so this cannot throw.
        try! self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// The day `days` later (or earlier when negative).
    public func adding(days: Int) -> CalendarDate {
        let utc = Self.utcCalendar
        let start = utc.date(from: DateComponents(year: year, month: month, day: day))!
        return CalendarDate(utc.date(byAdding: .day, value: days, to: start)!, calendar: utc)
    }

    /// Whole days from this day to `other`; negative when `other` is earlier.
    public func days(until other: CalendarDate) -> Int {
        let utc = Self.utcCalendar
        let from = utc.date(from: DateComponents(year: year, month: month, day: day))!
        let to = utc.date(from: DateComponents(year: other.year, month: other.month, day: other.day))!
        return utc.dateComponents([.day], from: from, to: to).day!
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Midday of the day in `calendar`, for date pickers.
    public func instant(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    /// For lists, for example "30 Oct".
    public var shortTitle: String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(day) \(names[month - 1])"
    }
}
