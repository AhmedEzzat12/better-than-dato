import Foundation

public struct MonthGridDay: Identifiable, Hashable, Sendable {
    public let date: Date
    public let dayNumber: Int
    public let isInDisplayedMonth: Bool
    public var id: Date { date }
}

public struct MonthGridWeek: Identifiable, Hashable, Sendable {
    public let weekNumber: Int
    public let days: [MonthGridDay]
    public var id: Date { days[0].date }
}

public struct MonthGridModel: Hashable, Sendable {
    public let monthStart: Date
    public let weeks: [MonthGridWeek]
    /// Very short weekday symbols, rotated to start at `calendar.firstWeekday`.
    public let weekdaySymbols: [String]
    /// From the first cell's midnight to the midnight after the last cell.
    public let interval: DateInterval

    public var days: [MonthGridDay] { weeks.flatMap(\.days) }
}

public enum MonthGrid {
    /// Always 6 rows so the popover height never jumps between months.
    public static let rowCount = 6

    public static func make(containing date: Date, calendar: Calendar) -> MonthGridModel {
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        let leadingDays = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart
        let displayedMonth = calendar.component(.month, from: monthStart)

        var weeks: [MonthGridWeek] = []
        for row in 0..<rowCount {
            var days: [MonthGridDay] = []
            for column in 0..<7 {
                let day = calendar.date(byAdding: .day, value: row * 7 + column, to: gridStart) ?? gridStart
                days.append(MonthGridDay(
                    date: day,
                    dayNumber: calendar.component(.day, from: day),
                    isInDisplayedMonth: calendar.component(.month, from: day) == displayedMonth
                ))
            }
            weeks.append(MonthGridWeek(weekNumber: calendar.component(.weekOfYear, from: days[0].date), days: days))
        }

        let gridEnd = calendar.date(byAdding: .day, value: rowCount * 7, to: gridStart) ?? gridStart
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return MonthGridModel(
            monthStart: monthStart,
            weeks: weeks,
            weekdaySymbols: Array(symbols[shift...] + symbols[..<shift]),
            interval: DateInterval(start: gridStart, end: gridEnd)
        )
    }
}
