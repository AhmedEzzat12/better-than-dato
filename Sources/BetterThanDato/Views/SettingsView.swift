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
            AlertsSettingsView().tabItem { Label("Alerts", systemImage: "bell") }
            AccountsSettingsView().tabItem { Label("Accounts", systemImage: "person.2") }
            ShortcutsSettingsView().tabItem { Label("Shortcuts", systemImage: "keyboard") }
            PermissionsSettingsView().tabItem { Label("Permissions", systemImage: "lock") }
        }
        .padding(.top, 10)
        .frame(width: 600, height: 620)
    }
}

/// Explanatory text under a settings group, left-aligned like macOS Settings.
private struct SectionFooter: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A form row whose only content is a button, aligned to the trailing edge like macOS Settings.
private struct TrailingButtons<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            Spacer()
            content
        }
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
            Section("Startup") {
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
            }

            Section("Events") {
                Toggle("Hide duplicate events across accounts", isOn: $prefs.hideDuplicates)
                Toggle("Open meetings in desktop apps (Zoom, Teams)", isOn: $prefs.openMeetingsInApp)
            }

            Section("Free time") {
                Toggle("Show free time today", isOn: $prefs.showFreeTime)
                if prefs.showFreeTime {
                    Picker("Working hours start", selection: $prefs.workingHoursStart) {
                        ForEach(Self.halfHours, id: \.self) { Text(Self.label($0)).tag($0) }
                    }
                    Picker("Working hours end", selection: $prefs.workingHoursEnd) {
                        ForEach(Self.halfHours, id: \.self) { Text(Self.label($0)).tag($0) }
                    }
                }
            }

            Section("Updates") {
                LabeledContent("Version", value: model.updater.version)
                if model.updater.isEnabled {
                    Toggle("Check for updates automatically", isOn: Binding(
                        get: { autoUpdate },
                        set: { autoUpdate = $0; model.updater.automaticallyChecks = $0 }
                    ))
                    TrailingButtons {
                        Button("Check for Updates…") { model.updater.checkForUpdates() }
                    }
                } else {
                    Text("Updates are available in builds downloaded from GitHub Releases.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
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
            Section("Next event") {
                Toggle("Show next event in the menu bar", isOn: $prefs.showNextEvent)
                Picker("Show it when it starts within", selection: $prefs.menuBarWindow) {
                    Text("30 minutes").tag(MenuBarWindow.thirtyMinutes)
                    Text("1 hour").tag(MenuBarWindow.oneHour)
                    Text("3 hours").tag(MenuBarWindow.threeHours)
                    Text("The rest of today").tag(MenuBarWindow.restOfToday)
                    Text("Any time").tag(MenuBarWindow.always)
                }
                .disabled(!prefs.showNextEvent)
                LabeledContent("Maximum title length") {
                    HStack(spacing: 6) {
                        Text("\(prefs.maxTitleLength) characters").monospacedDigit()
                        Stepper("Maximum title length", value: $prefs.maxTitleLength, in: 15...40).labelsHidden()
                    }
                }
                .disabled(!prefs.showNextEvent)
                Toggle("Show calendar color dot", isOn: $prefs.showColorDot)
                    .disabled(!prefs.showNextEvent)
            }

            Section {
                Text("The popover uses macOS's Liquid Glass, which apps can't adjust. To make it more opaque, "
                     + "turn on Reduce Transparency, or choose Tinted for Liquid Glass in Appearance settings "
                     + "(on macOS versions that offer it).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TrailingButtons {
                    Button("Reduce Transparency…") { AppearanceSettingsLink.openAccessibilityDisplay() }
                    Button("Appearance…") { AppearanceSettingsLink.openAppearance() }
                }
            } header: {
                Text("Appearance")
            }
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
            Section("Month") {
                Picker("First day of week", selection: $prefs.firstWeekday) {
                    Text("System").tag(0)
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Saturday").tag(7)
                }
                Toggle("Show week numbers", isOn: $prefs.showWeekNumbers)
            }
            Section("Agenda") {
                Picker("Upcoming days", selection: $prefs.agendaDays) {
                    ForEach([1, 3, 7, 14], id: \.self) { days in
                        Text(days == 1 ? "1 day" : "\(days) days").tag(days)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: prefs.agendaDays) { model.scheduleRefresh(delay: 0) }
        .onChange(of: prefs.firstWeekday) { model.scheduleRefresh(delay: 0) }
    }
}

struct AlertsSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var prefs = prefs
        Form {
            Section {
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
                TrailingButtons {
                    Button("Preview Alert") { model.previewMeetingAlert() }
                }
            } header: {
                Text("Meeting alerts")
            } footer: {
                SectionFooter("The alert covers every screen. Press Return to join the meeting or Esc to dismiss.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: prefs.meetingAlertSettings) { model.rescheduleMeetingAlerts() }
        .onChange(of: prefs.meetingAlertsEnabled) { model.rescheduleMeetingAlerts() }
    }
}

struct AccountsSettingsView: View {
    @Environment(PreferencesStore.self) private var prefs
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            if model.accounts.isEmpty {
                Section {
                    Text("No accounts yet. Add accounts in System Settings → Internet Accounts.")
                        .foregroundStyle(.secondary)
                }
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
                    HStack(spacing: 6) {
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
            Section {
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
            } header: {
                Text("Global shortcuts")
            } footer: {
                SectionFooter("These work from any app. Click a shortcut, then press the new keys (with ⌘, ⌥ or ⌃); Esc cancels.")
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
            if combo != nil {
                Button {
                    combo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
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
            Section {
                LabeledContent("Calendars") {
                    HStack(spacing: 10) {
                        status(model.eventAccess)
                        Button("Open…") { SystemSettingsLink.open(.calendars) }
                    }
                }
                LabeledContent("Reminders") {
                    HStack(spacing: 10) {
                        status(model.reminderAccess)
                        Button("Open…") { SystemSettingsLink.open(.reminders) }
                    }
                }
                if model.eventAccess == .notDetermined || model.reminderAccess == .notDetermined {
                    TrailingButtons {
                        Button("Grant Access") { Task { await model.requestAccess() } }
                    }
                }
            } header: {
                Text("Access")
            } footer: {
                SectionFooter("“Open…” shows the matching page in System Settings → Privacy & Security.")
            }
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
