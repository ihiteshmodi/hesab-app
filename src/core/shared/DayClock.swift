import Foundation

/// The only place that knows what day it is, so rules and tests can control time.
public protocol DayClock: Sendable {
    func today() -> CalendarDate
}

public struct SystemDayClock: DayClock {
    public init() {}

    public func today() -> CalendarDate {
        CalendarDate(Date())
    }
}
