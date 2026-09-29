import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let windowID = NSUserInterfaceItemIdentifier("BetterThanDatoSettings")
    private var window: NSWindow?

    func show(model: AppModel, prefs: PreferencesStore) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView().environment(model).environment(prefs))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Better Than Dato Settings"
            window.identifier = Self.windowID
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
