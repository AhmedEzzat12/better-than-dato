import Foundation

/// sRGB color that crosses the module boundary without AppKit.
public struct ColorRef: Hashable, Sendable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let gray = ColorRef(red: 0.56, green: 0.56, blue: 0.58)
}

/// One account as macOS sees it (an EventKit source: iCloud, Google, Exchange, ...).
public struct AccountInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    /// Display order among accounts; lower comes first.
    public var order: Int

    public init(id: String, title: String, order: Int) {
        self.id = id
        self.title = title
        self.order = order
    }
}

public enum CalendarKind: String, Hashable, Sendable {
    case events
    case reminders
}

/// An event calendar or a reminders list.
public struct CalendarInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var color: ColorRef
    public var accountID: String
    public var kind: CalendarKind
    public var isWritable: Bool

    public init(id: String, title: String, color: ColorRef, accountID: String, kind: CalendarKind, isWritable: Bool) {
        self.id = id
        self.title = title
        self.color = color
        self.accountID = accountID
        self.kind = kind
        self.isWritable = isWritable
    }
}

public struct CalendarEvent: Identifiable, Hashable, Sendable {
    /// Unique per occurrence (recurring events share `eventIdentifier`).
    public let id: String
    public var eventIdentifier: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var calendarID: String
    public var location: String?
    public var url: URL?
    public var notes: String?
    public var attendeeCount: Int
    public var isDeclined: Bool
    public var isCancelled: Bool

    public init(
        id: String,
        eventIdentifier: String? = nil,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        calendarID: String,
        location: String? = nil,
        url: URL? = nil,
        notes: String? = nil,
        attendeeCount: Int = 0,
        isDeclined: Bool = false,
        isCancelled: Bool = false
    ) {
        self.id = id
        self.eventIdentifier = eventIdentifier ?? id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.location = location
        self.url = url
        self.notes = notes
        self.attendeeCount = attendeeCount
        self.isDeclined = isDeclined
        self.isCancelled = isCancelled
    }
}

public struct ReminderItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var due: Date
    /// False for date-only reminders.
    public var hasTime: Bool
    public var isCompleted: Bool
    public var listID: String

    public init(id: String, title: String, due: Date, hasTime: Bool = true, isCompleted: Bool = false, listID: String) {
        self.id = id
        self.title = title
        self.due = due
        self.hasTime = hasTime
        self.isCompleted = isCompleted
        self.listID = listID
    }
}
