import Foundation

public struct MeetingAlertSettings: Sendable, Equatable {
    /// 0 = alert when the meeting starts; N = N minutes before.
    public var leadMinutes: Int
    /// Only alert for events that have a video-call link.
    public var onlyWithVideoLink: Bool

    public init(leadMinutes: Int = 0, onlyWithVideoLink: Bool = false) {
        self.leadMinutes = leadMinutes
        self.onlyWithVideoLink = onlyWithVideoLink
    }
}

/// Decides when the full-screen meeting alert fires.
public enum MeetingAlertPlanner {
    /// How late an alert may still fire (after sleep, launch, or a slow timer). Later than this,
    /// a full-screen interruption for a meeting already under way is more annoying than useful.
    public static let grace: TimeInterval = 120

    /// Events whose alert moment is in `(now - grace, now]`, in start order.
    public static func dueAlerts(
        events: [CalendarEvent], now: Date, settings: MeetingAlertSettings, alreadyAlerted: Set<String>
    ) -> [CalendarEvent] {
        candidates(events, now: now, settings: settings, alreadyAlerted: alreadyAlerted)
            .filter { alertDate(for: $0, settings) <= now && alertDate(for: $0, settings) > now.addingTimeInterval(-grace) }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    /// The next moment after `now` when an alert becomes due, for scheduling a precise timer.
    public static func nextAlertDate(
        events: [CalendarEvent], now: Date, settings: MeetingAlertSettings, alreadyAlerted: Set<String>
    ) -> Date? {
        candidates(events, now: now, settings: settings, alreadyAlerted: alreadyAlerted)
            .map { alertDate(for: $0, settings) }
            .filter { $0 > now }
            .min()
    }

    static func alertDate(for event: CalendarEvent, _ settings: MeetingAlertSettings) -> Date {
        event.start.addingTimeInterval(TimeInterval(-settings.leadMinutes * 60))
    }

    private static func candidates(
        _ events: [CalendarEvent], now: Date, settings: MeetingAlertSettings, alreadyAlerted: Set<String>
    ) -> [CalendarEvent] {
        events.filter { event in
            !event.isAllDay && !event.isCancelled && !event.isDeclined && event.end > now
                && !alreadyAlerted.contains(event.id)
                && (!settings.onlyWithVideoLink
                    || MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes) != nil)
        }
    }
}
