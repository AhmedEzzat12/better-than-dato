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

/// macOS's own transparency controls; the popover's Liquid Glass follows them (apps can't change it).
enum AppearanceSettingsLink {
    static func openAppearance() { open("x-apple.systempreferences:com.apple.Appearance-Settings.extension") }
    static func openAccessibilityDisplay() { open("x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display") }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
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
