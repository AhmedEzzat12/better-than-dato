import DatoCore
import SwiftUI

struct AgendaScreen: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            MonthGridView()
                .padding(.bottom, 6)
            Divider()
            AgendaListView()
                .frame(height: 330)
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(phases: .down) { press in handle(press) }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        let command = press.modifiers.contains(.command)
        switch press.key {
        case .leftArrow: command ? model.showMonth(offset: -1) : model.moveSelection(byDays: -1)
        case .rightArrow: command ? model.showMonth(offset: 1) : model.moveSelection(byDays: 1)
        case .upArrow: model.moveSelection(byDays: -7)
        case .downArrow: model.moveSelection(byDays: 7)
        case "t" where !command: model.goToToday()
        default: return .ignored
        }
        return .handled
    }
}

struct HeaderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Text(model.monthTitle)
                .font(.headline)
            Spacer()
            Button { model.showMonth(offset: -1) } label: { Image(systemName: "chevron.left") }
                .help("Previous month (⌘←)")
            Button("Today") { model.goToToday() }
                .help("Today (T)")
            Button { model.showMonth(offset: 1) } label: { Image(systemName: "chevron.right") }
                .help("Next month (⌘→)")
            Button { model.isPinned.toggle() } label: { Image(systemName: model.isPinned ? "pin.fill" : "pin") }
                .help("Keep open (⌘P)")
                .keyboardShortcut("p")
            Button { model.openSettings() } label: { Image(systemName: "gearshape") }
                .help("Settings (⌘,)")
                .keyboardShortcut(",")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}
