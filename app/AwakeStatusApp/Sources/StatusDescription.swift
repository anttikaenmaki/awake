// Copyright (C) 2026 Antti Käenmäki

import Foundation

/// The one-line status shown at the top of the Ctrl-click menu and as the menu
/// bar tooltip. `awake --status` prints the same sentences for active sessions.
enum StatusDescription {
    static func text(for status: AwakeStatus, lastStoppedAt: Date?, now: Date = Date()) -> String {
        if let error = status.error, !error.isEmpty {
            return error
        }
        if status.active {
            return activeText(for: status, now: now)
        }
        guard let lastStoppedAt else {
            return "Awake is off"
        }
        let secondsOff = Int(now.timeIntervalSince(lastStoppedAt))
        return "Awake has been off for \(elapsedText(seconds: secondsOff))"
    }

    private static func activeText(for status: AwakeStatus, now: Date) -> String {
        let text: String
        if let remaining = status.secondsLeft(at: now) {
            text = "Awake is on and has \(remainingText(seconds: remaining)) left"
        } else {
            // Sleep is disabled but there is no timed session, for example
            // after a crash. Clicking the icon restores normal sleep.
            text = "Awake is on with no end time"
        }
        if status.sessionBackend == .caffeinate && status.keepDisplay == false {
            return text + " (keep the lid open; the display may sleep)"
        }
        if status.sessionBackend == .caffeinate {
            return text + " (keep the lid open)"
        }
        return text
    }

    /// Time left in a session, rounded up to whole minutes so a fresh
    /// 20-minute session reads "20 minutes": "25 minutes", "1 hour 5 minutes".
    static func remainingText(seconds: Int) -> String {
        guard seconds >= 60 else {
            return "less than a minute"
        }
        let totalMinutes = (seconds + 59) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append(count(hours, unit: "hour"))
        }
        if minutes > 0 {
            parts.append(count(minutes, unit: "minute"))
        }
        return parts.joined(separator: " ")
    }

    /// Time since Awake stopped, in the largest whole unit: "5 minutes",
    /// "2 hours", "3 weeks". Months count as 30 days and years as 365 days.
    static func elapsedText(seconds: Int) -> String {
        let minute = 60
        let hour = 60 * minute
        let day = 24 * hour
        let week = 7 * day
        let month = 30 * day
        let year = 365 * day

        switch seconds {
        case ..<minute:
            return "less than a minute"
        case ..<hour:
            return count(seconds / minute, unit: "minute")
        case ..<day:
            return count(seconds / hour, unit: "hour")
        case ..<week:
            return count(seconds / day, unit: "day")
        case ..<month:
            return count(seconds / week, unit: "week")
        case ..<year:
            return count(seconds / month, unit: "month")
        default:
            return count(seconds / year, unit: "year")
        }
    }

    private static func count(_ value: Int, unit: String) -> String {
        value == 1 ? "1 \(unit)" : "\(value) \(unit)s"
    }
}
