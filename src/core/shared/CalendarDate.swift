public enum CalendarDateError: Error, Equatable {
    case invalid(String)
}

/// A day on the calendar with no time zone: expenses belong to days, never to instants.
public struct CalendarDate: Hashable, Comparable, Sendable {
    public struct YearMonth: Hashable, Comparable, Sendable {
        public let year: Int
        public let month: Int

        public init(year: Int, month: Int) {
            self.year = year
            self.month = month
        }

        /// For example "October 2026".
        public var title: String {
            let names = ["January", "February", "March", "April", "May", "June",
                         "July", "August", "September", "October", "November", "December"]
            return "\(names[month - 1]) \(year)"
        }

        public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
            (lhs.year, lhs.month) < (rhs.year, rhs.month)
        }
    }

    public let year: Int
    public let month: Int
    public let day: Int

    public var yearMonth: YearMonth { YearMonth(year: year, month: month) }

    public var isoString: String {
        "\(Self.pad(year, to: 4))-\(Self.pad(month, to: 2))-\(Self.pad(day, to: 2))"
    }

    public init(year: Int, month: Int, day: Int) throws {
        guard (1...12).contains(month), day >= 1, day <= Self.daysIn(month: month, year: year) else {
            throw CalendarDateError.invalid("\(year)-\(month)-\(day)")
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public init(isoString: String) throws {
        let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            throw CalendarDateError.invalid(isoString)
        }
        try self.init(year: year, month: month, day: day)
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    private static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    private static func pad(_ value: Int, to width: Int) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }
}
