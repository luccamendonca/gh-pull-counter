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

    private static let queryFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private static let searchDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var startSearchTerm: String { Self.queryFormatter.string(from: start) }
    var endSearchTerm: String { Self.queryFormatter.string(from: end.addingTimeInterval(-0.001)) }
    var startDaySearchTerm: String { Self.searchDayFormatter.string(from: start) }
    var lastDaySearchTerm: String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        return Self.searchDayFormatter.string(from: lastDay)
    }

    var title: String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        return "\(Self.dayFormatter.string(from: start)) – \(Self.dayFormatter.string(from: lastDay))"
    }
}
