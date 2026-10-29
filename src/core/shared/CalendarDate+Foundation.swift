import Foundation

extension CalendarDate {
    /// The calendar day the instant falls on, as seen in `calendar`.
    public init(_ instant: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        // A Calendar always yields a real day, so this cannot throw.
        try! self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// For lists, for example "30 Oct".
    public var shortTitle: String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(day) \(names[month - 1])"
    }
}
