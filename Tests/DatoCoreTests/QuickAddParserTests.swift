import Foundation
import Testing
@testable import DatoCore

/// NSDataDetector resolves "tomorrow" against the real clock and the system time zone,
/// so these tests use Calendar.current and Date() rather than Fixture.
@Suite struct QuickAddParserTests {
    let cal = Calendar.current
    let calendars: [CalendarInfo] = [
        CalendarInfo(id: "work-stuff", title: "Work Stuff", color: .gray, accountID: "g", kind: .events, isWritable: true),
        CalendarInfo(id: "work", title: "Work", color: .gray, accountID: "g", kind: .events, isWritable: true),
        CalendarInfo(id: "family", title: "Family Plans", color: .gray, accountID: "i", kind: .events, isWritable: true),
        CalendarInfo(id: "holidays", title: "Holidays", color: .gray, accountID: "i", kind: .events, isWritable: false),
        CalendarInfo(id: "r-work", title: "Work", color: .gray, accountID: "g", kind: .reminders, isWritable: true),
    ]

    func parse(_ text: String, now: Date = Date(), forcedKind: QuickAddKind? = nil) -> QuickAddDraft {
        QuickAddParser(calendar: cal, now: now).parse(text, calendars: calendars, forcedKind: forcedKind)
    }

    func today(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    func tomorrow(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: cal.date(byAdding: .day, value: 1, to: Date())!)!
    }

    @Test func plainTitleStartsAtNextHalfHour() {
        let draft = parse("Focus block", now: today(10, 7))
        #expect(draft.kind == .event)
        #expect(draft.title == "Focus block")
        #expect(draft.start == today(10, 30))
        #expect(draft.end == today(11, 0))
        #expect(!draft.isAllDay)
        #expect(!draft.hasExplicitDate)
        #expect(draft.calendarID == nil)
    }

    @Test func halfHourRollsIntoNextHour() {
        #expect(parse("Focus", now: today(10, 30)).start == today(11, 0))
    }

    @Test(arguments: [
        ("Review for 45m", "Review", 45),
        ("Planning 1h30m", "Planning", 90),
        ("Deep work 1.5h", "Deep work", 90),
        ("Sync 2 hours", "Sync", 120),
        ("Chat 20 min", "Chat", 20),
    ])
    func durations(input: String, title: String, minutes: Int) {
        let draft = parse(input, now: today(10, 7))
        #expect(draft.title == title)
        #expect(draft.end.timeIntervalSince(draft.start) == TimeInterval(minutes * 60))
    }

    @Test func hashtagExactMatchBeatsPrefix() {
        let draft = parse("Standup #work")
        #expect(draft.calendarID == "work")
        #expect(draft.title == "Standup")
    }

    @Test func hashtagPrefixMatch() {
        #expect(parse("Dinner #fam").calendarID == "family")
    }

    @Test func hashtagSubstringMatch() {
        #expect(parse("Deploy #stuff").calendarID == "work-stuff")
    }

    @Test func readOnlyCalendarsAreNotTargets() {
        let draft = parse("Day off #holidays")
        #expect(draft.calendarID == nil)
        #expect(draft.unmatchedCalendarToken == "holidays")
    }

    @Test func unmatchedHashtagIsReported() {
        let draft = parse("Gym #zzz")
        #expect(draft.calendarID == nil)
        #expect(draft.unmatchedCalendarToken == "zzz")
        #expect(draft.title == "Gym")
    }

    @Test func bangMakesReminderInMatchingList() {
        let draft = parse("!Send report #work", now: today(10))
        #expect(draft.kind == .reminder)
        #expect(draft.calendarID == "r-work")
        #expect(draft.title == "Send report")
        #expect(!draft.hasDueTime)
        #expect(draft.start == cal.startOfDay(for: today(10)))
    }

    @Test func forcedKindOverridesBang() {
        #expect(parse("!Send report", forcedKind: .event).kind == .event)
    }

    @Test func tomorrowWithTimeAndDuration() {
        let draft = parse("Lunch with Sara tomorrow 1pm 1h #work")
        #expect(draft.title == "Lunch with Sara")
        #expect(draft.calendarID == "work")
        #expect(draft.start == tomorrow(13))
        #expect(draft.end == tomorrow(14))
        #expect(draft.hasExplicitDate)
    }

    @Test func dateWithoutTimeIsAllDay() {
        let draft = parse("Offsite tomorrow")
        #expect(draft.isAllDay)
        #expect(draft.title == "Offsite")
        #expect(draft.start == cal.startOfDay(for: tomorrow(12)))
        #expect(draft.end == cal.date(byAdding: .day, value: 1, to: draft.start))
    }

    @Test func reminderWithTime() {
        let draft = parse("!Call mom tomorrow at 6pm")
        #expect(draft.kind == .reminder)
        #expect(draft.hasDueTime)
        #expect(draft.start == tomorrow(18))
        #expect(draft.title == "Call mom")
    }

    @Test func timeRangeSetsEnd() {
        let draft = parse("Workshop tomorrow from 2pm to 4pm")
        #expect(draft.start == tomorrow(14))
        #expect(draft.end == tomorrow(16))
        #expect(draft.title == "Workshop")
    }

    @Test func detectorDoesNotSwallowTitleWords() {
        // NSDataDetector matches "Dinner friday 7pm" as one phrase.
        let draft = parse("Dinner friday 7pm")
        #expect(draft.title == "Dinner")
        #expect(cal.component(.weekday, from: draft.start) == 6)
        #expect(cal.component(.hour, from: draft.start) == 19)
    }

    @Test func emptyInputs() {
        #expect(parse("").title == "")
        let bang = parse("!")
        #expect(bang.kind == .reminder)
        #expect(bang.title == "")
    }
}
