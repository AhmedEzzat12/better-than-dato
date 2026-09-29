import Foundation
import Testing
@testable import DatoCore

@Suite struct FreeTimeCalculatorTests {
    let cal = Fixture.calendar

    func at(_ hour: Int, _ minute: Int = 0) -> Date { Fixture.date(2026, 9, 29, hour, minute) }

    func hm(_ date: Date) -> String {
        let c = cal.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }

    func slots(_ events: [CalendarEvent], now: Date) -> [String] {
        FreeTimeCalculator.freeSlots(events: events, now: now, workingHours: .standard, calendar: cal)
            .map { "\(hm($0.start))-\(hm($0.end))" }
    }

    @Test func emptyDayIsFreeFromNowUntilEndOfWork() {
        #expect(slots([], now: at(10)) == ["10:00-18:00"])
    }

    @Test func gapsShorterThanThirtyMinutesAreDropped() {
        let events = [
            Fixture.event("A", at(11), at(12)),
            Fixture.event("B", at(12, 15), at(13)),
            Fixture.event("C", at(14), at(15)),
        ]
        #expect(slots(events, now: at(10)) == ["10:00-11:00", "13:00-14:00", "15:00-18:00"])
    }

    @Test func overlappingEventsMerge() {
        let events = [Fixture.event("A", at(11), at(13)), Fixture.event("B", at(12), at(14))]
        #expect(slots(events, now: at(10)) == ["10:00-11:00", "14:00-18:00"])
    }

    @Test func ongoingEventDelaysFirstSlot() {
        #expect(slots([Fixture.event("A", at(9, 30), at(10, 45))], now: at(10)) == ["10:45-18:00"])
    }

    @Test func beforeWorkStartsAtWorkingHours() {
        #expect(slots([], now: at(7)) == ["09:00-18:00"])
    }

    @Test func afterWorkIsEmpty() {
        #expect(slots([], now: at(19)).isEmpty)
    }

    @Test func allDayEventsDoNotBlockTime() {
        let holiday = Fixture.event("Holiday", Fixture.date(2026, 9, 29), Fixture.date(2026, 9, 30), allDay: true)
        #expect(slots([holiday], now: at(10)) == ["10:00-18:00"])
    }
}
