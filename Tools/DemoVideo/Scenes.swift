import AppKit
import DatoCore
import SwiftUI

let canvas = CGSize(width: 1920, height: 1080)
let accent = Color(hex: 0x0A7AFF)
/// Horizontal center of the app's menu bar item; the popover hangs from it.
let statusItemX: CGFloat = 1440

enum DemoAssets {
    static let icon = NSImage(contentsOfFile: "docs/icon.png") ?? NSImage()
}

// MARK: - Frame

struct DemoFrame: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        ZStack {
            DesktopScene(t: t, story: story)
            if t < Timeline.titleOut + 0.7 {
                TitleCard(t: t).opacity(1 - ramp(t, Timeline.titleOut, 0.6))
            }
            if t >= Timeline.endIn {
                EndCard(t: t).opacity(ramp(t, Timeline.endIn, 0.6))
            }
            CaptionOverlay(t: t)
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}

struct BrandBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0x6E8DFF), Color(hex: 0x3A2BC4)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct TitleCard: View {
    let t: Double

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 26) {
                Image(nsImage: DemoAssets.icon).resizable().frame(width: 230, height: 230)
                    .scaleEffect(0.82 + 0.18 * pop(t, 0.1, 0.7))
                    .opacity(ramp(t, 0.1, 0.35))
                Text("Better Than Dato")
                    .font(.system(size: 80, weight: .bold))
                    .opacity(ramp(t, 0.55)).offset(y: 22 * (1 - ramp(t, 0.55)))
                Text("A small, native menu bar calendar for macOS")
                    .font(.system(size: 34, weight: .medium))
                    .opacity(0.85 * ramp(t, 0.95)).offset(y: 22 * (1 - ramp(t, 0.95)))
            }
            .foregroundStyle(.white)
        }
    }
}

struct EndCard: View {
    let t: Double

    var body: some View {
        let start = Timeline.endIn
        ZStack {
            BrandBackground()
            VStack(spacing: 26) {
                Image(nsImage: DemoAssets.icon).resizable().frame(width: 170, height: 170)
                    .scaleEffect(0.85 + 0.15 * pop(t, start + 0.1, 0.6))
                Text("Better Than Dato").font(.system(size: 70, weight: .bold))
                Text("Free and open source · macOS 14 and later")
                    .font(.system(size: 30, weight: .medium)).opacity(0.85)
                // verbatim: a plain string literal is Markdown, which would turn the URL into a blue link.
                Text(verbatim: "curl -fsSL https://raw.githubusercontent.com/AhmedEzzat12/better-than-dato/main/scripts/install-latest.sh | bash")
                    .font(.system(size: 19, design: .monospaced))
                    .padding(.horizontal, 24).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))
                    .opacity(ramp(t, start + 0.8))
                Text("github.com/AhmedEzzat12/better-than-dato")
                    .font(.system(size: 28, weight: .semibold))
                    .opacity(ramp(t, start + 1.3))
            }
            .foregroundStyle(.white)
        }
    }
}

struct CaptionOverlay: View {
    let t: Double

    var body: some View {
        ZStack {
            ForEach(Array(Timeline.captions.enumerated()), id: \.offset) { _, caption in
                let visible = window(t, caption.start, caption.end)
                if visible > 0 {
                    Text(caption.text)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36).padding(.vertical, 17)
                        .background(Capsule().fill(Color.black.opacity(0.74)))
                        .opacity(visible)
                        .offset(y: 14 * (1 - visible))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 54)
    }
}

// MARK: - Desktop

struct DesktopScene: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let alert = window(t, Timeline.alertIn, Timeline.alertOut, fade: 0.4)
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Wallpaper()
                FakeWindow()
                MenuBar(t: t, story: story)
                MenuBarCallout(t: t, story: story)
                if t >= Timeline.popoverIn - 0.05 && t < Timeline.alertIn + 0.1 {
                    PopoverMock(t: t, story: story)
                }
                let settings = window(t, Timeline.settingsIn, Timeline.settingsOut, fade: 0.35)
                if settings > 0 {
                    SettingsMock(t: t, story: story)
                        .scaleEffect(1.45 * (0.94 + 0.06 * settings))
                        .opacity(settings)
                        .frame(width: canvas.width, height: canvas.height)
                }
            }
            .blur(radius: 24 * alert)
            Color.black.opacity(0.45 * alert)
            if alert > 0 {
                MeetingAlertMock(t: t, story: story)
                    .frame(width: canvas.width, height: canvas.height)
                    .opacity(alert)
                    .scaleEffect(0.94 + 0.06 * alert)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
    }
}

struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1D3B6E), Color(hex: 0x4B2A7B), Color(hex: 0xC2567A)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(Color(hex: 0x39C0ED).opacity(0.55)).frame(width: 900).blur(radius: 120).offset(x: -520, y: -260)
            Circle().fill(Color(hex: 0xFF9F6E).opacity(0.5)).frame(width: 800).blur(radius: 120).offset(x: 560, y: 320)
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

/// A generic app window, so the desktop looks lived-in.
struct FakeWindow: View {
    private let lineWidths: [CGFloat] = [520, 610, 440, 580, 300, 560, 480, 600, 380, 540]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { Circle().fill(Color(hex: $0)).frame(width: 13) }
            }
            .padding(14)
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.16)).frame(width: 300, height: 22)
                ForEach(lineWidths.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.08)).frame(width: lineWidths[index], height: 12)
                }
            }
            .padding(.horizontal, 40).padding(.top, 20)
            Spacer()
        }
        .frame(width: 900, height: 640, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.93)))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
        .offset(x: 160, y: 190)
    }
}

// MARK: - Menu bar

struct MenuBar: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let clock = RelativeTimeFormat.clock(story.now, story: story)
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.white.opacity(0.26)).frame(width: canvas.width, height: 36)
            HStack(spacing: 22) {
                Image(systemName: "applelogo").font(.system(size: 17, weight: .medium))
                Text("Finder").fontWeight(.bold)
                ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0) }
            }
            .font(.system(size: 15))
            .padding(.leading, 22)
            .frame(height: 36)
            StatusItem(t: t, story: story).position(x: statusItemX, y: 18)
            HStack(spacing: 20) {
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
                Text(clock).monospacedDigit()
            }
            .font(.system(size: 15, weight: .medium))
            .frame(width: canvas.width - 24, height: 36, alignment: .trailing)
        }
        .foregroundStyle(.white)
    }
}

enum RelativeTimeFormat {
    static func clock(_ date: Date, story: DemoStory) -> String {
        let formatter = DateFormatter()
        formatter.locale = story.locale
        formatter.calendar = story.calendar
        formatter.timeZone = story.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d h:mm a")
        return formatter.string(from: date)
    }

    static func date(_ date: Date, template: String, story: DemoStory) -> String {
        let formatter = DateFormatter()
        formatter.locale = story.locale
        formatter.calendar = story.calendar
        formatter.timeZone = story.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}

struct StatusItem: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let open = t >= Timeline.popoverIn && t < Timeline.alertIn
        let pulse = window(t, 3.6, Timeline.popoverIn) * (0.55 + 0.45 * sin(t * 5.5))
        HStack(spacing: 9.5) {
            MenuCalendarIcon(day: story.calendar.component(.day, from: story.now))
            Text(story.menuBarTitle).font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(open ? 0.3 : 0)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.95 * pulse), lineWidth: 2.5).padding(-6))
    }
}

/// A magnified copy of the menu bar item, hanging below it while the caption talks about it.
struct MenuBarCallout: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let visible = window(t, 3.5, Timeline.popoverIn - 0.2)
        if visible > 0 {
            VStack(spacing: 0) {
                Triangle().fill(Color.black.opacity(0.6)).frame(width: 28, height: 13)
                StatusItem(t: 0, story: story)
                    .scaleEffect(2.6)
                    .frame(width: 740, height: 116)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.6)))
            }
            .foregroundStyle(.white)
            .scaleEffect(0.9 + 0.1 * pop(t, 3.5, 0.45), anchor: .top)
            .opacity(visible)
            .position(x: statusItemX, y: 46 + 64.5)
        }
    }
}

struct MenuCalendarIcon: View {
    let day: Int

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3.5).stroke(Color.white, lineWidth: 1.6)
            Rectangle().fill(Color.white).frame(height: 4.5)
            Text("\(day)").font(.system(size: 10, weight: .bold)).padding(.top, 5)
        }
        .frame(width: 20, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 3.5))
    }
}

// MARK: - Popover

struct PopoverMock: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let appear = pop(t, Timeline.popoverIn, 0.4)
        let fadeOut = 1 - ramp(t, Timeline.alertIn - 0.35, 0.3)
        let quickAdd = window(t, Timeline.quickAddIn, Timeline.addPressed + 0.3, fade: 0.25)
        let toast = window(t, Timeline.addPressed + 0.35, Timeline.toastOut)
        VStack(spacing: 0) {
            Triangle().fill(Color(hex: 0xF6F6F8)).frame(width: 22, height: 10)
            ZStack(alignment: .top) {
                AgendaPanel(t: t, story: story).opacity(1 - quickAdd)
                if quickAdd > 0 { QuickAddPanel(t: t, story: story).opacity(quickAdd) }
            }
            .frame(width: 360, height: 610, alignment: .top)
            .background(Color(hex: 0xF6F6F8))
            .overlay(alignment: .bottom) {
                if toast > 0 {
                    Text("Added to Personal")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Color.white))
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                        .padding(.bottom, 52)
                        .opacity(toast)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        .scaleEffect(1.35 * (0.92 + 0.08 * appear), anchor: .top)
        .opacity(min(ramp(t, Timeline.popoverIn, 0.18), fadeOut))
        .offset(x: statusItemX - 180, y: 38)
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct BadgeMock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Capsule().fill(Color.secondary.opacity(0.18)))
    }
}

struct AgendaPanel: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let added = t >= Timeline.addPressed + 0.3
        let selected = added ? 1 : Timeline.selectedOffset(at: t)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(AgendaFormatting.monthTitle(for: story.now, calendar: story.calendar, locale: story.locale))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.left")
                Text("Today")
                Image(systemName: "chevron.right")
                Image(systemName: "pin")
                Image(systemName: "gearshape")
            }
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
            MonthGridMock(t: t, story: story, selectedOffset: selected, includeAdded: added)
                .padding(.bottom, 6)
            Divider()
            AgendaListMock(t: t, story: story, startOffset: selected, includeAdded: added)
                .frame(height: 318, alignment: .top)
                .clipped()
            Divider()
            HStack {
                Label("New", systemImage: "plus")
                Spacer()
                Text("Quit")
            }
            .font(.system(size: 13))
            .padding(.horizontal, 14).padding(.vertical, 9)
        }
    }
}

func reminders(at t: Double, story: DemoStory) -> [ReminderItem] {
    story.reminders.compactMap { item in
        guard item.id == story.overdueReminderID, t >= Timeline.reminderTick else { return item }
        if t >= Timeline.reminderGone { return nil }
        var done = item
        done.isCompleted = true
        return done
    }
}

struct MonthGridMock: View {
    let t: Double
    let story: DemoStory
    let selectedOffset: Int?
    let includeAdded: Bool

    var body: some View {
        let grid = MonthGrid.make(containing: story.now, calendar: story.calendar)
        let colors = Dictionary(uniqueKeysWithValues: story.calendars.map { ($0.id, $0.color) })
        let markers = DayMarkers.colors(
            days: grid.days.map(\.date), events: story.visibleEvents(includingAdded: includeAdded),
            reminders: reminders(at: t, story: story), calendarColors: colors, calendar: story.calendar
        )
        let today = story.day(0)
        let selected = selectedOffset.map { story.day($0) }
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            ForEach(grid.weeks) { week in
                HStack(spacing: 0) {
                    ForEach(week.days) { day in
                        VStack(spacing: 2) {
                            Text("\(day.dayNumber)")
                                .font(.system(size: 13, weight: day.date == today ? .bold : .regular))
                                .foregroundStyle(day.date == today ? Color.white : day.isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.55))
                                .frame(width: 26, height: 26)
                                .background {
                                    if day.date == today {
                                        Circle().fill(accent)
                                    } else if day.date == selected {
                                        Circle().strokeBorder(accent, lineWidth: 1.5)
                                    }
                                }
                            HStack(spacing: 2) {
                                ForEach(Array((markers[day.date] ?? []).enumerated()), id: \.offset) { _, color in
                                    Circle().fill(Color(color)).frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
}

struct AgendaListMock: View {
    let t: Double
    let story: DemoStory
    let startOffset: Int?
    let includeAdded: Bool

    var body: some View {
        let days = AgendaBuilder.build(
            events: story.visibleEvents(includingAdded: includeAdded), reminders: reminders(at: t, story: story),
            now: story.now, firstDay: story.now, dayCount: 7, settings: AgendaSettings(), calendar: story.calendar
        ).filter { day in startOffset.map { day.date >= story.day($0) } ?? true }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(days) { day in
                Text(AgendaFormatting.dayTitle(for: day.date, now: story.now, calendar: story.calendar, locale: story.locale))
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color.black.opacity(0.05))
                if !day.overdue.isEmpty {
                    Text("Overdue")
                        .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .padding(.horizontal, 12).padding(.top, 6)
                    ForEach(day.overdue) { ReminderRowMock(t: t, item: $0, story: story, showDate: true) }
                }
                if !day.earlierEvents.isEmpty {
                    Text("Show \(day.earlierEvents.count) earlier")
                        .font(.system(size: 11)).foregroundStyle(accent)
                        .padding(.horizontal, 12).padding(.vertical, 3)
                }
                ForEach(day.entries) { entry in
                    switch entry {
                    case .event(let event): EventRowMock(t: t, event: event, day: day.date, story: story)
                    case .reminder(let item): ReminderRowMock(t: t, item: item, story: story, showDate: false)
                    case .free(let interval): FreeRowMock(interval: interval, story: story)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct EventRowMock: View {
    let t: Double
    let event: CalendarEvent
    let day: Date
    let story: DemoStory

    var body: some View {
        let link = MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes)
        let ongoing = !event.isAllDay && event.start <= story.now && event.end > story.now
        let joinable = link != nil && !event.isAllDay && event.end > story.now && event.start.timeIntervalSince(story.now) <= 15 * 60
        let flash = event.id == "added" ? window(t, Timeline.addPressed + 0.35, Timeline.toastOut + 0.6) : 0
        let subtitle = link?.provider.displayName ?? event.location
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(AgendaFormatting.timeRange(for: event, on: day, calendar: story.calendar, locale: story.locale))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    BadgeMock(text: story.badge(event.calendarID))
                }
                Text(event.title).font(.system(size: 13.5)).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if joinable {
                Text("Join")
                    .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 4)
                    .background(Capsule().fill(accent))
            }
        }
        .padding(.leading, 11)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5).fill(story.color(event.calendarID)).frame(width: 3)
        }
        .padding(.vertical, 5).padding(.horizontal, 12)
        .background(ongoing ? accent.opacity(0.08) : Color.clear)
        .background(accent.opacity(0.2 * flash))
    }
}

struct ReminderRowMock: View {
    let t: Double
    let item: ReminderItem
    let story: DemoStory
    let showDate: Bool

    var body: some View {
        let tick = item.isCompleted ? pop(t, Timeline.reminderTick, 0.35) : 0
        let fade = item.isCompleted ? 1 - 0.6 * ramp(t, Timeline.reminderTick + 0.7, 0.6) : 1
        let time = item.hasTime ? story.time(item.due) : nil
        let when = showDate
            ? [AgendaFormatting.shortDate(item.due, calendar: story.calendar, locale: story.locale), time].compactMap { $0 }.joined(separator: " ")
            : time
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Image(systemName: "circle").opacity(1 - tick)
                Image(systemName: "checkmark.circle.fill").scaleEffect(0.6 + 0.4 * tick).opacity(tick)
            }
            .font(.system(size: 14))
            .foregroundStyle(story.color(item.listID))
            VStack(alignment: .leading, spacing: 2) {
                if let when {
                    HStack(spacing: 4) {
                        if showDate { Image(systemName: "clock.fill").foregroundStyle(Color.red) }
                        Text(when).foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11))
                }
                Text(item.title)
                    .font(.system(size: 13.5))
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
            }
            Spacer(minLength: 4)
            BadgeMock(text: story.badge(item.listID))
        }
        .padding(.vertical, 5).padding(.horizontal, 12)
        .opacity(fade)
    }
}

struct FreeRowMock: View {
    let interval: DateInterval
    let story: DemoStory

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer").font(.system(size: 10))
            Text("Free · \(RelativeTime.duration(minutes: Int(interval.duration / 60)))")
            Text("\(story.time(interval.start))–\(story.time(interval.end))")
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .padding(.vertical, 3).padding(.horizontal, 12)
    }
}

// MARK: - Quick add

struct QuickAddPanel: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let typed = Timeline.typedText(story.quickAddText, at: t)
        let typing = t >= Timeline.typingStart && typed.count < story.quickAddText.count
        let draft = story.draft(typed: typed)
        let calendarID = draft.calendarID ?? "work"
        let pressed = t >= Timeline.addPressed && t < Timeline.addPressed + 0.3
        let caretVisible = typing || Int(t * 2.4) % 2 == 0
        VStack(alignment: .leading, spacing: 13) {
            Text("New").font(.system(size: 15, weight: .semibold))
            HStack(spacing: 0) {
                Text(typed.isEmpty ? " " : typed).font(.system(size: 13.5))
                Rectangle().fill(accent).frame(width: 1.5, height: 17).opacity(caretVisible ? 1 : 0)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.65), lineWidth: 2.5))
            Text("Start with ! for a reminder · #name picks a calendar")
                .font(.system(size: 10.5)).foregroundStyle(.tertiary)

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 12) {
                GridRow {
                    label("Type")
                    HStack(spacing: 0) {
                        segment("Event", on: draft.kind == .event)
                        segment("Reminder", on: draft.kind == .reminder)
                    }
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.07)))
                }
                GridRow {
                    label("Title")
                    field(draft.title.isEmpty ? " " : draft.title)
                }
                GridRow {
                    label("Calendar")
                    HStack(spacing: 6) {
                        Circle().fill(story.color(calendarID)).frame(width: 9, height: 9)
                        Text(story.info(calendarID)?.title ?? "")
                        BadgeMock(text: story.badge(calendarID))
                    }
                }
                GridRow {
                    label("All day")
                    ToggleMock(on: draft.isAllDay ? 1 : 0)
                }
                GridRow {
                    label("Starts")
                    field(RelativeTimeFormat.date(draft.start, template: draft.isAllDay ? "EEE MMM d" : "EEE MMM d h:mm a", story: story))
                }
                if !draft.isAllDay {
                    GridRow {
                        label("Ends")
                        field(RelativeTimeFormat.date(draft.end, template: "h:mm a", story: story))
                    }
                }
            }
            .font(.system(size: 13))
            Spacer()
            HStack(spacing: 10) {
                Spacer()
                Text("Cancel")
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.08)))
                Text("Add")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(pressed ? Color(hex: 0x0858C8) : accent))
            }
            .font(.system(size: 13, weight: .medium))
        }
        .padding(16)
    }

    private func label(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
    }

    private func field(_ text: String) -> some View {
        Text(text)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.1)))
    }

    private func segment(_ text: String, on: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: on ? .semibold : .regular))
            .padding(.horizontal, 14).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5).fill(on ? Color.white : Color.clear).padding(2))
    }
}

struct ToggleMock: View {
    /// 0 = off, 1 = on; values in between animate the switch.
    let on: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.15))
            Capsule().fill(Color(hex: 0x34C759)).opacity(on)
            Circle().fill(Color.white).frame(width: 14).padding(2).offset(x: 12 * on)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
        }
        .frame(width: 30, height: 18)
    }
}

// MARK: - Settings

struct SettingsMock: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let onGeneral = t >= Timeline.generalTab
        let leadTime = t >= Timeline.leadTimeChanged ? "1 minute before" : "When it starts"
        let leadFlash = window(t, Timeline.leadTimeChanged, Timeline.leadTimeChanged + 0.6, fade: 0.15)
        let pressed = t >= Timeline.checkForUpdates && t < Timeline.checkForUpdates + 0.25
        let dialog = window(t, Timeline.upToDateIn, Timeline.settingsOut - 0.1, fade: 0.25)
        VStack(spacing: 0) {
            // Title bar and the tab strip, like the app's Settings window.
            ZStack {
                HStack(spacing: 8) {
                    ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { Circle().fill(Color(hex: $0)).frame(width: 12) }
                    Spacer()
                }
                Text("Better Than Dato Settings").font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
            HStack(spacing: 0) {
                ForEach(["General", "Menu Bar", "Calendar", "Alerts", "Accounts", "Shortcuts", "Permissions"], id: \.self) { name in
                    let selected = name == (onGeneral ? "General" : "Alerts")
                    Text(name)
                        .font(.system(size: 11.5))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(selected ? 1 : 0)))
                        .shadow(color: .black.opacity(selected ? 0.12 : 0), radius: 1, y: 0.5)
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.06)))
            .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 8) {
                if onGeneral {
                    sectionTitle("Startup")
                    box { row("Launch at login") { ToggleMock(on: 1) } }
                    sectionTitle("Updates").padding(.top, 6)
                    box {
                        row("Version") { Text(story.appVersion).foregroundStyle(.secondary) }
                        Divider()
                        row("Check for updates automatically") { ToggleMock(on: 1) }
                        Divider()
                        row(nil) { button("Check for Updates…", pressed: pressed) }
                    }
                } else {
                    sectionTitle("Meeting alerts")
                    box {
                        row("Full-screen alert when a meeting starts") { ToggleMock(on: 1) }
                        Divider()
                        row("Show it") {
                            HStack(spacing: 4) {
                                Text(leadTime)
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(accent.opacity(0.18 * leadFlash)))
                        }
                        Divider()
                        row("Only for events with a video call link") { ToggleMock(on: ramp(t, Timeline.videoOnlyOn, 0.25)) }
                        Divider()
                        row(nil) { button("Preview Alert", pressed: false) }
                    }
                    Text("The alert covers every screen. Press Return to join the meeting or Esc to dismiss.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 6)
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 18).padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(width: 600, height: 400)
        .background(Color(hex: 0xF4F4F6))
        .overlay {
            if dialog > 0 {
                ZStack {
                    Color.black.opacity(0.12 * dialog)
                    VStack(spacing: 10) {
                        Image(nsImage: DemoAssets.icon).resizable().frame(width: 56, height: 56)
                        Text("You’re up to date!").font(.system(size: 14, weight: .bold))
                        Text("Better Than Dato \(story.appVersion) is currently the newest version available.")
                            .font(.system(size: 12)).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Text("OK")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                            .frame(width: 220).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(accent))
                            .padding(.top, 4)
                    }
                    .padding(20)
                    .frame(width: 280)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
                    .scaleEffect(0.92 + 0.08 * dialog)
                    .opacity(dialog)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.35), radius: 26, y: 12)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold)).padding(.leading, 6)
    }

    private func box<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.black.opacity(0.06)))
    }

    private func row<Trailing: View>(_ title: String?, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            if let title { Text(title) }
            Spacer()
            trailing()
        }
        .frame(height: 34)
    }

    private func button(_ title: String, pressed: Bool) -> some View {
        Text(title)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(pressed ? 0.18 : 0.07)))
    }
}

// MARK: - Full-screen alert

struct MeetingAlertMock: View {
    let t: Double
    let story: DemoStory

    var body: some View {
        let event = story.visibleEvents(includingAdded: false).first { $0.title == "Design review" }!
        let details = [
            AgendaFormatting.timeRange(for: event, on: event.start, calendar: story.calendar, locale: story.locale),
            story.info(event.calendarID)?.title ?? "",
            story.accountTitle(event.calendarID),
        ].joined(separator: " · ")
        let press = window(t, Timeline.alertOut - 1.3, Timeline.alertOut - 0.9, fade: 0.15)
        VStack(spacing: 34) {
            Image(systemName: "calendar.badge.clock").font(.system(size: 68, weight: .medium))
            VStack(spacing: 16) {
                Text("Starting now").font(.system(size: 28, weight: .semibold)).opacity(0.75)
                HStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 3).fill(story.color(event.calendarID)).frame(width: 7, height: 58)
                    Text(event.title).font(.system(size: 66, weight: .bold))
                }
                Text(details).font(.system(size: 26)).opacity(0.75)
            }
            Label("Join Google Meet", systemImage: "video.fill")
                .font(.system(size: 28, weight: .semibold))
                .padding(.horizontal, 34).padding(.vertical, 16)
                .background(Capsule().fill(press > 0.5 ? Color(hex: 0x0858C8) : accent))
                .scaleEffect(1 - 0.04 * press)
            Text("Dismiss")
                .font(.system(size: 21))
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.18)))
        }
        .foregroundStyle(.white)
    }
}
