import AppKit

@main
enum BetterThanDatoApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        // NSApplication holds its delegate weakly; keep ours alive for the app's lifetime.
        withExtendedLifetime(delegate) { app.run() }
    }
}
