import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prefs: PreferencesStore!
    private var model: AppModel!
    private var statusController: StatusItemController!
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        prefs = PreferencesStore()
        model = AppModel(service: CalendarService(), prefs: prefs)
        statusController = StatusItemController(model: model, prefs: prefs)

        model.onOpenSettings = { [weak self] in self?.showSettings() }
        HotKeyCenter.shared.setHandler(for: .quickAdd) { [weak self] in
            self?.statusController.show(mode: .quickAdd)
        }
        HotKeyCenter.shared.setHandler(for: .joinMeeting) { [weak self] in
            self?.joinCurrentMeeting()
        }
        model.applyShortcuts()
        model.start()
    }

    /// Menu-bar-only apps show no menu, but AppKit still routes ⌘C/⌘V/⌘Z/⌘A/⌘W through the main
    /// menu's key equivalents. Without one, those shortcuts do nothing in text fields.
    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Better Than Dato", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z").keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let mainMenu = NSMenu()
        for submenu in [appMenu, editMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }

    private func showSettings() {
        if !model.isPinned { statusController.close() }
        settingsWindow.show(model: model, prefs: prefs)
    }

    private func joinCurrentMeeting() {
        if let meeting = model.currentMeeting() {
            model.join(meeting.link)
        } else {
            statusController.show(mode: .agenda)
            model.showToast("No meeting to join")
        }
    }
}
