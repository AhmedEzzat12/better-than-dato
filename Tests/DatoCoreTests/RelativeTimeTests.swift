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
