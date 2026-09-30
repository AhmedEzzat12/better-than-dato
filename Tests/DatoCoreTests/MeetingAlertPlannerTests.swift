import Foundation
import Testing
@testable import DatoCore

@Suite struct MeetingAlertPlannerTests {
    let now = Fixture.date(2026, 9, 29, 10, 0)

    func at(_ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        Fixture.date(2026, 9, 29, hour, minute).addingTimeInterval(TimeInterval(second))
    }

    func settings(lead: Int = 0, videoOnly: Bool = false) -> MeetingAlertSettings {
        MeetingAlertSettings(leadMinutes: lead, onlyWithVideoLink: videoOnly)
    }

    func due(_ events: [CalendarEvent], now: Date? = nil, lead: Int = 0, videoOnly: Bool = false, alerted: Set<String> = []) -> [String] {
        MeetingAlertPlanner.dueAlerts(events: events, now: now ?? self.now, settings: settings(lead: lead, videoOnly: videoOnly), alreadyAlerted: alerted)
            .map(\.title)
    }

    @Test func eventStartingNowIsDue() {
        #expect(due([Fixture.event("Standup", at(10), at(10, 15))]) == ["Standup"])
    }

    @Test func futureEventIsNotDueYet() {
        #expect(due([Fixture.event("Later", at(10, 5), at(10, 30))]).isEmpty)
    }

    @Test func leadTimeMakesItDueEarlier() {
        #expect(due([Fixture.event("Sync", at(10, 2), at(10, 30))], lead: 2) == ["Sync"])
        #expect(due([Fixture.event("Sync", at(10, 3), at(10, 30))], lead: 2).isEmpty)
    }

    @Test func missedByMoreThanTheGraceWindowIsSkipped() {
        // Laptop woke at 10:03 for a 10:00 meeting: too late for a full-screen interruption.
        #expect(due([Fixture.event("Standup", at(9, 57), at(10, 30))]).isEmpty)
        #expect(due([Fixture.event("Standup", at(9, 59), at(10, 30))]) == ["Standup"])
    }

    @Test func alreadyAlertedAllDayDeclinedAndCancelledAreSkipped() {
        let events = [
            Fixture.event("Done", at(10), at(10, 30)),
            Fixture.event("Holiday", Fixture.date(2026, 9, 29), Fixture.date(2026, 9, 30), allDay: true),
            Fixture.event("Declined", at(10), at(10, 30), declined: true),
            Fixture.event("Cancelled", at(10), at(10, 30), cancelled: true),
        ]
        #expect(due(events, alerted: [events[0].id]).isEmpty)
    }

    @Test func videoOnlyRequiresAMeetingLink() {
        var call = Fixture.event("Call", at(10), at(10, 30))
        call.location = "https://meet.google.com/abc-defg-hij"
        let lunch = Fixture.event("Lunch", at(10), at(11))
        #expect(due([call, lunch], videoOnly: true) == ["Call"])
        #expect(due([call, lunch]) == ["Call", "Lunch"])
    }

    @Test func nextAlertDateIsTheEarliestUpcomingAlertMoment() {
        let events = [
            Fixture.event("B", at(11), at(11, 30)),
            Fixture.event("A", at(10, 30), at(11)),
            Fixture.event("Started", at(9), at(10, 30)),
        ]
        #expect(MeetingAlertPlanner.nextAlertDate(events: events, now: now, settings: settings(lead: 1), alreadyAlerted: []) == at(10, 29))
    }

    @Test func nextAlertDateIgnoresAlertedEvents() {
        let a = Fixture.event("A", at(10, 30), at(11))
        let b = Fixture.event("B", at(11), at(11, 30))
        #expect(MeetingAlertPlanner.nextAlertDate(events: [a, b], now: now, settings: settings(), alreadyAlerted: [a.id]) == at(11))
    }
}
