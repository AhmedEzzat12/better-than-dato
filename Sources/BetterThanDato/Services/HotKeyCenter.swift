import Carbon

/// Global hotkeys via Carbon's RegisterEventHotKey (works without Accessibility permission).
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    enum Action: UInt32, CaseIterable {
        case quickAdd = 1
        case joinMeeting = 2
    }

    private var hotKeys: [Action: EventHotKeyRef] = [:]
    private var handlers: [Action: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private static let signature = OSType(0x4254_4454) // "BTDT"

    func setHandler(for action: Action, _ handler: @escaping () -> Void) {
        handlers[action] = handler
    }

    /// Replaces the shortcut for `action`. nil clears it. Returns false if macOS refused the combo.
    @discardableResult
    func register(_ action: Action, combo: KeyCombo?) -> Bool {
        if let existing = hotKeys.removeValue(forKey: action) { UnregisterEventHotKey(existing) }
        guard let combo else { return true }
        installEventHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: action.rawValue)
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        hotKeys[action] = ref
        return true
    }

    fileprivate func fire(_ rawValue: UInt32) {
        guard let action = Action(rawValue: rawValue) else { return }
        handlers[action]?()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr else { return status }
            let rawValue = hotKeyID.id
            Task { @MainActor in HotKeyCenter.shared.fire(rawValue) }
            return noErr
        }, 1, &spec, nil, &eventHandler)
    }
}
