import AppKit
import DatoCore
import Observation

enum PopoverMode {
    case agenda
    case quickAdd
}

/// Single source of UI state. Raw EventKit data comes in through `refresh()`;
/// everything the UI shows is derived with DatoCore.
@Observable
@MainActor
final class AppModel {
    @ObservationIgnored let service: CalendarService
    @ObservationIgnored let prefs: PreferencesStore
    @ObservationIgnored var onOpenSettings: (() -> Void)?
    /// Called with the meetings whose full-screen alert is due.
    @ObservationIgnored var onMeetingAlert: (([CalendarEvent]) -> Void)?

    private(set) var accounts: [AccountInfo] = []
    private(set) var calendars: [CalendarInfo] = [] {
        didSet { calendarsByID = Dictionary(calendars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) }
    }
    private(set) var calendarsByID: [String: CalendarInfo] = [:]
    private(set) var events: [CalendarEvent] = []
    private(set) var reminders: [ReminderItem] = []
    /// Reminders just ticked off; kept visible (struck through) for a short undo window.
    private(set) var pendingCompletions: [String: ReminderItem] = [:]
    private(set) var eventAccess: AccessState = .notDetermined
    private(set) var reminderAccess: AccessState = .notDetermined
    private(set) var now = Date()
    private(set) var toast: String?
    private(set) var hotKeyFailures: Set<HotKeyCenter.Action> = []

    var displayedMonth = Date() {
        didSet {
            if !calendar.isDate(oldValue, equalTo: displayedMonth, toGranularity: .month) { scheduleRefresh(delay: 0) }
        }
    }
    /// nil = upcoming agenda; otherwise the day picked in the grid.
    var selectedDay: Date?
    var popoverMode: PopoverMode = .agenda
    var isPinned = false
    /// Bumped each time the popover opens so its views start fresh (scroll position, expanded rows).
    private(set) var popoverSession = 0

    func beginPopoverSession() {
        popoverSession += 1
        goToToday()
    }

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var completionTokens: [String: UUID] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var alertTask: Task<Void, Never>?
    @ObservationIgnored private var alertedEventIDs: Set<String> = []

    init(service: CalendarService, prefs: PreferencesStore) {
        self.service = service
        self.prefs = prefs
    }

    // MARK: - Lifecycle

    func start() {
        service.onChange = { [weak self] in self?.scheduleRefresh() }
        let center = NotificationCenter.default
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    // Foundation caches TimeZone.current (and so Calendar.current) until told otherwise.
                    NSTimeZone.resetSystemTimeZone()
                    self?.scheduleRefresh(delay: 0)
                }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRefresh(delay: 0) }
        })
        startTicking()
        scheduleRefresh(delay: 0)
    }

    /// Coalesces bursts of change notifications into one fetch.
    func scheduleRefresh(delay: TimeInterval = 0.5) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    func refresh() async {
        eventAccess = service.eventAccess
        reminderAccess = service.reminderAccess
        now = Date()
        calendars = service.calendars()
        accounts = service.accounts()
        let interval = fetchInterval
        events = service.events(in: interval)
        reminders = await service.reminders(dueBefore: interval.end)
        alertedEventIDs.formIntersection(events.map(\.id))
        rescheduleMeetingAlerts()
    }

    func requestAccess() async {
        await service.requestAccess()
        await refresh()
    }

    /// Updates `now` on every minute boundary so the menu bar countdown stays exact.
    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                let current = Date().timeIntervalSinceReferenceDate
                let nextMinute = (current / 60).rounded(.down) * 60 + 60
                try? await Task.sleep(for: .seconds(nextMinute - current + 0.05))
                guard let self else { return }
                self.now = Date()
                self.rescheduleMeetingAlerts()
            }
        }
    }

    // MARK: - Derived state

    var calendar: Calendar {
        var calendar = Calendar.current
        if prefs.firstWeekday != 0 { calendar.firstWeekday = prefs.firstWeekday }
        return calendar
    }

    var visibleEvents: [CalendarEvent] {
        let preferredAccount = defaultCalendarID(for: .event).flatMap { calendarsByID[$0]?.accountID }
        let priority = EventPipeline.calendarPriority(calendars: calendars, accounts: accounts, preferredAccountID: preferredAccount)
        return EventPipeline.visible(
            events, hiddenCalendarIDs: prefs.hiddenCalendarIDs, hideDuplicates: prefs.hideDuplicates, calendarPriority: priority
        )
    }

    var visibleReminders: [ReminderItem] {
        let live = reminders.filter { pendingCompletions[$0.id] == nil }
        return (live + pendingCompletions.values).filter { !prefs.hiddenCalendarIDs.contains($0.listID) }
    }

    var upcomingRange: DateInterval {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: prefs.agendaDays, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// True when the picked day is outside the upcoming range, so the agenda shows just that day.
    var agendaIsSingleDay: Bool {
        guard let selectedDay else { return false }
        return selectedDay < upcomingRange.start || selectedDay >= upcomingRange.end
    }

    var agenda: [AgendaDay] {
        let settings = AgendaSettings(showFreeTime: prefs.showFreeTime, workingHours: prefs.workingHours)
        let singleDay = agendaIsSingleDay ? selectedDay : nil
        return AgendaBuilder.build(
            events: visibleEvents, reminders: visibleReminders, now: now,
            firstDay: singleDay ?? now, dayCount: singleDay == nil ? prefs.agendaDays : 1,
            settings: settings, calendar: calendar
        )
    }

    var monthGrid: MonthGridModel { MonthGrid.make(containing: displayedMonth, calendar: calendar) }

    var dayMarkers: [Date: [ColorRef]] {
        DayMarkers.colors(
            days: monthGrid.days.map(\.date), events: visibleEvents, reminders: visibleReminders,
            calendarColors: calendarsByID.mapValues(\.color), calendar: calendar
        )
    }

    var monthTitle: String { AgendaFormatting.monthTitle(for: displayedMonth, calendar: calendar, locale: .current) }

    var menuBarTitle: MenuBarTitle? {
        guard prefs.showNextEvent, eventAccess == .granted else { return nil }
        return MenuBarTitleFormatter.title(
            events: visibleEvents, now: now,
            settings: MenuBarTitleSettings(window: prefs.menuBarWindow, maxTitleLength: prefs.maxTitleLength),
            calendar: calendar, locale: .current
        )
    }

    private var fetchInterval: DateInterval {
        let grid = monthGrid.interval
        let upcoming = upcomingRange
        return DateInterval(start: min(grid.start, upcoming.start), end: max(grid.end, upcoming.end))
    }

    // MARK: - Lookups

    func calendarInfo(_ id: String) -> CalendarInfo? { calendarsByID[id] }

    func account(forCalendarID id: String) -> AccountInfo? {
        guard let accountID = calendarsByID[id]?.accountID else { return nil }
        return accounts.first { $0.id == accountID }
    }

    func badge(forCalendarID id: String) -> String {
        account(forCalendarID: id).map(prefs.badge(for:)) ?? "?"
    }

    func writableCalendars(for kind: QuickAddKind) -> [CalendarInfo] {
        calendars.filter { $0.kind == kind.calendarKind && $0.isWritable }
    }

    /// Last used calendar/list, else the system default, else the first writable one.
    func defaultCalendarID(for kind: QuickAddKind) -> String? {
        let writable = writableCalendars(for: kind)
        let preferred = kind == .event
            ? prefs.lastEventCalendarID ?? service.defaultEventCalendarID()
            : prefs.lastReminderListID ?? service.defaultReminderListID()
        if let preferred, writable.contains(where: { $0.id == preferred }) { return preferred }
        return writable.first?.id
    }

    // MARK: - Navigation

    func showMonth(offset: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    func goToToday() {
        selectedDay = nil
        displayedMonth = now
    }

    func select(day: Date) {
        let start = calendar.startOfDay(for: day)
        selectedDay = start
        if !calendar.isDate(start, equalTo: displayedMonth, toGranularity: .month) { displayedMonth = start }
    }

    func moveSelection(byDays days: Int) {
        let base = selectedDay ?? calendar.startOfDay(for: now)
        if let target = calendar.date(byAdding: .day, value: days, to: base) { select(day: target) }
    }

    // MARK: - Actions

    func toggleReminder(_ item: ReminderItem) {
        do {
            if item.isCompleted {
                try service.setReminder(id: item.id, completed: false)
                pendingCompletions[item.id] = nil
                completionTokens[item.id] = nil
                var restored = item
                restored.isCompleted = false
                if !reminders.contains(where: { $0.id == item.id }) { reminders.append(restored) }
            } else {
                try service.setReminder(id: item.id, completed: true)
                var done = item
                done.isCompleted = true
                reminders.removeAll { $0.id == item.id }
                pendingCompletions[item.id] = done
                let token = UUID()
                completionTokens[item.id] = token
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    guard let self, self.completionTokens[item.id] == token else { return }
                    self.pendingCompletions[item.id] = nil
                    self.completionTokens[item.id] = nil
                }
            }
        } catch {
            showToast("Couldn't update reminder: \(error.localizedDescription)")
        }
    }

    func save(_ draft: QuickAddDraft, calendarID: String) throws {
        let draft = draft.normalized(calendar: calendar)
        let title = draft.title.trimmingCharacters(in: .whitespaces)
        switch draft.kind {
        case .event:
            try service.saveEvent(title: title, start: draft.start, end: draft.end, isAllDay: draft.isAllDay, calendarID: calendarID)
            prefs.lastEventCalendarID = calendarID
        case .reminder:
            try service.saveReminder(title: title, due: draft.start, hasTime: draft.hasDueTime, listID: calendarID)
            prefs.lastReminderListID = calendarID
        }
        showToast("Added to \(calendarsByID[calendarID]?.title ?? "calendar")")
        popoverMode = .agenda
        select(day: draft.start)
        scheduleRefresh(delay: 0)
    }

    /// Ongoing or starting within 15 minutes, with a meeting link; earliest start wins.
    func currentMeeting() -> (event: CalendarEvent, link: MeetingLink)? {
        let horizon = now.addingTimeInterval(15 * 60)
        for event in visibleEvents where !event.isAllDay && event.start <= horizon && event.end > now {
            if let link = MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes) {
                return (event, link)
            }
        }
        return nil
    }

    // MARK: - Meeting alerts

    /// Fires any alert that is due now, then sleeps until the next one. Called after every refresh,
    /// minute tick and settings change, so the plan always reflects the latest events.
    func rescheduleMeetingAlerts() {
        alertTask?.cancel()
        guard prefs.meetingAlertsEnabled, eventAccess == .granted else { return }
        let settings = prefs.meetingAlertSettings
        let due = MeetingAlertPlanner.dueAlerts(events: visibleEvents, now: Date(), settings: settings, alreadyAlerted: alertedEventIDs)
        if !due.isEmpty {
            alertedEventIDs.formUnion(due.map(\.id))
            onMeetingAlert?(due)
        }
        guard let next = MeetingAlertPlanner.nextAlertDate(
            events: visibleEvents, now: Date(), settings: settings, alreadyAlerted: alertedEventIDs
        ) else { return }
        alertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, next.timeIntervalSinceNow) + 0.05))
            guard !Task.isCancelled else { return }
            self?.rescheduleMeetingAlerts()
        }
    }

    /// Shows the alert for the next upcoming meeting (or a sample) so the look can be checked from Settings.
    func previewMeetingAlert() {
        let upcoming = visibleEvents.first { !$0.isAllDay && $0.end > now }
        let sample = CalendarEvent(
            id: "preview", title: "Design review", start: now, end: now.addingTimeInterval(30 * 60),
            calendarID: writableCalendars(for: .event).first?.id ?? "preview",
            location: "https://meet.google.com/abc-defg-hij"
        )
        onMeetingAlert?([upcoming ?? sample])
    }

    func join(_ link: MeetingLink) {
        MeetingLauncher.open(link, preferNativeApp: prefs.openMeetingsInApp)
    }

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func applyShortcuts() {
        var failures = Set<HotKeyCenter.Action>()
        if !HotKeyCenter.shared.register(.quickAdd, combo: prefs.quickAddShortcut) { failures.insert(.quickAdd) }
        if !HotKeyCenter.shared.register(.joinMeeting, combo: prefs.joinMeetingShortcut) { failures.insert(.joinMeeting) }
        hotKeyFailures = failures
    }

    func openSettings() { onOpenSettings?() }
}
