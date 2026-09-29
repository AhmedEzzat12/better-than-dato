import Foundation
@testable import DatoCore

enum Fixture {
    static let timeZone = TimeZone(identifier: "Europe/Berlin")!
    static let locale = Locale(identifier: "en_GB")

    /// Gregorian, Berlin time, Monday-first, en_GB (24-hour clock).
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func event(
        _ title: String, _ start: Date, _ end: Date,
        calendar: String = "work", allDay: Bool = false, declined: Bool = false, cancelled: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: "\(title)-\(start.timeIntervalSince1970)", title: title, start: start, end: end,
            isAllDay: allDay, calendarID: calendar, isDeclined: declined, isCancelled: cancelled
        )
    }

    static func reminder(_ title: String, _ due: Date, hasTime: Bool = true, list: String = "tasks") -> ReminderItem {
        ReminderItem(id: "r-\(title)", title: title, due: due, hasTime: hasTime, listID: list)
    }
}
