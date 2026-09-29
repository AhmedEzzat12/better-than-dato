import Foundation

public enum RelativeTime {
    /// "now", "in 45m", "in 2h 15m", "at 17:30" (later today), "Thu 09:00" (another day).
    public static func untilStart(_ start: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        let seconds = start.timeIntervalSince(now)
        if seconds < 60 { return "now" }
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "in \(minutes)m" }
        if minutes < 6 * 60 { return "in \(duration(minutes: minutes))" }
        if calendar.isDate(start, inSameDayAs: now) {
            return "at \(format(start, template: "jmm", calendar: calendar, locale: locale))"
        }
        return format(start, template: "EEEjmm", calendar: calendar, locale: locale)
    }

    /// "8m left", "1h 5m left".
    public static func remaining(until end: Date, now: Date) -> String {
        let minutes = max(1, Int((end.timeIntervalSince(now) / 60).rounded(.up)))
        return "\(duration(minutes: minutes)) left"
    }

    /// "45m", "2h", "2h 15m".
    public static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    /// Formats with a locale-aware template ("jmm" follows the locale's 12/24-hour preference).
    static func format(_ date: Date, template: String, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale)
        return formatter.string(from: date)
    }
}
