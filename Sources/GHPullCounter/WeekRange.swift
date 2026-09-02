import Foundation

/// Thursday 11:00 local -> Thursday 10:00 local next week (exclusive).
///
/// The hour between 10:00 and 11:00 on Thursday belongs to no week: the counter
/// stays frozen on the week that just closed until the next one opens at 11:00.
struct WeekRange: Equatable {
    /// Gregorian weekday numbering: Sunday == 1, so Thursday == 5.
    private static let startWeekday = 5
    private static let startHour = 11
    private static let endHour = 10

    let start: Date
    let end: Date
    /// When the next week opens; the counter rolls over here, not at `end`.
    let nextStart: Date

    static func current(for date: Date = Date()) -> WeekRange {
        let calendar = Calendar.current
        let components = DateComponents(hour: startHour, minute: 0, second: 0, weekday: startWeekday)
        // `.backward` matches strictly before the anchor, so nudge it to keep an
        // exact Thursday 11:00:00 inside its own week.
        guard let start = calendar.nextDate(after: date.addingTimeInterval(1),
                                            matching: components,
                                            matchingPolicy: .nextTime,
                                            direction: .backward),
              let nextStart = calendar.date(byAdding: .day, value: 7, to: start),
              let end = calendar.date(byAdding: .hour, value: endHour - startHour, to: nextStart)
        else {
            let fallbackEnd = date.addingTimeInterval(7 * 86_400)
            return WeekRange(start: date, end: fallbackEnd, nextStart: fallbackEnd)
        }
        return WeekRange(start: start, end: end, nextStart: nextStart)
    }

    var startSearchTerm: String { start.formatted(.iso8601) }
    var endSearchTerm: String { end.addingTimeInterval(-0.001).formatted(.iso8601) }
    var startDaySearchTerm: String { Self.daySearchTerm(start) }
    /// `end` lands mid-morning, so its own day is still part of the window.
    var lastDaySearchTerm: String { Self.daySearchTerm(end) }

    var title: String {
        "\(start.formatted(.dateTime.day().month())) – \(end.formatted(.dateTime.day().month()))"
    }

    private static func daySearchTerm(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
