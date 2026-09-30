import AppKit
import Sparkle

/// Sparkle auto-updates from the appcast published with each GitHub Release.
/// Only builds that carry an update-signing public key (release builds from CI) turn it on:
/// a build without one couldn't verify an update, so it never checks.
@MainActor
final class UpdaterService: NSObject, SPUStandardUserDriverDelegate {
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        if !publicKey.isEmpty {
            controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        }
    }

    var isEnabled: Bool { controller != nil }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    func checkForUpdates() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    // Menu bar apps have no Dock icon to badge; let Sparkle present scheduled updates gently.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }
}
