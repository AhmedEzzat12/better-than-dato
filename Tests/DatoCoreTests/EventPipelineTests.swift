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
