import Foundation

public enum DayMarkers {
    /// Up to `maxDots` distinct calendar colors per day, in time order, keyed by start of day.
    /// Days with nothing scheduled have no entry.
    public static func colors(
        days: [Date], events: [CalendarEvent], reminders: [ReminderItem],
        calendarColors: [String: ColorRef], calendar: Calendar, maxDots: Int = 3
    ) -> [Date: [ColorRef]] {
        var result: [Date: [ColorRef]] = [:]
        for day in days {
            let start = calendar.startOfDay(for: day)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            let items = events.filter { $0.start < end && $0.end > start }.map { ($0.start, $0.calendarID) }
                + reminders.filter { $0.due >= start && $0.due < end }.map { ($0.due, $0.listID) }

            var colors: [ColorRef] = []
            for (_, calendarID) in items.sorted(by: { $0.0 < $1.0 }) {
                let color = calendarColors[calendarID] ?? .gray
                if !colors.contains(color) { colors.append(color) }
                if colors.count == maxDots { break }
            }
            if !colors.isEmpty { result[start] = colors }
        }
        return result
    }
}
