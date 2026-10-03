// Copyright (C) 2026 Antti Käenmäki

import Foundation

/// How warm the Mac got during one session, as the app saw it. Stored as a
/// property-list dictionary: `lastSessionHeat` for the last session that
/// ended, `sessionHeatInProgress` for the one being recorded. Thermal states
/// are macOS's: 0 nominal, 1 fair, 2 serious, 3 critical.
struct HeatSummary: Codable, Equatable {
    var sessionToken: String
    /// When the app first saw the session running.
    var firstSeenAt: Date
    /// False when the session was already running at the app's first poll
    /// after it launched.
    var watchedFromStart: Bool
    /// When the session ended; in a recording in progress, when it was last
    /// brought up to date.
    var endedAt: Date
    /// The thermal guard ended the session.
    var endedOnOverheating: Bool
    /// Not shown; for QA.
    var secondsAtLeastFair: TimeInterval
    var secondsAtLeastSerious: TimeInterval
    var secondsCritical: TimeInterval
    /// The highest thermal state seen, 0 to 3.
    var highestState: Int
    /// The time counted at any level. Not shown; for QA.
    var secondsWatched: TimeInterval
    /// The number of polls that fed the recording. Not shown; for QA.
    var samples: Int

    /// Whether the Mac got hot: the serious or critical thermal state, or a
    /// session the guard ended. Fair alone does not count.
    var shouldReport: Bool {
        highestState >= HeatSummary.seriousState || endedOnOverheating
    }

    /// The note under `Stop when too hot`, or nil when there is nothing to
    /// report: "Last session: hot for 3 minutes, so Awake ended it."
    func noteText(timeZone: TimeZone) -> String? {
        guard shouldReport else {
            return nil
        }
        var heat: String
        if highestState >= HeatSummary.seriousState {
            heat = "hot for " + HeatSummary.durationText(seconds: HeatSummary.wholeSeconds(secondsAtLeastSerious))
            if highestState >= HeatSummary.criticalState {
                heat += ", very hot for " + HeatSummary.durationText(seconds: HeatSummary.wholeSeconds(secondsCritical))
            }
            if endedOnOverheating {
                heat += ", so Awake ended it"
            }
        } else {
            // The app missed the heat, but the guard did not.
            heat = "the Mac got too hot, so Awake ended it"
        }
        let prefix: String
        if watchedFromStart {
            prefix = "Last session"
        } else {
            prefix = "Last session (from \(watchStartText(timeZone: timeZone)))"
        }
        return prefix + ": " + heat + "."
    }

    /// When watching began, in 24-hour time: "14:05", with the date first
    /// when that was on an earlier day than the end: "2026-09-28 23:50".
    private func watchStartText(timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        if calendar.isDate(firstSeenAt, inSameDayAs: endedAt) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
        }
        return formatter.string(from: firstSeenAt)
    }

    /// A time rounded down to whole minutes, so rounding never makes the
    /// note claim more than was counted: "less than a minute", "12 minutes",
    /// "1 hour 5 minutes", and from a day on "1 day 2 hours", the hours
    /// rounded down too.
    static func durationText(seconds: Int) -> String {
        let minute = 60
        let hour = 60 * minute
        let day = 24 * hour
        if seconds < minute {
            return "less than a minute"
        }
        if seconds < hour {
            return counted(seconds / minute, unit: "minute")
        }
        var parts: [String] = []
        if seconds < day {
            let hours = seconds / hour
            let minutes = (seconds % hour) / minute
            parts.append(counted(hours, unit: "hour"))
            if minutes > 0 {
                parts.append(counted(minutes, unit: "minute"))
            }
            return parts.joined(separator: " ")
        }
        let days = seconds / day
        let hours = (seconds % day) / hour
        parts.append(counted(days, unit: "day"))
        if hours > 0 {
            parts.append(counted(hours, unit: "hour"))
        }
        return parts.joined(separator: " ")
    }

    static let fairState = 1
    static let seriousState = 2
    static let criticalState = 3

    /// macOS's thermal state on this scale, which is also bin/awake's and the
    /// helper's (they read NSProcessInfo.thermalState too). Nil for a state a
    /// later macOS might add; the CLI then reads the state itself.
    static func number(for state: ProcessInfo.ThermalState) -> Int? {
        switch state {
        case .nominal:
            return 0
        case .fair:
            return fairState
        case .serious:
            return seriousState
        case .critical:
            return criticalState
        @unknown default:
            return nil
        }
    }

    private static func counted(_ value: Int, unit: String) -> String {
        value == 1 ? "1 \(unit)" : "\(value) \(unit)s"
    }

    /// Whole seconds, rounded down. The tiny margin keeps a sum of intervals
    /// such as 179.9999999 from losing a minute.
    private static func wholeSeconds(_ value: TimeInterval) -> Int {
        guard value.isFinite, value > 0 else {
            return 0
        }
        let limited: Double = min(value + 0.000_001, 1_000_000_000_000)
        return Int(limited.rounded(.down))
    }
}

extension HeatSummary {
    /// The summary as a property-list dictionary for `UserDefaults`, so
    /// `defaults read` prints the numbers readably.
    var propertyList: [String: Any]? {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(self),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    /// Reads a dictionary stored from `propertyList`; nil when it is not one,
    /// or when a date or the sample count is out of range, as only a damaged
    /// value can be.
    init?(propertyList: [String: Any]) {
        guard PropertyListSerialization.propertyList(propertyList, isValidFor: .binary),
              let data = try? PropertyListSerialization.data(fromPropertyList: propertyList, format: .binary, options: 0),
              let summary = try? PropertyListDecoder().decode(HeatSummary.self, from: data),
              HeatSummary.isStoredDate(summary.firstSeenAt),
              HeatSummary.isStoredDate(summary.endedAt),
              summary.samples >= 0, summary.samples < Int.max else {
            return nil
        }
        self = summary
    }

    /// A date that is finite and within the range `wholeSeconds` allows.
    private static func isStoredDate(_ date: Date) -> Bool {
        let seconds = date.timeIntervalSince1970
        return seconds.isFinite && abs(seconds) <= 1_000_000_000_000
    }
}

/// One status read, reduced to what the recorder needs, with the thermal
/// state taken when the poll is built.
struct HeatPoll {
    /// When the status read started, by the clock.
    let at: Date
    /// The system's uptime when the status read started, such as
    /// `ProcessInfo.processInfo.systemUptime`. It puts polls and events in
    /// order and measures the time between them, as the clock can be set
    /// back or forward.
    let uptime: TimeInterval
    /// The token of this account's running session, or nil when none runs.
    let runningToken: String?
    /// When no session runs, the token of the last finished one.
    let finishedToken: String?
    let lastCompletedAt: Int?
    let lastCompletionReason: String?
    /// 0 to 3, read when the poll is built, after the status read finished,
    /// not when the read started: it is then current even for a read that
    /// a thermal change came during.
    let thermalState: Int

    /// Takes the status's fields as plain values. A status with an error
    /// gives no poll. Leftover sleep settings and another account's session
    /// give no tokens, as neither is a session of this account's, and a
    /// running session without a token counts as none.
    init?(
        at: Date,
        uptime: TimeInterval,
        active: Bool,
        hasError: Bool,
        leftoverSettings: Bool,
        otherUserSession: Bool,
        sessionToken: String?,
        lastCompletedAt: Int?,
        lastCompletionReason: String?,
        thermalState: Int
    ) {
        if hasError {
            return nil
        }
        var token: String? = nil
        if let sessionToken = sessionToken, !sessionToken.isEmpty {
            token = sessionToken
        }
        self.at = at
        self.uptime = uptime
        if leftoverSettings || otherUserSession {
            runningToken = nil
            finishedToken = nil
        } else if active {
            runningToken = token
            finishedToken = nil
        } else {
            runningToken = nil
            finishedToken = token
        }
        self.lastCompletedAt = lastCompletedAt
        self.lastCompletionReason = lastCompletionReason
        self.thermalState = HeatPoll.clampedState(thermalState)
    }

    /// A thermal state limited to 0...3.
    static func clampedState(_ state: Int) -> Int {
        min(max(state, 0), HeatSummary.criticalState)
    }
}

/// Records how warm the Mac gets during each of this account's sessions.
/// It never reads the clock, the uptime or the thermal state itself:
/// everything comes in through its methods, so the check can feed it
/// made-up events.
///
/// Time is measured only by the uptime, which never goes back and does not
/// advance while the Mac sleeps, so a clock step changes no count. Time is
/// added to the recording only at a poll that shows its session still
/// running; until then it is pending, and a poll that shows the end drops
/// it. So the times can be up to one poll interval short, and heat after
/// the last poll that showed the session running never counts.
final class HeatRecorder {
    /// No interval counts for more than this, so a gap when the app was not
    /// running, or its timers were held back, is never counted as time at
    /// one level.
    static let longestInterval: TimeInterval = 60

    /// The time since the last poll that showed the session running.
    private struct Tally {
        var secondsAtLeastFair: TimeInterval = 0
        var secondsAtLeastSerious: TimeInterval = 0
        var secondsCritical: TimeInterval = 0
        var secondsWatched: TimeInterval = 0
        var highestState = 0
    }

    /// The recording in progress, if any, as of the last poll that showed
    /// its session running.
    private var current: HeatSummary?
    private var pending = Tally()
    /// The thermal state in effect since the previous event.
    private var currentState = 0
    /// The uptime of the recording's previous event. Nil when nothing is
    /// recorded, and for a recording loaded at launch until its first poll.
    private var lastEventUptime: TimeInterval?
    private var lastPollUptime: TimeInterval?
    /// Tokens with a saved summary, which never start a recording again.
    private var finishedTokens: Set<String> = []
    private var asleep = false

    /// Whether a recording is in progress, including one loaded at launch.
    var isRecording: Bool {
        current != nil
    }

    /// The recording in progress as of the last poll that showed its
    /// session running, for saving as `sessionHeatInProgress`.
    var inProgress: HeatSummary? {
        current
    }

    /// `saved` is the recording in progress saved before the app last quit,
    /// and `lastFinishedToken` the token of the last finished summary.
    init(saved: HeatSummary?, lastFinishedToken: String?) {
        if let token = lastFinishedToken, !token.isEmpty {
            finishedTokens.insert(token)
        }
        // A recording in progress whose session already has a summary is
        // left over from a save that did not finish.
        if let saved = saved, !finishedTokens.contains(saved.sessionToken) {
            current = saved
        }
    }

    /// Feeds a status read. Returns a summary when a recording has finished,
    /// for saving; its token then counts as saved.
    func observe(_ poll: HeatPoll) -> HeatSummary? {
        // Status reads are not serialized: a slow read that finishes late
        // must not undo a newer one.
        if let lastPollUptime = lastPollUptime, poll.uptime < lastPollUptime {
            return nil
        }
        let isFirstPoll = lastPollUptime == nil
        lastPollUptime = poll.uptime

        var finished: HeatSummary? = nil
        if let recording = current {
            if poll.runningToken == recording.sessionToken {
                commit(poll)
                return nil
            }
            finished = finish(recording, with: poll)
        }
        if let running = poll.runningToken, !finishedTokens.contains(running) {
            start(running, with: poll, watchedFromStart: !isFirstPoll)
        }
        return finished
    }

    /// Feeds a thermal state change. Here and for sleep and wake, `uptime`
    /// is taken when the event arrives.
    func thermalStateChanged(to state: Int, uptime: TimeInterval) {
        advance(to: uptime)
        currentState = HeatPoll.clampedState(state)
        if lastEventUptime != nil {
            pending.highestState = max(pending.highestState, currentState)
        }
    }

    /// Time asleep is not counted, also for polls during a dark wake.
    func systemWillSleep(uptime: TimeInterval) {
        advance(to: uptime)
        asleep = true
    }

    func systemDidWake(uptime: TimeInterval) {
        advance(to: uptime)
        asleep = false
    }

    private func start(_ token: String, with poll: HeatPoll, watchedFromStart: Bool) {
        current = HeatSummary(sessionToken: token, firstSeenAt: poll.at, watchedFromStart: watchedFromStart,
                              endedAt: poll.at, endedOnOverheating: false, secondsAtLeastFair: 0,
                              secondsAtLeastSerious: 0, secondsCritical: 0, highestState: poll.thermalState,
                              secondsWatched: 0, samples: 1)
        currentState = poll.thermalState
        pending = Tally(highestState: currentState)
        lastEventUptime = poll.uptime
    }

    /// The same session still runs: counts the time up to the poll and adds
    /// the pending time to the recording. A read that started before the
    /// previous event adds no time up to it, as that is already counted.
    /// For a recording loaded at launch this is its first event, so the
    /// time the app was not running is skipped.
    private func commit(_ poll: HeatPoll) {
        advance(to: poll.uptime)
        if lastEventUptime == nil {
            lastEventUptime = poll.uptime
        }
        guard var recording = current else {
            return
        }
        recording.secondsAtLeastFair += pending.secondsAtLeastFair
        recording.secondsAtLeastSerious += pending.secondsAtLeastSerious
        recording.secondsCritical += pending.secondsCritical
        recording.secondsWatched += pending.secondsWatched
        recording.highestState = max(recording.highestState, pending.highestState, poll.thermalState)
        recording.endedAt = poll.at
        // A damaged saved count stops at the largest Int rather than trap.
        if recording.samples < Int.max {
            recording.samples += 1
        }
        current = recording
        currentState = poll.thermalState
        pending = Tally(highestState: currentState)
    }

    /// Ends the recording in progress and drops the pending time. When the
    /// poll names this session as finished, or names none, the recording
    /// has had a poll since launch, and `last_completed_at` is no earlier
    /// than `firstSeenAt`, it ends at `last_completed_at`, if the status has
    /// one, and overheated when `last_completion_reason` is `overheated`.
    /// Otherwise it ends at `endedAt`, not overheated.
    private func finish(_ recording: HeatSummary, with poll: HeatPoll) -> HeatSummary {
        var usesCompletion = poll.finishedToken == recording.sessionToken
        if poll.finishedToken == nil, lastEventUptime != nil, let completedAt = poll.lastCompletedAt {
            // Normally only the recorded session can have ended since the
            // last poll; while the app was not running, others may have.
            usesCompletion = TimeInterval(completedAt) >= recording.firstSeenAt.timeIntervalSince1970.rounded(.down)
        }
        var summary = recording
        summary.endedOnOverheating = false
        if usesCompletion {
            if let completedAt = poll.lastCompletedAt {
                summary.endedAt = Date(timeIntervalSince1970: TimeInterval(completedAt))
            }
            summary.endedOnOverheating = poll.lastCompletionReason == "overheated"
        }
        finishedTokens.insert(recording.sessionToken)
        current = nil
        pending = Tally()
        lastEventUptime = nil
        return summary
    }

    /// Counts the time since the previous event as pending, at the state in
    /// effect during it, capped at `longestInterval`; nothing while asleep.
    /// A late event, with a smaller uptime, counts nothing and leaves the
    /// previous event where it is.
    private func advance(to uptime: TimeInterval) {
        guard let last = lastEventUptime, uptime > last else {
            return
        }
        lastEventUptime = uptime
        let interval = asleep ? 0 : min(uptime - last, HeatRecorder.longestInterval)
        pending.secondsWatched += interval
        pending.secondsAtLeastFair += currentState >= HeatSummary.fairState ? interval : 0
        pending.secondsAtLeastSerious += currentState >= HeatSummary.seriousState ? interval : 0
        pending.secondsCritical += currentState >= HeatSummary.criticalState ? interval : 0
    }
}
