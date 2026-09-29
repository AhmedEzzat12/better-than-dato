import DatoCore
import SwiftUI

/// One line of text parsed live into an editable form. Fields the user edits by hand
/// stop being overwritten by further typing.
struct QuickAddView: View {
    @Environment(AppModel.self) private var model
    @Environment(PreferencesStore.self) private var prefs
    @State private var text = ""
    @State private var draft = QuickAddParser(calendar: .current, now: Date()).parse("", calendars: [])
    @State private var overridden: Set<Field> = []
    @State private var errorMessage: String?
    @State private var isSaving = false
    @FocusState private var inputFocused: Bool

    enum Field: Hashable {
        case kind, title, calendar, allDay, start, end, dueTime
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New").font(.headline)
            TextField("Lunch with Sara tomorrow 1pm 1h #work", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
            Text("Start with ! for a reminder · #name picks a calendar")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            form

            if let token = draft.unmatchedCalendarToken {
                Text("No calendar matches #\(token), using the default.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if model.writableCalendars(for: draft.kind).isEmpty {
                Text(draft.kind == .event ? "No writable calendars." : "No writable reminder lists.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { model.popoverMode = .agenda }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(12)
        .onAppear {
            reparse()
            inputFocused = true
        }
        .onChange(of: text) { reparse() }
    }

    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                label("Type")
                Picker("", selection: kindBinding) {
                    Text("Event").tag(QuickAddKind.event)
                    Text("Reminder").tag(QuickAddKind.reminder)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            GridRow {
                label("Title")
                TextField("Title", text: binding(\.title, .title))
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
            }
            GridRow {
                label(draft.kind == .event ? "Calendar" : "List")
                calendarPicker
            }
            if draft.kind == .event {
                GridRow {
                    label("All day")
                    Toggle("", isOn: binding(\.isAllDay, .allDay)).labelsHidden()
                }
                GridRow {
                    label("Starts")
                    DatePicker("", selection: startBinding,
                               displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }
                if !draft.isAllDay {
                    GridRow {
                        label("Ends")
                        DatePicker("", selection: binding(\.end, .end), in: draft.start...,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                }
            } else {
                GridRow {
                    label("Due")
                    DatePicker("", selection: binding(\.start, .start),
                               displayedComponents: draft.hasDueTime ? [.date, .hourAndMinute] : [.date])
                        .labelsHidden()
                }
                GridRow {
                    label("Time")
                    Toggle("", isOn: binding(\.hasDueTime, .dueTime)).labelsHidden()
                }
            }
        }
        .font(.callout)
    }

    private var calendarPicker: some View {
        Picker("", selection: calendarBinding) {
            ForEach(model.accounts) { account in
                let calendars = model.writableCalendars(for: draft.kind).filter { $0.accountID == account.id }
                if !calendars.isEmpty {
                    Section("\(account.title) [\(prefs.badge(for: account))]") {
                        ForEach(calendars) { calendar in
                            Text(calendar.title).tag(Optional(calendar.id))
                        }
                    }
                }
            }
        }
        .labelsHidden()
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
    }

    // MARK: - Bindings

    private func binding<Value>(_ keyPath: WritableKeyPath<QuickAddDraft, Value>, _ field: Field) -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { draft[keyPath: keyPath] = $0; overridden.insert(field) }
        )
    }

    private var kindBinding: Binding<QuickAddKind> {
        Binding(
            get: { draft.kind },
            set: { kind in
                draft.kind = kind
                overridden.insert(.kind)
                reparse()
            }
        )
    }

    /// Moving the start keeps the event's length, like Calendar.app.
    private var startBinding: Binding<Date> {
        Binding(
            get: { draft.start },
            set: { newStart in
                let length = draft.end.timeIntervalSince(draft.start)
                draft.start = newStart
                draft.end = newStart.addingTimeInterval(length)
                overridden.insert(.start)
            }
        )
    }

    private var calendarBinding: Binding<String?> {
        Binding(
            get: { resolvedCalendarID },
            set: { draft.calendarID = $0; overridden.insert(.calendar) }
        )
    }

    // MARK: - Parsing and saving

    private var resolvedCalendarID: String? { draft.calendarID ?? model.defaultCalendarID(for: draft.kind) }

    private var canSave: Bool {
        !isSaving && !draft.title.trimmingCharacters(in: .whitespaces).isEmpty && resolvedCalendarID != nil
    }

    private func reparse() {
        let parser = QuickAddParser(calendar: model.calendar, now: Date())
        let parsed = parser.parse(text, calendars: model.calendars, forcedKind: overridden.contains(.kind) ? draft.kind : nil)
        var next = draft
        if !overridden.contains(.kind) { next.kind = parsed.kind }
        if !overridden.contains(.title) { next.title = parsed.title }
        if !overridden.contains(.calendar) { next.calendarID = parsed.calendarID }
        next.unmatchedCalendarToken = parsed.unmatchedCalendarToken
        if !overridden.contains(.allDay) { next.isAllDay = parsed.isAllDay }
        if !overridden.contains(.start) { next.start = parsed.start }
        if !overridden.contains(.end) {
            let parsedLength = parsed.end.timeIntervalSince(parsed.start)
            next.end = overridden.contains(.start) ? next.start.addingTimeInterval(parsedLength) : parsed.end
        }
        if !overridden.contains(.dueTime) { next.hasDueTime = parsed.hasDueTime }
        next.hasExplicitDate = parsed.hasExplicitDate
        draft = next
    }

    private func save() {
        guard canSave, let calendarID = resolvedCalendarID else { return }
        isSaving = true
        do {
            try model.save(draft, calendarID: calendarID)
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
