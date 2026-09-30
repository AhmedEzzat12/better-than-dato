import AppKit
import Carbon
import Combine
import DatoCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView().tabItem { Label("General", systemImage: "gearshape") }
            MenuBarSettingsView().tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            CalendarSettingsView().tabItem { Label("Calendar", systemImage: "calendar") }
            AccountsSettingsView().tabItem { Label("Accounts", systemImage: "person.2") }
            ShortcutsSettingsView().tabItem { Label("Shortcuts", systemImage: "keyboard") }
            PermissionsSettingsView().tabItem { Label("Permissions", systemImage: "lock") }
        }
        .frame(width: 500, height: 520)
    }
}

struct GeneralSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?
    @State private var autoUpdate = false

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { enabled in
                    do {
                        try LoginItem.set(enabled)
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                    }
                    launchAtLogin = LoginItem.isEnabled
                }
            ))
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            Toggle("Hide duplicate events across accounts", isOn: $prefs.hideDuplicates)
            Toggle("Open meetings in desktop apps (Zoom, Teams)", isOn: $prefs.openMeetingsInApp)
            Toggle("Show free time today", isOn: $prefs.showFreeTime)
            if prefs.showFreeTime {
                Picker("Working hours start", selection: $prefs.workingHoursStart) {
                    ForEach(Self.halfHours, id: \.self) { Text(Self.label($0)).tag($0) }
                }
                Picker("Working hours end", selection: $prefs.workingHoursEnd) {
                    ForEach(Self.halfHours, id: \.self) { Text(Self.label($0)).tag($0) }
                }
            }

            Section("Meeting alerts") {
                Toggle("Full-screen alert when a meeting starts", isOn: $prefs.meetingAlertsEnabled)
                Picker("Show it", selection: $prefs.meetingAlertLeadMinutes) {
                    Text("When it starts").tag(0)
                    Text("1 minute before").tag(1)
                    Text("2 minutes before").tag(2)
                    Text("5 minutes before").tag(5)
                }
                .disabled(!prefs.meetingAlertsEnabled)
                Toggle("Only for events with a video call link", isOn: $prefs.meetingAlertsVideoOnly)
                    .disabled(!prefs.meetingAlertsEnabled)
                Button("Preview alert") { model.previewMeetingAlert() }
            }

            Section("Updates") {
                LabeledContent("Version", value: model.updater.version)
                if model.updater.isEnabled {
                    Toggle("Check for updates automatically", isOn: Binding(
                        get: { autoUpdate },
                        set: { autoUpdate = $0; model.updater.automaticallyChecks = $0 }
                    ))
                    Button("Check for Updates…") { model.updater.checkForUpdates() }
                } else {
                    Text("Updates are available in builds downloaded from GitHub Releases.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                Text("The popover uses macOS's Liquid Glass, which apps can't adjust. To make it more opaque, "
                     + "turn on Reduce Transparency, or choose Tinted for Liquid Glass in Appearance settings "
                     + "(on macOS versions that offer it).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Accessibility → Display…") { AppearanceSettingsLink.openAccessibilityDisplay() }
                    Button("Appearance…") { AppearanceSettingsLink.openAppearance() }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: prefs.meetingAlertSettings) { model.rescheduleMeetingAlerts() }
        .onChange(of: prefs.meetingAlertsEnabled) { model.rescheduleMeetingAlerts() }
        .onAppear { autoUpdate = model.updater.automaticallyChecks }
    }

    static let halfHours = Array(stride(from: 0, through: 24 * 60, by: 30))

    static func label(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

struct MenuBarSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Toggle("Show next event in the menu bar", isOn: $prefs.showNextEvent)
            Picker("Show it when it starts within", selection: $prefs.menuBarWindow) {
                Text("30 minutes").tag(MenuBarWindow.thirtyMinutes)
                Text("1 hour").tag(MenuBarWindow.oneHour)
                Text("3 hours").tag(MenuBarWindow.threeHours)
                Text("The rest of today").tag(MenuBarWindow.restOfToday)
                Text("Any time").tag(MenuBarWindow.always)
            }
            .disabled(!prefs.showNextEvent)
            Stepper("Maximum title length: \(prefs.maxTitleLength)", value: $prefs.maxTitleLength, in: 15...40)
            Toggle("Show calendar color dot", isOn: $prefs.showColorDot)
        }
        .formStyle(.grouped)
    }
}

struct CalendarSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Picker("First day of week", selection: $prefs.firstWeekday) {
                Text("System").tag(0)
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
                Text("Saturday").tag(7)
            }
            Toggle("Show week numbers", isOn: $prefs.showWeekNumbers)
            Picker("Upcoming days in the agenda", selection: $prefs.agendaDays) {
                ForEach([1, 3, 7, 14], id: \.self) { Text("\($0)").tag($0) }
            }
        }
        .formStyle(.grouped)
        .onChange(of: prefs.agendaDays) { model.scheduleRefresh(delay: 0) }
        .onChange(of: prefs.firstWeekday) { model.scheduleRefresh(delay: 0) }
    }
}

struct AccountsSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            if model.accounts.isEmpty {
                Text("No accounts yet. Add accounts in System Settings → Internet Accounts.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.accounts) { account in
                Section {
                    TextField("Badge", text: badgeBinding(account), prompt: Text(AccountBadge.defaultLabel(for: account.title)))
                    ForEach(model.calendars.filter { $0.accountID == account.id }) { calendar in
                        Toggle(isOn: visibleBinding(calendar)) {
                            HStack(spacing: 6) {
                                Circle().fill(Color(calendar.color)).frame(width: 8, height: 8)
                                Text(calendar.title)
                                if calendar.kind == .reminders {
                                    Text("Reminders").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(account.title)
                        AccountBadgeView(text: prefs.badge(for: account))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func badgeBinding(_ account: AccountInfo) -> Binding<String> {
        Binding(
            get: { prefs.accountBadges[account.id] ?? "" },
            set: { prefs.accountBadges[account.id] = String($0.prefix(2)) }
        )
    }

    private func visibleBinding(_ calendar: CalendarInfo) -> Binding<Bool> {
        Binding(
            get: { !prefs.hiddenCalendarIDs.contains(calendar.id) },
            set: { visible in
                if visible { prefs.hiddenCalendarIDs.remove(calendar.id) } else { prefs.hiddenCalendarIDs.insert(calendar.id) }
            }
        )
    }
}

struct ShortcutsSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            LabeledContent("Quick add") {
                ShortcutRecorder(combo: $prefs.quickAddShortcut)
            }
            if model.hotKeyFailures.contains(.quickAdd) {
                Text("Shortcut unavailable — another app uses it.").font(.caption).foregroundStyle(.red)
            }
            LabeledContent("Join current meeting") {
                ShortcutRecorder(combo: $prefs.joinMeetingShortcut)
            }
            if model.hotKeyFailures.contains(.joinMeeting) {
                Text("Shortcut unavailable — another app uses it.").font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onChange(of: prefs.quickAddShortcut) { model.applyShortcuts() }
        .onChange(of: prefs.joinMeetingShortcut) { model.applyShortcuts() }
    }
}

/// Click, then press a key combination with ⌘, ⌥ or ⌃. Esc cancels.
struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(recording ? "Press shortcut…" : combo?.displayString ?? "None") {
                recording ? stop() : start()
            }
            .frame(minWidth: 110)
            if combo != nil {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
            }
        }
        .onDisappear(perform: stop)
        // onDisappear doesn't fire when the (retained) Settings window is merely closed.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            if (note.object as? NSWindow)?.identifier == SettingsWindowController.windowID { stop() }
        }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only capture keys typed into Settings; never swallow typing in the popover.
            guard event.window?.identifier == SettingsWindowController.windowID else { return event }
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
            } else if let newCombo = KeyCombo(event: event) {
                combo = newCombo
                stop()
            }
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

struct PermissionsSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            LabeledContent("Calendars") { status(model.eventAccess) }
            LabeledContent("Reminders") { status(model.reminderAccess) }
            if model.eventAccess == .notDetermined || model.reminderAccess == .notDetermined {
                Button("Grant access") { Task { await model.requestAccess() } }
            }
            Button("Open Calendars privacy settings") { SystemSettingsLink.open(.calendars) }
            Button("Open Reminders privacy settings") { SystemSettingsLink.open(.reminders) }
        }
        .formStyle(.grouped)
        .onAppear { model.scheduleRefresh(delay: 0) }
    }

    @ViewBuilder
    private func status(_ state: AccessState) -> some View {
        switch state {
        case .granted: Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .denied: Label("Denied", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case .notDetermined: Label("Not asked yet", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        }
    }
}
