import AppKit
import DatoCore

enum MeetingLauncher {
    /// Prefers the provider's desktop app when one is installed; otherwise the browser.
    static func open(_ link: MeetingLink, preferNativeApp: Bool) {
        if preferNativeApp, let native = link.nativeURL,
           NSWorkspace.shared.urlForApplication(toOpen: native) != nil,
           NSWorkspace.shared.open(native) {
            return
        }
        NSWorkspace.shared.open(link.url)
    }
}
