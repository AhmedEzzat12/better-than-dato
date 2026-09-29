import Foundation
import Testing
@testable import DatoCore

@Suite struct MonthGridTests {
    func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Fixture.calendar
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    @Test func mondayStart() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 2))
        #expect(grid.weeks.count == 6)
        #expect(grid.weeks.allSatisfy { $0.days.count == 7 })
        #expect(grid.days.first?.date == Fixture.date(2026, 8, 31))
        #expect(grid.days.last?.date == Fixture.date(2026, 10, 11))
        #expect(grid.weekdaySymbols == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test func sundayStart() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 1))
        #expect(grid.days.first?.date == Fixture.date(2026, 8, 30))
        #expect(grid.weekdaySymbols == ["S", "M", "T", "W", "T", "F", "S"])
    }

    @Test func saturdayStart() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 7))
        #expect(grid.days.first?.date == Fixture.date(2026, 8, 29))
    }

    @Test func marksDaysOutsideTheMonth() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 2))
        #expect(grid.days[0].isInDisplayedMonth == false)
        #expect(grid.days[1].isInDisplayedMonth)
        #expect(grid.days[1].dayNumber == 1)
    }

    @Test func intervalCoversEveryCell() {
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: calendar(firstWeekday: 2))
        #expect(grid.interval.start == Fixture.date(2026, 8, 31))
        #expect(grid.interval.end == Fixture.date(2026, 10, 12))
    }

    @Test func isoWeekNumbers() {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = Fixture.timeZone
        let grid = MonthGrid.make(containing: Fixture.date(2026, 9, 15), calendar: iso)
        #expect(grid.weeks.first?.weekNumber == 36)
    }

    @Test func dstMonthStillHasMidnightsOnConsecutiveDays() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        newYork.firstWeekday = 1
        let november = newYork.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        let days = MonthGrid.make(containing: november, calendar: newYork).days
        #expect(days.allSatisfy { newYork.startOfDay(for: $0.date) == $0.date })
        for (a, b) in zip(days, days.dropFirst()) {
            #expect(newYork.dateComponents([.day], from: a.date, to: b.date).day == 1)
        }
    }
}
