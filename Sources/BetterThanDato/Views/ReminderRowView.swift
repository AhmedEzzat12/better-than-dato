import DatoCore
import SwiftUI

struct ReminderRowView: View {
    let item: ReminderItem
    /// Overdue rows show the due date instead of just the time.
    var showDate = false
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                model.toggleReminder(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(Color(model.calendarInfo(item.listID)?.color ?? .gray))
            }
            .buttonStyle(.plain)
            .help(item.isCompleted ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 2) {
                if let when = whenText {
                    // Red text on glass is hard to read; overdue gets a red icon, the date stays neutral.
                    HStack(spacing: 4) {
                        if showDate {
                            Image(systemName: "clock.fill").foregroundStyle(Color.red)
                        }
                        Text(when).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            AccountBadgeView(text: model.badge(forCalendarID: item.listID))
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 12)
        .opacity(item.isCompleted ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: item.isCompleted)
    }

    private var whenText: String? {
        let time = item.hasTime ? AgendaFormatting.time(item.due, calendar: model.calendar, locale: .current) : nil
        guard showDate else { return time }
        let date = AgendaFormatting.shortDate(item.due, calendar: model.calendar, locale: .current)
        return [date, time].compactMap { $0 }.joined(separator: " ")
    }
}

struct FreeRowView: View {
    let interval: DateInterval
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer")
                .font(.caption2)
                .frame(width: 3)
            Text("Free · \(RelativeTime.duration(minutes: Int(interval.duration / 60)))")
                .font(.caption)
            Text("\(time(interval.start))–\(time(interval.end))")
                .font(.caption)
                .monospacedDigit()
            Spacer()
        }
        .foregroundStyle(.tertiary)
        .padding(.vertical, 3)
        .padding(.horizontal, 12)
    }

    private func time(_ date: Date) -> String {
        AgendaFormatting.time(date, calendar: model.calendar, locale: .current)
    }
}
