# Developer guide

Everything you need to build, run, test and extend Better Than Dato. Read
[ARCHITECTURE.md](ARCHITECTURE.md) first for how the pieces fit together.

## Setup

You need macOS 14 or later and a Swift 6 toolchain. **Xcode is optional**; the Command Line Tools are enough:

```bash
xcode-select --install
git clone https://github.com/AhmedEzzat12/better-than-dato.git
cd better-than-dato
scripts/test.sh     # run the unit tests
scripts/run.sh      # build a debug app and launch it from build/
```

On first launch click the calendar icon in the menu bar → **Grant Access**. Optional tools: `gh` (releases),
`ffmpeg` (demo video).

## Scripts

Always use the scripts rather than bare `swift build`: they apply the toolchain fixes described below.

| Script | What it does |
|---|---|
| `scripts/test.sh [--filter Name]` | Runs the DatoCore unit tests (Swift Testing) |
| `scripts/run.sh` | Debug build → `build/BetterThanDato.app`, quits the running copy, launches the new one |
| `scripts/build-app.sh [debug\|release]` | Builds and assembles the signed `.app` (release = universal) |
| `scripts/install.sh` | Release build into `~/Applications` (stable path, needed for launch at login) |
| `scripts/update-from-source.sh [--main]` | Pull, build the latest release tag (or `main`) in a temp checkout, replace the installed app |
| `scripts/release.sh <version>` | Publish a GitHub release with auto-update feed (maintainers) |
| `scripts/make-demo-video.sh` | Re-render `docs/demo.mp4` and `docs/demo.gif` |
| `swift scripts/make-icon.swift` | Re-render `Resources/AppIcon.icns` and `docs/icon.png` |

## Project layout

```
Sources/DatoCore/          Pure logic — start here for any behavior change
  Models.swift             CalendarEvent, ReminderItem, CalendarInfo, AccountInfo, ColorRef
  MenuBarTitleFormatter    which event the menu bar shows, and how
  EventPipeline            hidden calendars, declined/cancelled, cross-account dedupe
  AgendaBuilder            days, overdue reminders, ordering, free time
  QuickAddParser           natural-language quick add
  MeetingAlertPlanner      when full-screen alerts fire
  MeetingLinkDetector      Zoom/Meet/Teams/… links and native-app URLs
  …                        MonthGrid, DayMarkers, FreeTimeCalculator, RelativeTime, AgendaFormatting, AccountBadge
Sources/BetterThanDato/    The app
  AppModel.swift           all UI state; derived values come from DatoCore
  StatusItemController     menu bar item + popover
  Services/                EventKit (CalendarService), settings, hotkeys, updates, system links
  Views/                   SwiftUI: popover screens, rows, quick add, settings, meeting alert
Tests/DatoCoreTests/       one test file per DatoCore unit; Fixture.swift has shared helpers
Tools/DemoVideo/           motion-graphics demo renderer (not shipped)
scripts/                   build, test, release and install tooling
```

## Toolchain quirks (Command Line Tools only)

These are already handled by the scripts; know them so they don't surprise you.

- **SwiftUI `@State` needs Xcode on the macOS 27 SDK.** There, SwiftUI's property wrappers are compiler macros
  whose plugin ships only with Xcode. `scripts/sdk-env.sh` builds against the newest macOS 26 SDK the Command Line
  Tools still include. If you see `external macro implementation type 'SwiftUIMacros.StateMacro' could not be
  found`, you ran `swift build` without sourcing it: `source scripts/sdk-env.sh && swift build`.
- **Swift Testing needs extra paths** with the Command Line Tools (framework, macro plugin and runtime library).
  `scripts/test.sh` passes them.
- **Incremental builds can hide those errors.** If something builds for you but not for someone else, try a clean
  build: `rm -rf .build && scripts/test.sh`.
- **Permission prompts after every rebuild.** Builds are ad-hoc signed, so macOS sees each one as a new app and
  asks for Calendar/Reminders access again. To avoid it, create a code-signing certificate once (Keychain Access →
  Certificate Assistant → Create a Certificate → type *Code Signing*) and export
  `SIGN_IDENTITY="<certificate name>"` before running the scripts.

## Coding guidelines

- **Decisions go in DatoCore, with tests.** If code decides *what* to show or *when* something happens, it belongs
  in `Sources/DatoCore` as a pure function or value type, with a test in `Tests/DatoCoreTests`. The app layer
  should only fetch, store and render.
- **Never read the clock or `Calendar.current` inside DatoCore.** Take `now: Date` and `calendar: Calendar` as
  parameters. Tests use `Fixture.calendar` (Berlin time, Monday-first, `en_GB`) and fixed dates, including a DST
  week.
- **Write the test first.** Run it, watch it fail for the right reason, then implement.
- **Keep EventKit inside `CalendarService`.** Map to DatoCore value types there; nothing else imports EventKit.
- **Prefer native macOS behavior** over custom imitations (see the opacity decision in ARCHITECTURE.md).
- **Match the surrounding code**: small focused files, doc comments that explain *why*, no dead code.
- **Use fictional sample data** in tests, docs and the demo (`jane@bluebird.com`, `alex@northwind.io`), never real
  addresses.

## Tutorial 1: add a meeting provider

Say you want a Join button for [Whereby](https://whereby.com) links (`https://whereby.com/<room>`).

**1. Write the failing test** in `Tests/DatoCoreTests/MeetingLinkDetectorTests.swift`:

```swift
@Test func whereby() {
    let link = MeetingLinkDetector.detect(in: "Room: https://whereby.com/team-sync")
    #expect(link?.provider == .whereby)
    #expect(link?.provider.displayName == "Whereby")
}
```

Run `scripts/test.sh --filter MeetingLinkDetector`; it fails because `.whereby` doesn't exist.

**2. Implement** in `Sources/DatoCore/MeetingLinkDetector.swift`: add the case and its display name to
`MeetingProvider`, then a branch in `classify(_:)` next to the other providers:

```swift
if host == "whereby.com", path.count > 1 {
    return MeetingLink(provider: .whereby, url: url, nativeURL: nil)
}
```

**3. Run the tests** again; they pass.

That's all. The app needs no changes: event rows, the Join button, ⌥⌘J and the full-screen alert all go through
`MeetingLinkDetector`. Finish by adding Whereby to the provider list in the README.

## Tutorial 2: add a setting

Say you want a "Show all-day events in the agenda" option.

**1. Logic and test in DatoCore.** Add a field to `AgendaSettings` in `AgendaBuilder.swift`
(`public var showAllDayEvents: Bool`, defaulting to `true` in `init`) and skip all-day events in `build` when it's
off. Add a test to `AgendaBuilderTests.swift` that builds a day with an all-day and a timed event and expects only
the timed one when the setting is off.

**2. Persist it** in `Sources/BetterThanDato/Services/PreferencesStore.swift`, following the existing pattern:

```swift
static let showAllDayEvents = "showAllDayEvents"                       // in Key
var showAllDayEvents: Bool { didSet { defaults.set(showAllDayEvents, forKey: Key.showAllDayEvents) } }
showAllDayEvents = defaults.object(forKey: Key.showAllDayEvents) as? Bool ?? true   // in init
```

**3. Use it** where `AppModel.agenda` creates `AgendaSettings`:

```swift
let settings = AgendaSettings(
    showFreeTime: prefs.showFreeTime, workingHours: prefs.workingHours, showAllDayEvents: prefs.showAllDayEvents
)
```

Because `AppModel.agenda` is a computed property and `PreferencesStore` is `@Observable`, the popover updates as
soon as the value changes. There's nothing to refresh by hand.

**4. Add the control** in `Views/SettingsView.swift` (the Calendar tab fits):

```swift
Toggle("Show all-day events in the agenda", isOn: $prefs.showAllDayEvents)
```

**5. Check it in the app** with `scripts/run.sh`, and add a line to `docs/qa-checklist.md`.

If a setting changes the **date range** the app fetches (like *Upcoming days*), also call
`model.scheduleRefresh(delay: 0)` from the view's `onChange`, as `CalendarSettingsView` does.

## Testing and debugging

- **Unit tests:** `scripts/test.sh`. Every DatoCore unit has its own test file. Quick-add tests use the real clock
  because `NSDataDetector` resolves "tomorrow" against it.
- **Manual QA:** `docs/qa-checklist.md` lists what to click through before a release.
- **Logs:** run the binary directly to see `print` output, or stream system logs:
  ```bash
  build/BetterThanDato.app/Contents/MacOS/BetterThanDato
  log stream --predicate 'process == "BetterThanDato"'
  ```
- **Re-test the permission flow** by resetting the app's privacy grants:
  ```bash
  tccutil reset Calendar com.ahmede.BetterThanDato
  tccutil reset Reminders com.ahmede.BetterThanDato
  ```
- **Preview the meeting alert** any time from Settings → General → Meeting alerts → *Preview alert*.

## Releasing (maintainers)

```bash
scripts/release.sh 1.2.0
```

It checks that `gh` is signed in and your commits are pushed, runs the tests, builds the universal app with
version 1.2.0 (build number = commit count), signs the update with the Sparkle key in your login keychain
(created on first run), writes `appcast.xml` and publishes GitHub release `v1.2.0`. Installed copies update
themselves. **Back up the signing key** once (`generate_keys -x`, see the README); losing it means installed copies
can't verify future updates.

If the UI changed, re-render the demo first with `scripts/make-demo-video.sh` and commit it.
