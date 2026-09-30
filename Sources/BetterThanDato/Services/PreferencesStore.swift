import DatoCore
import Foundation
import Observation

/// User settings persisted in UserDefaults. Every property writes through on change.
@Observable
@MainActor
final class PreferencesStore {
    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let showNextEvent = "showNextEvent"
        static let menuBarWindow = "menuBarWindow"
        static let maxTitleLength = "maxTitleLength"
        static let showColorDot = "showColorDot"
        static let firstWeekday = "firstWeekday"
        static let showWeekNumbers = "showWeekNumbers"
        static let agendaDays = "agendaDays"
        static let hideDuplicates = "hideDuplicates"
        static let openMeetingsInApp = "openMeetingsInApp"
        static let showFreeTime = "showFreeTime"
        static let workingHoursStart = "workingHoursStart"
        static let workingHoursEnd = "workingHoursEnd"
        static let hiddenCalendarIDs = "hiddenCalendarIDs"
        static let accountBadges = "accountBadges"
        static let lastEventCalendarID = "lastEventCalendarID"
        static let lastReminderListID = "lastReminderListID"
        static let quickAddShortcut = "quickAddShortcut"
        static let joinMeetingShortcut = "joinMeetingShortcut"
        static let meetingAlertsEnabled = "meetingAlertsEnabled"
        static let meetingAlertLeadMinutes = "meetingAlertLeadMinutes"
        static let meetingAlertsVideoOnly = "meetingAlertsVideoOnly"
    }

    var showNextEvent: Bool { didSet { defaults.set(showNextEvent, forKey: Key.showNextEvent) } }
    var menuBarWindow: MenuBarWindow { didSet { defaults.set(menuBarWindow.rawValue, forKey: Key.menuBarWindow) } }
    var maxTitleLength: Int { didSet { defaults.set(maxTitleLength, forKey: Key.maxTitleLength) } }
    var showColorDot: Bool { didSet { defaults.set(showColorDot, forKey: Key.showColorDot) } }
    /// 0 = follow the system; otherwise Calendar.firstWeekday (1 = Sunday, 2 = Monday, 7 = Saturday).
    var firstWeekday: Int { didSet { defaults.set(firstWeekday, forKey: Key.firstWeekday) } }
    var showWeekNumbers: Bool { didSet { defaults.set(showWeekNumbers, forKey: Key.showWeekNumbers) } }
    var agendaDays: Int { didSet { defaults.set(agendaDays, forKey: Key.agendaDays) } }
    var hideDuplicates: Bool { didSet { defaults.set(hideDuplicates, forKey: Key.hideDuplicates) } }
    var openMeetingsInApp: Bool { didSet { defaults.set(openMeetingsInApp, forKey: Key.openMeetingsInApp) } }
    var showFreeTime: Bool { didSet { defaults.set(showFreeTime, forKey: Key.showFreeTime) } }
    var workingHoursStart: Int { didSet { defaults.set(workingHoursStart, forKey: Key.workingHoursStart) } }
    var workingHoursEnd: Int { didSet { defaults.set(workingHoursEnd, forKey: Key.workingHoursEnd) } }
    var hiddenCalendarIDs: Set<String> { didSet { defaults.set(Array(hiddenCalendarIDs), forKey: Key.hiddenCalendarIDs) } }
    /// Custom badge per account id; missing = AccountBadge.defaultLabel.
    var accountBadges: [String: String] { didSet { defaults.set(accountBadges, forKey: Key.accountBadges) } }
    var lastEventCalendarID: String? { didSet { defaults.set(lastEventCalendarID, forKey: Key.lastEventCalendarID) } }
    var lastReminderListID: String? { didSet { defaults.set(lastReminderListID, forKey: Key.lastReminderListID) } }
    var quickAddShortcut: KeyCombo? { didSet { Self.saveCombo(quickAddShortcut, Key.quickAddShortcut, defaults) } }
    var joinMeetingShortcut: KeyCombo? { didSet { Self.saveCombo(joinMeetingShortcut, Key.joinMeetingShortcut, defaults) } }
    var meetingAlertsEnabled: Bool { didSet { defaults.set(meetingAlertsEnabled, forKey: Key.meetingAlertsEnabled) } }
    /// 0 = when the meeting starts; otherwise minutes before.
    var meetingAlertLeadMinutes: Int { didSet { defaults.set(meetingAlertLeadMinutes, forKey: Key.meetingAlertLeadMinutes) } }
    var meetingAlertsVideoOnly: Bool { didSet { defaults.set(meetingAlertsVideoOnly, forKey: Key.meetingAlertsVideoOnly) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showNextEvent = defaults.object(forKey: Key.showNextEvent) as? Bool ?? true
        menuBarWindow = defaults.string(forKey: Key.menuBarWindow).flatMap(MenuBarWindow.init(rawValue:)) ?? .restOfToday
        maxTitleLength = defaults.object(forKey: Key.maxTitleLength) as? Int ?? 25
        showColorDot = defaults.object(forKey: Key.showColorDot) as? Bool ?? false
        firstWeekday = defaults.object(forKey: Key.firstWeekday) as? Int ?? 0
        showWeekNumbers = defaults.object(forKey: Key.showWeekNumbers) as? Bool ?? false
        agendaDays = defaults.object(forKey: Key.agendaDays) as? Int ?? 7
        hideDuplicates = defaults.object(forKey: Key.hideDuplicates) as? Bool ?? true
        openMeetingsInApp = defaults.object(forKey: Key.openMeetingsInApp) as? Bool ?? true
        showFreeTime = defaults.object(forKey: Key.showFreeTime) as? Bool ?? true
        workingHoursStart = defaults.object(forKey: Key.workingHoursStart) as? Int ?? WorkingHours.standard.startMinutes
        workingHoursEnd = defaults.object(forKey: Key.workingHoursEnd) as? Int ?? WorkingHours.standard.endMinutes
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Key.hiddenCalendarIDs) ?? [])
        accountBadges = defaults.dictionary(forKey: Key.accountBadges) as? [String: String] ?? [:]
        lastEventCalendarID = defaults.string(forKey: Key.lastEventCalendarID)
        lastReminderListID = defaults.string(forKey: Key.lastReminderListID)
        quickAddShortcut = Self.loadCombo(Key.quickAddShortcut, defaults, fallback: .quickAddDefault)
        joinMeetingShortcut = Self.loadCombo(Key.joinMeetingShortcut, defaults, fallback: .joinMeetingDefault)
        meetingAlertsEnabled = defaults.object(forKey: Key.meetingAlertsEnabled) as? Bool ?? true
        meetingAlertLeadMinutes = defaults.object(forKey: Key.meetingAlertLeadMinutes) as? Int ?? 0
        meetingAlertsVideoOnly = defaults.object(forKey: Key.meetingAlertsVideoOnly) as? Bool ?? false
    }

    var workingHours: WorkingHours { WorkingHours(startMinutes: workingHoursStart, endMinutes: workingHoursEnd) }

    var meetingAlertSettings: MeetingAlertSettings {
        MeetingAlertSettings(leadMinutes: meetingAlertLeadMinutes, onlyWithVideoLink: meetingAlertsVideoOnly)
    }

    func badge(for account: AccountInfo) -> String {
        if let custom = accountBadges[account.id], !custom.isEmpty { return custom }
        return AccountBadge.defaultLabel(for: account.title)
    }

    /// Absent key = default shortcut; empty data = user cleared it.
    private static func loadCombo(_ key: String, _ defaults: UserDefaults, fallback: KeyCombo) -> KeyCombo? {
        guard let data = defaults.data(forKey: key) else { return fallback }
        if data.isEmpty { return nil }
        return (try? JSONDecoder().decode(KeyCombo.self, from: data)) ?? fallback
    }

    private static func saveCombo(_ combo: KeyCombo?, _ key: String, _ defaults: UserDefaults) {
        let data = combo.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        defaults.set(data, forKey: key)
    }
}
