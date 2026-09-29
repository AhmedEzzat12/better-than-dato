import Foundation

/// Turns raw events from every account into the list the UI shows.
public enum EventPipeline {
    public static func visible(
        _ events: [CalendarEvent], hiddenCalendarIDs: Set<String>, hideDuplicates: Bool, calendarPriority: [String]
    ) -> [CalendarEvent] {
        let shown = events.filter { !hiddenCalendarIDs.contains($0.calendarID) && !$0.isCancelled && !$0.isDeclined }
        let unique = hideDuplicates ? dedupe(shown, calendarPriority: calendarPriority) : shown
        return unique.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    /// Collapses events with the same normalized title, start, end and all-day flag
    /// (the same meeting invited to two accounts). Keeps the copy whose calendar ranks first.
    public static func dedupe(_ events: [CalendarEvent], calendarPriority: [String]) -> [CalendarEvent] {
        let rank = Dictionary(calendarPriority.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        func rankOf(_ event: CalendarEvent) -> Int { rank[event.calendarID] ?? Int.max }

        var keptIndex: [DuplicateKey: Int] = [:]
        var kept: [CalendarEvent] = []
        for event in events {
            let key = DuplicateKey(event)
            if let index = keptIndex[key] {
                if rankOf(event) < rankOf(kept[index]) { kept[index] = event }
            } else {
                keptIndex[key] = kept.count
                kept.append(event)
            }
        }
        return kept
    }

    /// Calendar ids ordered by: the preferred account first, then account order, then title.
    public static func calendarPriority(
        calendars: [CalendarInfo], accounts: [AccountInfo], preferredAccountID: String?
    ) -> [String] {
        let accountOrder = Dictionary(accounts.map { ($0.id, $0.order) }, uniquingKeysWith: { first, _ in first })
        return calendars.sorted { a, b in
            let preferredA = a.accountID == preferredAccountID ? 0 : 1
            let preferredB = b.accountID == preferredAccountID ? 0 : 1
            if preferredA != preferredB { return preferredA < preferredB }
            let orderA = accountOrder[a.accountID] ?? Int.max
            let orderB = accountOrder[b.accountID] ?? Int.max
            if orderA != orderB { return orderA < orderB }
            return a.title.lowercased() < b.title.lowercased()
        }.map(\.id)
    }

    struct DuplicateKey: Hashable {
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool

        init(_ event: CalendarEvent) {
            title = event.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            start = event.start
            end = event.end
            isAllDay = event.isAllDay
        }
    }
}
