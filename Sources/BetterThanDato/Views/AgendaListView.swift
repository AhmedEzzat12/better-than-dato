import DatoCore
import SwiftUI

struct AgendaListView: View {
    @Environment(AppModel.self) private var model
    @State private var showEarlier = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if model.agendaIsSingleDay {
                        Button("← Back to upcoming") { model.selectedDay = nil }
                            .buttonStyle(.link)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    ForEach(model.agenda) { day in
                        Section {
                            DayContentView(day: day, showEarlier: $showEarlier)
                        } header: {
                            DayHeaderView(date: day.date).id(day.date)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .onChange(of: model.selectedDay) { _, day in
                // Back to "upcoming" (Today button, T) scrolls to the top.
                guard let target = day.map(model.calendar.startOfDay(for:)) ?? model.agenda.first?.date else { return }
                withAnimation { proxy.scrollTo(target, anchor: .top) }
            }
        }
    }
}

struct DayHeaderView: View {
    let date: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        Text(AgendaFormatting.dayTitle(for: date, now: model.now, calendar: model.calendar, locale: .current))
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
    }
}

struct DayContentView: View {
    let day: AgendaDay
    @Binding var showEarlier: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        if !day.overdue.isEmpty {
            Text("Overdue")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            ForEach(day.overdue) { ReminderRowView(item: $0, showDate: true) }
        }
        if !day.earlierEvents.isEmpty {
            Button(showEarlier ? "Hide earlier" : "Show \(day.earlierEvents.count) earlier") { showEarlier.toggle() }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            if showEarlier {
                ForEach(day.earlierEvents) { EventRowView(event: $0, day: day.date).opacity(0.55) }
            }
        }
        ForEach(day.entries) { entry in
            switch entry {
            case .event(let event): EventRowView(event: event, day: day.date)
            case .reminder(let reminder): ReminderRowView(item: reminder)
            case .free(let interval): FreeRowView(interval: interval)
            }
        }
        if day.entries.isEmpty && model.calendar.isDate(day.date, inSameDayAs: model.now) {
            Text("Nothing else today")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
    }
}
