import Foundation

/// When each beat of the demo happens, in seconds.
enum Timeline {
    static let duration = 37.0

    static let titleOut = 3.0
    static let popoverIn = 7.4
    /// (time, day offset from today) — the selection walks forward, then returns to today.
    static let navigation: [(time: Double, offset: Int)] = [(10.2, 1), (10.7, 2), (11.2, 3), (12.2, 0)]
    static let reminderTick = 13.5
    static let reminderGone = 15.0
    static let quickAddIn = 15.6
    static let typingStart = 16.4
    static let typingInterval = 0.068
    static let addPressed = 21.2
    static let toastOut = 22.9
    static let alertIn = 23.3
    static let alertOut = 27.7
    static let settingsIn = 27.9
    static let leadTimeChanged = 29.1
    static let videoOnlyOn = 29.8
    /// The Settings scene opens on Alerts, then switches to General for Check for Updates (as in the app).
    static let generalTab = 30.6
    static let checkForUpdates = 31.3
    static let upToDateIn = 31.6
    static let settingsOut = 33.1
    static let endIn = 33.0

    static let captions: [(start: Double, end: Double, text: String)] = [
        (3.4, 7.2, "Your next meeting, counting down in the menu bar"),
        (7.8, 13.2, "A month at a glance — every account in one agenda"),
        (13.3, 15.4, "Tick off reminders right in the agenda"),
        (15.8, 22.8, "Quick add: just type it — or press ⌥⌘N from any app"),
        (23.6, 27.5, "A full-screen alert when a meeting starts — Return joins"),
        (28.2, 32.9, "Alerts, shortcuts and automatic updates — all in Settings"),
    ]

    static func typedText(_ full: String, at t: Double) -> String {
        guard t >= typingStart else { return "" }
        let count = Int((t - typingStart) / typingInterval) + 1
        return String(full.prefix(count))
    }

    static func selectedOffset(at t: Double) -> Int? {
        guard let step = navigation.last(where: { t >= $0.time }), step.offset != 0 else { return nil }
        return step.offset
    }
}

// MARK: - Easing

/// 0 before `start`, 1 after `start + length`, eased in between.
func ramp(_ t: Double, _ start: Double, _ length: Double = 0.4) -> Double {
    let x = min(max((t - start) / length, 0), 1)
    return x * x * (3 - 2 * x)
}

/// Fades in at `start` and out at `end`.
func window(_ t: Double, _ start: Double, _ end: Double, fade: Double = 0.35) -> Double {
    ramp(t, start, fade) * (1 - ramp(t, end - fade, fade))
}

/// Ease-out with a small overshoot, for things that pop into place.
func pop(_ t: Double, _ start: Double, _ length: Double = 0.45) -> Double {
    let x = min(max((t - start) / length, 0), 1)
    let c1 = 1.4, c3 = c1 + 1
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}
