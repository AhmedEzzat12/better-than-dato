import Foundation

public enum QuickAddKind: String, CaseIterable, Hashable, Sendable {
    case event
    case reminder

    public var calendarKind: CalendarKind { self == .event ? .events : .reminders }
}

public struct QuickAddDraft: Equatable, Sendable {
    public var kind: QuickAddKind
    public var title: String
    /// Calendar (events) or list (reminders) chosen with `#token`; nil means "use the default".
    public var calendarID: String?
    public var unmatchedCalendarToken: String?
    public var isAllDay: Bool
    /// Event start, or reminder due date.
    public var start: Date
    public var end: Date
    public var hasDueTime: Bool
    public var hasExplicitDate: Bool

    /// All-day events are saved as one whole day (midnight to the next midnight), whatever time or
    /// seconds-based length the date pickers left behind.
    public func normalized(calendar: Calendar) -> QuickAddDraft {
        guard kind == .event, isAllDay else { return self }
        var copy = self
        copy.start = calendar.startOfDay(for: start)
        copy.end = calendar.date(byAdding: .day, value: 1, to: copy.start) ?? copy.start
        return copy
    }
}

/// Parses "Lunch with Sara tomorrow 1pm 1h #work" or "!Pay rent friday".
/// Rules: leading "!" = reminder; "#token" = calendar/list; "45m" / "1h30m" / "for 2 hours" = duration;
/// dates and times via NSDataDetector. Whatever is left is the title.
public struct QuickAddParser {
    public let calendar: Calendar
    public let now: Date
    public var defaultDurationMinutes = 30

    public init(calendar: Calendar, now: Date) {
        self.calendar = calendar
        self.now = now
    }

    static let hashtagPattern = #"(?:^|\s)#([\p{L}\p{N}_-]+)"#
    static let durationPattern = #"(?i)(?:\bfor\s+)?\b(?:(\d+(?:\.\d+)?)\s*(?:hours|hour|hrs|hr|h)(?:\s*(\d+)\s*(?:minutes|minute|mins|min|m))?|(\d+)\s*(?:minutes|minute|mins|min|m))\b"#
    static let clockTimePattern = #"(?i)\b\d{1,2}(:\d{2})?\s?(am|pm)\b|\b\d{1,2}:\d{2}\b|\bnoon\b|\bmidnight\b|\bat\s+\d{1,2}\b"#

    public func parse(_ input: String, calendars: [CalendarInfo], forcedKind: QuickAddKind? = nil) -> QuickAddDraft {
        var text = Self.collapsingWhitespace(input)
        var kind = QuickAddKind.event
        if text.hasPrefix("!") {
            kind = .reminder
            text = Self.collapsingWhitespace(String(text.dropFirst()))
        }
        if let forcedKind { kind = forcedKind }

        var calendarID: String?
        var unmatchedToken: String?
        if let match = Self.firstMatch(Self.hashtagPattern, in: text), let token = Self.group(1, of: match, in: text) {
            let targets = calendars.filter { $0.kind == kind.calendarKind && $0.isWritable }
            if let target = Self.matchCalendar(token, in: targets) {
                calendarID = target.id
            } else {
                unmatchedToken = token
            }
            text = Self.removing(match.range, from: text)
        }

        var durationMinutes: Int?
        if kind == .event, let match = Self.firstMatch(Self.durationPattern, in: text) {
            let hours = Self.group(1, of: match, in: text).flatMap(Double.init) ?? 0
            let extraMinutes = Self.group(2, of: match, in: text).flatMap(Int.init) ?? 0
            let minutes = Self.group(3, of: match, in: text).flatMap(Int.init) ?? 0
            let total = Int((hours * 60).rounded()) + extraMinutes + minutes
            if total > 0 {
                durationMinutes = total
                text = Self.removing(match.range, from: text)
            }
        }

        let detected = detectDate(in: text)
        if let detected { text = Self.removing(detected.range, from: text) }

        var draft = QuickAddDraft(
            kind: kind, title: Self.cleanTitle(text), calendarID: calendarID, unmatchedCalendarToken: unmatchedToken,
            isAllDay: false, start: now, end: now, hasDueTime: false, hasExplicitDate: detected != nil
        )
        let duration = TimeInterval((durationMinutes ?? defaultDurationMinutes) * 60)
        switch (kind, detected) {
        case (.event, .some(let found)) where found.hasTime:
            draft.start = found.date
            draft.end = found.date.addingTimeInterval(found.duration > 0 ? found.duration : duration)
        case (.event, .some(let found)):
            draft.isAllDay = true
            draft.start = calendar.startOfDay(for: found.date)
            draft.end = calendar.date(byAdding: .day, value: 1, to: draft.start) ?? draft.start
        case (.event, .none):
            draft.start = nextHalfHour()
            draft.end = draft.start.addingTimeInterval(duration)
        case (.reminder, .some(let found)):
            draft.hasDueTime = found.hasTime
            draft.start = found.hasTime ? found.date : calendar.startOfDay(for: found.date)
            draft.end = draft.start
        case (.reminder, .none):
            draft.start = calendar.startOfDay(for: now)
            draft.end = draft.start
        }
        return draft
    }

    // MARK: - Dates

    struct DetectedDate {
        let range: NSRange
        let date: Date
        let duration: TimeInterval
        let hasTime: Bool
    }

    func detectDate(in text: String) -> DetectedDate? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let ns = text as NSString
        guard let match = detector.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let date = match.date else { return nil }
        let hasTime = Self.containsClockTime(ns.substring(with: match.range))

        func isDateWord(_ word: String) -> Bool {
            detector.firstMatch(in: word, range: NSRange(location: 0, length: (word as NSString).length)) != nil
        }
        // True when `candidate` on its own is entirely a date phrase with the same meaning.
        func meansSame(_ candidate: NSRange) -> Bool {
            let phrase = ns.substring(with: candidate)
            let length = (phrase as NSString).length
            guard let other = detector.firstMatch(in: phrase, range: NSRange(location: 0, length: length)),
                  other.range.location == 0, other.range.length == length, let otherDate = other.date else { return false }
            return hasTime
                ? otherDate == date && other.duration == match.duration
                : calendar.isDate(otherDate, inSameDayAs: date)
        }

        // NSDataDetector sometimes swallows neighbouring title words ("Dinner friday 7pm").
        // Peel non-date words off both edges while the rest still means the same date.
        var range = match.range
        while let next = Self.peel(range, in: ns, fromStart: true), !isDateWord(next.word), meansSame(next.rest) {
            range = next.rest
        }
        while let next = Self.peel(range, in: ns, fromStart: false), !isDateWord(next.word), meansSame(next.rest) {
            range = next.rest
        }
        return DetectedDate(range: range, date: date, duration: match.duration, hasTime: hasTime)
    }

    /// Splits the first (or last) word off `range`; nil when `range` is a single word.
    static func peel(_ range: NSRange, in text: NSString, fromStart: Bool) -> (word: String, rest: NSRange)? {
        let phrase = text.substring(with: range) as NSString
        let space = fromStart ? phrase.range(of: " ") : phrase.range(of: " ", options: .backwards)
        guard space.location != NSNotFound else { return nil }
        if fromStart {
            return (phrase.substring(to: space.location),
                    NSRange(location: range.location + space.location + 1, length: range.length - space.location - 1))
        }
        return (phrase.substring(from: space.location + 1), NSRange(location: range.location, length: space.location))
    }

    static func containsClockTime(_ text: String) -> Bool {
        text.range(of: clockTimePattern, options: .regularExpression) != nil
    }

    func nextHalfHour() -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let minute = calendar.component(.minute, from: now)
        return calendar.date(byAdding: .minute, value: minute < 30 ? 30 : 60, to: hourStart) ?? now
    }

    // MARK: - Calendars

    /// Exact title match, then prefix, then substring; spaces and case ignored.
    static func matchCalendar(_ token: String, in calendars: [CalendarInfo]) -> CalendarInfo? {
        let wanted = normalize(token)
        let named = calendars.map { (calendar: $0, name: normalize($0.title)) }
        return named.first { $0.name == wanted }?.calendar
            ?? named.first { $0.name.hasPrefix(wanted) }?.calendar
            ?? named.first { $0.name.contains(wanted) }?.calendar
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }

    // MARK: - Text helpers

    static func cleanTitle(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        let dangling: Set<String> = ["at", "on", "by", "from", "for", "to", "@", "-", "–"]
        while let last = words.last, dangling.contains(last.lowercased()) { words.removeLast() }
        return words.joined(separator: " ")
    }

    static func collapsingWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    static func group(_ index: Int, of match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    static func removing(_ range: NSRange, from text: String) -> String {
        collapsingWhitespace((text as NSString).replacingCharacters(in: range, with: " "))
    }
}
