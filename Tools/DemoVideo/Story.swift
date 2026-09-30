import DatoCore
import Foundation
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    init(_ ref: ColorRef) {
        self.init(.sRGB, red: ref.red, green: ref.green, blue: ref.blue)
    }
}

extension ColorRef {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Sample accounts, calendars, events and reminders for the demo video. Fictional people and companies;
/// everything shown is computed from this data by the app's real DatoCore logic.
struct DemoStory {
    let calendar: Calendar
    let locale = Locale(identifier: "en_US")
    let now: Date
    let accounts: [AccountInfo]
    let calendars: [CalendarInfo]
    let events: [CalendarEvent]
    let reminders: [ReminderItem]
    let overdueReminderID = "r-passport"
    let quickAddText = "Lunch with Sam tomorrow 1pm 1h #personal"

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        self.calendar = calendar
        // Today at 10:52, so the next meeting (11:00) is 8 minutes away. Today's real date keeps
        // NSDataDetector's "tomorrow" (used by the quick-add parser) consistent with the story.
        let today = calendar.startOfDay(for: Date())
        now = calendar.date(bySettingHour: 10, minute: 52, second: 0, of: today)!

        accounts = [
            AccountInfo(id: "northwind", title: "alex@northwind.io", order: 0),
            AccountInfo(id: "icloud", title: "iCloud", order: 1),
            AccountInfo(id: "gmail", title: "alex.lee@gmail.com", order: 2),
        ]
        calendars = [
            CalendarInfo(id: "work", title: "Work", color: ColorRef(hex: 0x0A84FF), accountID: "northwind", kind: .events, isWritable: true),
            CalendarInfo(id: "product", title: "Product", color: ColorRef(hex: 0xBF5AF2), accountID: "northwind", kind: .events, isWritable: true),
            CalendarInfo(id: "personal", title: "Personal", color: ColorRef(hex: 0xFF9F0A), accountID: "icloud", kind: .events, isWritable: true),
            CalendarInfo(id: "family", title: "Family", color: ColorRef(hex: 0x30D158), accountID: "gmail", kind: .events, isWritable: true),
            CalendarInfo(id: "tasks", title: "Tasks", color: ColorRef(hex: 0xFF453A), accountID: "icloud", kind: .reminders, isWritable: true),
            CalendarInfo(id: "errands", title: "Errands", color: ColorRef(hex: 0x64D2FF), accountID: "gmail", kind: .reminders, isWritable: true),
        ]

        var list: [CalendarEvent] = []
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.date(byAdding: .day, value: day, to: today)!)!
        }
        func add(_ title: String, _ calendarID: String, _ start: Date, _ end: Date,
                 allDay: Bool = false, location: String? = nil, url: String? = nil) {
            list.append(CalendarEvent(
                id: "demo-\(list.count)", title: title, start: start, end: end, isAllDay: allDay,
                calendarID: calendarID, location: location, url: url.flatMap(URL.init(string:))
            ))
        }
        func allDay(_ title: String, _ calendarID: String, _ day: Int) {
            add(title, calendarID, at(day, 0), at(day + 1, 0), allDay: true)
        }

        add("Team standup", "work", at(0, 9, 30), at(0, 9, 45))
        add("Design review", "work", at(0, 11), at(0, 11, 45), location: "https://meet.google.com/abc-defg-hij")
        add("Design review", "personal", at(0, 11), at(0, 11, 45)) // same invite on a second account: shown once
        add("Focus time", "product", at(0, 12), at(0, 14))
        add("1:1 with Priya", "work", at(0, 14, 30), at(0, 15), url: "https://northwind.zoom.us/j/123456789")
        add("Dinner with Sam", "personal", at(0, 19), at(0, 20, 30), location: "Lucca, 5th Ave")
        allDay("Product offsite", "product", 1)
        add("Dentist", "personal", at(1, 9, 30), at(1, 10, 15))
        add("Sprint planning", "work", at(1, 11), at(1, 12))
        allDay("Mom's birthday", "family", 2)
        add("Gym", "personal", at(2, 7, 30), at(2, 8, 30))
        add("Quarterly review", "work", at(3, 14), at(3, 15, 30), url: "https://teams.microsoft.com/l/meetup-join/abc")
        add("Family dinner", "family", at(4, 19), at(4, 21))
        allDay("Weekend hike", "family", 5)
        // A month of routine events so the grid has colored dots.
        for day in -35...35 where !(-1...6).contains(day) {
            let weekday = calendar.component(.weekday, from: at(day, 12))
            if (2...6).contains(weekday), day % 2 == 0 { add("Standup", "work", at(day, 9, 30), at(day, 9, 45)) }
            if day % 3 == 0 { add("Gym", "personal", at(day, 7, 30), at(day, 8, 30)) }
            if day % 5 == 1 { add("Roadmap sync", "product", at(day, 15), at(day, 16)) }
            if day % 7 == 3 { add("Family call", "family", at(day, 19), at(day, 19, 30)) }
        }
        events = list

        reminders = [
            ReminderItem(id: "r-passport", title: "Renew passport", due: at(-1, 18), listID: "tasks"),
            ReminderItem(id: "r-invoice", title: "Send invoice to Contoso", due: at(0, 16), listID: "tasks"),
            ReminderItem(id: "r-flowers", title: "Buy flowers for Mom", due: at(2, 0), hasTime: false, listID: "errands"),
        ]
    }

    // MARK: - Derived with DatoCore

    func visibleEvents(includingAdded: Bool) -> [CalendarEvent] {
        let all = includingAdded ? events + [addedEvent] : events
        let priority = EventPipeline.calendarPriority(calendars: calendars, accounts: accounts, preferredAccountID: "northwind")
        return EventPipeline.visible(all, hiddenCalendarIDs: [], hideDuplicates: true, calendarPriority: priority)
    }

    var menuBarTitle: String {
        MenuBarTitleFormatter.title(
            events: visibleEvents(includingAdded: false), now: now, settings: MenuBarTitleSettings(),
            calendar: calendar, locale: locale
        )?.text ?? ""
    }

    func draft(typed: String) -> QuickAddDraft {
        QuickAddParser(calendar: calendar, now: now).parse(typed, calendars: calendars)
    }

    var addedEvent: CalendarEvent {
        let draft = draft(typed: quickAddText)
        return CalendarEvent(
            id: "added", title: draft.title, start: draft.start, end: draft.end,
            isAllDay: draft.isAllDay, calendarID: draft.calendarID ?? "work"
        )
    }

    func info(_ calendarID: String) -> CalendarInfo? { calendars.first { $0.id == calendarID } }

    func color(_ calendarID: String) -> Color { Color(info(calendarID)?.color ?? .gray) }

    func badge(_ calendarID: String) -> String {
        guard let accountID = info(calendarID)?.accountID, let account = accounts.first(where: { $0.id == accountID }) else { return "?" }
        return AccountBadge.defaultLabel(for: account.title)
    }

    func accountTitle(_ calendarID: String) -> String {
        guard let accountID = info(calendarID)?.accountID else { return "" }
        return accounts.first { $0.id == accountID }?.title ?? ""
    }

    func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    func time(_ date: Date) -> String { AgendaFormatting.time(date, calendar: calendar, locale: locale) }
}
