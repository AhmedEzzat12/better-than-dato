<p align="center"><img src="docs/icon.png" width="128" alt="Better Than Dato icon"></p>

# Better Than Dato

A small, native macOS menu bar calendar. It shows your next event at a glance, and one click opens a month
overview with a merged agenda of every calendar and reminder list on your Mac. Inspired by
[Dato](https://sindresorhus.com/dato), minus the features I never used.

![Better Than Dato demo: menu bar countdown, month overview, quick add and the full-screen meeting alert](docs/demo.gif)

[Watch the full-quality video](docs/demo.mp4) (32 s, 1080p).

## Features

- **Menu bar:** today's date icon plus the next event: `Standup · in 12m`, `Focus · 20m left`.
- **Popover:** month grid with per-day color dots and an agenda for the next 7 days (configurable).
- **Every account, one list:** iCloud, Google, Exchange, CalDAV — whatever is set up in
  *System Settings → Internet Accounts*. Each row shows its calendar color and an account badge.
- **Quick add (⌥⌘N from anywhere):** type `Lunch with Sara tomorrow 1pm 1h #work` and check the pre-filled form.
  Start with `!` for a reminder (`!Pay rent friday`).
- **Reminders:** due and overdue reminders sit in the agenda; tick them off in place (with a 2-second undo).
- **Meetings:** a Join button for Zoom, Google Meet, Teams, Webex, FaceTime and Slack links; ⌥⌘J joins the
  current meeting, opening Zoom/Teams in their desktop apps when installed.
- **Full-screen meeting alerts:** when a meeting starts (or 1/2/5 minutes before), an alert covers every
  screen with a big Join button — Return joins, Esc dismisses. Optional, with a video-calls-only filter.
- **Also:** hides the same meeting invited to two accounts, shows free time between today's meetings,
  keyboard navigation, launch at login, automatic updates. The popover uses macOS's native Liquid Glass; to make
  it more opaque use *System Settings → Accessibility → Display → Reduce Transparency* (or the Liquid Glass
  option in *Appearance* where available).

## Install

**Recommended** — one command in Terminal installs the latest release into Applications and opens it:

```bash
curl -fsSL https://raw.githubusercontent.com/AhmedEzzat12/better-than-dato/main/scripts/install-latest.sh | bash
```

Run the same command again any time to reinstall. After that the app updates itself
(Settings → General → Updates). Then click the calendar icon in the menu bar → **Grant Access**.

**Or build from source** — for Macs where downloaded apps are blocked by an organization's profile, or to
run unreleased changes. Needs the Command Line Tools (`xcode-select --install`):

```bash
git clone https://github.com/AhmedEzzat12/better-than-dato.git
cd better-than-dato
scripts/update-from-source.sh          # latest release
scripts/update-from-source.sh --main   # or: newest code on main
```

It updates the local repo, builds in a temporary checkout (your working copy is never touched), removes
any installed copy, installs the new build into `~/Applications` and opens it. It cleans up after itself —
the temporary build is deleted even if the build fails or you press Ctrl-C — so each run is a full build
(about a minute). Your
settings are kept. Source builds don't update themselves — run the script again to update. Each rebuild is a
new app to macOS, so it asks for Calendar/Reminders access again unless you set `SIGN_IDENTITY` (see
[Releasing](#releasing)).

**Or download manually:** get `BetterThanDato.zip` from the [latest release](../../releases/latest), unzip it and
move `BetterThanDato.app` to Applications. The first launch will be blocked — see below.

### "BetterThanDato.app" Not Opened / "Apple could not verify…"

The app is free and open source but not notarized by Apple (that needs a paid developer account), so macOS
blocks copies downloaded in a browser. Any **one** of these fixes it, and you only need it once — updates
installed by the app itself aren't blocked:

1. **System Settings:** click **Done** on the warning, open **System Settings → Privacy & Security**, scroll to
   *Security*, click **Open Anyway** next to "BetterThanDato.app was blocked", and confirm with your password.
2. **Terminal:** remove the download's quarantine flag, then open the app normally:
   ```bash
   xattr -dr com.apple.quarantine /Applications/BetterThanDato.app
   ```
3. **Reinstall with the one-command installer above** — `curl` downloads aren't quarantined, so the warning never
   appears.

If **Open Anyway** is missing or *Allow applications from* says "configured by a profile", your Mac is managed
by an organization; options 2 and 3 still work unless the administrator blocks unsigned apps entirely. If they
don't, [build from source](#install) with `scripts/update-from-source.sh`.

## Requirements

- macOS 14 Sonoma or later, including macOS 26 Tahoe and macOS 27. Release builds are universal
  (Apple silicon + Intel).
- To build: a Swift 6 toolchain. Xcode is **not** required — the Command Line Tools are enough
  (`xcode-select --install`).

## Build and run

```bash
scripts/update-from-source.sh   # pull, build the latest release, replace the installed app
scripts/run.sh          # debug build, relaunches the app from build/
scripts/install.sh      # release build into ~/Applications (use this for launch at login)
scripts/test.sh         # unit tests (Swift Testing)
scripts/make-demo-video.sh      # regenerate docs/demo.mp4 and docs/demo.gif (needs ffmpeg)
```

The demo video is motion graphics, not a screen recording: `Tools/DemoVideo` draws each frame in SwiftUI from
sample data, using the app's real `DatoCore` logic for the menu bar title, month grid, agenda and quick-add
parsing. No permissions or personal data involved.

On first launch, click the menu bar icon → **Grant Access** and allow Calendars and Reminders.

> The app is ad-hoc signed, so macOS treats every rebuild as a new app and may ask for Calendar/Reminders
> access again. To avoid that, create a code-signing certificate in Keychain Access and build with
> `SIGN_IDENTITY="<certificate name>" scripts/install.sh`.

## Releasing

Releases are built and published from your Mac — no CI, nothing to pay for:

```bash
scripts/release.sh 1.2.0
```

It runs the tests, builds the universal app, signs the update with your Sparkle key (kept in the login
keychain, created on first run), writes `appcast.xml`, and creates GitHub release `v1.2.0` with both files.
Installed copies read `releases/latest/download/appcast.xml` and offer the update. Commit and push first;
the script refuses to release unpushed code.

- **Back up the signing key** once: `.build/sparkle-tools/*/bin/generate_keys -x ~/sparkle-key.txt`, then
  store it in a password manager. Without it, installed copies can't verify future updates.
- **Fewer permission prompts:** ad-hoc signed updates look like a new app to macOS, which asks for
  Calendar/Reminders access again. Create a code-signing certificate once (Keychain Access → Certificate
  Assistant → Create a Certificate → type *Code Signing*) and release with
  `SIGN_IDENTITY="<certificate name>" scripts/release.sh 1.2.0`. An Apple Developer ID ($99/year) would also
  remove the first-launch Gatekeeper step.
- The repository must be **public** for others to download releases and for updates to reach them.

## Quick add syntax

| You type | You get |
|---|---|
| `Focus block` | Event today at the next half hour, 30 minutes |
| `Review for 45m` / `Planning 1h30m` | Event with that duration |
| `Offsite tomorrow` | All-day event |
| `Workshop friday from 2pm to 4pm` | Event 14:00–16:00 on Friday |
| `Standup 9:30 #work` | Event in the calendar whose name matches `work` |
| `!Call mom tomorrow at 6pm` | Reminder with a due time |

Dates are parsed with Apple's `NSDataDetector` (English phrases). Anything you edit in the form by hand stays
put while you keep typing.

## Keyboard

| Key | Action |
|---|---|
| ⌥⌘N | Quick add (global) |
| ⌥⌘J | Join current meeting (global) |
| ← → ↑ ↓ | Move the selected day |
| ⌘← ⌘→ | Previous / next month |
| T | Today |
| ⌘N / ⌘, / ⌘P | New / Settings / Keep popover open |

Global shortcuts can be changed in Settings → Shortcuts.

## Project layout

```
Sources/DatoCore/        Pure Swift logic (menu bar title, agenda, month grid, quick-add parser, meeting links)
Sources/BetterThanDato/  AppKit status item, SwiftUI popover and settings, EventKit adapter
Tests/DatoCoreTests/     Unit tests for DatoCore
scripts/                 Build, run, install, test, and icon generation
docs/                    Design spec, implementation plan, QA checklist
```

All decisions the UI shows are made in `DatoCore`, which only depends on Foundation, so they're unit-tested
without EventKit. The app target is a thin layer that reads EventKit and renders.
