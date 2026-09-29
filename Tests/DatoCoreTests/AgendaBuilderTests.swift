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
