# BetterThanDato v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS menu bar app showing the next event, with a popover containing a month grid, a merged multi-account agenda (events + reminders), quick add, meeting join, and global hotkeys.

**Architecture:** SwiftPM package with a pure-logic library `DatoCore` (Foundation only, fully unit-tested) and a thin executable `BetterThanDato` (AppKit status item + SwiftUI popover + EventKit adapter). `AppModel` (`@Observable`) is the single UI state holder; every decision (what the menu bar says, how the agenda is grouped, how quick-add text parses) lives in `DatoCore`.

**Tech Stack:** Swift 6.3 toolchain, SwiftPM, SwiftUI + AppKit, EventKit, Carbon (hotkeys), ServiceManagement, Swift Testing. No Xcode.

**Spec:** `docs/superpowers/specs/2026-09-29-menu-bar-calendar-design.md`

## Global Constraints

- Minimum macOS 14.0 (`platforms: [.macOS(.v14)]`, `LSMinimumSystemVersion=14.0`).
- No Xcode; build with Command Line Tools. Tests only via `scripts/test.sh` (adds CLT framework paths).
- `DatoCore` imports Foundation only — no AppKit, SwiftUI or EventKit.
- App target compiles in Swift 5 language mode (`.swiftLanguageMode(.v5)`); `DatoCore` in Swift 6 mode.
- Bundle id `com.ahmede.BetterThanDato`, executable/product name `BetterThanDato`, display name `Better Than Dato`.
- `LSUIElement=true` (no Dock icon). Not sandboxed, no hardened runtime.
- Signing: `codesign --sign "${SIGN_IDENTITY:--}"`.
- Tests use `Fixture.calendar` (Gregorian, `Europe/Berlin`, Monday-first, `en_GB` locale → 24h times) except `QuickAddParser` date tests, which must use `Calendar.current` + `Date()` because `NSDataDetector` resolves relative words against the real clock and system time zone.
- Commit after every task. Never push.

## File Structure

```
Package.swift
Resources/Info.plist
scripts/test.sh               # swift test with CLT framework paths
scripts/build-app.sh          # build + assemble + sign build/BetterThanDato.app
scripts/run.sh                # build debug app, relaunch
scripts/install.sh            # release build into ~/Applications
Sources/DatoCore/
  Models.swift                # ColorRef, AccountInfo, CalendarKind, CalendarInfo, CalendarEvent, ReminderItem
  AccountBadge.swift          # default 1-letter account badge
  RelativeTime.swift          # "in 12m", "8m left", "at 17:30", duration strings, shared DateFormatter helper
  MenuBarTitleFormatter.swift # which event the menu bar shows + text
  EventPipeline.swift         # visibility filter, dedupe, calendar priority
  MonthGrid.swift             # 6x7 grid model
  DayMarkers.swift            # per-day color dots
  FreeTimeCalculator.swift    # WorkingHours + free gaps today
  AgendaBuilder.swift         # AgendaSettings, AgendaEntry, AgendaDay, builder
  AgendaFormatting.swift      # day titles, time ranges, short dates, month title, plain notes
  QuickAddParser.swift        # QuickAddKind, QuickAddDraft, parser
  MeetingLinkDetector.swift   # MeetingProvider, MeetingLink, detector
Sources/BetterThanDato/
  App.swift                   # @main entry
  AppDelegate.swift           # wiring
  CalendarIconRenderer.swift  # menu bar template icon
  Services/
    CalendarService.swift     # EventKit adapter (only file importing EventKit)
    PreferencesStore.swift    # UserDefaults-backed settings
    KeyCombo.swift            # hotkey value type
    HotKeyCenter.swift        # Carbon global hotkeys
    MeetingLauncher.swift     # open meeting links (native app preferred)
    LoginItem.swift           # SMAppService wrapper
    SystemLinks.swift         # System Settings privacy panes, Calendar.app deep link
    ColorRef+AppKit.swift     # ColorRef <-> NSColor/Color
  AppModel.swift              # @Observable UI state
  StatusItemController.swift  # NSStatusItem + NSPopover
  Views/
    PopoverView.swift         # root, footer, toast, permission view
    AgendaScreen.swift        # header + grid + agenda + keyboard handling
    MonthGridView.swift
    AgendaListView.swift      # day sections, rows
    EventRowView.swift        # event row + inline detail
    ReminderRowView.swift     # reminder row + free row + badge
    QuickAddView.swift
    SettingsView.swift        # all settings tabs + shortcut recorder
    SettingsWindowController.swift
Tests/DatoCoreTests/
  Fixture.swift
  AccountBadgeTests.swift
  RelativeTimeTests.swift
  MenuBarTitleFormatterTests.swift
  EventPipelineTests.swift
  MonthGridTests.swift
  DayMarkersTests.swift
  FreeTimeCalculatorTests.swift
  AgendaBuilderTests.swift
  AgendaFormattingTests.swift
  QuickAddParserTests.swift
  MeetingLinkDetectorTests.swift
docs/qa-checklist.md
```

---

### Task 1: Package skeleton, scripts, models, app that shows the icon

**Files:**
- Create: `Package.swift`, `Resources/Info.plist`, `scripts/test.sh`, `scripts/build-app.sh`, `scripts/run.sh`, `scripts/install.sh`
- Create: `Sources/DatoCore/Models.swift`, `Sources/DatoCore/AccountBadge.swift`
- Create: `Sources/BetterThanDato/App.swift`, `Sources/BetterThanDato/AppDelegate.swift`, `Sources/BetterThanDato/CalendarIconRenderer.swift`
- Test: `Tests/DatoCoreTests/Fixture.swift`, `Tests/DatoCoreTests/AccountBadgeTests.swift`

**Interfaces:**
- Produces: `ColorRef(red:green:blue:)`, `ColorRef.gray`; `AccountInfo(id:title:order:)`; `CalendarKind { events, reminders }`; `CalendarInfo(id:title:color:accountID:kind:isWritable:)`; `CalendarEvent(id:eventIdentifier:title:start:end:isAllDay:calendarID:location:url:notes:attendeeCount:isDeclined:isCancelled:)`; `ReminderItem(id:title:due:hasTime:isCompleted:listID:)`; `AccountBadge.defaultLabel(for:) -> String`; `CalendarIconRenderer.image(day:) -> NSImage`; `Fixture.calendar/date/event/reminder`.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BetterThanDato",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DatoCore"),
        .executableTarget(
            name: "BetterThanDato",
            dependencies: ["DatoCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "DatoCoreTests", dependencies: ["DatoCore"]),
    ]
)
```

- [ ] **Step 2: Create scripts**

`scripts/test.sh`:
```bash
#!/usr/bin/env bash
# Runs the test suite. The Command Line Tools ship Swift Testing but SwiftPM
# doesn't find it on its own, so pass the framework and runtime paths explicitly.
set -euo pipefail
cd "$(dirname "$0")/.."
DEV_DIR="$(xcode-select -p)"
if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
  FW="$DEV_DIR/Library/Developer/Frameworks"
  LIB="$DEV_DIR/Library/Developer/usr/lib"
  exec swift test \
    -Xswiftc -F -Xswiftc "$FW" \
    -Xlinker -F -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$LIB" \
    "$@"
fi
exec swift test "$@"
```

`scripts/build-app.sh`:
```bash
#!/usr/bin/env bash
# Builds BetterThanDato and assembles a signed .app bundle in build/.
# Usage: scripts/build-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-debug}"
NAME="BetterThanDato"
APP="build/$NAME.app"

swift build -c "$CONFIG" --product "$NAME"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$NAME" "$APP/Contents/MacOS/$NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP"
```

`scripts/run.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh debug
pkill -x BetterThanDato || true
open build/BetterThanDato.app
```

`scripts/install.sh`:
```bash
#!/usr/bin/env bash
# Release build copied to ~/Applications (a stable path for launch at login).
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh release
pkill -x BetterThanDato || true
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/BetterThanDato.app"
cp -R build/BetterThanDato.app "$HOME/Applications/"
open "$HOME/Applications/BetterThanDato.app"
```

Run: `chmod +x scripts/*.sh`

- [ ] **Step 3: Create `Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>BetterThanDato</string>
    <key>CFBundleIdentifier</key>
    <string>com.ahmede.BetterThanDato</string>
    <key>CFBundleName</key>
    <string>BetterThanDato</string>
    <key>CFBundleDisplayName</key>
    <string>Better Than Dato</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Better Than Dato shows your upcoming events in the menu bar and lets you add new ones.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Better Than Dato shows your upcoming events in the menu bar and lets you add new ones.</string>
    <key>NSRemindersFullAccessUsageDescription</key>
    <string>Better Than Dato shows reminders due each day and lets you complete or add them.</string>
    <key>NSRemindersUsageDescription</key>
    <string>Better Than Dato shows reminders due each day and lets you complete or add them.</string>
</dict>
</plist>
```

- [ ] **Step 4: Create `Sources/DatoCore/Models.swift`**

```swift
import Foundation

/// sRGB color that crosses the module boundary without AppKit.
public struct ColorRef: Hashable, Sendable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let gray = ColorRef(red: 0.56, green: 0.56, blue: 0.58)
}

/// One account as macOS sees it (an EventKit source: iCloud, Google, Exchange, ...).
public struct AccountInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    /// Display order among accounts; lower comes first.
    public var order: Int

    public init(id: String, title: String, order: Int) {
        self.id = id
        self.title = title
        self.order = order
    }
}

public enum CalendarKind: String, Hashable, Sendable {
    case events
    case reminders
}

/// An event calendar or a reminders list.
public struct CalendarInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var color: ColorRef
    public var accountID: String
    public var kind: CalendarKind
    public var isWritable: Bool

    public init(id: String, title: String, color: ColorRef, accountID: String, kind: CalendarKind, isWritable: Bool) {
        self.id = id
        self.title = title
        self.color = color
        self.accountID = accountID
        self.kind = kind
        self.isWritable = isWritable
    }
}

public struct CalendarEvent: Identifiable, Hashable, Sendable {
    /// Unique per occurrence (recurring events share `eventIdentifier`).
    public let id: String
    public var eventIdentifier: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var calendarID: String
    public var location: String?
    public var url: URL?
    public var notes: String?
    public var attendeeCount: Int
    public var isDeclined: Bool
    public var isCancelled: Bool

    public init(
        id: String,
        eventIdentifier: String? = nil,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        calendarID: String,
        location: String? = nil,
        url: URL? = nil,
        notes: String? = nil,
        attendeeCount: Int = 0,
        isDeclined: Bool = false,
        isCancelled: Bool = false
    ) {
        self.id = id
        self.eventIdentifier = eventIdentifier ?? id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.location = location
        self.url = url
        self.notes = notes
        self.attendeeCount = attendeeCount
        self.isDeclined = isDeclined
        self.isCancelled = isCancelled
    }
}

public struct ReminderItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var due: Date
    /// False for date-only reminders.
    public var hasTime: Bool
    public var isCompleted: Bool
    public var listID: String

    public init(id: String, title: String, due: Date, hasTime: Bool = true, isCompleted: Bool = false, listID: String) {
        self.id = id
        self.title = title
        self.due = due
        self.hasTime = hasTime
        self.isCompleted = isCompleted
        self.listID = listID
    }
}
```

- [ ] **Step 5: Write the failing test** — `Tests/DatoCoreTests/Fixture.swift` and `Tests/DatoCoreTests/AccountBadgeTests.swift`

```swift
// Fixture.swift
import Foundation
@testable import DatoCore

enum Fixture {
    static let timeZone = TimeZone(identifier: "Europe/Berlin")!
    static let locale = Locale(identifier: "en_GB")

    /// Gregorian, Berlin time, Monday-first, en_GB (24-hour clock).
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func event(
        _ title: String, _ start: Date, _ end: Date,
        calendar: String = "work", allDay: Bool = false, declined: Bool = false, cancelled: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: "\(title)-\(start.timeIntervalSince1970)", title: title, start: start, end: end,
            isAllDay: allDay, calendarID: calendar, isDeclined: declined, isCancelled: cancelled
        )
    }

    static func reminder(_ title: String, _ due: Date, hasTime: Bool = true, list: String = "tasks") -> ReminderItem {
        ReminderItem(id: "r-\(title)", title: title, due: due, hasTime: hasTime, listID: list)
    }
}
```

```swift
// AccountBadgeTests.swift
import Testing
@testable import DatoCore

@Suite struct AccountBadgeTests {
    @Test func emailUsesDomainInitial() {
        #expect(AccountBadge.defaultLabel(for: "jane@bluebird.com") == "B")
    }

    @Test func plainTitleUsesFirstLetter() {
        #expect(AccountBadge.defaultLabel(for: "iCloud") == "I")
    }

    @Test func skipsLeadingSymbols() {
        #expect(AccountBadge.defaultLabel(for: "  (Work)") == "W")
    }

    @Test func emptyTitleFallsBack() {
        #expect(AccountBadge.defaultLabel(for: "") == "?")
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `scripts/test.sh`
Expected: build FAIL — `cannot find 'AccountBadge' in scope`.

- [ ] **Step 7: Implement `Sources/DatoCore/AccountBadge.swift`**

```swift
import Foundation

public enum AccountBadge {
    /// Default one-letter badge for an account. Email-style titles use the domain
    /// ("jane@bluebird.com" → "B") so two addresses starting with the same letter still differ.
    public static func defaultLabel(for accountTitle: String) -> String {
        let source = accountTitle.split(separator: "@").last.map(String.init) ?? accountTitle
        guard let first = source.first(where: { $0.isLetter || $0.isNumber }) else { return "?" }
        return String(first).uppercased()
    }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `scripts/test.sh`
Expected: `✔ Test run with 4 tests ... passed`.

- [ ] **Step 9: Create the app shell**

`Sources/BetterThanDato/App.swift`:
```swift
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
```

`Sources/BetterThanDato/CalendarIconRenderer.swift`:
```swift
import AppKit

/// Draws the menu bar icon: a small calendar page with today's day number.
/// Template image, so macOS tints it for light, dark and tinted menu bars.
enum CalendarIconRenderer {
    static func image(day: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: 17, height: 16), flipped: false) { _ in
            let page = NSRect(x: 1, y: 1, width: 15, height: 14)
            let outline = NSBezierPath(roundedRect: page, xRadius: 3, yRadius: 3)
            let bandHeight: CGFloat = 3.5
            NSColor.black.set()

            NSGraphicsContext.saveGraphicsState()
            outline.addClip()
            NSRect(x: page.minX, y: page.maxY - bandHeight, width: page.width, height: bandHeight).fill()
            NSGraphicsContext.restoreGraphicsState()

            outline.lineWidth = 1.2
            outline.stroke()

            let text = "\(day)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let size = text.size(withAttributes: attributes)
            let bodyHeight = page.height - bandHeight
            text.draw(
                at: NSPoint(x: page.midX - size.width / 2, y: page.minY + (bodyHeight - size.height) / 2),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        return image
    }
}
```

`Sources/BetterThanDato/AppDelegate.swift` (temporary shell, replaced in Task 9):
```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = CalendarIconRenderer.image(day: Calendar.current.component(.day, from: Date()))
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}
```

- [ ] **Step 10: Build and launch the app**

Run: `scripts/run.sh`
Expected: `Built build/BetterThanDato.app`; a calendar icon with today's day number appears in the menu bar; clicking it shows "Quit".

- [ ] **Step 11: Commit**

```bash
git add Package.swift Resources scripts Sources Tests
git commit -m "feat: package skeleton, app bundle scripts, core models, menu bar icon"
```

---

### Task 2: Relative time and menu bar title

**Files:**
- Create: `Sources/DatoCore/RelativeTime.swift`, `Sources/DatoCore/MenuBarTitleFormatter.swift`
- Test: `Tests/DatoCoreTests/RelativeTimeTests.swift`, `Tests/DatoCoreTests/MenuBarTitleFormatterTests.swift`

**Interfaces:**
- Consumes: `CalendarEvent`, `Fixture`.
- Produces: `RelativeTime.untilStart(_:now:calendar:locale:) -> String`, `RelativeTime.remaining(until:now:) -> String`, `RelativeTime.duration(minutes:) -> String`, internal `RelativeTime.format(_:template:calendar:locale:) -> String`; `MenuBarWindow` (`thirtyMinutes, oneHour, threeHours, restOfToday, always`, `String` raw values); `MenuBarTitleSettings(window:maxTitleLength:)`; `MenuBarTitle { text, event }`; `MenuBarTitleFormatter.title(events:now:settings:calendar:locale:) -> MenuBarTitle?`; `MenuBarTitleFormatter.truncate(_:to:) -> String`.

- [ ] **Step 1: Write the failing tests**

```swift
// RelativeTimeTests.swift
import Foundation
import Testing
@testable import DatoCore

@Suite struct RelativeTimeTests {
    let cal = Fixture.calendar
    let now = Fixture.date(2026, 9, 29, 10, 0)

    func until(_ date: Date) -> String {
        RelativeTime.untilStart(date, now: now, calendar: cal, locale: Fixture.locale)
    }

    @Test func underAMinuteIsNow() {
        #expect(until(now.addingTimeInterval(30)) == "now")
    }

    @Test func minutes() {
        #expect(until(now.addingTimeInterval(45 * 60)) == "in 45m")
    }

    @Test func partialMinutesRoundUp() {
        #expect(until(now.addingTimeInterval(12 * 60 + 30)) == "in 13m")
    }

    @Test func hoursAndMinutes() {
        #expect(until(now.addingTimeInterval(135 * 60)) == "in 2h 15m")
        #expect(until(now.addingTimeInterval(120 * 60)) == "in 2h")
    }

    @Test func laterTodayShowsClockTime() {
        #expect(until(Fixture.date(2026, 9, 29, 17, 30)) == "at 17:30")
    }

    @Test func anotherDayShowsWeekday() {
        #expect(until(Fixture.date(2026, 10, 1, 9, 0)) == "Thu 09:00")
    }

    @Test func remaining() {
        #expect(RelativeTime.remaining(until: now.addingTimeInterval(8 * 60), now: now) == "8m left")
        #expect(RelativeTime.remaining(until: now.addingTimeInterval(65 * 60), now: now) == "1h 5m left")
    }
}
```

```swift
// MenuBarTitleFormatterTests.swift
import Foundation
import Testing
@testable import DatoCore

@Suite struct MenuBarTitleFormatterTests {
    let cal = Fixture.calendar
    let now = Fixture.date(2026, 9, 29, 10, 0)

    func at(_ hour: Int, _ minute: Int = 0, day: Int = 29) -> Date { Fixture.date(2026, 9, day, hour, minute) }

    func title(_ events: [CalendarEvent], window: MenuBarWindow = .restOfToday, max: Int = 25) -> String? {
        MenuBarTitleFormatter.title(
            events: events, now: now,
            settings: MenuBarTitleSettings(window: window, maxTitleLength: max),
            calendar: cal, locale: Fixture.locale
        )?.text
    }

    @Test func nothingScheduledShowsNoTitle() {
        #expect(title([]) == nil)
    }

    @Test func imminentEventBeatsOngoingEvent() {
        let events = [Fixture.event("Focus", at(9, 30), at(10, 30)), Fixture.event("Standup", at(10, 8), at(10, 23))]
        #expect(title(events) == "Standup · in 8m")
    }

    @Test func ongoingEventShowsTimeLeft() {
        let events = [Fixture.event("Focus", at(9, 30), at(10, 30)), Fixture.event("Lunch", at(12), at(13))]
        #expect(title(events) == "Focus · 30m left")
    }

    @Test func ongoingEventEndingSoonestWins() {
        let events = [Fixture.event("Long", at(9), at(12)), Fixture.event("Short", at(9, 45), at(10, 20))]
        #expect(title(events) == "Short · 20m left")
    }

    @Test func laterTodayWithinDefaultWindow() {
        #expect(title([Fixture.event("Lunch", at(12), at(13))]) == "Lunch · in 2h")
    }

    @Test func narrowWindowHidesFarEvents() {
        #expect(title([Fixture.event("Lunch", at(12), at(13))], window: .oneHour) == nil)
    }

    @Test func tomorrowHiddenUnlessWindowIsAlways() {
        let events = [Fixture.event("Planning", at(9, day: 30), at(10, day: 30))]
        #expect(title(events) == nil)
        #expect(title(events, window: .always) == "Planning · Wed 09:00")
    }

    @Test func skipsAllDayDeclinedAndCancelled() {
        let events = [
            Fixture.event("Holiday", Fixture.date(2026, 9, 29), Fixture.date(2026, 9, 30), allDay: true),
            Fixture.event("Declined", at(10, 5), at(11), declined: true),
            Fixture.event("Cancelled", at(10, 6), at(11), cancelled: true),
            Fixture.event("Real", at(11), at(12)),
        ]
        #expect(title(events) == "Real · in 1h")
    }

    @Test func truncatesLongTitles() {
        let events = [Fixture.event("Quarterly planning with design team", at(10, 30), at(11))]
        #expect(title(events, max: 10) == "Quarterly… · in 30m")
    }

    @Test func truncationTrimsTrailingSpace() {
        #expect(MenuBarTitleFormatter.truncate("Team sync meeting", to: 6) == "Team…")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test.sh`
Expected: build FAIL — `cannot find 'RelativeTime' in scope`.

- [ ] **Step 3: Implement `Sources/DatoCore/RelativeTime.swift`**

```swift
import Foundation

public enum RelativeTime {
    /// "now", "in 45m", "in 2h 15m", "at 17:30" (later today), "Thu 09:00" (another day).
    public static func untilStart(_ start: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        let seconds = start.timeIntervalSince(now)
        if seconds < 60 { return "now" }
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "in \(minutes)m" }
        if minutes < 6 * 60 { return "in \(duration(minutes: minutes))" }
        if calendar.isDate(start, inSameDayAs: now) {
            return "at \(format(start, template: "jmm", calendar: calendar, locale: locale))"
        }
        return format(start, template: "EEEjmm", calendar: calendar, locale: locale)
    }

    /// "8m left", "1h 5m left".
    public static func remaining(until end: Date, now: Date) -> String {
        let minutes = max(1, Int((end.timeIntervalSince(now) / 60).rounded(.up)))
        return "\(duration(minutes: minutes)) left"
    }

    /// "45m", "2h", "2h 15m".
    public static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    /// Formats with a locale-aware template ("jmm" follows the locale's 12/24-hour preference).
    static func format(_ date: Date, template: String, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale)
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 4: Implement `Sources/DatoCore/MenuBarTitleFormatter.swift`**

```swift
import Foundation

/// How far ahead the next event may be and still appear in the menu bar.
public enum MenuBarWindow: String, CaseIterable, Codable, Sendable {
    case thirtyMinutes
    case oneHour
    case threeHours
    case restOfToday
    case always
}

public struct MenuBarTitleSettings: Sendable {
    public var window: MenuBarWindow
    public var maxTitleLength: Int

    public init(window: MenuBarWindow = .restOfToday, maxTitleLength: Int = 25) {
        self.window = window
        self.maxTitleLength = maxTitleLength
    }
}

public struct MenuBarTitle: Equatable, Sendable {
    public let text: String
    public let event: CalendarEvent
}

public enum MenuBarTitleFormatter {
    /// An upcoming event closer than this takes priority over an ongoing one.
    static let imminentInterval: TimeInterval = 10 * 60

    public static func title(
        events: [CalendarEvent], now: Date, settings: MenuBarTitleSettings, calendar: Calendar, locale: Locale
    ) -> MenuBarTitle? {
        let candidates = events.filter { !$0.isAllDay && !$0.isCancelled && !$0.isDeclined && $0.end > now }
        let upcoming = candidates.filter { $0.start > now }.sorted { $0.start < $1.start }
        let ongoing = candidates.filter { $0.start <= now }.sorted { $0.end < $1.end }

        if let next = upcoming.first, next.start.timeIntervalSince(now) <= imminentInterval {
            return make(next, RelativeTime.untilStart(next.start, now: now, calendar: calendar, locale: locale), settings)
        }
        if let current = ongoing.first {
            return make(current, RelativeTime.remaining(until: current.end, now: now), settings)
        }
        if let next = upcoming.first, isWithinWindow(next.start, now: now, window: settings.window, calendar: calendar) {
            return make(next, RelativeTime.untilStart(next.start, now: now, calendar: calendar, locale: locale), settings)
        }
        return nil
    }

    public static func truncate(_ text: String, to maxLength: Int) -> String {
        guard maxLength > 1, text.count > maxLength else { return text }
        return text.prefix(maxLength - 1).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func make(_ event: CalendarEvent, _ relative: String, _ settings: MenuBarTitleSettings) -> MenuBarTitle {
        MenuBarTitle(text: "\(truncate(event.title, to: settings.maxTitleLength)) · \(relative)", event: event)
    }

    private static func isWithinWindow(_ start: Date, now: Date, window: MenuBarWindow, calendar: Calendar) -> Bool {
        let seconds = start.timeIntervalSince(now)
        switch window {
        case .thirtyMinutes: return seconds <= 30 * 60
        case .oneHour: return seconds <= 60 * 60
        case .threeHours: return seconds <= 3 * 60 * 60
        case .restOfToday: return calendar.isDate(start, inSameDayAs: now)
        case .always: return true
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DatoCore Tests/DatoCoreTests
git commit -m "feat(core): relative time strings and menu bar title selection"
```

---

### Task 3: Event pipeline — visibility, dedupe, calendar priority

**Files:**
- Create: `Sources/DatoCore/EventPipeline.swift`
- Test: `Tests/DatoCoreTests/EventPipelineTests.swift`

**Interfaces:**
- Consumes: `CalendarEvent`, `CalendarInfo`, `AccountInfo`.
- Produces: `EventPipeline.visible(_:hiddenCalendarIDs:hideDuplicates:calendarPriority:) -> [CalendarEvent]` (sorted by start, then title); `EventPipeline.dedupe(_:calendarPriority:) -> [CalendarEvent]`; `EventPipeline.calendarPriority(calendars:accounts:preferredAccountID:) -> [String]`.

- [ ] **Step 1: Write the failing test**

```swift
// EventPipelineTests.swift
import Foundation
import Testing
@testable import DatoCore

@Suite struct EventPipelineTests {
    let nine = Fixture.date(2026, 9, 29, 9, 0)
    let ten = Fixture.date(2026, 9, 29, 10, 0)

    func visible(_ events: [CalendarEvent], hidden: Set<String> = [], dedupe: Bool = true, priority: [String] = []) -> [CalendarEvent] {
        EventPipeline.visible(events, hiddenCalendarIDs: hidden, hideDuplicates: dedupe, calendarPriority: priority)
    }

    @Test func removesHiddenCancelledAndDeclined() {
        let events = [
            Fixture.event("Keep", nine, ten),
            Fixture.event("Hidden", nine, ten, calendar: "secret"),
            Fixture.event("Cancelled", nine, ten, cancelled: true),
            Fixture.event("Declined", nine, ten, declined: true),
        ]
        #expect(visible(events, hidden: ["secret"]).map(\.title) == ["Keep"])
    }

    @Test func duplicatesKeepHigherPriorityCalendar() {
        let events = [
            Fixture.event("Standup", nine, ten, calendar: "personal"),
            Fixture.event("standup ", nine, ten, calendar: "work"),
        ]
        #expect(visible(events, priority: ["work", "personal"]).map(\.calendarID) == ["work"])
    }

    @Test func differentTimesAreNotDuplicates() {
        let events = [Fixture.event("Standup", nine, ten), Fixture.event("Standup", ten, ten.addingTimeInterval(900))]
        #expect(visible(events).count == 2)
    }

    @Test func dedupeCanBeDisabled() {
        let events = [Fixture.event("Standup", nine, ten, calendar: "a"), Fixture.event("Standup", nine, ten, calendar: "b")]
        #expect(visible(events, dedupe: false).count == 2)
    }

    @Test func sortedByStartThenTitle() {
        let events = [Fixture.event("B", ten, ten), Fixture.event("A", ten, ten), Fixture.event("C", nine, ten)]
        #expect(visible(events).map(\.title) == ["C", "A", "B"])
    }

    @Test func priorityPrefersAccountThenAccountOrderThenTitle() {
        let accounts = [
            AccountInfo(id: "icloud", title: "iCloud", order: 0),
            AccountInfo(id: "google", title: "Google", order: 1),
        ]
        let calendars = [
            CalendarInfo(id: "home", title: "Home", color: .gray, accountID: "icloud", kind: .events, isWritable: true),
            CalendarInfo(id: "work", title: "Work", color: .gray, accountID: "google", kind: .events, isWritable: true),
            CalendarInfo(id: "birthdays", title: "Birthdays", color: .gray, accountID: "google", kind: .events, isWritable: false),
            CalendarInfo(id: "family", title: "Family", color: .gray, accountID: "icloud", kind: .events, isWritable: true),
        ]
        #expect(EventPipeline.calendarPriority(calendars: calendars, accounts: accounts, preferredAccountID: "google")
            == ["birthdays", "work", "family", "home"])
        #expect(EventPipeline.calendarPriority(calendars: calendars, accounts: accounts, preferredAccountID: nil)
            == ["family", "home", "birthdays", "work"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/test.sh`
Expected: build FAIL — `cannot find 'EventPipeline' in scope`.

- [ ] **Step 3: Implement `Sources/DatoCore/EventPipeline.swift`**

```swift
import Foundation

/// Turns raw events from every account into the list the UI shows.
public enum EventPipeline {
    public static func visible(
        _ events: [CalendarEvent], hiddenCalendarIDs: Set<String>, hideDuplicates: Bool, calendarPriority: [String]
    ) -> [CalendarEvent] {
        let shown = events.filter { !hiddenCalendarIDs.contains($0.calendarID) && !$0.isCancelled && !$0.isDeclined }
        let unique = hideDuplicates ? dedupe(shown, calendarPriority: calendarPriority) : shown
        return unique.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    /// Collapses events with the same normalized title, start, end and all-day flag
    /// (the same meeting invited to two accounts). Keeps the copy whose calendar ranks first.
    public static func dedupe(_ events: [CalendarEvent], calendarPriority: [String]) -> [CalendarEvent] {
        let rank = Dictionary(calendarPriority.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        func rankOf(_ event: CalendarEvent) -> Int { rank[event.calendarID] ?? Int.max }

        var keptIndex: [DuplicateKey: Int] = [:]
        var kept: [CalendarEvent] = []
        for event in events {
            let key = DuplicateKey(event)
            if let index = keptIndex[key] {
                if rankOf(event) < rankOf(kept[index]) { kept[index] = event }
            } else {
                keptIndex[key] = kept.count
                kept.append(event)
            }
        }
        return kept
    }

    /// Calendar ids ordered by: the preferred account first, then account order, then title.
    public static func calendarPriority(
        calendars: [CalendarInfo], accounts: [AccountInfo], preferredAccountID: String?
    ) -> [String] {
        let accountOrder = Dictionary(accounts.map { ($0.id, $0.order) }, uniquingKeysWith: { first, _ in first })
        return calendars.sorted { a, b in
            let preferredA = a.accountID == preferredAccountID ? 0 : 1
            let preferredB = b.accountID == preferredAccountID ? 0 : 1
            if preferredA != preferredB { return preferredA < preferredB }
            let orderA = accountOrder[a.accountID] ?? Int.max
            let orderB = accountOrder[b.accountID] ?? Int.max
            if orderA != orderB { return orderA < orderB }
            return a.title.lowercased() < b.title.lowercased()
        }.map(\.id)
    }

    struct DuplicateKey: Hashable {
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool

        init(_ event: CalendarEvent) {
            title = event.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            start = event.start
            end = event.end
            isAllDay = event.isAllDay
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DatoCore/EventPipeline.swift Tests/DatoCoreTests/EventPipelineTests.swift
git commit -m "feat(core): event visibility pipeline with cross-account dedupe"
```

---

### Task 4: Month grid and day markers

**Files:**
- Create: `Sources/DatoCore/MonthGrid.swift`, `Sources/DatoCore/DayMarkers.swift`
- Test: `Tests/DatoCoreTests/MonthGridTests.swift`, `Tests/DatoCoreTests/DayMarkersTests.swift`

**Interfaces:**
- Produces: `MonthGridDay { date, dayNumber, isInDisplayedMonth, id }`; `MonthGridWeek { weekNumber, days, id }`; `MonthGridModel { monthStart, weeks, weekdaySymbols, interval, days }`; `MonthGrid.make(containing:calendar:) -> MonthGridModel` (always 6 rows, first weekday from `calendar.firstWeekday`); `DayMarkers.colors(days:events:reminders:calendarColors:calendar:maxDots:) -> [Date: [ColorRef]]` keyed by start of day.

- [ ] **Step 1: Write the failing tests**

```swift
// MonthGridTests.swift
import Foundation
import Testing
@testable import DatoCore

@Suite struct MonthGridTests {
    func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Fixture.calendar
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    @Test func mondayStart() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 2))
        #expect(grid.weeks.count == 6)
        #expect(grid.weeks.allSatisfy { $0.days.count == 7 })
        #expect(grid.days.first?.date == Fixture.date(2026, 8, 31))
        #expect(grid.days.last?.date == Fixture.date(2026, 10, 11))
        #expect(grid.weekdaySymbols == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test func sundayStart() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 1))
        #expect(grid.days.first?.date == Fixture.date(2026, 8, 30))
        #expect(grid.weekdaySymbols == ["S", "M", "T", "W", "T", "F", "S"])
    }

    @Test func saturdayStart() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 7))
        #expect(grid.days.first?.date == Fixture.date(2026, 8, 29))
    }

    @Test func marksDaysOutsideTheMonth() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 2))
        #expect(grid.days[0].isInDisplayedMonth == false)
        #expect(grid.days[1].isInDisplayedMonth)
        #expect(grid.days[1].dayNumber == 1)
    }

    @Test func intervalCoversEveryCell() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 2))
        #expect(grid.interval.start == Fixture.date(2026, 8, 31))
        #expect(grid.interval.end == Fixture.date(2026, 10, 12))
    }

    @Test func isoWeekNumbers() {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = Fixture.timeZone
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: iso)
        #expect(grid.weeks.first?.weekNumber == 36)
    }

    @Test func dstMonthStillHasMidnightsOnConsecutiveDays() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        newYork.firstWeekday = 1
        let november = newYork.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        let days = MonthGrid.make(containing: november, calendar: newYork).days
        #expect(days.allSatisfy { newYork.startOfDay(for: $0.date) == $0.date })
        for (a, b) in zip(days, days.dropFirst()) {
            #expect(newYork.dateComponents([.day], from: a.date, to: b.date).day == 1)
        }
    }
}
```

```swift
// DayMarkersTests.swift
import Foundation
import Testing
@testable import DatoCore

@Suite struct DayMarkersTests {
    let cal = Fixture.calendar
    let red = ColorRef(red: 1, green: 0, blue: 0)
    let blue = ColorRef(red: 0, green: 0, blue: 1)
    let green = ColorRef(red: 0, green: 1, blue: 0)
    let yellow = ColorRef(red: 1, green: 1, blue: 0)
    var colors: [String: ColorRef] { ["work": red, "home": blue, "gym": green, "tasks": yellow] }

    func at(_ hour: Int, day: Int = 1) -> Date { Fixture.date(2026, 10, day, hour) }
    func day(_ day: Int) -> Date { Fixture.date(2026, 10, day) }

    func markers(_ days: [Date], events: [CalendarEvent] = [], reminders: [ReminderItem] = []) -> [Date: [ColorRef]] {
        DayMarkers.colors(days: days, events: events, reminders: reminders, calendarColors: colors, calendar: cal)
    }

    @Test func firstThreeDistinctColorsInTimeOrder() {
        let events = [
            Fixture.event("H", at(12), at(13), calendar: "home"),
            Fixture.event("W1", at(9), at(10), calendar: "work"),
            Fixture.event("W2", at(10), at(11), calendar: "work"),
            Fixture.event("G", at(15), at(16), calendar: "gym"),
            Fixture.event("X", at(17), at(18), calendar: "unknown"),
        ]
        #expect(markers([day(1)], events: events)[day(1)] == [red, blue, green])
    }

    @Test func remindersAddDots() {
        #expect(markers([day(2)], reminders: [Fixture.reminder("Pay", at(9, day: 2))])[day(2)] == [yellow])
    }

    @Test func emptyDaysHaveNoEntry() {
        #expect(markers([day(3)])[day(3)] == nil)
    }

    @Test func eventCrossingMidnightMarksBothDays() {
        let result = markers([day(1), day(2)], events: [Fixture.event("Late", at(22), at(2, day: 2))])
        #expect(result[day(1)] == [red])
        #expect(result[day(2)] == [red])
    }

    @Test func unknownCalendarFallsBackToGray() {
        let result = markers([day(1)], events: [Fixture.event("X", at(9), at(10), calendar: "unknown")])
        #expect(result[day(1)] == [.gray])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test.sh`
Expected: build FAIL — `cannot find 'MonthGrid' in scope`.

- [ ] **Step 3: Implement `Sources/DatoCore/MonthGrid.swift`**

```swift
import Foundation

public struct MonthGridDay: Identifiable, Hashable, Sendable {
    public let date: Date
    public let dayNumber: Int
    public let isInDisplayedMonth: Bool
    public var id: Date { date }
}

public struct MonthGridWeek: Identifiable, Hashable, Sendable {
    public let weekNumber: Int
    public let days: [MonthGridDay]
    public var id: Date { days[0].date }
}

public struct MonthGridModel: Hashable, Sendable {
    public let monthStart: Date
    public let weeks: [MonthGridWeek]
    /// Very short weekday symbols, rotated to start at `calendar.firstWeekday`.
    public let weekdaySymbols: [String]
    /// From the first cell's midnight to the midnight after the last cell.
    public let interval: DateInterval

    public var days: [MonthGridDay] { weeks.flatMap(\.days) }
}

public enum MonthGrid {
    /// Always 6 rows so the popover height never jumps between months.
    public static let rowCount = 6

    public static func make(containing date: Date, calendar: Calendar) -> MonthGridModel {
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        let leadingDays = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        let displayedMonth = calendar.component(.month, from: monthStart)

        var weeks: [MonthGridWeek] = []
        for row in 0..<rowCount {
            var days: [MonthGridDay] = []
            for column in 0..<7 {
                let day = calendar.date(byAdding: .day, value: row * 7 + column, to: gridStart) ?? gridStart
                days.append(MonthGridDay(
                    date: day,
                    dayNumber: calendar.component(.day, from: day),
                    isInDisplayedMonth: calendar.component(.month, from: day) == displayedMonth
                ))
            }
            weeks.append(MonthGridWeek(weekNumber: calendar.component(.weekOfYear, from: days[0].date), days: days))
        }

        let gridEnd = calendar.date(byAdding: .day, value: rowCount * 7, to: gridStart) ?? gridStart
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return MonthGridModel(
            monthStart: monthStart,
            weeks: weeks,
            weekdaySymbols: Array(symbols[shift...] + symbols[..<shift]),
            interval: DateInterval(start: gridStart, end: gridEnd)
        )
    }
}
```

- [ ] **Step 4: Implement `Sources/DatoCore/DayMarkers.swift`**

```swift
import Foundation

public enum DayMarkers {
    /// Up to `maxDots` distinct calendar colors per day, in time order, keyed by start of day.
    /// Days with nothing scheduled have no entry.
    public static func colors(
        days: [Date], events: [CalendarEvent], reminders: [ReminderItem],
        calendarColors: [String: ColorRef], calendar: Calendar, maxDots: Int = 3
    ) -> [Date: [ColorRef]] {
        var result: [Date: [ColorRef]] = [:]
        for day in days {
            let start = calendar.startOfDay(for: day)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            let items = events.filter { $0.start < end && $0.end > start }.map { ($0.start, $0.calendarID) }
                + reminders.filter { $0.due >= start && $0.due < end }.map { ($0.due, $0.listID) }

            var colors: [ColorRef] = []
            for (_, calendarID) in items.sorted(by: { $0.0 < $1.0 }) {
                let color = calendarColors[calendarID] ?? .gray
                if !colors.contains(color) { colors.append(color) }
                if colors.count == maxDots { break }
            }
            if !colors.isEmpty { result[start] = colors }
        }
        return result
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DatoCore Tests/DatoCoreTests
git commit -m "feat(core): month grid model and per-day color markers"
```

---

### Task 5: Free time, agenda builder, agenda formatting

**Files:**
- Create: `Sources/DatoCore/FreeTimeCalculator.swift`, `Sources/DatoCore/AgendaBuilder.swift`, `Sources/DatoCore/AgendaFormatting.swift`
- Test: `Tests/DatoCoreTests/FreeTimeCalculatorTests.swift`, `Tests/DatoCoreTests/AgendaBuilderTests.swift`, `Tests/DatoCoreTests/AgendaFormattingTests.swift`

**Interfaces:**
- Consumes: `RelativeTime.format` (internal), models.
- Produces: `WorkingHours(startMinutes:endMinutes:)`, `WorkingHours.standard` (09:00–18:00); `FreeTimeCalculator.freeSlots(events:now:workingHours:minimumMinutes:calendar:) -> [DateInterval]`; `AgendaSettings(showFreeTime:workingHours:)`; `AgendaEntry { .event, .reminder, .free; id }`; `AgendaDay { date, overdue, earlierEvents, entries, id }`; `AgendaBuilder.build(events:reminders:now:firstDay:dayCount:settings:calendar:) -> [AgendaDay]`; `AgendaFormatting.dayTitle(for:now:calendar:locale:)`, `.timeRange(for:on:calendar:locale:)`, `.time(_:calendar:locale:)`, `.shortDate(_:calendar:locale:)`, `.monthTitle(for:calendar:locale:)`, `.plainNotes(_:limit:)` — all `-> String`.

- [ ] **Step 1: Write the failing tests**

```swift
// FreeTimeCalculatorTests.swift
import Foundation
import Testing
@testable import DatoCore

@Suite struct FreeTimeCalculatorTests {
    let cal = Fixture.calendar

    func at(_ hour: Int, _ minute: Int = 0) -> Date { Fixture.date(2026, 9, 29, hour, minute) }

    func hm(_ date: Date) -> String {
        let c = cal.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    func slots(_ events: [CalendarEvent], now: Date) -> [String] {
        FreeTimeCalculator.freeSlots(events: events, now: now, workingHours: .standard, calendar: cal)
            .map { "\(hm($0.start))-\(hm($0.end))" }
    }

    @Test func emptyDayIsFreeFromNowUntilEndOfWork() {
        #expect(slots([], now: at(10)) == ["10:00-18:00"])
    }

    @Test func gapsShorterThanThirtyMinutesAreDropped() {
        let events = [
            Fixture.event("A", at(11), at(12)),
            Fixture.event("B", at(12, 15), at(13)),
            Fixture.event("C", at(14), at(15)),
        ]
        #expect(slots(events, now: at(10)) == ["10:00-11:00", "13:00-14:00", "15:00-18:00"])
    }

    @Test func overlappingEventsMerge() {
        let events = [Fixture.event("A", at(11), at(13)), Fixture.event("B", at(12), at(14))]
        #expect(slots(events, now: at(10)) == ["10:00-11:00", "14:00-18:00"])
    }

    @Test func ongoingEventDelaysFirstSlot() {
        #expect(slots([Fixture.event("A", at(9, 30), at(10, 45))], now: at(10)) == ["10:45-18:00"])
    }

    @Test func beforeWorkStartsAtWorkingHours() {
        #expect(slots([], now: at(7)) == ["09:00-18:00"])
    }

    @Test func afterWorkIsEmpty() {
        #expect(slots([], now: at(19)).isEmpty)
    }

    @Test func allDayEventsDoNotBlockTime() {
        let holiday = Fixture.event("Holiday", Fixture.date(2026, 9, 29), Fixture.date(2026, 9, 30), allDay: true)
        #expect(slots([holiday], now: at(10)) == ["10:00-18:00"])
    }
}
```

```swift
// AgendaBuilderTests.swift
import Foundation
import Testing
@testable import DatoCore

extension AgendaEntry {
    var title: String {
        switch self {
        case .event(let event): event.title
        case .reminder(let reminder): reminder.title
        case .free: "free"
        }
    }
}

@Suite struct AgendaBuilderTests {
    let cal = Fixture.calendar
    let now = Fixture.date(2026, 9, 29, 10, 0)

    func at(_ hour: Int, _ minute: Int = 0, month: Int = 9, day: Int = 29) -> Date {
        Fixture.date(2026, month, day, hour, minute)
    }

    func build(
        _ events: [CalendarEvent] = [], _ reminders: [ReminderItem] = [],
        firstDay: Date? = nil, days: Int = 7, freeTime: Bool = false
    ) -> [AgendaDay] {
        AgendaBuilder.build(
            events: events, reminders: reminders, now: now, firstDay: firstDay ?? now, dayCount: days,
            settings: AgendaSettings(showFreeTime: freeTime, workingHours: .standard), calendar: cal
        )
    }

    @Test func groupsByDayAndSkipsEmptyDays() {
        let days = build([
            Fixture.event("A", at(11), at(12)),
            Fixture.event("B", at(9, month: 10, day: 1), at(10, month: 10, day: 1)),
        ])
        #expect(days.map(\.date) == [Fixture.date(2026, 9, 29), Fixture.date(2026, 10, 1)])
    }

    @Test func todayIsAlwaysPresent() {
        #expect(build().map(\.date) == [Fixture.date(2026, 9, 29)])
    }

    @Test func endedEventsTodayAreCollapsed() {
        let today = build([Fixture.event("Ended", at(8), at(9)), Fixture.event("Ongoing", at(9, 30), at(10, 30))])[0]
        #expect(today.earlierEvents.map(\.title) == ["Ended"])
        #expect(today.entries.map(\.title) == ["Ongoing"])
    }

    @Test func overdueRemindersSitOnTodayOldestFirst() {
        let reminders = [
            Fixture.reminder("Old", at(9, day: 27)),
            Fixture.reminder("Older", at(9, day: 25)),
            Fixture.reminder("Today", at(14)),
        ]
        let today = build([], reminders)[0]
        #expect(today.overdue.map(\.title) == ["Older", "Old"])
        #expect(today.entries.map(\.title) == ["Today"])
    }

    @Test func orderingWithinADay() {
        let oct1 = Fixture.date(2026, 10, 1)
        let days = build(
            [
                Fixture.event("Timed", at(9, month: 10, day: 1), at(10, month: 10, day: 1)),
                Fixture.event("Holiday", oct1, Fixture.date(2026, 10, 2), allDay: true),
            ],
            [
                Fixture.reminder("Rem9", at(9, month: 10, day: 1)),
                Fixture.reminder("AllDayRem", oct1, hasTime: false),
            ]
        )
        #expect(days.last?.entries.map(\.title) == ["Holiday", "AllDayRem", "Timed", "Rem9"])
    }

    @Test func multiDayAllDayEventAppearsOnEachDay() {
        let trip = Fixture.event("Trip", Fixture.date(2026, 9, 30), Fixture.date(2026, 10, 2), allDay: true)
        let days = build([trip])
        #expect(days.filter { $0.entries.map(\.title).contains("Trip") }.map(\.date)
            == [Fixture.date(2026, 9, 30), Fixture.date(2026, 10, 1)])
    }

    @Test func freeSlotsOnlyToday() {
        let days = build(
            [Fixture.event("Meeting", at(11), at(12)), Fixture.event("Tomorrow", at(11, day: 30), at(12, day: 30))],
            freeTime: true
        )
        #expect(days[0].entries.map(\.title) == ["free", "Meeting", "free"])
        #expect(days[1].entries.map(\.title) == ["Tomorrow"])
    }

    @Test func singleDayModeKeepsAnEmptyDay() {
        #expect(build(firstDay: Fixture.date(2026, 10, 5), days: 1).map(\.date) == [Fixture.date(2026, 10, 5)])
    }
}
```

```swift
// AgendaFormattingTests.swift
import Foundation
import Testing
@testable import DatoCore

@Suite struct AgendaFormattingTests {
    let cal = Fixture.calendar
    let now = Fixture.date(2026, 9, 29, 10, 0)

    @Test func dayTitles() {
        func title(_ date: Date) -> String {
            AgendaFormatting.dayTitle(for: date, now: now, calendar: cal, locale: Fixture.locale)
        }
        #expect(title(Fixture.date(2026, 9, 29)) == "Today")
        #expect(title(Fixture.date(2026, 9, 30)) == "Tomorrow")
        #expect(title(Fixture.date(2026, 9, 28)) == "Yesterday")
        #expect(title(Fixture.date(2026, 10, 1)) == "Thu 1 Oct")
    }

    @Test func timeRanges() {
        let day = Fixture.date(2026, 10, 1)
        func range(_ start: Date, _ end: Date, allDay: Bool = false) -> String {
            AgendaFormatting.timeRange(
                for: Fixture.event("E", start, end, allDay: allDay), on: day, calendar: cal, locale: Fixture.locale
            )
        }
        #expect(range(Fixture.date(2026, 10, 1, 9, 0), Fixture.date(2026, 10, 1, 9, 30)) == "09:00–09:30")
        #expect(range(day, Fixture.date(2026, 10, 2), allDay: true) == "All day")
        #expect(range(Fixture.date(2026, 9, 30, 22, 0), Fixture.date(2026, 10, 1, 2, 0)) == "…–02:00")
        #expect(range(Fixture.date(2026, 10, 1, 22, 0), Fixture.date(2026, 10, 2, 1, 0)) == "22:00–…")
        #expect(range(Fixture.date(2026, 9, 30, 8, 0), Fixture.date(2026, 10, 2, 8, 0)) == "All day")
    }

    @Test func shortDateAndMonthTitle() {
        #expect(AgendaFormatting.shortDate(Fixture.date(2026, 9, 28), calendar: cal, locale: Fixture.locale) == "Mon 28 Sep")
        #expect(AgendaFormatting.monthTitle(for: Fixture.date(2026, 9, 15), calendar: cal, locale: Fixture.locale) == "September 2026")
    }

    @Test func plainNotesStripsHtml() {
        let html = "<p>Hello&nbsp;<b>world</b></p><br>Join &amp; go"
        #expect(AgendaFormatting.plainNotes(html, limit: 500) == "Hello world\n\nJoin & go")
    }

    @Test func plainNotesKeepsAngleBracketLinks() {
        let notes = "Join <https://meet.google.com/abc-defg-hij>"
        #expect(AgendaFormatting.plainNotes(notes, limit: 500) == notes)
    }

    @Test func plainNotesTruncates() {
        #expect(AgendaFormatting.plainNotes("abcdef", limit: 3) == "abc…")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `scripts/test.sh`
Expected: build FAIL — `cannot find 'FreeTimeCalculator' in scope`.

- [ ] **Step 3: Implement `Sources/DatoCore/FreeTimeCalculator.swift`**

```swift
import Foundation

public struct WorkingHours: Hashable, Sendable, Codable {
    /// Minutes after midnight.
    public var startMinutes: Int
    public var endMinutes: Int

    public init(startMinutes: Int, endMinutes: Int) {
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    public static let standard = WorkingHours(startMinutes: 9 * 60, endMinutes: 18 * 60)
}

public enum FreeTimeCalculator {
    /// Gaps of at least `minimumMinutes` between `now` and the end of today's working hours.
    public static func freeSlots(
        events: [CalendarEvent], now: Date, workingHours: WorkingHours, minimumMinutes: Int = 30, calendar: Calendar
    ) -> [DateInterval] {
        let dayStart = calendar.startOfDay(for: now)
        guard let workStart = wallClock(workingHours.startMinutes, on: dayStart, calendar: calendar),
              let workEnd = wallClock(workingHours.endMinutes, on: dayStart, calendar: calendar) else { return [] }
        let windowStart = max(now, workStart)
        guard windowStart < workEnd else { return [] }

        let busy = events
            .filter { !$0.isAllDay && !$0.isCancelled && !$0.isDeclined && $0.end > windowStart && $0.start < workEnd }
            .map { (start: max($0.start, windowStart), end: min($0.end, workEnd)) }
            .sorted { $0.start < $1.start }

        var slots: [DateInterval] = []
        var cursor = windowStart
        for block in busy {
            if block.start > cursor { slots.append(DateInterval(start: cursor, end: block.start)) }
            cursor = max(cursor, block.end)
        }
        if cursor < workEnd { slots.append(DateInterval(start: cursor, end: workEnd)) }
        return slots.filter { $0.duration >= TimeInterval(minimumMinutes * 60) }
    }

    /// Wall-clock time on `dayStart` (DST-safe). 24:00 means the next midnight.
    static func wallClock(_ minutes: Int, on dayStart: Date, calendar: Calendar) -> Date? {
        if minutes >= 24 * 60 { return calendar.date(byAdding: .day, value: 1, to: dayStart) }
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: dayStart)
    }
}
```

- [ ] **Step 4: Implement `Sources/DatoCore/AgendaBuilder.swift`**

```swift
import Foundation

public struct AgendaSettings: Sendable {
    public var showFreeTime: Bool
    public var workingHours: WorkingHours

    public init(showFreeTime: Bool = true, workingHours: WorkingHours = .standard) {
        self.showFreeTime = showFreeTime
        self.workingHours = workingHours
    }
}

public enum AgendaEntry: Identifiable, Hashable, Sendable {
    case event(CalendarEvent)
    case reminder(ReminderItem)
    case free(DateInterval)

    public var id: String {
        switch self {
        case .event(let event): "event:\(event.id)"
        case .reminder(let reminder): "reminder:\(reminder.id)"
        case .free(let interval): "free:\(interval.start.timeIntervalSince1970)"
        }
    }
}

public struct AgendaDay: Identifiable, Hashable, Sendable {
    /// Start of the day.
    public let date: Date
    /// Incomplete reminders due before today; only filled on today.
    public let overdue: [ReminderItem]
    /// Today's timed events that already ended (shown collapsed).
    public let earlierEvents: [CalendarEvent]
    public let entries: [AgendaEntry]
    public var id: Date { date }
}

public enum AgendaBuilder {
    /// Days from `firstDay` for `dayCount` days. Empty days are skipped except today,
    /// and except when a single day was requested.
    public static func build(
        events: [CalendarEvent], reminders: [ReminderItem], now: Date,
        firstDay: Date, dayCount: Int, settings: AgendaSettings, calendar: Calendar
    ) -> [AgendaDay] {
        let todayStart = calendar.startOfDay(for: now)
        let count = max(1, dayCount)
        var days: [AgendaDay] = []
        var dayStart = calendar.startOfDay(for: firstDay)

        for _ in 0..<count {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let isToday = dayStart == todayStart
            let dayEvents = events.filter { $0.start < dayEnd && ($0.end > dayStart || $0.start == dayStart) }
            let earlier = isToday ? dayEvents.filter { !$0.isAllDay && $0.end <= now } : []
            let earlierIDs = Set(earlier.map(\.id))
            let shown = dayEvents.filter { !earlierIDs.contains($0.id) }
            let dayReminders = reminders.filter { $0.due >= dayStart && $0.due < dayEnd }
            let overdue = isToday ? reminders.filter { $0.due < todayStart }.sorted { $0.due < $1.due } : []
            let free = isToday && settings.showFreeTime
                ? FreeTimeCalculator.freeSlots(events: dayEvents, now: now, workingHours: settings.workingHours, calendar: calendar)
                : []
            let entries = ordered(events: shown, reminders: dayReminders, free: free, dayStart: dayStart)

            if isToday || count == 1 || !entries.isEmpty || !earlier.isEmpty {
                days.append(AgendaDay(date: dayStart, overdue: overdue, earlierEvents: earlier, entries: entries))
            }
            dayStart = dayEnd
        }
        return days
    }

    /// All-day events, then date-only reminders, then timed items by time
    /// (events before reminders at the same minute, then by title).
    private static func ordered(
        events: [CalendarEvent], reminders: [ReminderItem], free: [DateInterval], dayStart: Date
    ) -> [AgendaEntry] {
        typealias Key = (group: Int, time: Date, kind: Int, title: String)
        var keyed: [(key: Key, entry: AgendaEntry)] = []
        for event in events {
            keyed.append(((event.isAllDay ? 0 : 2, event.isAllDay ? dayStart : event.start, 0, event.title), .event(event)))
        }
        for reminder in reminders {
            keyed.append(((reminder.hasTime ? 2 : 1, reminder.hasTime ? reminder.due : dayStart, 1, reminder.title), .reminder(reminder)))
        }
        for slot in free {
            keyed.append(((2, slot.start, 2, ""), .free(slot)))
        }
        return keyed
            .sorted { ($0.key.group, $0.key.time, $0.key.kind, $0.key.title) < ($1.key.group, $1.key.time, $1.key.kind, $1.key.title) }
            .map(\.entry)
    }
}
```

- [ ] **Step 5: Implement `Sources/DatoCore/AgendaFormatting.swift`**

```swift
import Foundation

public enum AgendaFormatting {
    /// "Today", "Tomorrow", "Yesterday", or a short date such as "Thu 1 Oct".
    public static func dayTitle(for day: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return shortDate(day, calendar: calendar, locale: locale)
    }

    /// "09:00–09:30"; "…–02:00" / "22:00–…" when the event crosses midnight; "All day" when it covers the day.
    public static func timeRange(for event: CalendarEvent, on day: Date, calendar: Calendar, locale: Locale) -> String {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        if event.isAllDay || (event.start <= dayStart && event.end >= dayEnd) { return "All day" }
        let start = event.start < dayStart ? "…" : time(event.start, calendar: calendar, locale: locale)
        let end = event.end > dayEnd ? "…" : time(event.end, calendar: calendar, locale: locale)
        return "\(start)–\(end)"
    }

    public static func time(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        RelativeTime.format(date, template: "jmm", calendar: calendar, locale: locale)
    }

    /// "Mon 28 Sep".
    public static func shortDate(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        RelativeTime.format(date, template: "EEEdMMM", calendar: calendar, locale: locale)
    }

    /// "September 2026".
    public static func monthTitle(for date: Date, calendar: Calendar, locale: Locale) -> String {
        RelativeTime.format(date, template: "MMMMyyyy", calendar: calendar, locale: locale)
    }

    /// Event notes as plain text: HTML tags stripped, common entities decoded, capped at `limit` characters.
    /// Angle-bracketed links such as `<https://...>` are kept.
    public static func plainNotes(_ raw: String, limit: Int) -> String {
        var text = raw.replacingOccurrences(of: #"(?i)<br\s*/?>|</p>|</div>|</li>"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<(?!https?:)[/!a-zA-Z][^>]*>"#, with: "", options: .regularExpression)
        // &amp; last so "&amp;lt;" becomes "&lt;", not "<".
        let entities = [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")]
        for (entity, value) in entities {
            text = text.replacingOccurrences(of: entity, with: value)
        }
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/DatoCore Tests/DatoCoreTests
git commit -m "feat(core): agenda builder with overdue reminders, free time and formatting"
```

---

### Task 6: Quick-add parser

**Files:**
- Create: `Sources/DatoCore/QuickAddParser.swift`
- Test: `Tests/DatoCoreTests/QuickAddParserTests.swift`

**Interfaces:**
- Consumes: `CalendarInfo`, `CalendarKind`.
- Produces: `QuickAddKind { event, reminder; calendarKind }`; `QuickAddDraft { kind, title, calendarID, unmatchedCalendarToken, isAllDay, start, end, hasDueTime, hasExplicitDate }` (all `var`); `QuickAddParser(calendar:now:)`, `.parse(_:calendars:forcedKind:) -> QuickAddDraft`.

- [ ] **Step 1: Write the failing test**

```swift
// QuickAddParserTests.swift
import Foundation
import Testing
@testable import DatoCore

/// NSDataDetector resolves "tomorrow" against the real clock and the system time zone,
/// so these tests use Calendar.current and Date() rather than Fixture.
@Suite struct QuickAddParserTests {
    let cal = Calendar.current
    let calendars: [CalendarInfo] = [
        CalendarInfo(id: "work-stuff", title: "Work Stuff", color: .gray, accountID: "g", kind: .events, isWritable: true),
        CalendarInfo(id: "work", title: "Work", color: .gray, accountID: "g", kind: .events, isWritable: true),
        CalendarInfo(id: "family", title: "Family Plans", color: .gray, accountID: "i", kind: .events, isWritable: true),
        CalendarInfo(id: "holidays", title: "Holidays", color: .gray, accountID: "i", kind: .events, isWritable: false),
        CalendarInfo(id: "r-work", title: "Work", color: .gray, accountID: "g", kind: .reminders, isWritable: true),
    ]

    func parse(_ text: String, now: Date = Date(), forcedKind: QuickAddKind? = nil) -> QuickAddDraft {
        QuickAddParser(calendar: cal, now: now).parse(text, calendars: calendars, forcedKind: forcedKind)
    }

    func today(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    func tomorrow(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: cal.date(byAdding: .day, value: 1, to: Date())!)!
    }

    @Test func plainTitleStartsAtNextHalfHour() {
        let draft = parse("Focus block", now: today(10, 7))
        #expect(draft.kind == .event)
        #expect(draft.title == "Focus block")
        #expect(draft.start == today(10, 30))
        #expect(draft.end == today(11, 0))
        #expect(!draft.isAllDay)
        #expect(!draft.hasExplicitDate)
        #expect(draft.calendarID == nil)
    }

    @Test func halfHourRollsIntoNextHour() {
        #expect(parse("Focus", now: today(10, 30)).start == today(11, 0))
    }

    @Test(arguments: [
        ("Review for 45m", "Review", 45),
        ("Planning 1h30m", "Planning", 90),
        ("Deep work 1.5h", "Deep work", 90),
        ("Sync 2 hours", "Sync", 120),
        ("Chat 20 min", "Chat", 20),
    ])
    func durations(input: String, title: String, minutes: Int) {
        let draft = parse(input, now: today(10, 7))
        #expect(draft.title == title)
        #expect(draft.end.timeIntervalSince(draft.start) == TimeInterval(minutes * 60))
    }

    @Test func hashtagExactMatchBeatsPrefix() {
        let draft = parse("Standup #work")
        #expect(draft.calendarID == "work")
        #expect(draft.title == "Standup")
    }

    @Test func hashtagPrefixMatch() {
        #expect(parse("Dinner #fam").calendarID == "family")
    }

    @Test func hashtagSubstringMatch() {
        #expect(parse("Deploy #stuff").calendarID == "work-stuff")
    }

    @Test func readOnlyCalendarsAreNotTargets() {
        let draft = parse("Day off #holidays")
        #expect(draft.calendarID == nil)
        #expect(draft.unmatchedCalendarToken == "holidays")
    }

    @Test func unmatchedHashtagIsReported() {
        let draft = parse("Gym #zzz")
        #expect(draft.calendarID == nil)
        #expect(draft.unmatchedCalendarToken == "zzz")
        #expect(draft.title == "Gym")
    }

    @Test func bangMakesReminderInMatchingList() {
        let draft = parse("!Send report #work", now: today(10))
        #expect(draft.kind == .reminder)
        #expect(draft.calendarID == "r-work")
        #expect(draft.title == "Send report")
        #expect(!draft.hasDueTime)
        #expect(draft.start == cal.startOfDay(for: today(10)))
    }

    @Test func forcedKindOverridesBang() {
        #expect(parse("!Send report", forcedKind: .event).kind == .event)
    }

    @Test func tomorrowWithTimeAndDuration() {
        let draft = parse("Lunch with Sara tomorrow 1pm 1h #work")
        #expect(draft.title == "Lunch with Sara")
        #expect(draft.calendarID == "work")
        #expect(draft.start == tomorrow(13))
        #expect(draft.end == tomorrow(14))
        #expect(draft.hasExplicitDate)
    }

    @Test func dateWithoutTimeIsAllDay() {
        let draft = parse("Offsite tomorrow")
        #expect(draft.isAllDay)
        #expect(draft.title == "Offsite")
        #expect(draft.start == cal.startOfDay(for: tomorrow(12)))
        #expect(draft.end == cal.date(byAdding: .day, value: 1, to: draft.start))
    }

    @Test func reminderWithTime() {
        let draft = parse("!Call mom tomorrow at 6pm")
        #expect(draft.kind == .reminder)
        #expect(draft.hasDueTime)
        #expect(draft.start == tomorrow(18))
        #expect(draft.title == "Call mom")
    }

    @Test func timeRangeSetsEnd() {
        let draft = parse("Workshop tomorrow from 2pm to 4pm")
        #expect(draft.start == tomorrow(14))
        #expect(draft.end == tomorrow(16))
        #expect(draft.title == "Workshop")
    }

    @Test func detectorDoesNotSwallowTitleWords() {
        // NSDataDetector matches "Dinner friday 7pm" as one phrase.
        let draft = parse("Dinner friday 7pm")
        #expect(draft.title == "Dinner")
        #expect(cal.component(.weekday, from: draft.start) == 6)
        #expect(cal.component(.hour, from: draft.start) == 19)
    }

    @Test func emptyInputs() {
        #expect(parse("").title == "")
        let bang = parse("!")
        #expect(bang.kind == .reminder)
        #expect(bang.title == "")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/test.sh`
Expected: build FAIL — `cannot find 'QuickAddParser' in scope`.

- [ ] **Step 3: Implement `Sources/DatoCore/QuickAddParser.swift`**

```swift
import Foundation

public enum QuickAddKind: String, CaseIterable, Hashable, Sendable {
    case event
    case reminder

    public var calendarKind: CalendarKind { self == .event ? .events : .reminders }
}

public struct QuickAddDraft: Equatable, Sendable {
    public var kind: QuickAddKind
    public var title: String
    /// Calendar (events) or list (reminders) chosen with `#token`; nil means "use the default".
    public var calendarID: String?
    public var unmatchedCalendarToken: String?
    public var isAllDay: Bool
    /// Event start, or reminder due date.
    public var start: Date
    public var end: Date
    public var hasDueTime: Bool
    public var hasExplicitDate: Bool
}

/// Parses "Lunch with Sara tomorrow 1pm 1h #work" or "!Pay rent friday".
/// Rules: leading "!" = reminder; "#token" = calendar/list; "45m" / "1h30m" / "for 2 hours" = duration;
/// dates and times via NSDataDetector. Whatever is left is the title.
public struct QuickAddParser {
    public let calendar: Calendar
    public let now: Date
    public var defaultDurationMinutes = 30

    public init(calendar: Calendar, now: Date) {
        self.calendar = calendar
        self.now = now
    }

    static let hashtagPattern = #"(?:^|\s)#([\p{L}\p{N}_-]+)"#
    static let durationPattern = #"(?i)(?:\bfor\s+)?\b(?:(\d+(?:\.\d+)?)\s*(?:hours|hour|hrs|hr|h)(?:\s*(\d+)\s*(?:minutes|minute|mins|min|m))?|(\d+)\s*(?:minutes|minute|mins|min|m))\b"#
    static let clockTimePattern = #"(?i)\b\d{1,2}(:\d{2})?\s?(am|pm)\b|\b\d{1,2}:\d{2}\b|\bnoon\b|\bmidnight\b|\bat\s+\d{1,2}\b"#

    public func parse(_ input: String, calendars: [CalendarInfo], forcedKind: QuickAddKind? = nil) -> QuickAddDraft {
        var text = Self.collapsingWhitespace(input)
        var kind = QuickAddKind.event
        if text.hasPrefix("!") {
            kind = .reminder
            text = Self.collapsingWhitespace(String(text.dropFirst()))
        }
        if let forcedKind { kind = forcedKind }

        var calendarID: String?
        var unmatchedToken: String?
        if let match = Self.firstMatch(Self.hashtagPattern, in: text), let token = Self.group(1, of: match, in: text) {
            let targets = calendars.filter { $0.kind == kind.calendarKind && $0.isWritable }
            if let target = Self.matchCalendar(token, in: targets) {
                calendarID = target.id
            } else {
                unmatchedToken = token
            }
            text = Self.removing(match.range, from: text)
        }

        var durationMinutes: Int?
        if kind == .event, let match = Self.firstMatch(Self.durationPattern, in: text) {
            let hours = Self.group(1, of: match, in: text).flatMap(Double.init) ?? 0
            let extraMinutes = Self.group(2, of: match, in: text).flatMap(Int.init) ?? 0
            let minutes = Self.group(3, of: match, in: text).flatMap(Int.init) ?? 0
            let total = Int((hours * 60).rounded()) + extraMinutes + minutes
            if total > 0 {
                durationMinutes = total
                text = Self.removing(match.range, from: text)
            }
        }

        let detected = detectDate(in: text)
        if let detected { text = Self.removing(detected.range, from: text) }

        var draft = QuickAddDraft(
            kind: kind, title: Self.cleanTitle(text), calendarID: calendarID, unmatchedCalendarToken: unmatchedToken,
            isAllDay: false, start: now, end: now, hasDueTime: false, hasExplicitDate: detected != nil
        )
        let duration = TimeInterval((durationMinutes ?? defaultDurationMinutes) * 60)
        switch (kind, detected) {
        case (.event, .some(let found)) where found.hasTime:
            draft.start = found.date
            draft.end = found.date.addingTimeInterval(found.duration > 0 ? found.duration : duration)
        case (.event, .some(let found)):
            draft.isAllDay = true
            draft.start = calendar.startOfDay(for: found.date)
            draft.end = calendar.date(byAdding: .day, value: 1, to: draft.start) ?? draft.start
        case (.event, .none):
            draft.start = nextHalfHour()
            draft.end = draft.start.addingTimeInterval(duration)
        case (.reminder, .some(let found)):
            draft.hasDueTime = found.hasTime
            draft.start = found.hasTime ? found.date : calendar.startOfDay(for: found.date)
            draft.end = draft.start
        case (.reminder, .none):
            draft.start = calendar.startOfDay(for: now)
            draft.end = draft.start
        }
        return draft
    }

    // MARK: - Dates

    struct DetectedDate {
        let range: NSRange
        let date: Date
        let duration: TimeInterval
        let hasTime: Bool
    }

    func detectDate(in text: String) -> DetectedDate? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let ns = text as NSString
        guard let match = detector.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let date = match.date else { return nil }
        let hasTime = Self.containsClockTime(ns.substring(with: match.range))

        func isDateWord(_ word: String) -> Bool {
            detector.firstMatch(in: word, range: NSRange(location: 0, length: (word as NSString).length)) != nil
        }
        // True when `candidate` on its own is entirely a date phrase with the same meaning.
        func meansSame(_ candidate: NSRange) -> Bool {
            let phrase = ns.substring(with: candidate)
            let length = (phrase as NSString).length
            guard let other = detector.firstMatch(in: phrase, range: NSRange(location: 0, length: length)),
                  other.range.location == 0, other.range.length == length, let otherDate = other.date else { return false }
            return hasTime
                ? otherDate == date && other.duration == match.duration
                : calendar.isDate(otherDate, inSameDayAs: date)
        }

        // NSDataDetector sometimes swallows neighbouring title words ("Dinner friday 7pm").
        // Peel non-date words off both edges while the rest still means the same date.
        var range = match.range
        while let next = Self.peel(range, in: ns, fromStart: true), !isDateWord(next.word), meansSame(next.rest) {
            range = next.rest
        }
        while let next = Self.peel(range, in: ns, fromStart: false), !isDateWord(next.word), meansSame(next.rest) {
            range = next.rest
        }
        return DetectedDate(range: range, date: date, duration: match.duration, hasTime: hasTime)
    }

    /// Splits the first (or last) word off `range`; nil when `range` is a single word.
    static func peel(_ range: NSRange, in text: NSString, fromStart: Bool) -> (word: String, rest: NSRange)? {
        let phrase = text.substring(with: range) as NSString
        let space = fromStart ? phrase.range(of: " ") : phrase.range(of: " ", options: .backwards)
        guard space.location != NSNotFound else { return nil }
        if fromStart {
            return (phrase.substring(to: space.location),
                    NSRange(location: range.location + space.location + 1, length: range.length - space.location - 1))
        }
        return (phrase.substring(from: space.location + 1), NSRange(location: range.location, length: space.location))
    }

    static func containsClockTime(_ text: String) -> Bool {
        text.range(of: clockTimePattern, options: .regularExpression) != nil
    }

    func nextHalfHour() -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let minute = calendar.component(.minute, from: now)
        return calendar.date(byAdding: .minute, value: minute < 30 ? 30 : 60, to: hourStart) ?? now
    }

    // MARK: - Calendars

    /// Exact title match, then prefix, then substring; spaces and case ignored.
    static func matchCalendar(_ token: String, in calendars: [CalendarInfo]) -> CalendarInfo? {
        let wanted = normalize(token)
        let named = calendars.map { (calendar: $0, name: normalize($0.title)) }
        return named.first { $0.name == wanted }?.calendar
            ?? named.first { $0.name.hasPrefix(wanted) }?.calendar
            ?? named.first { $0.name.contains(wanted) }?.calendar
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace }
    }

    // MARK: - Text helpers

    static func cleanTitle(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        let dangling: Set<String> = ["at", "on", "by", "from", "for", "to", "@", "-", "–"]
        while let last = words.last, dangling.contains(last.lowercased()) { words.removeLast() }
        return words.joined(separator: " ")
    }

    static func collapsingWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    static func group(_ index: Int, of match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    static func removing(_ range: NSRange, from text: String) -> String {
        collapsingWhitespace((text as NSString).replacingCharacters(in: range, with: " "))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test.sh`
Expected: all tests pass. If a `NSDataDetector` expectation fails (it is system-provided), print `detectDate(in:)` for the failing phrase and adjust the peeling rule — not the test's intent.

- [ ] **Step 5: Commit**

```bash
git add Sources/DatoCore/QuickAddParser.swift Tests/DatoCoreTests/QuickAddParserTests.swift
git commit -m "feat(core): natural-language quick-add parser"
```

---

### Task 7: Meeting link detector

**Files:**
- Create: `Sources/DatoCore/MeetingLinkDetector.swift`
- Test: `Tests/DatoCoreTests/MeetingLinkDetectorTests.swift`

**Interfaces:**
- Produces: `MeetingProvider { zoom, googleMeet, teams, webex, facetime, slack; displayName }`; `MeetingLink { provider, url, nativeURL }`; `MeetingLinkDetector.detect(url:location:notes:) -> MeetingLink?`; `MeetingLinkDetector.detect(in:) -> MeetingLink?`.

- [ ] **Step 1: Write the failing test**

```swift
// MeetingLinkDetectorTests.swift
import Foundation
import Testing
@testable import DatoCore

@Suite struct MeetingLinkDetectorTests {
    @Test func zoomWithPasswordGetsNativeURL() {
        let link = MeetingLinkDetector.detect(in: "Join: https://acme.zoom.us/j/123456789?pwd=abc123.")
        #expect(link?.provider == .zoom)
        #expect(link?.url.absoluteString == "https://acme.zoom.us/j/123456789?pwd=abc123")
        #expect(link?.nativeURL?.absoluteString == "zoommtg://acme.zoom.us/join?action=join&confno=123456789&pwd=abc123")
    }

    @Test func zoomPersonalLinkHasNoNativeURL() {
        let link = MeetingLinkDetector.detect(in: "https://acme.zoom.us/my/jane")
        #expect(link?.provider == .zoom)
        #expect(link?.nativeURL == nil)
    }

    @Test func googleMeet() {
        let link = MeetingLinkDetector.detect(in: "https://meet.google.com/abc-defg-hij?authuser=0")
        #expect(link?.provider == .googleMeet)
        #expect(link?.nativeURL == nil)
    }

    @Test func teamsGetsNativeURL() {
        let url = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d"
        let link = MeetingLinkDetector.detect(in: "Click here \(url)")
        #expect(link?.provider == .teams)
        #expect(link?.nativeURL?.absoluteString == "msteams:/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d")
    }

    @Test func otherProviders() {
        #expect(MeetingLinkDetector.detect(in: "https://teams.live.com/meet/9876")?.provider == .teams)
        #expect(MeetingLinkDetector.detect(in: "https://acme.webex.com/meet/jane")?.provider == .webex)
        #expect(MeetingLinkDetector.detect(in: "https://facetime.apple.com/join#v=1&p=abc")?.provider == .facetime)
        #expect(MeetingLinkDetector.detect(in: "https://app.slack.com/huddle/T123/C456")?.provider == .slack)
    }

    @Test func ignoresOrdinaryLinks() {
        #expect(MeetingLinkDetector.detect(in: "Docs: https://docs.google.com/document/d/1") == nil)
    }

    @Test func findsAngleBracketedLinks() {
        #expect(MeetingLinkDetector.detect(in: "Meeting <https://meet.google.com/abc-defg-hij>")?.provider == .googleMeet)
    }

    @Test func urlFieldWinsThenLocationThenNotes() {
        let zoom = URL(string: "https://acme.zoom.us/j/1")!
        let teams = "https://teams.live.com/meet/1"
        let meet = "https://meet.google.com/abc-defg-hij"
        #expect(MeetingLinkDetector.detect(url: zoom, location: teams, notes: meet)?.provider == .zoom)
        #expect(MeetingLinkDetector.detect(url: nil, location: teams, notes: meet)?.provider == .teams)
        #expect(MeetingLinkDetector.detect(url: nil, location: "Room 4", notes: meet)?.provider == .googleMeet)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/test.sh`
Expected: build FAIL — `cannot find 'MeetingLinkDetector' in scope`.

- [ ] **Step 3: Implement `Sources/DatoCore/MeetingLinkDetector.swift`**

```swift
import Foundation

public enum MeetingProvider: String, CaseIterable, Hashable, Sendable {
    case zoom, googleMeet, teams, webex, facetime, slack

    public var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .googleMeet: "Google Meet"
        case .teams: "Microsoft Teams"
        case .webex: "Webex"
        case .facetime: "FaceTime"
        case .slack: "Slack Huddle"
        }
    }
}

public struct MeetingLink: Hashable, Sendable {
    public let provider: MeetingProvider
    public let url: URL
    /// Opens the provider's desktop app directly (Zoom, Teams); nil when there is none.
    public let nativeURL: URL?
}

public enum MeetingLinkDetector {
    /// Looks in the event URL, then location, then notes; the first meeting link wins.
    public static func detect(url: URL?, location: String?, notes: String?) -> MeetingLink? {
        if let url, let link = classify(url) { return link }
        for text in [location, notes].compactMap({ $0 }) {
            if let link = detect(in: text) { return link }
        }
        return nil
    }

    public static func detect(in text: String) -> MeetingLink? {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>"'\)\]]+"#) else { return nil }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            var candidate = String(text[range])
            while let last = candidate.last, ".,;:!?".contains(last) { candidate.removeLast() }
            if let url = URL(string: candidate), let link = classify(url) { return link }
        }
        return nil
    }

    static func classify(_ url: URL) -> MeetingLink? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path

        if host == "zoom.us" || host.hasSuffix(".zoom.us"), ["/j/", "/my/", "/w/"].contains(where: path.hasPrefix) {
            return MeetingLink(provider: .zoom, url: url, nativeURL: zoomNativeURL(url, host: host))
        }
        if host == "meet.google.com", path.range(of: #"^/[a-z]{3}-[a-z]{4}-[a-z]{3}$"#, options: .regularExpression) != nil {
            return MeetingLink(provider: .googleMeet, url: url, nativeURL: nil)
        }
        if host == "teams.microsoft.com", path.hasPrefix("/l/meetup-join/") {
            return MeetingLink(provider: .teams, url: url, nativeURL: teamsNativeURL(url))
        }
        if host == "teams.live.com", path.hasPrefix("/meet/") {
            return MeetingLink(provider: .teams, url: url, nativeURL: nil)
        }
        if host.hasSuffix(".webex.com"), path.count > 1 {
            return MeetingLink(provider: .webex, url: url, nativeURL: nil)
        }
        if host == "facetime.apple.com", path.hasPrefix("/join") {
            return MeetingLink(provider: .facetime, url: url, nativeURL: nil)
        }
        if host == "app.slack.com", path.hasPrefix("/huddle/") {
            return MeetingLink(provider: .slack, url: url, nativeURL: nil)
        }
        return nil
    }

    /// https://acme.zoom.us/j/123?pwd=x → zoommtg://acme.zoom.us/join?action=join&confno=123&pwd=x
    static func zoomNativeURL(_ url: URL, host: String) -> URL? {
        guard url.path.hasPrefix("/j/") else { return nil }
        let meetingID = url.lastPathComponent
        guard !meetingID.isEmpty, meetingID.allSatisfy(\.isNumber) else { return nil }
        var components = URLComponents()
        components.scheme = "zoommtg"
        components.host = host
        components.path = "/join"
        var query = [URLQueryItem(name: "action", value: "join"), URLQueryItem(name: "confno", value: meetingID)]
        if let password = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "pwd" })?.value {
            query.append(URLQueryItem(name: "pwd", value: password))
        }
        components.queryItems = query
        return components.url
    }

    /// Keeps the original percent-encoding: msteams:/l/meetup-join/...?context=...
    static func teamsNativeURL(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return URL(string: "msteams:\(components.percentEncodedPath)\(query)")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `scripts/test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DatoCore/MeetingLinkDetector.swift Tests/DatoCoreTests/MeetingLinkDetectorTests.swift
git commit -m "feat(core): meeting link detection with native app URLs"
```

---

### Task 8: App services (EventKit, preferences, hotkeys, system integration)

**Files:**
- Create: `Sources/BetterThanDato/Services/CalendarService.swift`, `PreferencesStore.swift`, `KeyCombo.swift`, `HotKeyCenter.swift`, `MeetingLauncher.swift`, `LoginItem.swift`, `SystemLinks.swift`, `ColorRef+AppKit.swift`

**Interfaces:**
- Consumes: DatoCore models, `MenuBarWindow`, `WorkingHours`, `AccountBadge`, `MeetingLink`.
- Produces:
  - `AccessState { notDetermined, granted, denied }`
  - `CalendarService` (`@MainActor`): `onChange: (() -> Void)?`, `eventAccess`, `reminderAccess`, `requestAccess() async`, `accounts() -> [AccountInfo]`, `calendars() -> [CalendarInfo]`, `events(in: DateInterval) -> [CalendarEvent]`, `reminders(dueBefore: Date) async -> [ReminderItem]`, `saveEvent(title:start:end:isAllDay:calendarID:) throws`, `saveReminder(title:due:hasTime:listID:) throws`, `setReminder(id:completed:) throws`, `defaultEventCalendarID() -> String?`, `defaultReminderListID() -> String?`
  - `PreferencesStore` (`@Observable @MainActor`) with properties listed in Step 3, plus `workingHours: WorkingHours`, `badge(for: AccountInfo) -> String`
  - `KeyCombo { keyCode, modifiers, key; displayString; quickAddDefault; joinMeetingDefault; init?(event:) }`
  - `HotKeyCenter.shared`, `HotKeyCenter.Action { quickAdd, joinMeeting }`, `setHandler(for:_:)`, `register(_:combo:) -> Bool`
  - `MeetingLauncher.open(_:preferNativeApp:)`, `LoginItem.isEnabled`, `LoginItem.set(_:) throws`, `SystemSettingsLink.open(_:)`, `CalendarAppLauncher.open(eventIdentifier:)`
  - `ColorRef(nsColor:)`, `Color(_ ref: ColorRef)`, `NSColor(_ ref: ColorRef)`

- [ ] **Step 1: Create `Services/ColorRef+AppKit.swift`**

```swift
import AppKit
import DatoCore
import SwiftUI

extension ColorRef {
    init(nsColor: NSColor?) {
        guard let color = nsColor?.usingColorSpace(.sRGB) else {
            self = .gray
            return
        }
        self.init(red: Double(color.redComponent), green: Double(color.greenComponent), blue: Double(color.blueComponent))
    }
}

extension Color {
    init(_ ref: ColorRef) {
        self.init(.sRGB, red: ref.red, green: ref.green, blue: ref.blue)
    }
}

extension NSColor {
    convenience init(_ ref: ColorRef) {
        self.init(srgbRed: ref.red, green: ref.green, blue: ref.blue, alpha: 1)
    }
}
```

- [ ] **Step 2: Create `Services/CalendarService.swift`**

```swift
import AppKit
import DatoCore
import EventKit

enum AccessState: Equatable {
    case notDetermined
    case granted
    case denied

    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .fullAccess: self = .granted
        case .notDetermined: self = .notDetermined
        default: self = .denied // denied, restricted, write-only
        }
    }
}

enum CalendarServiceError: LocalizedError {
    case calendarNotFound
    case reminderNotFound

    var errorDescription: String? {
        switch self {
        case .calendarNotFound: "That calendar no longer exists."
        case .reminderNotFound: "That reminder no longer exists."
        }
    }
}

/// The only type that talks to EventKit. Maps EK objects into DatoCore value types.
@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?

    /// Called on the main thread when anything in the calendar database changes.
    var onChange: (() -> Void)?

    init() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    var eventAccess: AccessState { AccessState(EKEventStore.authorizationStatus(for: .event)) }
    var reminderAccess: AccessState { AccessState(EKEventStore.authorizationStatus(for: .reminder)) }

    func requestAccess() async {
        if eventAccess == .notDetermined { _ = try? await store.requestFullAccessToEvents() }
        if reminderAccess == .notDetermined { _ = try? await store.requestFullAccessToReminders() }
        store.reset()
    }

    func calendars() -> [CalendarInfo] {
        var result: [CalendarInfo] = []
        if eventAccess == .granted { result += store.calendars(for: .event).map { Self.info($0, kind: .events) } }
        if reminderAccess == .granted { result += store.calendars(for: .reminder).map { Self.info($0, kind: .reminders) } }
        return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Accounts that own at least one visible calendar or list, alphabetical.
    func accounts() -> [AccountInfo] {
        let used = Set(calendars().map(\.accountID))
        return store.sources
            .filter { used.contains($0.sourceIdentifier) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .enumerated()
            .map { AccountInfo(id: $1.sourceIdentifier, title: $1.title, order: $0) }
    }

    func events(in interval: DateInterval) -> [CalendarEvent] {
        guard eventAccess == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate).compactMap(Self.event)
    }

    /// Incomplete reminders due before `end`, including overdue ones.
    func reminders(dueBefore end: Date) async -> [ReminderItem] {
        guard reminderAccess == .granted else { return [] }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
        return await Self.fetchReminders(store, predicate)
    }

    func saveEvent(title: String, start: Date, end: Date, isAllDay: Bool, calendarID: String) throws {
        guard let calendar = store.calendar(withIdentifier: calendarID) else { throw CalendarServiceError.calendarNotFound }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.calendar = calendar
        event.isAllDay = isAllDay
        event.startDate = start
        // EventKit's all-day convention: end on the last second of the final day.
        event.endDate = isAllDay ? end.addingTimeInterval(-1) : end
        try store.save(event, span: .thisEvent, commit: true)
    }

    func saveReminder(title: String, due: Date, hasTime: Bool, listID: String) throws {
        guard let list = store.calendar(withIdentifier: listID) else { throw CalendarServiceError.calendarNotFound }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list
        let fields: Set<Calendar.Component> = hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: due)
        if hasTime { reminder.addAlarm(EKAlarm(absoluteDate: due)) }
        try store.save(reminder, commit: true)
    }

    func setReminder(id: String, completed: Bool) throws {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw CalendarServiceError.reminderNotFound
        }
        reminder.isCompleted = completed
        try store.save(reminder, commit: true)
    }

    func defaultEventCalendarID() -> String? { store.defaultCalendarForNewEvents?.calendarIdentifier }
    func defaultReminderListID() -> String? { store.defaultCalendarForNewReminders()?.calendarIdentifier }

    // MARK: - Mapping

    private static func info(_ calendar: EKCalendar, kind: CalendarKind) -> CalendarInfo {
        CalendarInfo(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            color: ColorRef(nsColor: calendar.color),
            accountID: calendar.source?.sourceIdentifier ?? "local",
            kind: kind,
            isWritable: calendar.allowsContentModifications
        )
    }

    private static func event(_ event: EKEvent) -> CalendarEvent? {
        guard let identifier = event.eventIdentifier,
              let start = event.startDate, let end = event.endDate,
              let calendar = event.calendar else { return nil }
        let title = event.title ?? ""
        let me = event.attendees?.first(where: \.isCurrentUser)
        return CalendarEvent(
            id: "\(identifier)|\(start.timeIntervalSince1970)",
            eventIdentifier: identifier,
            title: title.isEmpty ? "Untitled" : title,
            start: start,
            end: end,
            isAllDay: event.isAllDay,
            calendarID: calendar.calendarIdentifier,
            location: event.location,
            url: event.url,
            notes: event.notes,
            attendeeCount: event.attendees?.count ?? 0,
            isDeclined: me?.participantStatus == .declined,
            isCancelled: event.status == .canceled
        )
    }

    /// Nonisolated so the EventKit callback (background thread) never touches main-actor state.
    private nonisolated static func fetchReminders(_ store: EKEventStore, _ predicate: NSPredicate) async -> [ReminderItem] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: (reminders ?? []).compactMap(reminder))
            }
        }
    }

    private nonisolated static func reminder(_ reminder: EKReminder) -> ReminderItem? {
        guard let components = reminder.dueDateComponents, let list = reminder.calendar,
              let due = (components.calendar ?? Calendar.current).date(from: components) else { return nil }
        let title = reminder.title ?? ""
        return ReminderItem(
            id: reminder.calendarItemIdentifier,
            title: title.isEmpty ? "Untitled" : title,
            due: due,
            hasTime: components.hour != nil,
            isCompleted: reminder.isCompleted,
            listID: list.calendarIdentifier
        )
    }
}
```

- [ ] **Step 3: Create `Services/KeyCombo.swift` and `Services/PreferencesStore.swift`**

```swift
// KeyCombo.swift
import AppKit
import Carbon

/// A global shortcut: Carbon key code + Carbon modifier mask + the character to display.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    static let quickAddDefault = KeyCombo(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | optionKey), key: "N")
    static let joinMeetingDefault = KeyCombo(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey | optionKey), key: "J")

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// nil unless ⌘, ⌥ or ⌃ is held — a bare key can't be a global shortcut.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: (event.charactersIgnoringModifiers ?? "?").uppercased())
    }

    var displayString: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + key
    }
}
```

```swift
// PreferencesStore.swift
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
    }

    var workingHours: WorkingHours { WorkingHours(startMinutes: workingHoursStart, endMinutes: workingHoursEnd) }

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
```

- [ ] **Step 4: Create `Services/HotKeyCenter.swift`**

```swift
import Carbon

/// Global hotkeys via Carbon's RegisterEventHotKey (works without Accessibility permission).
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    enum Action: UInt32, CaseIterable {
        case quickAdd = 1
        case joinMeeting = 2
    }

    private var hotKeys: [Action: EventHotKeyRef] = [:]
    private var handlers: [Action: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private static let signature = OSType(0x4254_4454) // "BTDT"

    func setHandler(for action: Action, _ handler: @escaping () -> Void) {
        handlers[action] = handler
    }

    /// Replaces the shortcut for `action`. nil clears it. Returns false if macOS refused the combo.
    @discardableResult
    func register(_ action: Action, combo: KeyCombo?) -> Bool {
        if let existing = hotKeys.removeValue(forKey: action) { UnregisterEventHotKey(existing) }
        guard let combo else { return true }
        installEventHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: action.rawValue)
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeys[action] = ref
        return true
    }

    fileprivate func fire(_ rawValue: UInt32) {
        guard let action = Action(rawValue: rawValue) else { return }
        handlers[action]?()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            let rawValue = hotKeyID.id
            Task { @MainActor in HotKeyCenter.shared.fire(rawValue) }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}
```

- [ ] **Step 5: Create `Services/MeetingLauncher.swift`, `Services/LoginItem.swift`, `Services/SystemLinks.swift`**

```swift
// MeetingLauncher.swift
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
```

```swift
// LoginItem.swift
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

```swift
// SystemLinks.swift
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
```

- [ ] **Step 6: Build**

Run: `swift build`
Expected: `Build complete!` (warnings about Sendable in Swift 5 mode are acceptable; no errors).

- [ ] **Step 7: Commit**

```bash
git add Sources/BetterThanDato/Services
git commit -m "feat(app): EventKit service, preferences, hotkeys and system integration"
```

---

### Task 9: App model, status item with live title, popover shell

**Files:**
- Create: `Sources/BetterThanDato/AppModel.swift`, `Sources/BetterThanDato/StatusItemController.swift`, `Sources/BetterThanDato/Views/PopoverView.swift`
- Modify (replace whole file): `Sources/BetterThanDato/AppDelegate.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–8.
- Produces:
  - `PopoverMode { agenda, quickAdd }`
  - `AppModel` (`@Observable @MainActor`): state `accounts, calendars, events, reminders, eventAccess, reminderAccess, now, displayedMonth, selectedDay, popoverMode, isPinned, toast, hotKeyFailures`; derived `calendar, visibleEvents, visibleReminders, upcomingRange, agendaIsSingleDay, agenda, monthGrid, dayMarkers, monthTitle, menuBarTitle`; lookups `calendarInfo(_:)`, `account(forCalendarID:)`, `badge(forCalendarID:)`, `writableCalendars(for:)`, `defaultCalendarID(for:)`; actions `start()`, `refresh() async`, `scheduleRefresh(delay:)`, `requestAccess() async`, `showMonth(offset:)`, `goToToday()`, `select(day:)`, `moveSelection(byDays:)`, `toggleReminder(_:)`, `save(_:calendarID:) throws`, `currentMeeting() -> (event: CalendarEvent, link: MeetingLink)?`, `join(_:)`, `showToast(_:)`, `applyShortcuts()`, `openSettings()`; hook `onOpenSettings`.
  - `StatusItemController.show(mode:)`, `.close()`.
  - `PopoverView`, `FooterView`, `ToastView`, `PermissionView`, `AccountBadgeView`.

- [ ] **Step 1: Create `Sources/BetterThanDato/AppModel.swift`**

```swift
import AppKit
import DatoCore
import Observation

enum PopoverMode {
    case agenda
    case quickAdd
}

/// Single source of UI state. Raw EventKit data comes in through `refresh()`;
/// everything the UI shows is derived with DatoCore.
@Observable
@MainActor
final class AppModel {
    @ObservationIgnored let service: CalendarService
    @ObservationIgnored let prefs: PreferencesStore
    @ObservationIgnored var onOpenSettings: (() -> Void)?

    private(set) var accounts: [AccountInfo] = []
    private(set) var calendars: [CalendarInfo] = [] {
        didSet { calendarsByID = Dictionary(calendars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) }
    }
    private(set) var calendarsByID: [String: CalendarInfo] = [:]
    private(set) var events: [CalendarEvent] = []
    private(set) var reminders: [ReminderItem] = []
    /// Reminders just ticked off; kept visible (struck through) for a short undo window.
    private(set) var pendingCompletions: [String: ReminderItem] = [:]
    private(set) var eventAccess: AccessState = .notDetermined
    private(set) var reminderAccess: AccessState = .notDetermined
    private(set) var now = Date()
    private(set) var toast: String?
    private(set) var hotKeyFailures: Set<HotKeyCenter.Action> = []

    var displayedMonth = Date() {
        didSet {
            if !calendar.isDate(oldValue, equalTo: displayedMonth, toGranularity: .month) { scheduleRefresh(delay: 0) }
        }
    }
    /// nil = upcoming agenda; otherwise the day picked in the grid.
    var selectedDay: Date?
    var popoverMode: PopoverMode = .agenda
    var isPinned = false

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var completionTokens: [String: UUID] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(service: CalendarService, prefs: PreferencesStore) {
        self.service = service
        self.prefs = prefs
    }

    // MARK: - Lifecycle

    func start() {
        service.onChange = { [weak self] in self?.scheduleRefresh() }
        let center = NotificationCenter.default
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRefresh(delay: 0) }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRefresh(delay: 0) }
        })
        startTicking()
        scheduleRefresh(delay: 0)
    }

    /// Coalesces bursts of change notifications into one fetch.
    func scheduleRefresh(delay: TimeInterval = 0.5) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    func refresh() async {
        eventAccess = service.eventAccess
        reminderAccess = service.reminderAccess
        now = Date()
        calendars = service.calendars()
        accounts = service.accounts()
        let interval = fetchInterval
        events = service.events(in: interval)
        reminders = await service.reminders(dueBefore: interval.end)
    }

    func requestAccess() async {
        await service.requestAccess()
        await refresh()
    }

    /// Updates `now` on every minute boundary so the menu bar countdown stays exact.
    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                let current = Date().timeIntervalSinceReferenceDate
                let nextMinute = (current / 60).rounded(.down) * 60 + 60
                try? await Task.sleep(for: .seconds(nextMinute - current + 0.05))
                guard let self else { return }
                self.now = Date()
            }
        }
    }

    // MARK: - Derived state

    var calendar: Calendar {
        var calendar = Calendar.current
        if prefs.firstWeekday != 0 { calendar.firstWeekday = prefs.firstWeekday }
        return calendar
    }

    var visibleEvents: [CalendarEvent] {
        let preferredAccount = defaultCalendarID(for: .event).flatMap { calendarsByID[$0]?.accountID }
        let priority = EventPipeline.calendarPriority(calendars: calendars, accounts: accounts, preferredAccountID: preferredAccount)
        return EventPipeline.visible(
            events, hiddenCalendarIDs: prefs.hiddenCalendarIDs, hideDuplicates: prefs.hideDuplicates, calendarPriority: priority
        )
    }

    var visibleReminders: [ReminderItem] {
        let live = reminders.filter { pendingCompletions[$0.id] == nil }
        return (live + pendingCompletions.values).filter { !prefs.hiddenCalendarIDs.contains($0.listID) }
    }

    var upcomingRange: DateInterval {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: prefs.agendaDays, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// True when the picked day is outside the upcoming range, so the agenda shows just that day.
    var agendaIsSingleDay: Bool {
        guard let selectedDay else { return false }
        return selectedDay < upcomingRange.start || selectedDay >= upcomingRange.end
    }

    var agenda: [AgendaDay] {
        let settings = AgendaSettings(showFreeTime: prefs.showFreeTime, workingHours: prefs.workingHours)
        let singleDay = agendaIsSingleDay ? selectedDay : nil
        return AgendaBuilder.build(
            events: visibleEvents, reminders: visibleReminders, now: now,
            firstDay: singleDay ?? now, dayCount: singleDay == nil ? prefs.agendaDays : 1,
            settings: settings, calendar: calendar
        )
    }

    var monthGrid: MonthGridModel { MonthGrid.make(containing: displayedMonth, calendar: calendar) }

    var dayMarkers: [Date: [ColorRef]] {
        DayMarkers.colors(
            days: monthGrid.days.map(\.date), events: visibleEvents, reminders: visibleReminders,
            calendarColors: calendarsByID.mapValues(\.color), calendar: calendar
        )
    }

    var monthTitle: String { AgendaFormatting.monthTitle(for: displayedMonth, calendar: calendar, locale: .current) }

    var menuBarTitle: MenuBarTitle? {
        guard prefs.showNextEvent, eventAccess == .granted else { return nil }
        return MenuBarTitleFormatter.title(
            events: visibleEvents, now: now,
            settings: MenuBarTitleSettings(window: prefs.menuBarWindow, maxTitleLength: prefs.maxTitleLength),
            calendar: calendar, locale: .current
        )
    }

    private var fetchInterval: DateInterval {
        let grid = monthGrid.interval
        let upcoming = upcomingRange
        return DateInterval(start: min(grid.start, upcoming.start), end: max(grid.end, upcoming.end))
    }

    // MARK: - Lookups

    func calendarInfo(_ id: String) -> CalendarInfo? { calendarsByID[id] }

    func account(forCalendarID id: String) -> AccountInfo? {
        guard let accountID = calendarsByID[id]?.accountID else { return nil }
        return accounts.first { $0.id == accountID }
    }

    func badge(forCalendarID id: String) -> String {
        account(forCalendarID: id).map(prefs.badge(for:)) ?? "?"
    }

    func writableCalendars(for kind: QuickAddKind) -> [CalendarInfo] {
        calendars.filter { $0.kind == kind.calendarKind && $0.isWritable }
    }

    /// Last used calendar/list, else the system default, else the first writable one.
    func defaultCalendarID(for kind: QuickAddKind) -> String? {
        let writable = writableCalendars(for: kind)
        let preferred = kind == .event
            ? prefs.lastEventCalendarID ?? service.defaultEventCalendarID()
            : prefs.lastReminderListID ?? service.defaultReminderListID()
        if let preferred, writable.contains(where: { $0.id == preferred }) { return preferred }
        return writable.first?.id
    }

    // MARK: - Navigation

    func showMonth(offset: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
    }

    func goToToday() {
        selectedDay = nil
        displayedMonth = now
    }

    func select(day: Date) {
        let start = calendar.startOfDay(for: day)
        selectedDay = start
        if !calendar.isDate(start, equalTo: displayedMonth, toGranularity: .month) { displayedMonth = start }
    }

    func moveSelection(byDays days: Int) {
        let base = selectedDay ?? calendar.startOfDay(for: now)
        if let target = calendar.date(byAdding: .day, value: days, to: base) { select(day: target) }
    }

    // MARK: - Actions

    func toggleReminder(_ item: ReminderItem) {
        do {
            if item.isCompleted {
                try service.setReminder(id: item.id, completed: false)
                pendingCompletions[item.id] = nil
                completionTokens[item.id] = nil
                var restored = item
                restored.isCompleted = false
                if !reminders.contains(where: { $0.id == item.id }) { reminders.append(restored) }
            } else {
                try service.setReminder(id: item.id, completed: true)
                var done = item
                done.isCompleted = true
                reminders.removeAll { $0.id == item.id }
                pendingCompletions[item.id] = done
                let token = UUID()
                completionTokens[item.id] = token
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    guard let self, self.completionTokens[item.id] == token else { return }
                    self.pendingCompletions[item.id] = nil
                    self.completionTokens[item.id] = nil
                }
            }
        } catch {
            showToast("Couldn't update reminder: \(error.localizedDescription)")
        }
    }

    func save(_ draft: QuickAddDraft, calendarID: String) throws {
        let title = draft.title.trimmingCharacters(in: .whitespaces)
        switch draft.kind {
        case .event:
            try service.saveEvent(title: title, start: draft.start, end: draft.end, isAllDay: draft.isAllDay, calendarID: calendarID)
            prefs.lastEventCalendarID = calendarID
        case .reminder:
            try service.saveReminder(title: title, due: draft.start, hasTime: draft.hasDueTime, listID: calendarID)
            prefs.lastReminderListID = calendarID
        }
        showToast("Added to \(calendarsByID[calendarID]?.title ?? "calendar")")
        popoverMode = .agenda
        select(day: draft.start)
        scheduleRefresh(delay: 0)
    }

    /// Ongoing or starting within 15 minutes, with a meeting link; earliest start wins.
    func currentMeeting() -> (event: CalendarEvent, link: MeetingLink)? {
        let horizon = now.addingTimeInterval(15 * 60)
        for event in visibleEvents where !event.isAllDay && event.start <= horizon && event.end > now {
            if let link = MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes) {
                return (event, link)
            }
        }
        return nil
    }

    func join(_ link: MeetingLink) {
        MeetingLauncher.open(link, preferNativeApp: prefs.openMeetingsInApp)
    }

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func applyShortcuts() {
        var failures = Set<HotKeyCenter.Action>()
        if !HotKeyCenter.shared.register(.quickAdd, combo: prefs.quickAddShortcut) { failures.insert(.quickAdd) }
        if !HotKeyCenter.shared.register(.joinMeeting, combo: prefs.joinMeetingShortcut) { failures.insert(.joinMeeting) }
        hotKeyFailures = failures
    }

    func openSettings() { onOpenSettings?() }
}
```

- [ ] **Step 2: Create `Sources/BetterThanDato/StatusItemController.swift`**

```swift
import AppKit
import DatoCore
import Observation
import SwiftUI

/// Owns the menu bar item and the popover. Re-renders the title whenever the model changes.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let model: AppModel
    private let prefs: PreferencesStore
    private var renderedDay = 0

    init(model: AppModel, prefs: PreferencesStore) {
        self.model = model
        self.prefs = prefs
        super.init()

        let hosting = NSHostingController(rootView: PopoverView().environment(model).environment(prefs))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self

        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        observeModel()
    }

    func show(mode: PopoverMode) {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            model.goToToday()
            model.scheduleRefresh(delay: 0)
        }
        model.popoverMode = mode
        NSApp.activate()
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
    }

    func close() {
        popover.performClose(nil)
    }

    @objc private func togglePopover() {
        if popover.isShown { close() } else { show(mode: .agenda) }
    }

    func popoverDidClose(_ notification: Notification) {
        model.popoverMode = .agenda
    }

    /// withObservationTracking fires once per change, so re-arm after every render.
    private func observeModel() {
        withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeModel() }
        }
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let day = model.calendar.component(.day, from: model.now)
        if day != renderedDay {
            button.image = CalendarIconRenderer.image(day: day)
            renderedDay = day
        }
        popover.behavior = model.isPinned ? .applicationDefined : .transient

        guard let title = model.menuBarTitle else {
            button.title = ""
            button.imagePosition = .imageOnly
            return
        }
        button.imagePosition = .imageLeading
        if prefs.showColorDot, let color = model.calendarInfo(title.event.calendarID)?.color {
            let font = NSFont.menuBarFont(ofSize: 0)
            let text = NSMutableAttributedString(string: "● ", attributes: [.font: font, .foregroundColor: NSColor(color)])
            text.append(NSAttributedString(string: title.text, attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
            button.attributedTitle = text
        } else {
            button.title = title.text
        }
    }
}
```

- [ ] **Step 3: Create `Sources/BetterThanDato/Views/PopoverView.swift`**

```swift
import DatoCore
import SwiftUI

struct PopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if model.eventAccess != .granted {
                PermissionView()
            } else if model.popoverMode == .quickAdd {
                QuickAddView()
            } else {
                AgendaScreen()
            }
            Divider()
            FooterView()
        }
        .frame(width: 360)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(text: toast).padding(.bottom, 44)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.toast)
    }
}

struct FooterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.popoverMode = .quickAdd
            } label: {
                Label("New", systemImage: "plus")
            }
            .keyboardShortcut("n")
            .disabled(model.eventAccess != .granted)

            if model.eventAccess == .granted && model.reminderAccess == .denied {
                Button("Reminders off") { model.openSettings() }
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 4)
            .transition(.opacity)
    }
}

struct PermissionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            if model.eventAccess == .notDetermined {
                Text("Better Than Dato needs access to your calendars and reminders to show your schedule.")
                    .multilineTextAlignment(.center)
                Button("Grant Access") {
                    Task { await model.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Calendar access is off. Turn on Better Than Dato in System Settings → Privacy & Security → Calendars.")
                    .multilineTextAlignment(.center)
                Button("Open System Settings") { SystemSettingsLink.open(.calendars) }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct AccountBadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.secondary.opacity(0.18)))
    }
}
```

`PopoverView` references `AgendaScreen` (Task 10) and `QuickAddView` (Task 11). To build this task on its own, add temporary stubs at the bottom of `PopoverView.swift`, which Tasks 10 and 11 delete:

```swift
// Replaced in Task 10.
struct AgendaScreen: View {
    var body: some View { Text("Agenda").padding(40) }
}

// Replaced in Task 11.
struct QuickAddView: View {
    var body: some View { Text("Quick add").padding(40) }
}
```

- [ ] **Step 4: Replace `Sources/BetterThanDato/AppDelegate.swift`**

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prefs: PreferencesStore!
    private var model: AppModel!
    private var statusController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        prefs = PreferencesStore()
        model = AppModel(service: CalendarService(), prefs: prefs)
        statusController = StatusItemController(model: model, prefs: prefs)

        HotKeyCenter.shared.setHandler(for: .quickAdd) { [weak self] in
            self?.statusController.show(mode: .quickAdd)
        }
        HotKeyCenter.shared.setHandler(for: .joinMeeting) { [weak self] in
            self?.joinCurrentMeeting()
        }
        model.applyShortcuts()
        model.start()
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
```

- [ ] **Step 5: Build, run and verify manually**

Run: `scripts/run.sh`
Expected:
1. Clicking the icon shows the popover with "Grant Access" (first run). Clicking it shows the macOS Calendar and Reminders prompts.
2. After granting, the popover shows the "Agenda" stub, and within a second the menu bar shows the next event today, e.g. `📅 Standup · in 12m` (or just the icon if nothing is left today).
3. ⌥⌘N opens the popover showing the "Quick add" stub.

- [ ] **Step 6: Commit**

```bash
git add Sources/BetterThanDato
git commit -m "feat(app): app model, live menu bar title and popover shell"
```

---

### Task 10: Agenda screen — header, month grid, agenda list, rows, keyboard

**Files:**
- Create: `Sources/BetterThanDato/Views/AgendaScreen.swift`, `MonthGridView.swift`, `AgendaListView.swift`, `EventRowView.swift`, `ReminderRowView.swift`
- Modify: `Sources/BetterThanDato/Views/PopoverView.swift` — delete the `AgendaScreen` stub.

**Interfaces:**
- Consumes: `AppModel` (Task 9), `AccountBadgeView`, DatoCore formatting.
- Produces: `AgendaScreen`, `HeaderView`, `MonthGridView`, `DayCellView`, `AgendaListView`, `DayContentView`, `DayHeaderView`, `EventRowView(event:day:)`, `EventDetailView(event:link:)`, `ReminderRowView(item:showDate:)`, `FreeRowView(interval:)`.

- [ ] **Step 1: Create `Views/AgendaScreen.swift`**

```swift
import DatoCore
import SwiftUI

struct AgendaScreen: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            MonthGridView()
                .padding(.bottom, 6)
            Divider()
            AgendaListView()
                .frame(height: 330)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(phases: .down) { press in handle(press) }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        let command = press.modifiers.contains(.command)
        switch press.key {
        case .leftArrow: command ? model.showMonth(offset: -1) : model.moveSelection(byDays: -1)
        case .rightArrow: command ? model.showMonth(offset: 1) : model.moveSelection(byDays: 1)
        case .upArrow: model.moveSelection(byDays: -7)
        case .downArrow: model.moveSelection(byDays: 7)
        case "t" where !command: model.goToToday()
        default: return .ignored
        }
        return .handled
    }
}

struct HeaderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Text(model.monthTitle)
                .font(.headline)
            Spacer()
            Button { model.showMonth(offset: -1) } label: { Image(systemName: "chevron.left") }
                .help("Previous month (⌘←)")
            Button("Today") { model.goToToday() }
                .help("Today (T)")
            Button { model.showMonth(offset: 1) } label: { Image(systemName: "chevron.right") }
                .help("Next month (⌘→)")
            Button { model.isPinned.toggle() } label: { Image(systemName: model.isPinned ? "pin.fill" : "pin") }
                .help("Keep open (⌘P)")
                .keyboardShortcut("p")
            Button { model.openSettings() } label: { Image(systemName: "gearshape") }
                .help("Settings (⌘,)")
                .keyboardShortcut(",")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}
```

- [ ] **Step 2: Create `Views/MonthGridView.swift`**

```swift
import DatoCore
import SwiftUI

struct MonthGridView: View {
    @Environment(AppModel.self) private var model
    @Environment(PreferencesStore.self) private var prefs

    var body: some View {
        let grid = model.monthGrid
        let markers = model.dayMarkers
        let today = model.calendar.startOfDay(for: model.now)

        VStack(spacing: 2) {
            HStack(spacing: 0) {
                if prefs.showWeekNumbers { Color.clear.frame(width: 22, height: 1) }
                ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(grid.weeks) { week in
                HStack(spacing: 0) {
                    if prefs.showWeekNumbers {
                        Text("\(week.weekNumber)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(width: 22)
                    }
                    ForEach(week.days) { day in
                        DayCellView(
                            day: day,
                            isToday: day.date == today,
                            isSelected: day.date == model.selectedDay,
                            dots: markers[day.date] ?? []
                        )
                        .onTapGesture { model.select(day: day.date) }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
}

struct DayCellView: View {
    let day: MonthGridDay
    let isToday: Bool
    let isSelected: Bool
    let dots: [ColorRef]

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day.dayNumber)")
                .font(.callout.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : day.isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.6))
                .frame(width: 26, height: 26)
                .background {
                    if isToday {
                        Circle().fill(Color.accentColor)
                    } else if isSelected {
                        Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
            HStack(spacing: 2) {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                    Circle().fill(Color(color)).frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 3: Create `Views/AgendaListView.swift`**

```swift
import DatoCore
import SwiftUI

struct AgendaListView: View {
    @Environment(AppModel.self) private var model
    @State private var showEarlier = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if model.agendaIsSingleDay {
                        Button("← Back to upcoming") { model.selectedDay = nil }
                            .buttonStyle(.link)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    ForEach(model.agenda) { day in
                        Section {
                            DayContentView(day: day, showEarlier: $showEarlier)
                        } header: {
                            DayHeaderView(date: day.date).id(day.date)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: model.selectedDay) { _, day in
                guard let day else { return }
                withAnimation { proxy.scrollTo(model.calendar.startOfDay(for: day), anchor: .top) }
            }
        }
    }
}

struct DayHeaderView: View {
    let date: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        Text(AgendaFormatting.dayTitle(for: date, now: model.now, calendar: model.calendar, locale: .current))
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
    }
}

struct DayContentView: View {
    let day: AgendaDay
    @Binding var showEarlier: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        if !day.overdue.isEmpty {
            Text("Overdue")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            ForEach(day.overdue) { ReminderRowView(item: $0, showDate: true) }
        }
        if !day.earlierEvents.isEmpty {
            Button(showEarlier ? "Hide earlier" : "Show \(day.earlierEvents.count) earlier") { showEarlier.toggle() }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            if showEarlier {
                ForEach(day.earlierEvents) { EventRowView(event: $0, day: day.date).opacity(0.55) }
            }
        }
        ForEach(day.entries) { entry in
            switch entry {
            case .event(let event): EventRowView(event: event, day: day.date)
            case .reminder(let reminder): ReminderRowView(item: reminder)
            case .free(let interval): FreeRowView(interval: interval)
            }
        }
        if day.entries.isEmpty && model.calendar.isDate(day.date, inSameDayAs: model.now) {
            Text("Nothing else today")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
    }
}
```

- [ ] **Step 4: Create `Views/EventRowView.swift`**

```swift
import AppKit
import DatoCore
import SwiftUI

struct EventRowView: View {
    let event: CalendarEvent
    let day: Date
    @Environment(AppModel.self) private var model
    @State private var expanded = false

    var body: some View {
        let link = MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes)
        let ongoing = !event.isAllDay && event.start <= model.now && event.end > model.now
        let joinable = link != nil && !event.isAllDay && event.end > model.now
            && event.start.timeIntervalSince(model.now) <= 15 * 60
        let subtitle = link?.provider.displayName ?? event.location

        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(model.calendarInfo(event.calendarID)?.color ?? .gray))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(AgendaFormatting.timeRange(for: event, on: day, calendar: model.calendar, locale: .current))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    AccountBadgeView(text: model.badge(forCalendarID: event.calendarID))
                        .help(model.account(forCalendarID: event.calendarID)?.title ?? "")
                }
                Text(event.title)
                    .lineLimit(expanded ? nil : 1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if expanded {
                    EventDetailView(event: event, link: link)
                }
            }
            if joinable, let link {
                Button("Join") { model.join(link) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 12)
        .background(ongoing ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }
    }
}

struct EventDetailView: View {
    let event: CalendarEvent
    let link: MeetingLink?
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(intervalText)
                .font(.caption)
            if let calendar = model.calendarInfo(event.calendarID) {
                Text([calendar.title, model.account(forCalendarID: event.calendarID)?.title].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse").font(.caption)
            }
            if let url = event.url {
                Link(url.absoluteString, destination: url).font(.caption).lineLimit(1)
            }
            if event.attendeeCount > 0 {
                Label("\(event.attendeeCount) attendees", systemImage: "person.2").font(.caption)
            }
            if let notes = event.notes.map({ AgendaFormatting.plainNotes($0, limit: 500) }), !notes.isEmpty {
                Text(Self.linkified(notes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack {
                if let link {
                    Button("Join") { model.join(link) }
                    Button("Copy link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link.url.absoluteString, forType: .string)
                        model.showToast("Link copied")
                    }
                }
                Button("Open in Calendar") { CalendarAppLauncher.open(eventIdentifier: event.eventIdentifier) }
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    private var intervalText: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = event.isAllDay ? .none : .short
        return formatter.string(from: event.start, to: event.end)
    }

    static func linkified(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return attributed }
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url,
                  let range = Range(match.range, in: text),
                  let attributedRange = Range(range, in: attributed) else { continue }
            attributed[attributedRange].link = url
        }
        return attributed
    }
}
```

- [ ] **Step 5: Create `Views/ReminderRowView.swift`**

```swift
import DatoCore
import SwiftUI

struct ReminderRowView: View {
    let item: ReminderItem
    /// Overdue rows show the due date instead of just the time.
    var showDate = false
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                model.toggleReminder(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color(model.calendarInfo(item.listID)?.color ?? .gray))
            }
            .buttonStyle(.plain)
            .help(item.isCompleted ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 2) {
                if let when = whenText {
                    Text(when)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(showDate ? Color.red : Color.secondary)
                }
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            AccountBadgeView(text: model.badge(forCalendarID: item.listID))
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 12)
        .opacity(item.isCompleted ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: item.isCompleted)
    }

    private var whenText: String? {
        let time = item.hasTime ? AgendaFormatting.time(item.due, calendar: model.calendar, locale: .current) : nil
        guard showDate else { return time }
        let date = AgendaFormatting.shortDate(item.due, calendar: model.calendar, locale: .current)
        return [date, time].compactMap { $0 }.joined(separator: " ")
    }
}

struct FreeRowView: View {
    let interval: DateInterval
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer")
                .font(.caption2)
                .frame(width: 3)
            Text("Free · \(RelativeTime.duration(minutes: Int(interval.duration / 60)))")
                .font(.caption)
            Text("\(time(interval.start))–\(time(interval.end))")
                .font(.caption)
                .monospacedDigit()
            Spacer()
        }
        .foregroundStyle(.tertiary)
        .padding(.vertical, 3)
        .padding(.horizontal, 12)
    }

    private func time(_ date: Date) -> String {
        AgendaFormatting.time(date, calendar: model.calendar, locale: .current)
    }
}
```

- [ ] **Step 6: Delete the `AgendaScreen` stub from `PopoverView.swift`**

Remove these lines from the bottom of `Sources/BetterThanDato/Views/PopoverView.swift`:
```swift
// Replaced in Task 10.
struct AgendaScreen: View {
    var body: some View { Text("Agenda").padding(40) }
}
```

- [ ] **Step 7: Build, run and verify manually**

Run: `scripts/run.sh`
Expected:
1. Popover shows month header, 6-row grid with today filled, colored dots under days with events.
2. Agenda lists Today/Tomorrow/… with color bars and account badges; events from different accounts are interleaved by time.
3. Clicking an event expands details; "Open in Calendar" opens Calendar.app.
4. Clicking a day in the grid scrolls to it; a day beyond 7 days shows "← Back to upcoming".
5. Arrow keys move the selection, ⌘←/⌘→ change month, T returns to today, ⌘P toggles pin.
6. Reminders due today appear with a circle; overdue reminders appear under "Overdue".

- [ ] **Step 8: Commit**

```bash
git add Sources/BetterThanDato/Views
git commit -m "feat(app): popover month grid, merged agenda, event details and keyboard nav"
```

---

### Task 11: Quick add

**Files:**
- Create: `Sources/BetterThanDato/Views/QuickAddView.swift`
- Modify: `Sources/BetterThanDato/Views/PopoverView.swift` — delete the `QuickAddView` stub.

**Interfaces:**
- Consumes: `QuickAddParser`, `QuickAddDraft`, `AppModel.save(_:calendarID:)`, `AppModel.defaultCalendarID(for:)`, `AppModel.writableCalendars(for:)`, `AppModel.accounts`, `PreferencesStore.badge(for:)`.
- Produces: `QuickAddView`.

- [ ] **Step 1: Create `Views/QuickAddView.swift`**

```swift
import DatoCore
import SwiftUI

/// One line of text parsed live into an editable form. Fields the user edits by hand
/// stop being overwritten by further typing.
struct QuickAddView: View {
    @Environment(AppModel.self) private var model
    @Environment(PreferencesStore.self) private var prefs
    @State private var text = ""
    @State private var draft = QuickAddParser(calendar: .current, now: Date()).parse("", calendars: [])
    @State private var overridden: Set<Field> = []
    @State private var errorMessage: String?
    @State private var isSaving = false
    @FocusState private var inputFocused: Bool

    enum Field: Hashable {
        case kind, title, calendar, allDay, start, end, dueTime
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New").font(.headline)
            TextField("Lunch with Sara tomorrow 1pm 1h #work", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
            Text("Start with ! for a reminder · #name picks a calendar")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            form

            if let token = draft.unmatchedCalendarToken {
                Text("No calendar matches #\(token), using the default.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if model.writableCalendars(for: draft.kind).isEmpty {
                Text(draft.kind == .event ? "No writable calendars." : "No writable reminder lists.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { model.popoverMode = .agenda }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(12)
        .onAppear {
            reparse()
            inputFocused = true
        }
        .onChange(of: text) { reparse() }
    }

    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                label("Type")
                Picker("", selection: kindBinding) {
                    Text("Event").tag(QuickAddKind.event)
                    Text("Reminder").tag(QuickAddKind.reminder)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            GridRow {
                label("Title")
                TextField("Title", text: binding(\.title, .title))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }
            GridRow {
                label(draft.kind == .event ? "Calendar" : "List")
                calendarPicker
            }
            if draft.kind == .event {
                GridRow {
                    label("All day")
                    Toggle("", isOn: binding(\.isAllDay, .allDay)).labelsHidden()
                }
                GridRow {
                    label("Starts")
                    DatePicker("", selection: startBinding,
                               displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }
                if !draft.isAllDay {
                    GridRow {
                        label("Ends")
                        DatePicker("", selection: binding(\.end, .end), in: draft.start...,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                }
            } else {
                GridRow {
                    label("Due")
                    DatePicker("", selection: binding(\.start, .start),
                               displayedComponents: draft.hasDueTime ? [.date, .hourAndMinute] : [.date])
                        .labelsHidden()
                }
                GridRow {
                    label("Time")
                    Toggle("", isOn: binding(\.hasDueTime, .dueTime)).labelsHidden()
                }
            }
        }
        .font(.callout)
    }

    private var calendarPicker: some View {
        Picker("", selection: calendarBinding) {
            ForEach(model.accounts) { account in
                let calendars = model.writableCalendars(for: draft.kind).filter { $0.accountID == account.id }
                if !calendars.isEmpty {
                    Section("\(account.title) [\(prefs.badge(for: account))]") {
                        ForEach(calendars) { calendar in
                            Text(calendar.title).tag(Optional(calendar.id))
                        }
                    }
                }
            }
        }
        .labelsHidden()
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
    }

    // MARK: - Bindings

    private func binding<Value>(_ keyPath: WritableKeyPath<QuickAddDraft, Value>, _ field: Field) -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = $0; overridden.insert(field) }
        )
    }

    private var kindBinding: Binding<QuickAddKind> {
        Binding(
            get: { draft.kind },
            set: { kind in
                draft.kind = kind
                overridden.insert(.kind)
                reparse()
            }
        )
    }

    /// Moving the start keeps the event's length, like Calendar.app.
    private var startBinding: Binding<Date> {
        Binding(
            get: { draft.start },
            set: { newStart in
                let length = draft.end.timeIntervalSince(draft.start)
                draft.start = newStart
                draft.end = newStart.addingTimeInterval(length)
                overridden.insert(.start)
            }
        )
    }

    private var calendarBinding: Binding<String?> {
        Binding(
            get: { resolvedCalendarID },
            set: { draft.calendarID = $0; overridden.insert(.calendar) }
        )
    }

    // MARK: - Parsing and saving

    private var resolvedCalendarID: String? { draft.calendarID ?? model.defaultCalendarID(for: draft.kind) }

    private var canSave: Bool {
        !isSaving && !draft.title.trimmingCharacters(in: .whitespaces).isEmpty && resolvedCalendarID != nil
    }

    private func reparse() {
        let parser = QuickAddParser(calendar: model.calendar, now: Date())
        let parsed = parser.parse(text, calendars: model.calendars, forcedKind: overridden.contains(.kind) ? draft.kind : nil)
        var next = draft
        if !overridden.contains(.kind) { next.kind = parsed.kind }
        if !overridden.contains(.title) { next.title = parsed.title }
        if !overridden.contains(.calendar) { next.calendarID = parsed.calendarID }
        next.unmatchedCalendarToken = parsed.unmatchedCalendarToken
        if !overridden.contains(.allDay) { next.isAllDay = parsed.isAllDay }
        if !overridden.contains(.start) { next.start = parsed.start }
        if !overridden.contains(.end) {
            let parsedLength = parsed.end.timeIntervalSince(parsed.start)
            next.end = overridden.contains(.start) ? next.start.addingTimeInterval(parsedLength) : parsed.end
        }
        if !overridden.contains(.dueTime) { next.hasDueTime = parsed.hasDueTime }
        next.hasExplicitDate = parsed.hasExplicitDate
        draft = next
    }

    private func save() {
        guard canSave, let calendarID = resolvedCalendarID else { return }
        isSaving = true
        do {
            try model.save(draft, calendarID: calendarID)
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
```

- [ ] **Step 2: Delete the `QuickAddView` stub from `PopoverView.swift`**

Remove these lines from the bottom of `Sources/BetterThanDato/Views/PopoverView.swift`:
```swift
// Replaced in Task 11.
struct QuickAddView: View {
    var body: some View { Text("Quick add").padding(40) }
}
```

- [ ] **Step 3: Build, run and verify manually**

Run: `scripts/run.sh`
Expected:
1. ⌥⌘N from any app opens the popover with the text field focused.
2. Typing `Lunch with Sara tomorrow 1pm 1h #work` fills Title "Lunch with Sara", the Work calendar, tomorrow 13:00–14:00.
3. Picking a different calendar by hand, then typing more, keeps the picked calendar.
4. Return adds the event; toast "Added to …"; the agenda scrolls to tomorrow and shows it with the right account badge.
5. `!Call mom tomorrow at 6pm` creates a reminder with a due time; it appears in the agenda with a checkbox; clicking the checkbox strikes it through and it disappears after ~2 s; clicking again within 2 s restores it.
6. Esc returns to the agenda without saving.

- [ ] **Step 4: Commit**

```bash
git add Sources/BetterThanDato/Views
git commit -m "feat(app): natural-language quick add for events and reminders"
```

---

### Task 12: Settings window, launch at login, QA checklist

**Files:**
- Create: `Sources/BetterThanDato/Views/SettingsView.swift`, `Sources/BetterThanDato/Views/SettingsWindowController.swift`, `docs/qa-checklist.md`
- Modify (replace whole file): `Sources/BetterThanDato/AppDelegate.swift`

**Interfaces:**
- Consumes: `PreferencesStore`, `AppModel` (`accounts`, `calendars`, `eventAccess`, `reminderAccess`, `hotKeyFailures`, `applyShortcuts()`, `scheduleRefresh(delay:)`, `requestAccess()`), `LoginItem`, `SystemSettingsLink`, `KeyCombo`, `AccountBadge`.
- Produces: `SettingsWindowController.show(model:prefs:)`, `SettingsView`, `ShortcutRecorder`.

- [ ] **Step 1: Create `Views/SettingsView.swift`**

```swift
import AppKit
import Carbon
import DatoCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView().tabItem { Label("General", systemImage: "gearshape") }
            MenuBarSettingsView().tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            CalendarSettingsView().tabItem { Label("Calendar", systemImage: "calendar") }
            AccountsSettingsView().tabItem { Label("Accounts", systemImage: "person.2") }
            ShortcutsSettingsView().tabItem { Label("Shortcuts", systemImage: "keyboard") }
            PermissionsSettingsView().tabItem { Label("Permissions", systemImage: "lock") }
        }
        .frame(width: 500, height: 440)
    }
}

struct GeneralSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { enabled in
                    do {
                        try LoginItem.set(enabled)
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                    }
                    launchAtLogin = LoginItem.isEnabled
                }
            ))
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            Toggle("Hide duplicate events across accounts", isOn: $prefs.hideDuplicates)
            Toggle("Open meetings in desktop apps (Zoom, Teams)", isOn: $prefs.openMeetingsInApp)
            Toggle("Show free time today", isOn: $prefs.showFreeTime)
            if prefs.showFreeTime {
                Picker("Working hours start", selection: $prefs.workingHoursStart) {
                    ForEach(Self.halfHours, id: \.self) { Text(Self.label($0)).tag($0) }
                }
                Picker("Working hours end", selection: $prefs.workingHoursEnd) {
                    ForEach(Self.halfHours, id: \.self) { Text(Self.label($0)).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
    }

    static let halfHours = Array(stride(from: 0, through: 24 * 60, by: 30))

    static func label(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

struct MenuBarSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Toggle("Show next event in the menu bar", isOn: $prefs.showNextEvent)
            Picker("Show it when it starts within", selection: $prefs.menuBarWindow) {
                Text("30 minutes").tag(MenuBarWindow.thirtyMinutes)
                Text("1 hour").tag(MenuBarWindow.oneHour)
                Text("3 hours").tag(MenuBarWindow.threeHours)
                Text("The rest of today").tag(MenuBarWindow.restOfToday)
                Text("Any time").tag(MenuBarWindow.always)
            }
            .disabled(!prefs.showNextEvent)
            Stepper("Maximum title length: \(prefs.maxTitleLength)", value: $prefs.maxTitleLength, in: 15...40)
            Toggle("Show calendar color dot", isOn: $prefs.showColorDot)
        }
        .formStyle(.grouped)
    }
}

struct CalendarSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Picker("First day of week", selection: $prefs.firstWeekday) {
                Text("System").tag(0)
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
                Text("Saturday").tag(7)
            }
            Toggle("Show week numbers", isOn: $prefs.showWeekNumbers)
            Picker("Upcoming days in the agenda", selection: $prefs.agendaDays) {
                ForEach([1, 3, 7, 14], id: \.self) { Text("\($0)").tag($0) }
            }
        }
        .formStyle(.grouped)
        .onChange(of: prefs.agendaDays) { model.scheduleRefresh(delay: 0) }
        .onChange(of: prefs.firstWeekday) { model.scheduleRefresh(delay: 0) }
    }
}

struct AccountsSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            if model.accounts.isEmpty {
                Text("No accounts yet. Add accounts in System Settings → Internet Accounts.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.accounts) { account in
                Section {
                    TextField("Badge", text: badgeBinding(account), prompt: Text(AccountBadge.defaultLabel(for: account.title)))
                    ForEach(model.calendars.filter { $0.accountID == account.id }) { calendar in
                        Toggle(isOn: visibleBinding(calendar)) {
                            HStack(spacing: 6) {
                                Circle().fill(Color(calendar.color)).frame(width: 8, height: 8)
                                Text(calendar.title)
                                if calendar.kind == .reminders {
                                    Text("Reminders").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(account.title)
                        AccountBadgeView(text: prefs.badge(for: account))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func badgeBinding(_ account: AccountInfo) -> Binding<String> {
        Binding(
            get: { prefs.accountBadges[account.id] ?? "" },
            set: { prefs.accountBadges[account.id] = String($0.prefix(2)) }
        )
    }

    private func visibleBinding(_ calendar: CalendarInfo) -> Binding<Bool> {
        Binding(
            get: { !prefs.hiddenCalendarIDs.contains(calendar.id) },
            set: { visible in
                if visible { prefs.hiddenCalendarIDs.remove(calendar.id) } else { prefs.hiddenCalendarIDs.insert(calendar.id) }
            }
        )
    }
}

struct ShortcutsSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            LabeledContent("Quick add") {
                ShortcutRecorder(combo: $prefs.quickAddShortcut)
            }
            if model.hotKeyFailures.contains(.quickAdd) {
                Text("Shortcut unavailable — another app uses it.").font(.caption).foregroundStyle(.red)
            }
            LabeledContent("Join current meeting") {
                ShortcutRecorder(combo: $prefs.joinMeetingShortcut)
            }
            if model.hotKeyFailures.contains(.joinMeeting) {
                Text("Shortcut unavailable — another app uses it.").font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onChange(of: prefs.quickAddShortcut) { model.applyShortcuts() }
        .onChange(of: prefs.joinMeetingShortcut) { model.applyShortcuts() }
    }
}

/// Click, then press a key combination with ⌘, ⌥ or ⌃. Esc cancels.
struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(recording ? "Press shortcut…" : combo?.displayString ?? "None") {
                recording ? stop() : start()
            }
            .frame(minWidth: 110)
            if combo != nil {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
            } else if let newCombo = KeyCombo(event: event) {
                combo = newCombo
                stop()
            }
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

struct PermissionsSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            LabeledContent("Calendars") { status(model.eventAccess) }
            LabeledContent("Reminders") { status(model.reminderAccess) }
            if model.eventAccess == .notDetermined || model.reminderAccess == .notDetermined {
                Button("Grant access") { Task { await model.requestAccess() } }
            }
            Button("Open Calendars privacy settings") { SystemSettingsLink.open(.calendars) }
            Button("Open Reminders privacy settings") { SystemSettingsLink.open(.reminders) }
        }
        .formStyle(.grouped)
        .onAppear { model.scheduleRefresh(delay: 0) }
    }

    @ViewBuilder
    private func status(_ state: AccessState) -> some View {
        switch state {
        case .granted: Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .denied: Label("Denied", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case .notDetermined: Label("Not asked yet", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 2: Create `Views/SettingsWindowController.swift`**

```swift
import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(model: AppModel, prefs: PreferencesStore) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView().environment(model).environment(prefs))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Better Than Dato Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
```

- [ ] **Step 3: Replace `Sources/BetterThanDato/AppDelegate.swift`**

```swift
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
```

- [ ] **Step 4: Create `docs/qa-checklist.md`**

```markdown
# Manual QA checklist

Run `scripts/run.sh` (or `scripts/install.sh` for launch-at-login checks).

## Permissions
- [ ] Fresh install: popover shows "Grant Access"; granting shows the Calendar and Reminders prompts.
- [ ] Deny Calendars in System Settings → popover explains and "Open System Settings" opens the right pane.
- [ ] Deny only Reminders → agenda works, footer shows "Reminders off".

## Menu bar
- [ ] Next event today shows `Title · in Xm`; the countdown ticks every minute.
- [ ] During an event: `Title · Xm left`; 10 minutes before the next event it switches to that event.
- [ ] Nothing left today → icon only. Icon date changes after midnight.
- [ ] Settings → Menu Bar: window, max length and color dot all take effect immediately.

## Popover
- [ ] Events from at least two accounts appear interleaved, each with its calendar color bar and account badge.
- [ ] The same meeting on two accounts appears once (Hide duplicates on) and twice (off).
- [ ] Month dots match the agenda; clicking a day scrolls; a far day shows "Back to upcoming".
- [ ] Arrow keys / ⌘← ⌘→ / T / ⌘P / ⌘, / ⌘N work.
- [ ] Expanding an event shows notes as plain text with clickable links; "Open in Calendar" works.
- [ ] Free-time rows appear today inside working hours only.

## Quick add
- [ ] ⌥⌘N opens quick add from another app, text field focused.
- [ ] `Lunch tomorrow 1pm 1h #<calendar>` → right calendar, 13:00–14:00.
- [ ] Event added to a non-default account appears with that account's badge.
- [ ] `!Pay rent friday` → reminder due Friday (date only).
- [ ] Unknown `#foo` shows the warning and uses the default calendar.

## Reminders
- [ ] Checkbox completes; row fades after ~2 s; clicking again within 2 s undoes.
- [ ] Overdue reminders appear under "Overdue" on Today.

## Meetings
- [ ] Zoom/Meet/Teams event within 15 minutes shows "Join"; Zoom opens in the Zoom app if installed.
- [ ] ⌥⌘J joins the current meeting; with none, the popover shows "No meeting to join".

## System
- [ ] Sleep/wake refreshes the title.
- [ ] Changing the time zone refreshes times.
- [ ] Launch at login toggle survives a logout/login (installed build in ~/Applications).
```

- [ ] **Step 5: Build, run and verify manually**

Run: `scripts/test.sh && scripts/run.sh`
Expected: all tests pass; ⌘, (or the gear) opens Settings; every tab works; hiding a calendar removes its events immediately; changing a badge updates rows; recording a new quick-add shortcut works and the old one stops working.

- [ ] **Step 6: Commit**

```bash
git add Sources/BetterThanDato docs/qa-checklist.md
git commit -m "feat(app): settings window, shortcut recorder, launch at login and QA checklist"
```
