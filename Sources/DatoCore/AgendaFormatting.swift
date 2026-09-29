import Foundation

public enum AgendaFormatting {
    /// "Today", "Tomorrow", "Yesterday", or a short date such as "Thu 1 Oct".
    public static func dayTitle(for day: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return shortDate(day, calendar: calendar, locale: locale)
    }

    /// "09:00–09:30"; "…–02:00" / "22:00–…" when the event crosses midnight; "All day" when it covers the day.
    public static func timeRange(for event: CalendarEvent, on day: Date, calendar: Calendar, locale: Locale) -> String {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        if event.isAllDay || (event.start <= dayStart && event.end >= dayEnd) { return "All day" }
        let start = event.start < dayStart ? "…" : time(event.start, calendar: calendar, locale: locale)
        let end = event.end > dayEnd ? "…" : time(event.end, calendar: calendar, locale: locale)
        return "\(start)–\(end)"
    }

    public static func time(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        RelativeTime.format(date, template: "jmm", calendar: calendar, locale: locale)
    }

    /// "Mon 28 Sep".
    public static func shortDate(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        RelativeTime.format(date, template: "EEEdMMM", calendar: calendar, locale: locale)
    }

    /// "September 2026".
    public static func monthTitle(for date: Date, calendar: Calendar, locale: Locale) -> String {
        RelativeTime.format(date, template: "MMMMyyyy", calendar: calendar, locale: locale)
    }

    /// Event notes as plain text: HTML tags stripped, common entities decoded, capped at `limit` characters.
    /// Angle-bracketed links such as `<https://...>` are kept.
    public static func plainNotes(_ raw: String, limit: Int) -> String {
        var text = raw.replacingOccurrences(of: #"(?i)<br\s*/?>|</p>|</div>|</li>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<(?!https?:)[/!a-zA-Z][^>]*>"#, with: "", options: .regularExpression)
        // &amp; last so "&amp;lt;" becomes "&lt;", not "<".
        let entities = [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
