import AppKit

enum SystemSettingsLink {
    enum Pane: String {
        case calendars = "Privacy_Calendars"
        case reminders = "Privacy_Reminders"
    }

    static func open(_ pane: Pane) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") else { return }
        NSWorkspace.shared.open(url)
    }
}

enum CalendarAppLauncher {
    /// Opens the event in Calendar.app (undocumented ical:// scheme), falling back to just launching Calendar.
    static func open(eventIdentifier: String) {
        if let encoded = eventIdentifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "ical://ekevent/\(encoded)?method=show&options=more"),
           NSWorkspace.shared.open(url) {
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }
}
