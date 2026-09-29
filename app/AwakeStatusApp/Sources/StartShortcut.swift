// Copyright (C) 2026 Antti Käenmäki

import Foundation

/// The keyboard shortcut that starts or stops Awake from any app, recorded
/// in the Settings window: a physical key with two or more modifier keys.
/// Stored as the property-list dictionary `startShortcut`. Foundation only,
/// so that the check (tests/app/start-shortcut-check.swift) builds it with
/// PickerSettings.swift alone.
struct StartShortcut: Equatable {
    /// The modifier keys a shortcut can use. Caps Lock and fn are never
    /// part of one: fn is how many keyboards type a function key or an
    /// arrow, not a choice.
    struct Modifiers: OptionSet {
        let rawValue: Int

        static let control = Modifiers(rawValue: 1)
        static let option = Modifiers(rawValue: 2)
        static let shift = Modifiers(rawValue: 4)
        static let command = Modifiers(rawValue: 8)
        static let all: Modifiers = [.control, .option, .shift, .command]

        /// In the order macOS shows them, ⌃ ⌥ ⇧ ⌘, with Carbon's flag for
        /// each (`controlKey`, `optionKey`, `shiftKey`, `cmdKey`) and
        /// `NSEvent.ModifierFlags`' raw value.
        static let ordered: [(modifier: Modifiers, symbol: String, name: String, carbonFlag: UInt32, cocoaFlag: UInt)] = [
            (.control, "⌃", "Control", 0x1000, 0x40000),
            (.option, "⌥", "Option", 0x0800, 0x80000),
            (.shift, "⇧", "Shift", 0x0200, 0x20000),
            (.command, "⌘", "Command", 0x0100, 0x100000),
        ]

        /// The modifiers set in Carbon flags, such as those of
        /// `CopySymbolicHotKeys`; other flags are ignored.
        init(carbonFlags: UInt32) {
            var modifiers: Modifiers = []
            for entry in Modifiers.ordered where carbonFlags & entry.carbonFlag != 0 {
                modifiers.insert(entry.modifier)
            }
            self = modifiers
        }

        /// The modifiers set in an `NSEvent.ModifierFlags` raw value; Caps
        /// Lock, fn and the others are ignored.
        init(cocoaFlags: UInt) {
            var modifiers: Modifiers = []
            for entry in Modifiers.ordered where cocoaFlags & entry.cocoaFlag != 0 {
                modifiers.insert(entry.modifier)
            }
            self = modifiers
        }

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        var count: Int {
            Modifiers.ordered.filter { contains($0.modifier) }.count
        }

        /// `⌃⌥⌘`.
        var symbols: String {
            Modifiers.ordered.filter { contains($0.modifier) }.map { $0.symbol }.joined()
        }

        /// `Control`, `Option`, `Command`, for VoiceOver.
        var names: [String] {
            Modifiers.ordered.filter { contains($0.modifier) }.map { $0.name }
        }

        var carbonFlags: UInt32 {
            Modifiers.ordered.filter { contains($0.modifier) }.reduce(0) { $0 | $1.carbonFlag }
        }
    }

    /// Why a combination cannot be the shortcut.
    enum Problem: Equatable {
        /// Not the key code of a real key, or a modifier key.
        case invalidKey
        /// Esc, which cancels recording.
        case escape
        /// Fewer than two modifiers, or neither ⌃ nor ⌘.
        case needsModifiers
        /// An enabled shortcut of macOS's own, from `CopySymbolicHotKeys`.
        case usedByMacOS
        /// One of `standardShortcuts`.
        case standardShortcut
    }

    /// The length a press starts: the Settings window's `Default selection`,
    /// as a duration or as `--indefinite`.
    struct StartRequest: Equatable {
        let durationSeconds: Int?
        let endArguments: [String]
    }

    /// The virtual key code of a physical key, as `NSEvent.keyCode` and
    /// Carbon's `kVK_` constants give it: 0 to 127.
    let keyCode: Int
    let modifiers: Modifiers
    /// The key as shown when the shortcut was recorded: `A`, `Ö`, `F5`, `↩`.
    let keyLabel: String

    // MARK: Keys

    static let maxKeyCode = 127
    static let escapeKeyCode = 0x35
    /// Right Command, Command, Shift, Caps Lock, Option, Control, Right
    /// Shift, Right Option, Right Control and fn.
    static let modifierKeyCodes = 0x36...0x3F
    /// F1 to F20, in that order.
    static let functionKeyCodes = [
        0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64, 0x65, 0x6D,
        0x67, 0x6F, 0x69, 0x6B, 0x71, 0x6A, 0x40, 0x4F, 0x50, 0x5A,
    ]
    /// A label longer than this is not one the recorder makes.
    static let maxLabelLength = 16

    /// The label and spoken name of each key that has no printable
    /// character of its own. The key codes are Carbon's `kVK_` constants,
    /// which the check compares.
    static let specialKeys: [Int: (label: String, name: String)] = {
        var keys: [Int: (label: String, name: String)] = [
            0x24: ("↩", "Return"),
            0x4C: ("⌤", "Enter"),
            0x30: ("⇥", "Tab"),
            0x31: ("Space", "Space"),
            0x33: ("⌫", "Delete"),
            0x75: ("⌦", "Forward Delete"),
            0x7B: ("←", "Left Arrow"),
            0x7C: ("→", "Right Arrow"),
            0x7E: ("↑", "Up Arrow"),
            0x7D: ("↓", "Down Arrow"),
            0x73: ("↖", "Home"),
            0x77: ("↘", "End"),
            0x74: ("⇞", "Page Up"),
            0x79: ("⇟", "Page Down"),
        ]
        for (index, keyCode) in StartShortcut.functionKeyCodes.enumerated() {
            keys[keyCode] = ("F\(index + 1)", "F\(index + 1)")
        }
        return keys
    }()

    /// The label of a key: a special key's own, otherwise `characters`, the
    /// character the key types without modifiers in the layout in use,
    /// uppercased, such as `A` or `Ö`, otherwise `Key 42`.
    static func label(forKeyCode keyCode: Int, characters: String?) -> String {
        if let special = specialKeys[keyCode] {
            return special.label
        }
        let text = characters ?? ""
        let printable = text.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) &&
                !CharacterSet.whitespacesAndNewlines.contains(scalar) &&
                !(0xE000...0xF8FF).contains(scalar.value)
        }
        guard !text.isEmpty, text.count <= 4, printable else {
            return "Key \(keyCode)"
        }
        // Some characters, such as ß, have no one-letter capital.
        let uppercased = text.uppercased()
        return uppercased.count == text.count ? uppercased : text
    }

    // MARK: Showing it

    /// `⌃⌥⌘A`: the modifiers in the order macOS shows them, then the key.
    var displayText: String {
        modifiers.symbols + keyLabel
    }

    /// `Control Option Command A`, for VoiceOver.
    var spokenText: String {
        let key = StartShortcut.specialKeys[keyCode]?.name ?? keyLabel
        return (modifiers.names + [key]).joined(separator: " ")
    }

    var carbonModifiers: UInt32 {
        modifiers.carbonFlags
    }

    // MARK: Rules

    /// Shortcuts that apps or macOS use and that `CopySymbolicHotKeys` may
    /// not list: Redo, Log Out with and without asking, Enter Full Screen,
    /// Lock Screen, and Emoji & Symbols. They are matched by label, as apps
    /// match them by the character a key types, whatever the layout.
    static let standardShortcuts: [(modifiers: Modifiers, keyLabel: String)] = [
        ([.shift, .command], "Z"),
        ([.shift, .command], "Q"),
        ([.option, .shift, .command], "Q"),
        ([.control, .command], "F"),
        ([.control, .command], "Q"),
        ([.control, .command], "Space"),
    ]

    /// Why this combination cannot be the shortcut, or nil when it can.
    /// `macOSShortcuts` are the enabled shortcuts macOS keeps for itself,
    /// from `CopySymbolicHotKeys`.
    func problem(macOSShortcuts: [(keyCode: Int, modifiers: Modifiers)]) -> Problem? {
        if let problem = StartShortcut.basicProblem(keyCode: keyCode, modifiers: modifiers) {
            return problem
        }
        if macOSShortcuts.contains(where: { $0.keyCode == keyCode && $0.modifiers == modifiers }) {
            return .usedByMacOS
        }
        let label = keyLabel.uppercased()
        if StartShortcut.standardShortcuts.contains(where: { $0.modifiers == modifiers && $0.keyLabel.uppercased() == label }) {
            return .standardShortcut
        }
        return nil
    }

    /// The rules that a stored shortcut is checked against too: a real key
    /// that is neither a modifier nor Esc, with two or more modifiers, one
    /// of them ⌃ or ⌘. Two modifiers keep the shortcut away from the ⌘ and
    /// ⌃ shortcuts apps use most, and ⌃ or ⌘ also avoids macOS 15's refusal
    /// of shortcuts whose only modifiers are ⌥ or ⌥⇧.
    static func basicProblem(keyCode: Int, modifiers: Modifiers) -> Problem? {
        if keyCode < 0 || keyCode > maxKeyCode || modifierKeyCodes.contains(keyCode) {
            return .invalidKey
        }
        if keyCode == escapeKeyCode {
            return .escape
        }
        if !Modifiers.all.isSuperset(of: modifiers) || modifiers.count < 2 || modifiers.isDisjoint(with: [.control, .command]) {
            return .needsModifiers
        }
        return nil
    }

    // MARK: Messages

    /// What the Settings window says while recording.
    static let recordingHint = "Press two or more modifier keys, including ⌃ or ⌘, together with a key, for example ⌃⌥⌘A. Esc cancels."

    /// What the Settings window says about a problem.
    func message(for problem: Problem) -> String {
        switch problem {
        case .invalidKey:
            return "This key cannot be part of a shortcut. Choose another."
        case .escape:
            return "Esc cannot be part of a shortcut, as it cancels recording."
        case .needsModifiers:
            return "Use two or more modifier keys, including ⌃ or ⌘."
        case .usedByMacOS:
            return "macOS uses \(displayText). Choose another shortcut."
        case .standardShortcut:
            return "\(displayText) is a standard shortcut in most apps. Choose another."
        }
    }

    /// What the Settings window says when registering failed: another app
    /// holds the shortcut, or macOS refused it with `status`.
    func registrationFailureMessage(takenByAnotherApp: Bool, status: Int) -> String {
        if takenByAnotherApp {
            return "Another app uses \(displayText). Choose another shortcut."
        }
        return "macOS did not accept \(displayText) (error \(status)). Choose another shortcut."
    }

    /// The notification posted once when the stored shortcut cannot be
    /// registered at launch.
    func launchFailureMessage(takenByAnotherApp: Bool, status: Int) -> String {
        let reason = takenByAnotherApp ? "as another app uses it" : "as macOS did not accept it (error \(status))"
        return "The keyboard shortcut \(displayText) is not available, \(reason). Choose another in Awake's Settings."
    }

    /// The note under the shortcut in the Settings window, for the default
    /// length and the mode.
    static func settingsNote(defaultToken: String, mode: StartShortcutMode) -> String {
        var note: String
        if let seconds = startRequest(defaultToken: defaultToken).durationSeconds {
            note = "From any app, starts a session of the default length, now \(PickerSettings.lengthLabel(seconds: seconds)), or stops the running one, like a click on the icon."
        } else {
            note = "From any app, starts a session without an end time, or stops the running one, like a click on the icon."
        }
        if mode.isLidClosed {
            note += " Lid-closed mode asks for your password unless Start without password is on."
        }
        return note
    }

    // MARK: Starting

    /// The length of a session the shortcut starts, from the Settings
    /// window's default: a duration, or `--indefinite` for Indefinitely.
    /// Any other token, which `PickerSettings.load()` never gives, counts as
    /// the picker's own fallback, 20 minutes.
    static func startRequest(defaultToken: String) -> StartRequest {
        if defaultToken == PickerSettings.indefiniteToken {
            return StartRequest(durationSeconds: nil, endArguments: ["--indefinite"])
        }
        if PickerSettings.isLengthToken(defaultToken), let seconds = Int(defaultToken) {
            return StartRequest(durationSeconds: seconds, endArguments: [])
        }
        return StartRequest(durationSeconds: PickerSettings.fallbackDefaultSeconds, endArguments: [])
    }
}

extension StartShortcut {
    /// The dictionary stored as `startShortcut`, so that `defaults read`
    /// shows `{ keyCode = 0; keyLabel = A; modifiers = 11; }`.
    var propertyList: [String: Any] {
        ["keyCode": keyCode, "modifiers": modifiers.rawValue, "keyLabel": keyLabel]
    }

    /// Reads a dictionary stored from `propertyList`; nil when it is not
    /// one, or when it breaks a rule every recorded shortcut keeps. macOS's
    /// shortcuts and the standard ones are not checked again: macOS's can
    /// change, and registering reports a real conflict.
    init?(propertyList: [String: Any]) {
        guard let keyCode = propertyList["keyCode"] as? Int,
              let rawModifiers = propertyList["modifiers"] as? Int,
              let keyLabel = propertyList["keyLabel"] as? String,
              rawModifiers >= 0, rawModifiers <= Modifiers.all.rawValue,
              !keyLabel.isEmpty, keyLabel.count <= StartShortcut.maxLabelLength else {
            return nil
        }
        let modifiers = Modifiers(rawValue: rawModifiers)
        guard StartShortcut.basicProblem(keyCode: keyCode, modifiers: modifiers) == nil else {
            return nil
        }
        self.init(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
    }
}

/// What the keyboard shortcut starts, stored as `startShortcutMode`. The
/// picker keeps its own choice.
enum StartShortcutMode: String, CaseIterable {
    case lidOpen = "lid-open"
    case lidOpenDisplaySleeps = "lid-open-display-sleeps"
    case lidClosed = "lid-closed"

    /// The mode of a stored value: lid-open with the display on, the
    /// default, when there is none or it is not one of the modes.
    init(storedValue: String?) {
        self = storedValue.flatMap { StartShortcutMode(rawValue: $0) } ?? .lidOpen
    }

    /// The Settings window's pop-up item.
    var title: String {
        switch self {
        case .lidOpen:
            return "Lid-open, display on"
        case .lidOpenDisplaySleeps:
            return "Lid-open, display can sleep"
        case .lidClosed:
            return "Lid-closed"
        }
    }

    var isLidClosed: Bool {
        self == .lidClosed
    }

    /// The `--keep-display` choice. A lid-closed session ignores it.
    var keepsDisplayOn: Bool {
        self != .lidOpenDisplaySleeps
    }
}
