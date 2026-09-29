import AppKit
import DatoCore
import SwiftUI

struct EventRowView: View {
    let event: CalendarEvent
    let day: Date
    @Environment(AppModel.self) private var model
    @State private var expanded = false

    var body: some View {
        let link = MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes)
        let ongoing = !event.isAllDay && event.start <= model.now && event.end > model.now
        let joinable = link != nil && !event.isAllDay && event.end > model.now
            && event.start.timeIntervalSince(model.now) <= 15 * 60
        let subtitle = link?.provider.displayName ?? event.location

        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(model.calendarInfo(event.calendarID)?.color ?? .gray))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(AgendaFormatting.timeRange(for: event, on: day, calendar: model.calendar, locale: .current))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    AccountBadgeView(text: model.badge(forCalendarID: event.calendarID))
                        .help(model.account(forCalendarID: event.calendarID)?.title ?? "")
                }
                Text(event.title)
                    .lineLimit(expanded ? nil : 1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if expanded {
                    EventDetailView(event: event, link: link)
                }
            }
            if joinable, let link {
                Button("Join") { model.join(link) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 12)
        .background(ongoing ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }
    }
}

struct EventDetailView: View {
    let event: CalendarEvent
    let link: MeetingLink?
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(intervalText)
                .font(.caption)
            if let calendar = model.calendarInfo(event.calendarID) {
                Text([calendar.title, model.account(forCalendarID: event.calendarID)?.title].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse").font(.caption)
            }
            if let url = event.url {
                Link(url.absoluteString, destination: url).font(.caption).lineLimit(1)
            }
            if event.attendeeCount > 0 {
                Label("\(event.attendeeCount) attendees", systemImage: "person.2").font(.caption)
            }
            if let notes = event.notes.map({ AgendaFormatting.plainNotes($0, limit: 500) }), !notes.isEmpty {
                Text(Self.linkified(notes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack {
                if let link {
                    Button("Join") { model.join(link) }
                    Button("Copy link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link.url.absoluteString, forType: .string)
                        model.showToast("Link copied")
                    }
                }
                Button("Open in Calendar") { CalendarAppLauncher.open(eventIdentifier: event.eventIdentifier) }
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    private var intervalText: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = event.isAllDay ? .none : .short
        return formatter.string(from: event.start, to: event.end)
    }

    static func linkified(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return attributed }
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url,
                  let range = Range(match.range, in: text),
                  let attributedRange = Range(range, in: attributed) else { continue }
            attributed[attributedRange].link = url
        }
        return attributed
    }
}
