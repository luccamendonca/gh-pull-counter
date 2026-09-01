import Foundation

/// Sunday 00:00 local -> next Sunday 00:00 local (exclusive).
struct WeekRange: Equatable {
    let start: Date
    let end: Date

    static func current(for date: Date = Date()) -> WeekRange {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return WeekRange(start: date, end: date.addingTimeInterval(7 * 86_400))
        }
        return WeekRange(start: interval.start, end: interval.end)
    }

    var startSearchTerm: String { start.formatted(.iso8601) }
    var endSearchTerm: String { end.addingTimeInterval(-0.001).formatted(.iso8601) }
    var startDaySearchTerm: String { Self.daySearchTerm(start) }
    var lastDaySearchTerm: String {
        Self.daySearchTerm(Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end)
    }

    var title: String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        return "\(start.formatted(.dateTime.day().month())) – \(lastDay.formatted(.dateTime.day().month()))"
    }

    private static func daySearchTerm(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
