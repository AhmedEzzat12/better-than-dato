import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prefs: PreferencesStore!
    private var model: AppModel!
    private var statusController: StatusItemController!
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
