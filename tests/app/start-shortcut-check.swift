// Copyright (C) 2026 Antti Käenmäki

import AppKit
import Carbon
import Foundation

// The start shortcut check: the rules, labels, Carbon and Cocoa values,
// menu key equivalents, storage, the default and the on/off rule, modes,
// lengths and texts of StartShortcut.swift, and the menu's time to add from
// PickerSettings.swift. Built with those two files alone, as CI does:
//
//   swiftc -target arm64-apple-macos12.5 -parse-as-library \
//     app/AwakeStatusApp/Sources/StartShortcut.swift app/AwakeStatusApp/Sources/PickerSettings.swift \
//     tests/app/start-shortcut-check.swift -o start-shortcut-check
//
// Carbon and AppKit are imported only for their constants, which the
// model repeats as plain numbers so that the app's Settings window and
// its check share one Foundation-only file.

/// The outcome of every check.
final class ShortcutCheckLog {
    private(set) var passed = 0
    private(set) var failures: [String] = []

    func expect(_ condition: Bool, _ description: String) {
        if condition {
            passed += 1
        } else {
            failures.append(description)
        }
    }

    func expectEqual<Value: Equatable>(_ actual: Value, _ expected: Value, _ description: String) {
        if actual == expected {
            passed += 1
        } else {
            failures.append("\(description): got \(String(describing: actual)), expected \(String(describing: expected))")
        }
    }
}

@main
struct StartShortcutCheck {
    typealias Modifiers = StartShortcut.Modifiers
    typealias Problem = StartShortcut.Problem
    typealias Request = StartShortcut.StartRequest

    static let controlOptionCommand: Modifiers = [.control, .option, .command]

    static func main() {
        let log = ShortcutCheckLog()
        checkModifierRule(log)
        checkOtherRules(log)
        checkText(log)
        checkLabels(log)
        checkCarbonAndCocoa(log)
        checkMenuKeys(log)
        checkPropertyList(log)
        checkDefault(log)
        checkModes(log)
        checkStartRequests(log)
        checkAddTime(log)
        checkMessages(log)

        if log.failures.isEmpty {
            print("Start shortcut check: all \(log.passed) checks passed.")
        } else {
            for failure in log.failures {
                print("FAIL: \(failure)")
            }
            print("Start shortcut check: \(log.failures.count) of \(log.passed + log.failures.count) checks failed.")
            exit(1)
        }
    }

    static func make(_ keyCode: Int, _ modifiers: Modifiers, _ keyLabel: String) -> StartShortcut {
        StartShortcut(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
    }

    static func labelOf(_ keyCode: Int, _ characters: String?) -> String {
        StartShortcut.label(forKeyCode: keyCode, characters: characters)
    }

    // MARK: Rules

    /// Rule 1: two or more modifiers, one of them ⌃ or ⌘.
    static func checkModifierRule(_ log: ShortcutCheckLog) {
        let allowed: [(modifiers: Modifiers, keyCode: Int, label: String, name: String)] = [
            ([.control, .option, .command], kVK_ANSI_A, "A", "⌃⌥⌘A"),
            ([.control, .command], kVK_ANSI_A, "A", "⌃⌘A"),
            ([.option, .command], kVK_ANSI_A, "A", "⌥⌘A"),
            ([.shift, .command], kVK_ANSI_A, "A", "⇧⌘A"),
            ([.control, .option], kVK_ANSI_A, "A", "⌃⌥A"),
            ([.control, .shift], kVK_F5, "F5", "⌃⇧F5"),
            ([.option, .shift, .command], kVK_ANSI_A, "A", "⌥⇧⌘A"),
            (Modifiers.all, kVK_ANSI_A, "A", "⌃⌥⇧⌘A"),
            ([.control, .option, .command], kVK_Space, "Space", "⌃⌥⌘Space"),
            ([.control, .option, .command], kVK_Return, "↩", "⌃⌥⌘↩"),
        ]
        for entry in allowed {
            let shortcut = make(entry.keyCode, entry.modifiers, entry.label)
            log.expect(shortcut.problem(macOSShortcuts: []) == nil, "rule 1: \(entry.name) is allowed")
            log.expectEqual(shortcut.displayText, entry.name, "rule 1: \(entry.name) is shown as such")
        }

        let refused: [(modifiers: Modifiers, keyCode: Int, label: String, name: String)] = [
            ([], kVK_ANSI_A, "A", "A"),
            ([.command], kVK_ANSI_A, "A", "⌘A"),
            ([.control], kVK_ANSI_A, "A", "⌃A"),
            ([.option], kVK_ANSI_A, "A", "⌥A"),
            ([.shift], kVK_ANSI_A, "A", "⇧A"),
            ([.option, .shift], kVK_ANSI_A, "A", "⌥⇧A"),
            ([.shift], kVK_F5, "F5", "⇧F5"),
            ([], kVK_F5, "F5", "F5"),
            ([.command], kVK_Space, "Space", "⌘Space"),
        ]
        for entry in refused {
            log.expectEqual(make(entry.keyCode, entry.modifiers, entry.label).problem(macOSShortcuts: []), Problem.needsModifiers, "rule 1: \(entry.name) is refused")
        }

        // Bits beyond the four modifiers, which only a damaged value has.
        log.expectEqual(StartShortcut.basicProblem(keyCode: kVK_ANSI_A, modifiers: Modifiers(rawValue: 16 | 9)), Problem.needsModifiers, "rule 1: an unknown modifier bit is refused")
    }

    /// Rules 2 to 4, and keys that cannot be recorded.
    static func checkOtherRules(_ log: ShortcutCheckLog) {
        let macOS: [(keyCode: Int, modifiers: Modifiers)] = [
            (kVK_ANSI_3, [.shift, .command]),
            (kVK_ANSI_D, [.option, .command]),
            (kVK_UpArrow, [.control]),
        ]
        log.expectEqual(make(kVK_ANSI_3, [.shift, .command], "3").problem(macOSShortcuts: macOS), Problem.usedByMacOS, "rule 2: ⇧⌘3 in macOS's list is refused")
        log.expectEqual(make(kVK_ANSI_D, [.option, .command], "D").problem(macOSShortcuts: macOS), Problem.usedByMacOS, "rule 2: ⌥⌘D in macOS's list is refused")
        log.expectEqual(make(kVK_ANSI_3, [.shift, .command], "\"").problem(macOSShortcuts: macOS), Problem.usedByMacOS, "rule 2: macOS's list is matched by key code, whatever the label")
        log.expect(make(kVK_ANSI_3, [.control, .shift, .command], "3").problem(macOSShortcuts: macOS) == nil, "rule 2: the same key with other modifiers is allowed")
        log.expect(make(kVK_ANSI_4, [.shift, .command], "4").problem(macOSShortcuts: macOS) == nil, "rule 2: another key with the same modifiers is allowed")
        log.expect(make(kVK_ANSI_3, [.shift, .command], "3").problem(macOSShortcuts: []) == nil, "rule 2: ⇧⌘3 is allowed when macOS does not list it")
        // Rule 1 is reported first, also for a shortcut macOS lists.
        log.expectEqual(make(kVK_UpArrow, [.control], "↑").problem(macOSShortcuts: macOS), Problem.needsModifiers, "rule 2: rule 1 is reported first")

        let expectedStandard = ["⇧⌘Z", "⇧⌘Q", "⌥⇧⌘Q", "⌃⌘F", "⌃⌘Q", "⌃⌘Space"]
        log.expectEqual(StartShortcut.standardShortcuts.map { $0.modifiers.symbols + $0.keyLabel }, expectedStandard, "rule 3: the standard shortcuts")
        for entry in StartShortcut.standardShortcuts {
            // Matched by label, so the key code does not matter.
            let keyCode = entry.keyLabel == "Space" ? kVK_Space : kVK_ANSI_A
            let shortcut = make(keyCode, entry.modifiers, entry.keyLabel)
            log.expectEqual(shortcut.problem(macOSShortcuts: []), Problem.standardShortcut, "rule 3: \(shortcut.displayText) is refused")
        }
        log.expectEqual(make(kVK_ANSI_Z, [.shift, .command], "z").problem(macOSShortcuts: []), Problem.standardShortcut, "rule 3: matched whatever the case of the label")
        // On a French layout, the key in the ANSI W position types Z.
        log.expectEqual(make(kVK_ANSI_W, [.shift, .command], "Z").problem(macOSShortcuts: []), Problem.standardShortcut, "rule 3: matched by label on another layout")
        log.expect(make(kVK_ANSI_Z, [.shift, .command], "W").problem(macOSShortcuts: []) == nil, "rule 3: the ANSI Z key typing W is allowed")
        log.expect(make(kVK_ANSI_Z, [.control, .shift, .command], "Z").problem(macOSShortcuts: []) == nil, "rule 3: ⌃⇧⌘Z is allowed")
        log.expect(make(kVK_ANSI_F, [.option, .command], "F").problem(macOSShortcuts: []) == nil, "rule 3: ⌥⌘F is allowed")

        let escapes: [Modifiers] = [[], [.command], [.control, .option, .command], Modifiers.all]
        for modifiers in escapes {
            log.expectEqual(make(kVK_Escape, modifiers, "Esc").problem(macOSShortcuts: []), Problem.escape, "rule 4: \(modifiers.symbols)Esc is refused")
        }

        for keyCode in [-1, 128, 1000] + Array(StartShortcut.modifierKeyCodes) {
            log.expectEqual(StartShortcut.basicProblem(keyCode: keyCode, modifiers: controlOptionCommand), Problem.invalidKey, "key code \(keyCode) is refused")
        }
        log.expectEqual(StartShortcut.basicProblem(keyCode: 200, modifiers: []), Problem.invalidKey, "an invalid key is reported before the modifiers")
        // Delete and Forward Delete no longer clear the shortcut: alone, they
        // are keys without modifiers.
        for keyCode in [kVK_Delete, kVK_ForwardDelete] {
            let key = make(keyCode, [], labelOf(keyCode, nil))
            log.expectEqual(key.problem(macOSShortcuts: []), Problem.needsModifiers, "\(key.keyLabel) alone is refused like any key")
        }
        log.expect(StartShortcut.basicProblem(keyCode: 0, modifiers: controlOptionCommand) == nil, "key code 0 (A) is a key")
        log.expect(StartShortcut.basicProblem(keyCode: 127, modifiers: controlOptionCommand) == nil, "key code 127 is a key")
    }

    // MARK: Showing it

    static func checkText(_ log: ShortcutCheckLog) {
        // An independent list in macOS's order, for all 15 sets.
        let order: [(modifier: Modifiers, symbol: String, name: String)] = [
            (.control, "⌃", "Control"),
            (.option, "⌥", "Option"),
            (.shift, "⇧", "Shift"),
            (.command, "⌘", "Command"),
        ]
        for raw in 1...15 {
            let modifiers = Modifiers(rawValue: raw)
            var symbols = ""
            var names: [String] = []
            for entry in order where modifiers.contains(entry.modifier) {
                symbols += entry.symbol
                names.append(entry.name)
            }
            let shortcut = make(kVK_ANSI_A, modifiers, "A")
            log.expectEqual(shortcut.displayText, symbols + "A", "display text of modifier set \(raw)")
            log.expectEqual(shortcut.spokenText, (names + ["A"]).joined(separator: " "), "spoken text of modifier set \(raw)")
            log.expectEqual(modifiers.count, names.count, "count of modifier set \(raw)")
        }
        log.expectEqual(Modifiers.all.symbols, "⌃⌥⇧⌘", "all four modifiers, in macOS's order")
        log.expectEqual(Modifiers([]).symbols, "", "no modifiers")
        log.expectEqual(Modifiers([]).count, 0, "no modifiers: count")
        log.expectEqual(make(kVK_ANSI_A, controlOptionCommand, "A").spokenText, "Control Option Command A", "spoken text of ⌃⌥⌘A")
        log.expectEqual(make(kVK_Return, [.control, .command], "↩").spokenText, "Control Command Return", "spoken text names a special key")
        log.expectEqual(make(kVK_F5, [.control, .shift], "F5").spokenText, "Control Shift F5", "spoken text of a function key")
        log.expectEqual(make(kVK_ANSI_Semicolon, controlOptionCommand, "Ö").displayText, "⌃⌥⌘Ö", "display text of a Finnish Ö")
    }

    static func checkLabels(_ log: ShortcutCheckLog) {
        let special: [(keyCode: Int, label: String, name: String)] = [
            (kVK_Return, "↩", "Return"),
            (kVK_ANSI_KeypadEnter, "⌤", "Enter"),
            (kVK_Tab, "⇥", "Tab"),
            (kVK_Space, "Space", "Space"),
            (kVK_Delete, "⌫", "Delete"),
            (kVK_ForwardDelete, "⌦", "Forward Delete"),
            (kVK_LeftArrow, "←", "Left Arrow"),
            (kVK_RightArrow, "→", "Right Arrow"),
            (kVK_UpArrow, "↑", "Up Arrow"),
            (kVK_DownArrow, "↓", "Down Arrow"),
            (kVK_Home, "↖", "Home"),
            (kVK_End, "↘", "End"),
            (kVK_PageUp, "⇞", "Page Up"),
            (kVK_PageDown, "⇟", "Page Down"),
        ]
        for entry in special {
            log.expectEqual(labelOf(entry.keyCode, "x"), entry.label, "label of \(entry.name), whatever its characters")
            log.expectEqual(StartShortcut.specialKeys[entry.keyCode]?.name, entry.name, "spoken name of \(entry.name)")
        }

        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        log.expectEqual(StartShortcut.functionKeyCodes, functionKeys, "function key codes are Carbon's kVK_F1 to kVK_F20")
        for (index, keyCode) in functionKeys.enumerated() {
            log.expectEqual(labelOf(keyCode, "\u{F704}"), "F\(index + 1)", "label of F\(index + 1)")
            log.expectEqual(StartShortcut.specialKeys[keyCode]?.name, "F\(index + 1)", "spoken name of F\(index + 1)")
        }
        log.expectEqual(StartShortcut.specialKeys.count, special.count + functionKeys.count, "no other special keys")

        log.expectEqual(labelOf(kVK_ANSI_A, "a"), "A", "a letter is uppercased")
        log.expectEqual(labelOf(kVK_ANSI_Semicolon, "ö"), "Ö", "a Finnish layout's Ö")
        log.expectEqual(labelOf(kVK_ANSI_Minus, "ß"), "ß", "ß, which has no one-letter capital, stays")
        log.expectEqual(labelOf(kVK_ANSI_1, "1"), "1", "a digit")
        log.expectEqual(labelOf(kVK_ANSI_Grave, "§"), "§", "a symbol")
        log.expectEqual(labelOf(kVK_ANSI_A, ""), "Key 0", "no characters")
        log.expectEqual(labelOf(kVK_ANSI_A, nil), "Key 0", "no characters at all")
        log.expectEqual(labelOf(kVK_Help, "\u{F746}"), "Key 114", "a private-use character, such as Help's")
        log.expectEqual(labelOf(kVK_ANSI_A, "\t"), "Key 0", "a control character")
        log.expectEqual(labelOf(kVK_ANSI_A, " "), "Key 0", "a space from a key other than Space")
        log.expectEqual(labelOf(kVK_ANSI_A, "abcde"), "Key 0", "more than four characters")
        log.expectEqual(labelOf(kVK_Return, "\r"), "↩", "Return ignores its characters")
    }

    static func checkCarbonAndCocoa(_ log: ShortcutCheckLog) {
        log.expectEqual(Modifiers.control.carbonFlags, UInt32(controlKey), "Carbon: controlKey")
        log.expectEqual(Modifiers.option.carbonFlags, UInt32(optionKey), "Carbon: optionKey")
        log.expectEqual(Modifiers.shift.carbonFlags, UInt32(shiftKey), "Carbon: shiftKey")
        log.expectEqual(Modifiers.command.carbonFlags, UInt32(cmdKey), "Carbon: cmdKey")
        log.expectEqual(make(kVK_ANSI_A, controlOptionCommand, "A").carbonModifiers, UInt32(controlKey | optionKey | cmdKey), "Carbon: the modifiers of ⌃⌥⌘A")
        for raw in 0...15 {
            let modifiers = Modifiers(rawValue: raw)
            log.expectEqual(Modifiers(carbonFlags: modifiers.carbonFlags), modifiers, "Carbon: round trip of modifier set \(raw)")
            log.expectEqual(Modifiers(cocoaFlags: cocoaFlags(of: modifiers)), modifiers, "Cocoa: round trip of modifier set \(raw)")
        }
        log.expectEqual(Modifiers(carbonFlags: UInt32(cmdKey | alphaLock | btnState)), Modifiers.command, "Carbon: Caps Lock and other flags are ignored")

        log.expectEqual(Modifiers(cocoaFlags: NSEvent.ModifierFlags.control.rawValue), Modifiers.control, "Cocoa: control")
        log.expectEqual(Modifiers(cocoaFlags: NSEvent.ModifierFlags.option.rawValue), Modifiers.option, "Cocoa: option")
        log.expectEqual(Modifiers(cocoaFlags: NSEvent.ModifierFlags.shift.rawValue), Modifiers.shift, "Cocoa: shift")
        log.expectEqual(Modifiers(cocoaFlags: NSEvent.ModifierFlags.command.rawValue), Modifiers.command, "Cocoa: command")
        let ignored: NSEvent.ModifierFlags = [.command, .capsLock, .function, .numericPad, .help]
        log.expectEqual(Modifiers(cocoaFlags: ignored.rawValue), Modifiers.command, "Cocoa: Caps Lock, fn, the keypad and Help are ignored")

        log.expectEqual(StartShortcut.escapeKeyCode, kVK_Escape, "Carbon: kVK_Escape")
        log.expectEqual(StartShortcut.ansiAKeyCode, kVK_ANSI_A, "Carbon: kVK_ANSI_A")
        let modifierKeys = [
            kVK_RightCommand, kVK_Command, kVK_Shift, kVK_CapsLock, kVK_Option,
            kVK_Control, kVK_RightShift, kVK_RightOption, kVK_RightControl, kVK_Function,
        ]
        log.expectEqual(Array(StartShortcut.modifierKeyCodes), modifierKeys.sorted(), "Carbon: the modifier keys' codes")
    }

    /// The shortcut as a menu item's key equivalent, against AppKit's own
    /// characters.
    static func checkMenuKeys(_ log: ShortcutCheckLog) {
        for raw in 0...15 {
            let modifiers = Modifiers(rawValue: raw)
            log.expectEqual(modifiers.cocoaFlags, cocoaFlags(of: modifiers), "menu: Cocoa flags of modifier set \(raw)")
        }

        func character(_ value: Int) -> String? {
            UnicodeScalar(UInt32(value)).map { String(Character($0)) }
        }
        let special: [(keyCode: Int, expected: Int, name: String)] = [
            (kVK_Return, NSCarriageReturnCharacter, "Return"),
            (kVK_ANSI_KeypadEnter, NSEnterCharacter, "Enter"),
            (kVK_Tab, NSTabCharacter, "Tab"),
            (kVK_Space, 0x20, "Space"),
            (kVK_Delete, NSBackspaceCharacter, "Delete"),
            (kVK_ForwardDelete, NSDeleteFunctionKey, "Forward Delete"),
            (kVK_LeftArrow, NSLeftArrowFunctionKey, "Left Arrow"),
            (kVK_RightArrow, NSRightArrowFunctionKey, "Right Arrow"),
            (kVK_UpArrow, NSUpArrowFunctionKey, "Up Arrow"),
            (kVK_DownArrow, NSDownArrowFunctionKey, "Down Arrow"),
            (kVK_Home, NSHomeFunctionKey, "Home"),
            (kVK_End, NSEndFunctionKey, "End"),
            (kVK_PageUp, NSPageUpFunctionKey, "Page Up"),
            (kVK_PageDown, NSPageDownFunctionKey, "Page Down"),
        ]
        for entry in special {
            let shortcut = make(entry.keyCode, controlOptionCommand, labelOf(entry.keyCode, nil))
            log.expectEqual(shortcut.menuKeyEquivalent, character(entry.expected), "menu: \(entry.name)")
        }
        for (index, keyCode) in StartShortcut.functionKeyCodes.enumerated() {
            log.expectEqual(make(keyCode, [.control, .shift], "F\(index + 1)").menuKeyEquivalent, character(NSF1FunctionKey + index), "menu: F\(index + 1)")
        }
        log.expectEqual(StartShortcut.menuKeyCharacters.count, special.count + StartShortcut.functionKeyCodes.count, "menu: a character for every special key")
        for keyCode in StartShortcut.specialKeys.keys {
            log.expect(StartShortcut.menuKeyCharacters[keyCode] != nil, "menu: special key \(keyCode) has a character")
        }

        log.expectEqual(StartShortcut.defaultShortcut().menuKeyEquivalent, "a", "menu: ⇧⌘A is a, with Shift in the modifiers")
        log.expectEqual(make(kVK_ANSI_Semicolon, controlOptionCommand, "Ö").menuKeyEquivalent, "ö", "menu: a Finnish Ö")
        log.expectEqual(make(kVK_ANSI_1, controlOptionCommand, "1").menuKeyEquivalent, "1", "menu: a digit")
        log.expectEqual(make(kVK_ANSI_Minus, controlOptionCommand, "ß").menuKeyEquivalent, "ß", "menu: ß stays")
        log.expect(make(kVK_Help, controlOptionCommand, "Key 114").menuKeyEquivalent == nil, "menu: a key without a character has none")
        log.expect(make(kVK_ANSI_A, controlOptionCommand, "AB").menuKeyEquivalent == nil, "menu: a label of more than one character has none")
    }

    /// `NSEvent.ModifierFlags` for a modifier set, from AppKit's own values.
    static func cocoaFlags(of modifiers: Modifiers) -> UInt {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) {
            flags.insert(.control)
        }
        if modifiers.contains(.option) {
            flags.insert(.option)
        }
        if modifiers.contains(.shift) {
            flags.insert(.shift)
        }
        if modifiers.contains(.command) {
            flags.insert(.command)
        }
        return flags.rawValue
    }

    // MARK: Storage

    static func checkPropertyList(_ log: ShortcutCheckLog) {
        let shortcut = make(kVK_ANSI_A, controlOptionCommand, "A")
        let stored = shortcut.propertyList
        log.expectEqual(stored["keyCode"] as? Int, 0, "property list: keyCode")
        log.expectEqual(stored["modifiers"] as? Int, 11, "property list: ⌃⌥⌘ is 11")
        log.expectEqual(stored["keyLabel"] as? String, "A", "property list: keyLabel")
        log.expectEqual(stored.count, 3, "property list: three fields")
        log.expectEqual(StartShortcut(propertyList: stored), shortcut, "property list: round trip")

        // UserDefaults stores it as a property list; read it back the same
        // way, with its numbers as NSNumber.
        let finnish = make(kVK_ANSI_Semicolon, [.control, .shift, .command], "Ö")
        for original in [shortcut, finnish, make(kVK_F20, [.control, .option], "F20")] {
            if let data = try? PropertyListSerialization.data(fromPropertyList: original.propertyList, format: .binary, options: 0),
               let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let read = object as? [String: Any] {
                log.expectEqual(StartShortcut(propertyList: read), original, "property list: \(original.displayText) through a binary property list")
            } else {
                log.expect(false, "property list: \(original.displayText) could not be serialized")
            }
        }

        let sixteen = String(repeating: "W", count: 16)
        var longest = stored
        longest["keyLabel"] = sixteen
        log.expectEqual(StartShortcut(propertyList: longest)?.keyLabel, sixteen, "property list: a 16-character label is kept")

        let damaged: [(key: String, value: Any?, description: String)] = [
            ("keyCode", -1, "a negative key code"),
            ("keyCode", 128, "a key code above 127"),
            ("keyCode", kVK_Command, "the Command key"),
            ("keyCode", kVK_Escape, "Esc"),
            ("keyCode", "0", "a key code as text"),
            ("keyCode", nil, "a missing key code"),
            ("modifiers", 16, "an unknown modifier bit"),
            ("modifiers", 27, "an unknown modifier bit with ⌃⌥⌘"),
            ("modifiers", -1, "negative modifiers"),
            ("modifiers", 1, "⌃ alone"),
            ("modifiers", 8, "⌘ alone"),
            ("modifiers", 6, "⌥⇧, without ⌃ or ⌘"),
            ("modifiers", "11", "modifiers as text"),
            ("modifiers", nil, "missing modifiers"),
            ("keyLabel", "", "an empty label"),
            ("keyLabel", String(repeating: "W", count: 17), "a 17-character label"),
            ("keyLabel", 5, "a label that is a number"),
            ("keyLabel", nil, "a missing label"),
        ]
        for entry in damaged {
            var dictionary = stored
            dictionary[entry.key] = entry.value
            log.expect(StartShortcut(propertyList: dictionary) == nil, "property list: \(entry.description) is not a shortcut")
        }
        let empty: [String: Any] = [:]
        log.expect(StartShortcut(propertyList: empty) == nil, "property list: an empty dictionary is not a shortcut")
        // macOS's shortcuts and the standard ones are not checked again.
        log.expectEqual(StartShortcut(propertyList: make(kVK_ANSI_Z, [.shift, .command], "Z").propertyList)?.displayText, "⇧⌘Z", "property list: a standard shortcut stored earlier is kept")
    }

    /// ⇧⌘A, the shortcut until another is recorded, and whether the
    /// shortcut is on.
    static func checkDefault(_ log: ShortcutCheckLog) {
        let standard = StartShortcut.defaultShortcut()
        log.expectEqual(standard, make(kVK_ANSI_A, [.shift, .command], "A"), "default: ⇧⌘ with the ANSI A key")
        log.expectEqual(standard.displayText, "⇧⌘A", "default: shown as ⇧⌘A")
        log.expectEqual(standard.spokenText, "Shift Command A", "default: spoken")
        log.expectEqual(standard.carbonModifiers, UInt32(shiftKey | cmdKey), "default: Carbon's modifiers")
        log.expect(standard.problem(macOSShortcuts: []) == nil, "default: keeps every rule")
        log.expectEqual(standard.propertyList["modifiers"] as? Int, 12, "default: ⇧⌘ is 12")
        log.expectEqual(StartShortcut(propertyList: standard.propertyList), standard, "default: property list round trip")
        log.expectEqual(StartShortcut.defaultShortcut(keyCode: nil), standard, "default: no key code gives the ANSI A key")

        // On an AZERTY layout, the ANSI Q key types A.
        let azerty = StartShortcut.defaultShortcut(keyCode: kVK_ANSI_Q)
        log.expectEqual(azerty, make(kVK_ANSI_Q, [.shift, .command], "A"), "default: the key that types A, on AZERTY")
        log.expectEqual(azerty.displayText, "⇧⌘A", "default: shown as ⇧⌘A on AZERTY")
        log.expect(azerty.problem(macOSShortcuts: []) == nil, "default: keeps every rule on AZERTY")
        for keyCode in [-1, 128, kVK_Escape, kVK_Command, kVK_Function] {
            log.expectEqual(StartShortcut.defaultShortcut(keyCode: keyCode), standard, "default: key code \(keyCode) gives the ANSI A key")
        }

        let enabled: [(stored: Bool?, hasShortcut: Bool, expected: Bool, description: String)] = [
            (nil, false, false, "nothing stored is off"),
            (nil, true, true, "a shortcut from 2.2.0, without the setting, is on"),
            (true, true, true, "on"),
            (true, false, true, "on before ⇧⌘A is stored"),
            (false, true, false, "off, keeping the shortcut"),
            (false, false, false, "off"),
        ]
        for entry in enabled {
            log.expectEqual(StartShortcut.isEnabled(storedFlag: entry.stored, hasStoredShortcut: entry.hasShortcut), entry.expected, "on/off: \(entry.description)")
        }
    }

    static func checkModes(_ log: ShortcutCheckLog) {
        log.expectEqual(StartShortcutMode(storedValue: nil), .lidOpen, "mode: none is lid-open with the display on")
        log.expectEqual(StartShortcutMode(storedValue: "lid-open"), .lidOpen, "mode: lid-open")
        log.expectEqual(StartShortcutMode(storedValue: "lid-open-display-sleeps"), .lidOpenDisplaySleeps, "mode: lid-open-display-sleeps")
        log.expectEqual(StartShortcutMode(storedValue: "lid-closed"), .lidClosed, "mode: lid-closed")
        log.expectEqual(StartShortcutMode(storedValue: "Lid-closed"), .lidOpen, "mode: an unknown value is lid-open")
        log.expectEqual(StartShortcutMode(storedValue: ""), .lidOpen, "mode: an empty value is lid-open")

        log.expectEqual(StartShortcutMode.allCases.map { $0.rawValue }, ["lid-open", "lid-open-display-sleeps", "lid-closed"], "mode: stored values, in the pop-up's order")
        log.expectEqual(StartShortcutMode.allCases.map { $0.title }, ["Lid-open, display on", "Lid-open, display can sleep", "Lid-closed"], "mode: pop-up titles")
        log.expectEqual(StartShortcutMode.allCases.map { $0.isLidClosed }, [false, false, true], "mode: lid-closed")
        log.expectEqual(StartShortcutMode.allCases.map { $0.keepsDisplayOn }, [true, false, true], "mode: display choice")
    }

    static func checkStartRequests(_ log: ShortcutCheckLog) {
        log.expectEqual(StartShortcut.startRequest(defaultToken: "1200"), Request(durationSeconds: 1200, endArguments: []), "length: 20 minutes")
        log.expectEqual(StartShortcut.startRequest(defaultToken: "60"), Request(durationSeconds: 60, endArguments: []), "length: 1 minute, the shortest")
        log.expectEqual(StartShortcut.startRequest(defaultToken: "31536000"), Request(durationSeconds: 31_536_000, endArguments: []), "length: 365 days, the longest")
        log.expectEqual(StartShortcut.startRequest(defaultToken: PickerSettings.indefiniteToken), Request(durationSeconds: nil, endArguments: ["--indefinite"]), "length: Indefinitely")
        log.expectEqual(StartShortcut.startRequest(defaultToken: "90"), Request(durationSeconds: 1200, endArguments: []), "length: not whole minutes falls back to 20 minutes")
        log.expectEqual(StartShortcut.startRequest(defaultToken: "31536060"), Request(durationSeconds: 1200, endArguments: []), "length: over 365 days falls back to 20 minutes")
        log.expectEqual(StartShortcut.startRequest(defaultToken: ""), Request(durationSeconds: 1200, endArguments: []), "length: no token falls back to 20 minutes")

        // What PickerSettings.load() gives, as the app will call it.
        let suiteName = "net.kaenmaki.awake.start-shortcut-check.\(ProcessInfo.processInfo.processIdentifier)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            log.expect(false, "length: a UserDefaults suite for the check")
            return
        }
        defaults.set("600 3600 indefinite", forKey: PickerSettings.durationsKey)
        defaults.set("indefinite", forKey: PickerSettings.defaultKey)
        log.expectEqual(StartShortcut.startRequest(defaultToken: PickerSettings.load(from: defaults).defaultToken), Request(durationSeconds: nil, endArguments: ["--indefinite"]), "length: a stored Indefinitely")
        defaults.set("3600", forKey: PickerSettings.defaultKey)
        log.expectEqual(StartShortcut.startRequest(defaultToken: PickerSettings.load(from: defaults).defaultToken), Request(durationSeconds: 3600, endArguments: []), "length: a stored hour")
        defaults.removeObject(forKey: PickerSettings.defaultKey)
        log.expectEqual(StartShortcut.startRequest(defaultToken: PickerSettings.load(from: defaults).defaultToken), Request(durationSeconds: 600, endArguments: []), "length: no stored default gives the first length")
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// What Add in the menu bar menu adds, and the choices for it.
    static func checkAddTime(_ log: ShortcutCheckLog) {
        log.expectEqual(PickerSettings.defaultAddSeconds, 3600, "add: an hour by default")
        log.expectEqual(PickerSettings.resolvedAddSeconds(stored: nil), 3600, "add: nothing stored is an hour")
        log.expectEqual(PickerSettings.resolvedAddSeconds(stored: 1800), 1800, "add: 30 minutes")
        log.expectEqual(PickerSettings.resolvedAddSeconds(stored: 31_536_000), 31_536_000, "add: 365 days, the longest")
        for stored in [0, -3600, 90, 30, 31_536_060] {
            log.expectEqual(PickerSettings.resolvedAddSeconds(stored: stored), 3600, "add: \(stored) seconds is not a length, so an hour")
        }
        let lengths = PickerSettings.builtinLengths
        log.expectEqual(PickerSettings.addChoices(lengths: lengths, current: 3600), lengths, "add: a listed time gives the list")
        log.expectEqual(PickerSettings.addChoices(lengths: [600, 7200], current: 3600), [600, 3600, 7200], "add: a time no longer listed keeps its place")
        log.expectEqual(PickerSettings.addChoices(lengths: [600], current: 86400), [600, 86400], "add: a longer time goes last")
        log.expectEqual(PickerSettings.lengthLabel(seconds: 5400), "1 hour 30 minutes", "add: the menu item's label")
    }

    // MARK: Texts

    static func checkMessages(_ log: ShortcutCheckLog) {
        let shortcut = make(kVK_ANSI_A, controlOptionCommand, "A")
        log.expectEqual(shortcut.message(for: .needsModifiers), "Use two or more modifier keys, including ⌃ or ⌘.", "message: rule 1")
        log.expectEqual(make(kVK_ANSI_3, [.shift, .command], "3").message(for: .usedByMacOS), "macOS uses ⇧⌘3. Choose another shortcut.", "message: rule 2")
        log.expectEqual(make(kVK_ANSI_Z, [.shift, .command], "Z").message(for: .standardShortcut), "⇧⌘Z is a standard shortcut in most apps. Choose another.", "message: rule 3")
        log.expectEqual(shortcut.message(for: .escape), "Esc cannot be part of a shortcut, as it cancels recording.", "message: rule 4")
        log.expectEqual(shortcut.message(for: .invalidKey), "This key cannot be part of a shortcut. Choose another.", "message: an invalid key")
        log.expectEqual(StartShortcut.recordingHint, "Press two or more modifier keys, including ⌃ or ⌘, together with a key, for example ⌃⌥⌘A. Esc cancels.", "message: the recording hint")

        log.expectEqual(shortcut.registrationFailureMessage(takenByAnotherApp: true, status: -9878), "Another app uses ⌃⌥⌘A. Choose another shortcut.", "message: taken by another app")
        log.expectEqual(shortcut.registrationFailureMessage(takenByAnotherApp: false, status: -9868), "macOS did not accept ⌃⌥⌘A (error -9868). Choose another shortcut.", "message: refused by macOS")
        log.expectEqual(shortcut.launchFailureMessage(takenByAnotherApp: true, status: -9878), "The keyboard shortcut ⌃⌥⌘A is not available, as another app uses it. Choose another in Awake's Settings.", "message: at launch, taken by another app")
        log.expectEqual(shortcut.launchFailureMessage(takenByAnotherApp: false, status: -9868), "The keyboard shortcut ⌃⌥⌘A is not available, as macOS did not accept it (error -9868). Choose another in Awake's Settings.", "message: at launch, refused by macOS")

        log.expectEqual(StartShortcut.settingsNote(defaultToken: "1200", mode: .lidOpen), "From any app, starts a session of the default length, now 20 minutes, or stops the running one, like a click on the icon. Start default session in the Ctrl-click menu does the same, also while the shortcut is off.", "note: 20 minutes")
        log.expectEqual(StartShortcut.settingsNote(defaultToken: "5400", mode: .lidOpenDisplaySleeps), "From any app, starts a session of the default length, now 1 hour 30 minutes, or stops the running one, like a click on the icon. Start default session in the Ctrl-click menu does the same, also while the shortcut is off.", "note: 1 hour 30 minutes")
        log.expectEqual(StartShortcut.settingsNote(defaultToken: "indefinite", mode: .lidOpen), "From any app, starts a session without an end time, or stops the running one, like a click on the icon. Start default session in the Ctrl-click menu does the same, also while the shortcut is off.", "note: Indefinitely")
        log.expectEqual(StartShortcut.settingsNote(defaultToken: "1200", mode: .lidClosed), "From any app, starts a session of the default length, now 20 minutes, or stops the running one, like a click on the icon. Start default session in the Ctrl-click menu does the same, also while the shortcut is off. Lid-closed mode asks for your password unless Start without password is on.", "note: lid-closed")
    }
}
