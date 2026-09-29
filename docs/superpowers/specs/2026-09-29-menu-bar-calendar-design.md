# BetterThanDato — Menu Bar Calendar (v1 Design)

Date: 2026-09-29
Status: Approved direction (user delegated remaining decisions)

## 1. Goal

A native macOS menu bar app that shows the next event at a glance and, on click,
a popover with a month overview plus an agenda of upcoming events and reminders
from **every account configured in macOS**. Fast quick-add of events/reminders to
a chosen calendar. A deliberately small subset of Dato.

### In scope (v1)

1. Menu bar item: calendar-page icon with today's date + next event title and relative time.
2. Popover: month grid with per-day dots + upcoming agenda (events and reminders), grouped by day.
3. All accounts from macOS (EventKit) merged, each marked with a calendar color bar and an account badge.
4. Quick add: natural-language line that pre-fills an editable form; events or reminders; per-calendar targeting.
5. Reminders: due/overdue reminders in the agenda, completable in place; creatable from quick add.
6. Quality-of-life: one-click meeting join, global hotkeys (quick add, join meeting), duplicate-event hiding,
   today's free-time gaps, keyboard navigation, launch at login.

### Non-goals (v1)

World clocks / time-travel slider, floating clocks, hourly chime, date calculator, Apple Shortcuts actions,
full-screen meeting alerts, editing/deleting existing events (use "Open in Calendar"), HTML-rendered notes
(notes are shown as plain text), in-app account sign-in/sync (accounts come from System Settings → Internet Accounts),
App Store/sandbox distribution, localization beyond system date/time formatting.

## 2. Platform & Tooling Constraints

- macOS 14+ minimum (EventKit full-access APIs, `@Observable`). Developer machine: macOS 27, Swift 6.3.3.
- **No Xcode required.** Swift Package Manager + Command Line Tools. Verified: SwiftUI, AppKit, EventKit, Carbon,
  ServiceManagement and the Observation macro all compile under CLT.
- `swift test` with Swift Testing works under CLT only with extra search paths
  (`Library/Developer/Frameworks` and `Library/Developer/usr/lib` inside the CLT). Wrapped in `scripts/test.sh`.
- The app must run from a real `.app` bundle (Info.plist usage strings are required for TCC prompts).
  `scripts/build-app.sh` assembles and signs it.
- Signing: `SIGN_IDENTITY` env var if set, otherwise ad-hoc (`-`). With ad-hoc signing, macOS may re-prompt for
  Calendar/Reminders access after each rebuild — acceptable in dev; fix by creating a self-signed code-signing
  certificate and exporting `SIGN_IDENTITY`.
- Not sandboxed, no hardened runtime (personal app; avoids entitlement setup).

## 3. Architecture

Two SwiftPM targets plus tests:

```
Package.swift
Sources/
  DatoCore/            # pure Swift, Foundation only. No AppKit/SwiftUI/EventKit.
  BetterThanDato/      # executable: AppKit + SwiftUI + EventKit + Carbon
Tests/
  DatoCoreTests/       # Swift Testing
Resources/Info.plist
scripts/{build-app.sh, run.sh, test.sh, install.sh}
```

`DatoCore` holds every piece of logic with a real decision in it, operating on value types, so it is fully
unit-testable with an injected `now`, `Calendar` and `TimeZone`. The app target is a thin adapter layer.

### 3.1 DatoCore units

| Unit | Responsibility | Input → Output |
|---|---|---|
| `Models` | `CalendarEvent`, `ReminderItem`, `CalendarInfo`, `AccountInfo`, `MeetingLink` value types (Sendable) | — |
| `MenuBarTitleFormatter` | Choose which event to show and format `"Standup · in 12m"` | events, now, settings → `String?` |
| `AgendaBuilder` | Filter hidden calendars, dedupe, group by day, attach overdue reminders, compute free slots | events, reminders, now, settings → `[AgendaDay]` |
| `Deduplicator` | Hide duplicate events across calendars | events, calendar priority → events |
| `FreeTimeCalculator` | Gaps ≥ 30 min between now and end of working hours, today only | events, now, working hours → `[DateInterval]` |
| `MonthGrid` | 6×7 day grid, week numbers, week-start handling | month, calendar, firstWeekday → `MonthGridModel` |
| `DayMarkers` | Up to 3 distinct color dots per day | events, reminders, days → `[Date: [ColorRef]]` |
| `QuickAddParser` | Parse the quick-add sentence | text, now, calendar, known calendars → `QuickAddDraft` |
| `MeetingLinkDetector` | Find meeting URL + provider; produce native-app URL | url/location/notes → `MeetingLink?` |
| `RelativeTimeFormatter` | `"in 5m"`, `"in 1h 20m"`, `"at 15:30"`, `"8m left"` | dates, now, locale → `String` |

### 3.2 App-target units

| Unit | Responsibility |
|---|---|
| `AppDelegate` / `main.swift` | `NSApplication` bootstrap, `.accessory` activation policy (no Dock icon) |
| `CalendarService` (`@MainActor`) | The only type importing EventKit: authorization, fetch events/reminders for a range, map to DatoCore value types, save event/reminder, toggle reminder completion, observe `EKEventStoreChanged`. |
| `AppModel` (`@Observable @MainActor`) | Single source of UI state: accounts, calendars, events, reminders, displayed month, selected day, `now`, auth state, transient toast. Owns refresh scheduling. |
| `PreferencesStore` (`@Observable`) | UserDefaults-backed settings (see §7) |
| `StatusItemController` | `NSStatusItem` title/icon rendering, `NSPopover` (transient; `.applicationDefined` when pinned), open modes (agenda / quick add) |
| `CalendarIconRenderer` | Draws the template calendar-page icon with the day number |
| `HotKeyCenter` | Carbon `RegisterEventHotKey` wrapper; two actions: quickAdd, joinMeeting |
| `MeetingLauncher` | Opens `MeetingLink`, preferring installed desktop apps (Zoom `us.zoom.xos`, Teams) |
| `LoginItem` | `SMAppService.mainApp` register/unregister |
| Views | `PopoverView` (Header, `MonthGridView`, `AgendaListView`, `EventRowView`, `ReminderRowView`, `EventDetailView`, `QuickAddView`, `PermissionView`, Footer), `SettingsView` (tabs) |

**Why `NSStatusItem` + `NSPopover` instead of SwiftUI `MenuBarExtra`:** `MenuBarExtra` cannot be opened
programmatically (needed for the global quick-add hotkey), cannot be pinned open, and offers little control over
the title image/text composition.

### 3.3 Data flow

```
EventKit store ──(EKEventStoreChanged, debounced 0.5s)──▶ CalendarService.fetch(range)
      │                                                        │ maps EK* → DatoCore value types
      ▼                                                        ▼
  save/complete ◀── Views ◀── AppModel (state) ── DatoCore builders (agenda, grid, title)
                                   ▲
      minute tick, day change, wake, clock/timezone change, popover open
```

- Fetch window: from the first day of the displayed month grid through
  `max(grid end, today + agendaDays)`. Refetched on month navigation and all triggers above.
- Minute tick: a timer fired at each minute boundary updates `now` → menu bar title + agenda "now" state (no refetch).
- Reminders fetch uses the callback API bridged to `async`; `EKReminder` is mapped to `ReminderItem` inside the callback
  (never crosses concurrency domains).

## 4. Menu Bar Item

**Icon:** template image (adapts to light/dark/tinted menu bars) — a 16×16 calendar page with the day-of-month number.
Updates on day change.

**Title:** `<title> · <relative>` after the icon; optional small calendar-color dot before the title (setting, default off).

**Event candidates:** non-all-day events on visible calendars, not cancelled, not declined by the current user,
after deduplication.

**Selection rule** (`MenuBarTitleFormatter`):
1. If an upcoming event starts within 10 minutes → show it: `in 8m` (`now` when < 1 minute).
2. Else if any event is ongoing → the ongoing event ending soonest: `8m left` / `1h 5m left`.
3. Else the next upcoming event, if its start falls inside the display window setting
   (30m / 1h / 3h / **rest of today (default)** / always).
4. Else no title — icon only.

**Relative time:** < 60 min → `in 45m`; < 6 h → `in 2h 15m`; otherwise `at 15:30` (locale time format; prefixed with
weekday if not today, e.g. `Thu 09:00`, only possible with window = always).

**Truncation:** title truncated to `maxTitleLength` characters (default 25, range 15–40) with `…`.

## 5. Popover (≈ 360 pt wide, max height 620 pt, scrolls)

### 5.1 Header
Month + year · `‹` `Today` `›` · pin toggle · gear (Settings).

### 5.2 Month grid
- 6 rows × 7 columns; first weekday from settings (default: system locale). Optional week-number column.
- Today: filled accent circle. Selected day: accent ring. Days outside the month: secondary color.
- Up to 3 dots under each day in the calendar colors of that day's events and reminders (first 3 distinct colors
  in time order).
- Click a day → selects it. If within the agenda range, the agenda scrolls to it; otherwise the agenda shows only
  that day with a "Back to upcoming" button.

### 5.3 Agenda
- Range: today through `agendaDays` (options 1 / 3 / **7** / 14). Section headers: "Today", "Tomorrow",
  then `EEE, MMM d`. Empty days omitted; Today always shown ("Nothing else today").
- **Overdue** block at the top of Today: incomplete reminders due before today (oldest first).
- Today's events that already ended are collapsed into a "Show N earlier" row.
- Ordering within a day: all-day events, then all-day reminders, then timed items by start time.
- **Event row:** 3 pt color bar (calendar color) · time range (`09:00–09:30`, or `All day`) · title (1 line) ·
  secondary line with location or meeting provider name · account badge at trailing edge · **Join** button when the
  event has a meeting link and is ongoing or starts within 15 minutes. Ongoing events get a subtle tinted background.
- **Reminder row:** circular checkbox in list color · title · due time if set · account badge. Clicking the checkbox
  completes it (strikethrough, fades out after 2 s; clicking again within that window undoes).
- **Free time rows** (Today only, setting default on): `Free · 1h 30m` between events inside working hours
  (default 09:00–18:00), only gaps ≥ 30 minutes and only from `now` onward.
- **Account badge:** 1–2 characters or an emoji in a neutral capsule, one per EventKit source (account).
  Default = first letter of the account title, editable in Settings. Together with the calendar color bar this
  distinguishes accounts at a glance.

### 5.4 Event detail (click a row to expand inline; click again to collapse)
Full date/time, calendar name + account, location, URL, attendee count, notes as plain text (first 500 characters,
links clickable). Buttons: **Join**, **Open in Calendar** (`ical://ekevent/<eventIdentifier>?method=show&options=more`,
falling back to opening Calendar.app), **Copy meeting link**.

### 5.5 Footer
`+ New` (quick add) · permission warnings if any · Quit.

### 5.6 Keyboard (while popover is key)
`←/→` previous/next day, `↑/↓` previous/next week, `⌘←/⌘→` previous/next month, `T` today, `⌘N` quick add,
`⌘,` settings, `⌘P` pin, `Esc` closes quick add, otherwise closes popover.

## 6. Quick Add

**Entry points:** footer `+ New`, `⌘N` in popover, global hotkey **⌥⌘N** (opens the popover directly in quick-add mode
with the text field focused).

**UI:** one text field on top; below it a live form: Kind (`Event | Reminder`), Title, Calendar/List picker
(grouped by account, with badges; only calendars that allow modifications), All-day toggle, Start, End
(events) / Due date + "has time" toggle (reminders). Once the user edits a form field by hand, further typing no
longer overwrites that field. `Return` saves, `Esc` cancels. After saving: toast "Added to Work", back to the agenda,
scrolled to the new item's day.

**Parser rules** (`QuickAddParser`, pure, deterministic given `now`/`Calendar`):
1. Leading `!` → Reminder; otherwise Event.
2. `#token` → calendar (events) or list (reminders): case-insensitive; exact title > prefix > substring;
   ties → first in calendar order. Token removed from title. No match → form shows "No calendar matches #token"
   and uses the default.
3. Duration (events): `for 45m`, `45m`, `45 min`, `1h`, `1.5h`, `1h30m`, `90 minutes` → removed from title.
4. Date/time: `NSDataDetector(.date)`; matched text removed from title. A time range (`2-3pm`) sets the end time.
   The detector sometimes absorbs title words ("Dinner friday 7pm" is one match), so non-date words are peeled off
   the match edges while the remaining phrase still resolves to the same date/time.
   The match counts as having a time if the matched text contains a clock time (`\d{1,2}(:\d{2})?\s?(am|pm)`,
   `\d{1,2}:\d{2}`, `noon`, `midnight`); otherwise it is date-only.
5. Resulting times:
   - Event, date + time → start at that time; end = explicit range end, else start + duration, else start + 30 min.
   - Event, date only → all-day event.
   - Event, no date → today, start at the next half-hour boundary, 30 min.
   - Reminder, date + time → due at that time. Date only → due that day (no time). No date → due today (no time).
6. Title = remaining text, whitespace-collapsed. Empty title → Save disabled.

**Defaults:** calendar/list = last used (persisted); fallback to `defaultCalendarForNewEvents` /
`defaultCalendarForNewReminders()`.

## 7. Settings (standalone window, tabs)

- **General:** Launch at login · Hide duplicate events (on) · Open meetings in desktop apps (on) · Show free time (on)
  + working hours.
- **Menu bar:** Show next event (on) · Display window (rest of today) · Max title length (25) · Calendar color dot (off).
- **Calendar:** First day of week (System / Sunday / Monday / Saturday) · Week numbers (off) · Agenda days (7).
- **Accounts:** per account: badge label editor; per calendar and reminders list: visibility toggle.
- **Shortcuts:** Quick add (⌥⌘N), Join meeting (⌥⌘J): record / clear. Recorder = field that captures the next
  keyDown with ≥ 1 modifier (⌘, ⌥, ⌃).
- **Permissions:** Calendar / Reminders status, "Grant access", "Open System Settings"
  (`x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars` / `...Privacy_Reminders`).

Persisted in `UserDefaults.standard`; hidden calendars stored as a set of `calendarIdentifier`; account badges keyed by
`EKSource.sourceIdentifier`.

## 8. Meeting Join

- `MeetingLinkDetector` scans `url`, then `location`, then `notes`; first match wins.
- Providers: Zoom (`*.zoom.us/j|my|w/…`), Google Meet (`meet.google.com/abc-defg-hij`), Microsoft Teams
  (`teams.microsoft.com/l/meetup-join/…`, `teams.live.com/meet/…`), Webex (`*.webex.com/…`),
  FaceTime (`facetime.apple.com/join…`), Slack huddles (`app.slack.com/huddle/…`).
- Native-app rewrite (setting on and app installed): Zoom → `zoommtg://zoom.us/join?confno=<id>&pwd=<pwd>`;
  Teams → `msteams:` + path. Otherwise open the https URL.
- Global hotkey **⌥⌘J** joins the "current meeting": ongoing or starting within 15 minutes, with a link; earliest
  start wins. None → popover opens with toast "No meeting to join".

## 9. Deduplication

Two events are duplicates when normalized title (trimmed, case-folded), start, end and all-day flag are equal.
Keep the copy whose calendar comes first in priority order: the default quick-add calendar's account first, then
EventKit source order, then calendar title. Toggle in Settings (default on). Dedup applies to agenda, dots and menu bar.

## 10. Error Handling

| Situation | Behavior |
|---|---|
| Calendar access not determined | Popover shows `PermissionView` with "Grant access" (calls `requestFullAccessToEvents`) |
| Calendar denied / write-only | `PermissionView` explains + "Open System Settings"; menu bar shows icon only |
| Reminders denied | App works; reminders hidden; footer warning links to Settings → Permissions |
| No writable calendars | Quick add shows "No writable calendars" and disables Save |
| Save fails | Inline error in the quick-add form with the EventKit message; user input kept |
| Reminder complete/undo fails | Toast with the EventKit message; row unchanged |
| Unmatched `#token` | Form warning, default calendar used |
| Meeting app launch fails | Fall back to https URL in default browser |
| Hotkey registration fails (taken) | Settings shows "Shortcut unavailable" next to the recorder |
| Launch-at-login fails | Toggle reverts; message shows the `SMAppService` error |

No crashes on EventKit returning nil fields (title, calendar, dates): mapping skips malformed items.

## 11. Testing

- **Unit (Swift Testing, `scripts/test.sh`):** all DatoCore units with fixed `now`, `TimeZone` (incl. a DST-change
  month in `America/New_York`) and `Locale(identifier: "en_GB")` (24-hour output). Exception: `QuickAddParser` date
  tests use `Calendar.current` + `Date()` because `NSDataDetector` resolves "tomorrow" against the real clock. Priority cases:
  - `QuickAddParser`: each rule in §6 incl. `!`, `#` matching precedence, durations, ranges, date-only vs time.
  - `MenuBarTitleFormatter`: every branch of the selection rule, window settings, truncation, declined/cancelled excluded.
  - `AgendaBuilder`: grouping, overdue, ended-today collapse count, ordering, free slots, hidden calendars.
  - `Deduplicator`, `MonthGrid` (Sunday/Monday/Saturday starts, week numbers, 6-row months), `MeetingLinkDetector`
    (each provider + native rewrite), `RelativeTimeFormatter`.
- **App layer:** thin adapters over DatoCore; verified manually with the QA checklist (EventKit needs a real bundle + TCC).
- **Manual QA checklist** (kept in `docs/qa-checklist.md`): first-launch permission flow, menu bar title across an
  event's start/end, multiple accounts visible with badges, quick add to a non-default account, reminder complete/undo,
  join via row and hotkey, sleep/wake refresh, month navigation, launch at login.

## 12. Build & Run

- `scripts/test.sh` — `swift test` with CLT framework paths.
- `scripts/build-app.sh [debug|release]` — `swift build`, assemble `build/BetterThanDato.app`
  (`Contents/MacOS`, `Contents/Info.plist`), `codesign --force --sign "${SIGN_IDENTITY:--}"`.
- `scripts/run.sh` — build debug app, quit running instance, `open` it.
- `scripts/install.sh` — release build copied to `~/Applications` (stable path for launch at login).
- Info.plist: `CFBundleIdentifier=com.ahmede.BetterThanDato`, `LSUIElement=true`, `LSMinimumSystemVersion=14.0`,
  `NSCalendarsFullAccessUsageDescription`, `NSRemindersFullAccessUsageDescription`, `CFBundleShortVersionString=0.1.0`.

## 13. Build Order (milestones)

1. Package skeleton, scripts, `.app` bundling, status item with icon.
2. DatoCore: models, relative time, menu bar title formatter (+ tests); CalendarService auth + fetch; live title.
3. DatoCore: month grid, day markers, agenda builder, dedup, free time (+ tests); popover with grid + agenda + detail.
4. DatoCore: quick-add parser (+ tests); quick add UI + save.
5. Reminders: fetch, rows, overdue, complete/undo, quick add reminders.
6. DatoCore: meeting link detector (+ tests); Join buttons, MeetingLauncher, HotKeyCenter (⌥⌘N, ⌥⌘J).
7. Settings window, accounts badges/visibility, launch at login, keyboard navigation, QA checklist pass.

## 14. Later (not v1)

Meeting-start notification with a Join action, world clocks, editing events in place, Shortcuts actions,
floating clock.
