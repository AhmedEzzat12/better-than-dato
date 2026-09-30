import AppKit
import DatoCore
import SwiftUI

/// Borderless panel that can take keyboard focus, so Return joins and Esc dismisses.
private final class AlertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The full-screen "your meeting is starting" alert: one panel per display, above full-screen apps
/// and on every Space.
@MainActor
final class MeetingAlertWindowController {
    private var panels: [NSPanel] = []

    func show(_ events: [CalendarEvent], model: AppModel) {
        dismiss()
        guard !events.isEmpty else { return }
        for screen in NSScreen.screens {
            let panel = AlertPanel(
                contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
            )
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(
                rootView: MeetingAlertView(events: events, shownAt: Date(), dismiss: { [weak self] in self?.dismiss() })
                    .environment(model)
            )
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        NSApp.activate()
        (panels.first { $0.screen == NSScreen.main } ?? panels.first)?.makeKey()
        NSSound(named: "Glass")?.play()
    }

    func dismiss() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}

struct MeetingAlertView: View {
    let events: [CalendarEvent]
    let shownAt: Date
    let dismiss: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color.black.opacity(0.4)
            VStack(spacing: 32) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 56, weight: .medium))
                ForEach(events) { event in
                    card(for: event, isPrimary: event.id == events.first?.id)
                }
                Button("Dismiss") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 680)
            .padding(40)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    private func card(for event: CalendarEvent, isPrimary: Bool) -> some View {
        let link = MeetingLinkDetector.detect(url: event.url, location: event.location, notes: event.notes)
        return VStack(spacing: 12) {
            Text(status(of: event))
                .font(.title3.weight(.semibold))
                .opacity(0.75)
            HStack(alignment: .center, spacing: 14) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(model.calendarInfo(event.calendarID)?.color ?? .gray))
                    .frame(width: 6, height: 44)
                Text(event.title)
                    .font(.system(size: 40, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            Text(details(of: event))
                .font(.title3)
                .opacity(0.75)
            if let link {
                Button {
                    model.join(link)
                    dismiss()
                } label: {
                    Label("Join \(link.provider.displayName)", systemImage: "video.fill")
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(isPrimary ? .defaultAction : nil)
                .padding(.top, 8)
            }
        }
    }

    private func status(of event: CalendarEvent) -> String {
        let seconds = event.start.timeIntervalSince(shownAt)
        if seconds >= 60 {
            return "Starts \(RelativeTime.untilStart(event.start, now: shownAt, calendar: model.calendar, locale: .current))"
        }
        return seconds > -60 ? "Starting now" : "Started \(RelativeTime.duration(minutes: Int(-seconds / 60))) ago"
    }

    private func details(of event: CalendarEvent) -> String {
        let time = AgendaFormatting.timeRange(for: event, on: event.start, calendar: model.calendar, locale: .current)
        let calendar = model.calendarInfo(event.calendarID)?.title
        let account = model.account(forCalendarID: event.calendarID)?.title
        return [time, calendar, account].compactMap { $0 }.joined(separator: " · ")
    }
}
