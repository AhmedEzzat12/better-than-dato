import DatoCore
import SwiftUI

struct MonthGridView: View {
    @Environment(AppModel.self) private var model
    @Environment(PreferencesStore.self) private var prefs

    var body: some View {
        let grid = model.monthGrid
        let markers = model.dayMarkers
        let today = model.calendar.startOfDay(for: model.now)

        VStack(spacing: 2) {
            HStack(spacing: 0) {
                if prefs.showWeekNumbers { Color.clear.frame(width: 22, height: 1) }
                ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(grid.weeks) { week in
                HStack(spacing: 0) {
                    if prefs.showWeekNumbers {
                        Text("\(week.weekNumber)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(width: 22)
                    }
                    ForEach(week.days) { day in
                        DayCellView(
                            day: day,
                            isToday: day.date == today,
                            isSelected: day.date == model.selectedDay,
                            dots: markers[day.date] ?? []
                        )
                        .onTapGesture { model.select(day: day.date) }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
}

struct DayCellView: View {
    let day: MonthGridDay
    let isToday: Bool
    let isSelected: Bool
    let dots: [ColorRef]

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day.dayNumber)")
                .font(.callout.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : day.isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.6))
                .frame(width: 26, height: 26)
                .background {
                    if isToday {
                        Circle().fill(Color.accentColor)
                    } else if isSelected {
                        Circle().strokeBorder(Color.accentColor, lineWidth: 1.5)
                    }
                }
            HStack(spacing: 2) {
                ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                    Circle().fill(Color(color)).frame(width: 4, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }
}
