import Foundation

/// How far ahead the next event may be and still appear in the menu bar.
public enum MenuBarWindow: String, CaseIterable, Codable, Sendable {
    case thirtyMinutes
    case oneHour
    case threeHours
    case restOfToday
    case always
}

public struct MenuBarTitleSettings: Sendable {
    public var window: MenuBarWindow
    public var maxTitleLength: Int

    public init(window: MenuBarWindow = .restOfToday, maxTitleLength: Int = 25) {
        self.window = window
        self.maxTitleLength = maxTitleLength
    }
}

public struct MenuBarTitle: Equatable, Sendable {
    public let text: String
    public let event: CalendarEvent
}

public enum MenuBarTitleFormatter {
    /// An upcoming event closer than this takes priority over an ongoing one.
    static let imminentInterval: TimeInterval = 10 * 60

    public static func title(
        events: [CalendarEvent], now: Date, settings: MenuBarTitleSettings, calendar: Calendar, locale: Locale
    ) -> MenuBarTitle? {
        let candidates = events.filter { !$0.isAllDay && !$0.isCancelled && !$0.isDeclined && $0.end > now }
        let upcoming = candidates.filter { $0.start > now }.sorted { $0.start < $1.start }
        let ongoing = candidates.filter { $0.start <= now }.sorted { $0.end < $1.end }

        if let next = upcoming.first, next.start.timeIntervalSince(now) <= imminentInterval {
            return make(next, RelativeTime.untilStart(next.start, now: now, calendar: calendar, locale: locale), settings)
        }
        if let current = ongoing.first {
            return make(current, RelativeTime.remaining(until: current.end, now: now), settings)
        }
        if let next = upcoming.first, isWithinWindow(next.start, now: now, window: settings.window, calendar: calendar) {
            return make(next, RelativeTime.untilStart(next.start, now: now, calendar: calendar, locale: locale), settings)
        }
        return nil
    }

    public static func truncate(_ text: String, to maxLength: Int) -> String {
        guard maxLength > 1, text.count > maxLength else { return text }
        return text.prefix(maxLength - 1).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func make(_ event: CalendarEvent, _ relative: String, _ settings: MenuBarTitleSettings) -> MenuBarTitle {
        MenuBarTitle(text: "\(truncate(event.title, to: settings.maxTitleLength)) · \(relative)", event: event)
    }

    private static func isWithinWindow(_ start: Date, now: Date, window: MenuBarWindow, calendar: Calendar) -> Bool {
        let seconds = start.timeIntervalSince(now)
        switch window {
        case .thirtyMinutes: return seconds <= 30 * 60
        case .oneHour: return seconds <= 60 * 60
        case .threeHours: return seconds <= 3 * 60 * 60
        case .restOfToday: return calendar.isDate(start, inSameDayAs: now)
        case .always: return true
        }
    }
}
