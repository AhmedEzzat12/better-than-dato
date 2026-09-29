import Foundation
import Testing
@testable import DatoCore

@Suite struct AgendaFormattingTests {
    let cal = Fixture.calendar
    let now = Fixture.date(2026, 9, 29, 10, 0)

    @Test func dayTitles() {
        func title(_ date: Date) -> String {
            AgendaFormatting.dayTitle(for: date, now: now, calendar: cal, locale: Fixture.locale)
        }
        #expect(title(Fixture.date(2026, 9, 29)) == "Today")
        #expect(title(Fixture.date(2026, 9, 30)) == "Tomorrow")
        #expect(title(Fixture.date(2026, 9, 28)) == "Yesterday")
        #expect(title(Fixture.date(2026, 10, 1)) == "Thu 1 Oct")
    }

    @Test func timeRanges() {
        let day = Fixture.date(2026, 10, 1)
        func range(_ start: Date, _ end: Date, allDay: Bool = false) -> String {
            AgendaFormatting.timeRange(
                for: Fixture.event("E", start, end, allDay: allDay), on: day, calendar: cal, locale: Fixture.locale
            )
        }
        #expect(range(Fixture.date(2026, 10, 1, 9, 0), Fixture.date(2026, 10, 1, 9, 30)) == "09:00–09:30")
        #expect(range(day, Fixture.date(2026, 10, 2), allDay: true) == "All day")
        #expect(range(Fixture.date(2026, 9, 30, 22, 0), Fixture.date(2026, 10, 1, 2, 0)) == "…–02:00")
        #expect(range(Fixture.date(2026, 10, 1, 22, 0), Fixture.date(2026, 10, 2, 1, 0)) == "22:00–…")
        #expect(range(Fixture.date(2026, 9, 30, 8, 0), Fixture.date(2026, 10, 2, 8, 0)) == "All day")
    }

    @Test func shortDateAndMonthTitle() {
        #expect(AgendaFormatting.shortDate(Fixture.date(2026, 9, 28), calendar: cal, locale: Fixture.locale) == "Mon 28 Sep")
        #expect(AgendaFormatting.monthTitle(for: Fixture.date(2026, 9, 15), calendar: cal, locale: Fixture.locale) == "September 2026")
    }

    @Test func plainNotesStripsHtml() {
        let html = "<p>Hello&nbsp;<b>world</b></p><br>Join &amp; go"
        #expect(AgendaFormatting.plainNotes(html, limit: 500) == "Hello world\n\nJoin & go")
    }

    @Test func plainNotesKeepsAngleBracketLinks() {
        let notes = "Join <https://meet.google.com/abc-defg-hij>"
        #expect(AgendaFormatting.plainNotes(notes, limit: 500) == notes)
    }

    @Test func plainNotesTruncates() {
        #expect(AgendaFormatting.plainNotes("abcdef", limit: 3) == "abc…")
    }
}
