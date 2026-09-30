// Copyright (C) 2026 Antti Käenmäki

import Carbon
import Foundation

/// Registers the keyboard shortcut of StartShortcut.swift with macOS, so
/// that a press reaches Awake from any app. It uses Carbon's hot keys,
/// which need no Accessibility or Input Monitoring permission, and which
/// take the key press, so the frontmost app never sees it. The only file
/// that imports Carbon.
final class StartShortcutHotKey {
    /// Why registering failed: the `OSStatus` of `RegisterEventHotKey`, or
    /// of `InstallEventHandler`.
    struct Failure: Error, Equatable {
        let status: Int

        /// Another app holds the same shortcut exclusively.
        var takenByAnotherApp: Bool {
            status == Int(eventHotKeyExistsErr)
        }
    }

    /// `AWKE`, the signature of Awake's one hot key.
    private static let signature: OSType = 0x4157_4B45
    private static let identifier: UInt32 = 1

    /// Called on the main queue for each press, with its Carbon event time,
    /// which `currentEventTime()` can be compared with.
    var onPress: ((TimeInterval) -> Void)?

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    var isRegistered: Bool {
        hotKey != nil
    }

    deinit {
        unregister()
        if let handler = handler {
            _ = RemoveEventHandler(handler)
        }
    }

    /// Registers `shortcut` in place of the one registered before, if any.
    /// Returns nil when that worked, and then nothing is registered.
    func register(_ shortcut: StartShortcut) -> Failure? {
        unregister()
        if let failure = installHandlerIfNeeded() {
            return failure
        }
        var reference: EventHotKeyRef?
        let identity = EventHotKeyID(signature: StartShortcutHotKey.signature, id: StartShortcutHotKey.identifier)
        // Exclusive, so that a shortcut another app holds the same way is
        // reported rather than shared. The dispatcher target also gets the
        // press while a menu is open.
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            identity,
            GetEventDispatcherTarget(),
            OptionBits(kEventHotKeyExclusive),
            &reference
        )
        guard status == noErr, let registered = reference else {
            return Failure(status: Int(status))
        }
        hotKey = registered
        return nil
    }

    func unregister() {
        if let registered = hotKey {
            _ = UnregisterEventHotKey(registered)
            hotKey = nil
        }
    }

    /// The handler, installed once. It runs on the main thread and only
    /// queues the press, so that no dialog opens inside a Carbon handler.
    private func installHandlerIfNeeded() -> Failure? {
        if handler != nil {
            return nil
        }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
                guard let event = event, let userData = userData else {
                    return OSStatus(eventNotHandledErr)
                }
                var identity = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identity
                )
                guard status == noErr,
                      identity.signature == StartShortcutHotKey.signature,
                      identity.id == StartShortcutHotKey.identifier else {
                    return OSStatus(eventNotHandledErr)
                }
                let time = GetEventTime(event)
                let hotKey = Unmanaged<StartShortcutHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    hotKey.onPress?(time)
                }
                return noErr
            },
            1,
            &pressed,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        if status != noErr {
            handler = nil
            return Failure(status: Int(status))
        }
        return nil
    }

    /// The shortcuts macOS keeps for itself and has turned on, such as the
    /// screenshot ones, from `CopySymbolicHotKeys`. Read when a shortcut is
    /// recorded, as the user can change them in System Settings.
    static func macOSShortcuts() -> [(keyCode: Int, modifiers: StartShortcut.Modifiers)] {
        var array: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&array) == noErr,
              let entries = array?.takeRetainedValue() as? [[String: Any]] else {
            return []
        }
        var shortcuts: [(keyCode: Int, modifiers: StartShortcut.Modifiers)] = []
        for entry in entries {
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let keyCode = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let flags = entry[kHISymbolicHotKeyModifiers as String] as? Int else {
                continue
            }
            shortcuts.append((keyCode: keyCode, modifiers: StartShortcut.Modifiers(carbonFlags: UInt32(truncatingIfNeeded: flags))))
        }
        return shortcuts
    }

    /// The key code of the key that types `character` without modifiers,
    /// such as the one that types `a`: the ANSI A key on most layouts, the
    /// ANSI Q key on AZERTY ones. It reads the current ASCII-capable
    /// layout, the one macOS uses for Command shortcuts, so a Russian layout
    /// gives the Latin layout used with it. Nil when the layout cannot be
    /// read or has no such key.
    static func keyCode(typing character: String) -> Int? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(layoutData) else {
            return nil
        }
        let wanted = character.lowercased()
        let keyboardType = UInt32(LMGetKbdType())
        let maxLength = 4
        return bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout -> Int? in
            for keyCode in 0...StartShortcut.maxKeyCode where !StartShortcut.modifierKeyCodes.contains(keyCode) {
                var deadKeyState: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: maxLength)
                let status = UCKeyTranslate(
                    layout,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &deadKeyState,
                    maxLength,
                    &length,
                    &characters
                )
                if status == noErr, length > 0, String(utf16CodeUnits: characters, count: length).lowercased() == wanted {
                    return keyCode
                }
            }
            return nil
        }
    }

    /// Carbon's clock for events, the one the times `onPress` gets use.
    static func currentEventTime() -> TimeInterval {
        GetCurrentEventTime()
    }
}
