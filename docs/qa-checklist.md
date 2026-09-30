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

## Meeting alerts
- [ ] Settings → General → Meeting alerts → Preview alert: covers every screen, Return joins, Esc dismisses.
- [ ] A real meeting fires the alert at its start (or the chosen lead time); only once per meeting.
- [ ] "Only for events with a video call link" skips events without one; turning alerts off stops them.
- [ ] The alert appears over a full-screen app.

## Appearance and updates
- [ ] Settings → Appearance slider moves the popover from system glass to solid.
- [ ] Overdue reminders are readable on a busy background (red badge, neutral date).
- [ ] A build from `scripts/release.sh` shows "Check for Updates…"; a local build shows the GitHub note.
- [ ] Install release N, publish N+1, Check for Updates installs and relaunches it.

## System
- [ ] Sleep/wake refreshes the title.
- [ ] Changing the time zone refreshes times.
- [ ] Launch at login toggle survives a logout/login (installed build in ~/Applications).
