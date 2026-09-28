// Copyright (C) 2026 Antti Käenmäki

import Foundation

/// The session lengths the picker offers and its default, stored as
/// `pickerDurations` and `pickerDefault` in the app's preferences, which the
/// CLI reads too. Keep these rules in sync with the picker settings in
/// bin/awake: is_picker_token, picker_entries, picker_default_entry, and
/// format_duration_label.
enum PickerSettings {
    static let durationsKey = "pickerDurations"
    static let defaultKey = "pickerDefault"
    static let indefiniteToken = "indefinite"
    /// At most this many lengths; Indefinitely does not count.
    static let maxLengths = 15
    /// 365 days, the longest session.
    static let maxSeconds = 31_536_000
    static let builtinLengths = [600, 1200, 1800, 2400, 3000, 3600, 7200, 10800, 14400, 21600, 28800]
    /// The default when the stored one is not listed, if it is listed.
    static let fallbackDefaultSeconds = 1200

    /// What the Settings window shows and edits.
    struct Configuration: Equatable {
        /// Sorted, without duplicates, 1 to `maxLengths` of them.
        var lengths: [Int]
        var includesIndefinite: Bool
        /// A length in seconds or `indefinite`, always one of `entries`.
        var defaultToken: String

        /// The picker's rows as tokens: the lengths, then indefinite.
        var entries: [String] {
            lengths.map(String.init) + (includesIndefinite ? [PickerSettings.indefiniteToken] : [])
        }
    }

    // MARK: Rules

    /// A whole number of minutes from 1 minute to 365 days, in seconds,
    /// written without leading zeros or a sign.
    static func isLengthToken(_ token: String) -> Bool {
        guard (2...8).contains(token.count),
              token.allSatisfy({ $0.isASCII && $0.isNumber }),
              token.first != "0",
              let seconds = Int(token) else {
            return false
        }
        return seconds % 60 == 0 && seconds <= maxSeconds
    }

    /// Reads a stored list the way the CLI does: tokens separated by spaces,
    /// commas, semicolons, parentheses or quotes. A value without a valid
    /// length gives the built-in list with Indefinitely.
    static func parse(_ raw: String?) -> (lengths: [Int], includesIndefinite: Bool) {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;()\""))
        let tokens = (raw ?? "").components(separatedBy: separators).filter { !$0.isEmpty }
        var lengths = Set<Int>()
        var includesIndefinite = false
        for token in tokens {
            if token == indefiniteToken {
                includesIndefinite = true
            } else if isLengthToken(token), let seconds = Int(token) {
                lengths.insert(seconds)
            }
        }
        if lengths.isEmpty {
            return (builtinLengths, true)
        }
        return (Array(lengths.sorted().prefix(maxLengths)), includesIndefinite)
    }

    /// The stored default when it is listed, otherwise 20 minutes when that
    /// is listed, otherwise the first entry.
    static func resolvedDefault(stored: String?, entries: [String]) -> String {
        let wanted = (stored ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !wanted.isEmpty && entries.contains(wanted) {
            return wanted
        }
        let fallback = String(fallbackDefaultSeconds)
        if entries.contains(fallback) {
            return fallback
        }
        return entries.first ?? fallback
    }

    /// "20 minutes", "1 hour 30 minutes", or "Indefinitely": every part that
    /// is not zero, as the CLI labels lengths.
    static func label(for token: String) -> String {
        if token == indefiniteToken {
            return "Indefinitely"
        }
        guard let seconds = Int(token) else {
            return token
        }
        return lengthLabel(seconds: seconds)
    }

    static func lengthLabel(seconds: Int) -> String {
        guard seconds > 0 else {
            return "0 seconds"
        }
        var rest = seconds
        var parts: [String] = []
        for (unit, size) in [("day", 86400), ("hour", 3600), ("minute", 60), ("second", 1)] {
            let amount = rest / size
            rest %= size
            if amount > 0 {
                parts.append(amount == 1 ? "1 \(unit)" : "\(amount) \(unit)s")
            }
        }
        return parts.joined(separator: " ")
    }

    // MARK: Storage

    /// The stored text of `key`. Numbers and lists count too, as the CLI
    /// reads them through `defaults read`.
    private static func storedText(_ key: String, in defaults: UserDefaults) -> String? {
        switch defaults.object(forKey: key) {
        case let text as String:
            return text
        case let number as NSNumber:
            return number.stringValue
        case let list as [Any]:
            return list.map { "\($0)" }.joined(separator: " ")
        default:
            return nil
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> Configuration {
        let parsed = parse(storedText(durationsKey, in: defaults))
        var configuration = Configuration(lengths: parsed.lengths, includesIndefinite: parsed.includesIndefinite, defaultToken: "")
        configuration.defaultToken = resolvedDefault(stored: storedText(defaultKey, in: defaults), entries: configuration.entries)
        return configuration
    }

    /// Stores `configuration` after cleaning it up: sorted lengths without
    /// duplicates, at most `maxLengths`, and a default that is listed.
    @discardableResult
    static func save(_ configuration: Configuration, to defaults: UserDefaults = .standard) -> Configuration {
        var cleaned = configuration
        let valid = configuration.lengths.filter { isLengthToken(String($0)) }
        cleaned.lengths = Array(Set(valid).sorted().prefix(maxLengths))
        if cleaned.lengths.isEmpty {
            cleaned.lengths = builtinLengths
        }
        cleaned.defaultToken = resolvedDefault(stored: configuration.defaultToken, entries: cleaned.entries)
        defaults.set(cleaned.entries.joined(separator: " "), forKey: durationsKey)
        defaults.set(cleaned.defaultToken, forKey: defaultKey)
        return cleaned
    }

    /// Restore Defaults: removes both keys, so the built-in list applies.
    static func restoreDefaults(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: durationsKey)
        defaults.removeObject(forKey: defaultKey)
    }
}
