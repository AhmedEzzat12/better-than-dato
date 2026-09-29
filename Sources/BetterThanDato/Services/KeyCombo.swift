import AppKit
import Carbon

/// A global shortcut: Carbon key code + Carbon modifier mask + the character to display.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    static let quickAddDefault = KeyCombo(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | optionKey), key: "N")
    static let joinMeetingDefault = KeyCombo(keyCode: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey | optionKey), key: "J")

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// nil unless ⌘, ⌥ or ⌃ is held — a bare key can't be a global shortcut.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: (event.charactersIgnoringModifiers ?? "?").uppercased())
    }

    var displayString: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + key
    }
}
