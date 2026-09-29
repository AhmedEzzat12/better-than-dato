import DatoCore
import SwiftUI

struct PopoverView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if model.eventAccess != .granted {
                PermissionView()
            } else if model.popoverMode == .quickAdd {
                QuickAddView()
            } else {
                AgendaScreen()
            }
            Divider()
            FooterView()
        }
        .frame(width: 360)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(text: toast).padding(.bottom, 44)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.toast)
    }
}

struct FooterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.popoverMode = .quickAdd
            } label: {
                Label("New", systemImage: "plus")
            }
            .keyboardShortcut("n")
            .disabled(model.eventAccess != .granted)

            if model.eventAccess == .granted && model.reminderAccess == .denied {
                Button("Reminders off") { model.openSettings() }
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 4)
            .transition(.opacity)
    }
}

struct PermissionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            if model.eventAccess == .notDetermined {
                Text("Better Than Dato needs access to your calendars and reminders to show your schedule.")
                    .multilineTextAlignment(.center)
                Button("Grant Access") {
                    Task { await model.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Calendar access is off. Turn on Better Than Dato in System Settings → Privacy & Security → Calendars.")
                    .multilineTextAlignment(.center)
                Button("Open System Settings") { SystemSettingsLink.open(.calendars) }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct AccountBadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.secondary.opacity(0.18)))
    }
}

// Replaced in Task 10.
struct AgendaScreen: View {
    var body: some View { Text("Agenda").padding(40) }
}

// Replaced in Task 11.
struct QuickAddView: View {
    var body: some View { Text("Quick add").padding(40) }
}
