import Foundation
import Testing
@testable import DatoCore

@Suite struct DayMarkersTests {
    let cal = Fixture.calendar
    let red = ColorRef(red: 1, green: 0, blue: 0)
    let blue = ColorRef(red: 0, green: 0, blue: 1)
    let green = ColorRef(red: 0, green: 1, blue: 0)
    let yellow = ColorRef(red: 1, green: 1, blue: 0)
    var colors: [String: ColorRef] { ["work": red, "home": blue, "gym": green, "tasks": yellow] }

    func at(_ hour: Int, day: Int = 1) -> Date { Fixture.date(2026, 10, day, hour) }
    func day(_ day: Int) -> Date { Fixture.date(2026, 10, day) }

    func markers(_ days: [Date], events: [CalendarEvent] = [], reminders: [ReminderItem] = []) -> [Date: [ColorRef]] {
        DayMarkers.colors(days: days, events: events, reminders: reminders, calendarColors: colors, calendar: cal)
    }

    @Test func firstThreeDistinctColorsInTimeOrder() {
        let events = [
            Fixture.event("H", at(12), at(13), calendar: "home"),
            Fixture.event("W1", at(9), at(10), calendar: "work"),
            Fixture.event("W2", at(10), at(11), calendar: "work"),
            Fixture.event("G", at(15), at(16), calendar: "gym"),
            Fixture.event("X", at(17), at(18), calendar: "unknown"),
        ]
        #expect(markers([day(1)], events: events)[day(1)] == [red, blue, green])
    }

    @Test func remindersAddDots() {
        #expect(markers([day(2)], reminders: [Fixture.reminder("Pay", at(9, day: 2))])[day(2)] == [yellow])
    }

    @Test func emptyDaysHaveNoEntry() {
        #expect(markers([day(3)])[day(3)] == nil)
    }

    @Test func eventCrossingMidnightMarksBothDays() {
        let result = markers([day(1), day(2)], events: [Fixture.event("Late", at(22), at(2, day: 2))])
        #expect(result[day(1)] == [red])
        #expect(result[day(2)] == [red])
    }

    @Test func unknownCalendarFallsBackToGray() {
        let result = markers([day(1)], events: [Fixture.event("X", at(9), at(10), calendar: "unknown")])
        #expect(result[day(1)] == [.gray])
    }
}
