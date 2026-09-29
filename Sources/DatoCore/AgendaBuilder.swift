import Foundation

public struct AgendaSettings: Sendable {
    public var showFreeTime: Bool
    public var workingHours: WorkingHours

    public init(showFreeTime: Bool = true, workingHours: WorkingHours = .standard) {
        self.showFreeTime = showFreeTime
        self.workingHours = workingHours
    }
}

public enum AgendaEntry: Identifiable, Hashable, Sendable {
    case event(CalendarEvent)
    case reminder(ReminderItem)
    case free(DateInterval)

    public var id: String {
        switch self {
        case .event(let event): "event:\(event.id)"
        case .reminder(let reminder): "reminder:\(reminder.id)"
        case .free(let interval): "free:\(interval.start.timeIntervalSince1970)"
        }
    }
}

public struct AgendaDay: Identifiable, Hashable, Sendable {
    /// Start of the day.
    public let date: Date
    /// Incomplete reminders due before today; only filled on today.
    public let overdue: [ReminderItem]
    /// Today's timed events that already ended (shown collapsed).
    public let earlierEvents: [CalendarEvent]
    public let entries: [AgendaEntry]
    public var id: Date { date }
}

public enum AgendaBuilder {
    /// Days from `firstDay` for `dayCount` days. Empty days are skipped except today,
    /// and except when a single day was requested.
    public static func build(
        events: [CalendarEvent], reminders: [ReminderItem], now: Date,
        firstDay: Date, dayCount: Int, settings: AgendaSettings, calendar: Calendar
    ) -> [AgendaDay] {
        let todayStart = calendar.startOfDay(for: now)
        let count = max(1, dayCount)
        var days: [AgendaDay] = []
        var dayStart = calendar.startOfDay(for: firstDay)

        for _ in 0..<count {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let isToday = dayStart == todayStart
            let dayEvents = events.filter { $0.start < dayEnd && ($0.end > dayStart || $0.start == dayStart) }
            let earlier = isToday ? dayEvents.filter { !$0.isAllDay && $0.end <= now } : []
            let earlierIDs = Set(earlier.map(\.id))
            let shown = dayEvents.filter { !earlierIDs.contains($0.id) }
            let dayReminders = reminders.filter { $0.due >= dayStart && $0.due < dayEnd }
            let overdue = isToday ? reminders.filter { $0.due < todayStart }.sorted { $0.due < $1.due } : []
            let free = isToday && settings.showFreeTime
                ? FreeTimeCalculator.freeSlots(events: dayEvents, now: now, workingHours: settings.workingHours, calendar: calendar)
                : []
            let entries = ordered(events: shown, reminders: dayReminders, free: free, dayStart: dayStart)

            if isToday || count == 1 || !entries.isEmpty || !earlier.isEmpty {
                days.append(AgendaDay(date: dayStart, overdue: overdue, earlierEvents: earlier, entries: entries))
            }
            dayStart = dayEnd
        }
        return days
    }

    /// All-day events, then date-only reminders, then timed items by time
    /// (events before reminders at the same minute, then by title).
    private static func ordered(
        events: [CalendarEvent], reminders: [ReminderItem], free: [DateInterval], dayStart: Date
    ) -> [AgendaEntry] {
        typealias Key = (group: Int, time: Date, kind: Int, title: String)
        var keyed: [(key: Key, entry: AgendaEntry)] = []
        for event in events {
            keyed.append(((event.isAllDay ? 0 : 2, event.isAllDay ? dayStart : event.start, 0, event.title), .event(event)))
        }
        for reminder in reminders {
            keyed.append(((reminder.hasTime ? 2 : 1, reminder.hasTime ? reminder.due : dayStart, 1, reminder.title), .reminder(reminder)))
        }
        for slot in free {
            keyed.append(((2, slot.start, 2, ""), .free(slot)))
        }
        return keyed
            .sorted { ($0.key.group, $0.key.time, $0.key.kind, $0.key.title) < ($1.key.group, $1.key.time, $1.key.kind, $1.key.title) }
            .map(\.entry)
    }
}
