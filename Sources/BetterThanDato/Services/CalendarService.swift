import AppKit
import DatoCore
import EventKit

enum AccessState: Equatable {
    case notDetermined
    case granted
    case denied

    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .fullAccess: self = .granted
        case .notDetermined: self = .notDetermined
        default: self = .denied // denied, restricted, write-only
        }
    }
}

enum CalendarServiceError: LocalizedError {
    case calendarNotFound
    case reminderNotFound

    var errorDescription: String? {
        switch self {
        case .calendarNotFound: "That calendar no longer exists."
        case .reminderNotFound: "That reminder no longer exists."
        }
    }
}

/// The only type that talks to EventKit. Maps EK objects into DatoCore value types.
@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?

    /// Called on the main thread when anything in the calendar database changes.
    var onChange: (() -> Void)?

    init() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    var eventAccess: AccessState { AccessState(EKEventStore.authorizationStatus(for: .event)) }
    var reminderAccess: AccessState { AccessState(EKEventStore.authorizationStatus(for: .reminder)) }

    func requestAccess() async {
        if eventAccess == .notDetermined { _ = try? await store.requestFullAccessToEvents() }
        if reminderAccess == .notDetermined { _ = try? await store.requestFullAccessToReminders() }
        store.reset()
    }

    func calendars() -> [CalendarInfo] {
        var result: [CalendarInfo] = []
        if eventAccess == .granted { result += store.calendars(for: .event).map { Self.info($0, kind: .events) } }
        if reminderAccess == .granted { result += store.calendars(for: .reminder).map { Self.info($0, kind: .reminders) } }
        return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Accounts that own at least one visible calendar or list, alphabetical.
    func accounts() -> [AccountInfo] {
        let used = Set(calendars().map(\.accountID))
        return store.sources
            .filter { used.contains($0.sourceIdentifier) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .enumerated()
            .map { AccountInfo(id: $1.sourceIdentifier, title: $1.title, order: $0) }
    }

    func events(in interval: DateInterval) -> [CalendarEvent] {
        guard eventAccess == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate).compactMap(Self.event)
    }

    /// Incomplete reminders due before `end`, including overdue ones.
    func reminders(dueBefore end: Date) async -> [ReminderItem] {
        guard reminderAccess == .granted else { return [] }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
        return await Self.fetchReminders(store, predicate)
    }

    func saveEvent(title: String, start: Date, end: Date, isAllDay: Bool, calendarID: String) throws {
        guard let calendar = store.calendar(withIdentifier: calendarID) else { throw CalendarServiceError.calendarNotFound }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.calendar = calendar
        event.isAllDay = isAllDay
        event.startDate = start
        // EventKit's all-day convention: end on the last second of the final day.
        event.endDate = isAllDay ? end.addingTimeInterval(-1) : end
        try store.save(event, span: .thisEvent, commit: true)
    }

    func saveReminder(title: String, due: Date, hasTime: Bool, listID: String) throws {
        guard let list = store.calendar(withIdentifier: listID) else { throw CalendarServiceError.calendarNotFound }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list
        let fields: Set<Calendar.Component> = hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: due)
        if hasTime { reminder.addAlarm(EKAlarm(absoluteDate: due)) }
        try store.save(reminder, commit: true)
    }

    func setReminder(id: String, completed: Bool) throws {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw CalendarServiceError.reminderNotFound
        }
        reminder.isCompleted = completed
        try store.save(reminder, commit: true)
    }

    func defaultEventCalendarID() -> String? { store.defaultCalendarForNewEvents?.calendarIdentifier }
    func defaultReminderListID() -> String? { store.defaultCalendarForNewReminders()?.calendarIdentifier }

    // MARK: - Mapping

    private static func info(_ calendar: EKCalendar, kind: CalendarKind) -> CalendarInfo {
        CalendarInfo(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            color: ColorRef(nsColor: calendar.color),
            accountID: calendar.source?.sourceIdentifier ?? "local",
            kind: kind,
            isWritable: calendar.allowsContentModifications
        )
    }

    private static func event(_ event: EKEvent) -> CalendarEvent? {
        guard let identifier = event.eventIdentifier,
              let start = event.startDate, let end = event.endDate,
              let calendar = event.calendar else { return nil }
        let title = event.title ?? ""
        let me = event.attendees?.first(where: \.isCurrentUser)
        return CalendarEvent(
            id: "\(identifier)|\(start.timeIntervalSince1970)",
            eventIdentifier: identifier,
            title: title.isEmpty ? "Untitled" : title,
            start: start,
            end: end,
            isAllDay: event.isAllDay,
            calendarID: calendar.calendarIdentifier,
            location: event.location,
            url: event.url,
            notes: event.notes,
            attendeeCount: event.attendees?.count ?? 0,
            isDeclined: me?.participantStatus == .declined,
            isCancelled: event.status == .canceled
        )
    }

    /// Nonisolated so the EventKit callback (background thread) never touches main-actor state.
    private nonisolated static func fetchReminders(_ store: EKEventStore, _ predicate: NSPredicate) async -> [ReminderItem] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: (reminders ?? []).compactMap(reminder))
            }
        }
    }

    private nonisolated static func reminder(_ reminder: EKReminder) -> ReminderItem? {
        guard let components = reminder.dueDateComponents, let list = reminder.calendar,
              let due = (components.calendar ?? Calendar.current).date(from: components) else { return nil }
        let title = reminder.title ?? ""
        return ReminderItem(
            id: reminder.calendarItemIdentifier,
            title: title.isEmpty ? "Untitled" : title,
            due: due,
            hasTime: components.hour != nil,
            isCompleted: reminder.isCompleted,
            listID: list.calendarIdentifier
        )
    }
}
