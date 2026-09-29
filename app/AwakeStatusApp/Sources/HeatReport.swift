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
/// It never reads the clock or the thermal state itself: everything comes in
/// through its methods, so the check can feed it made-up events.
///
/// Every event comes with two times. `at` is the clock's: it is stored, and
/// compared with the helper's `last_completed_at`. `uptime` is the system's
/// uptime, taken when the event arrives, or for a poll when its read
/// started: it never goes back and does not advance while the Mac sleeps,
/// so it puts events in order and measures the time between them, whatever
/// the clock does. Only the time up to an end at `last_completed_at`, a
/// clock time, is measured by the clock.
final class HeatRecorder {
    /// No interval counts for more than this, so a gap when the app was not
    /// running, or its timers were held back, is never counted as time at
    /// one level.
    static let longestInterval: TimeInterval = 60

    /// When an event happened, by the clock and by the uptime.
    private struct EventTime {
        let at: Date
        let uptime: TimeInterval
    }

    /// The recorder's state after an event of the recording in progress.
    private struct Checkpoint {
        let summary: HeatSummary
        let state: Int
        let event: EventTime
        let asleep: Bool
    }

    /// The recording in progress, if any.
    private var current: HeatSummary?
    /// The previous event of the recording in progress. Nil for a recording
    /// loaded at launch until the first poll decides what happens to it.
    private var lastEvent: EventTime?
    /// The clock time of the last poll since launch that showed the recorded
    /// session running. Polls come in the order their reads started, by
    /// uptime, so this is the newest one's, even after a set-back.
    private var lastRunningPollAt: Date?
    /// The thermal state in effect since `lastEvent`.
    private var currentState = 0
    /// The state after the last poll that started or continued the
    /// recording, then after each later event, in the order they came, so
    /// that the events that came after the session ended, before the poll
    /// that shows the end, can be taken back. A poll whose read started
    /// before the previous event keeps the checkpoints from the newest one
    /// at or before its read start. A recording whose first event moved
    /// (`firstEventTime`) also keeps the state from before the poll's.
    private var checkpoints: [Checkpoint] = []
    /// Tokens with a saved summary, which never start a recording again.
    private var finishedTokens: Set<String>
    private var lastPollUptime: TimeInterval?
    /// The last wake, by the clock and by the uptime, also when nothing was
    /// being recorded.
    private var lastWake: EventTime?
    /// The last sleep, by the clock and by the uptime, also when nothing
    /// was being recorded.
    private var lastSleep: EventTime?
    /// The last thermal change, by the clock and by the uptime, also when
    /// nothing was being recorded.
    private var lastThermalChange: EventTime?
    private var hasSeenPoll = false
    private var asleep = false

    /// Whether a recording is in progress, including one loaded at launch.
    var isRecording: Bool {
        current != nil
    }

    /// `saved` is the recording in progress saved before the app last quit,
    /// and `lastFinishedToken` the token of the last finished summary.
    init(saved: HeatSummary?, lastFinishedToken: String?) {
        var tokens = Set<String>()
        if let token = lastFinishedToken, !token.isEmpty {
            tokens.insert(token)
        }
        finishedTokens = tokens
        // A recording in progress whose session already has a summary is
        // left over from a save that did not finish.
        if let saved = saved, !tokens.contains(saved.sessionToken) {
            current = saved
        } else {
            current = nil
        }
    }

    /// Feeds a status read. Returns a summary when a recording has finished,
    /// for saving; its token then counts as saved.
    func observe(_ poll: HeatPoll) -> HeatSummary? {
        // Status reads are not serialized: a slow read that finishes late
        // must not undo a newer one. They are put in order by uptime, not
        // by the clock, so a clock set back does not make the recorder
        // ignore every poll until the clock catches up.
        if let lastPollUptime = lastPollUptime, poll.uptime < lastPollUptime {
            return nil
        }
        lastPollUptime = poll.uptime
        let isFirstPoll = !hasSeenPoll
        hasSeenPoll = true

        var finished: HeatSummary? = nil
        if let recording = current {
            if let running = poll.runningToken, running == recording.sessionToken {
                continueRecording(with: poll)
                return nil
            }
            finished = finishRecording(with: poll)
        }
        if let running = poll.runningToken, !finishedTokens.contains(running) {
            startRecording(token: running, with: poll, watchedFromStart: !isFirstPoll)
        }
        return finished
    }

    /// Feeds a thermal state change. Here and for sleep, wake and
    /// snapshots, `uptime` is taken when the event arrives.
    func thermalStateChanged(to state: Int, at date: Date, uptime: TimeInterval) {
        lastThermalChange = EventTime(at: date, uptime: uptime)
        guard isLive else {
            return
        }
        bringUpToDate(to: EventTime(at: date, uptime: uptime))
        setState(HeatPoll.clampedState(state))
        addCheckpoint()
    }

    /// Time asleep is not counted, also for polls during a dark wake.
    func systemWillSleep(at date: Date, uptime: TimeInterval) {
        if isLive {
            bringUpToDate(to: EventTime(at: date, uptime: uptime))
        }
        asleep = true
        lastSleep = EventTime(at: date, uptime: uptime)
        addCheckpoint()
    }

    func systemDidWake(at date: Date, uptime: TimeInterval) {
        if isLive {
            bringUpToDate(to: EventTime(at: date, uptime: uptime))
        }
        asleep = false
        lastWake = EventTime(at: date, uptime: uptime)
        addCheckpoint()
    }

    /// Brings the recording in progress up to date and returns it, for
    /// saving. Nil when nothing is being recorded.
    func snapshot(at date: Date, uptime: TimeInterval) -> HeatSummary? {
        if isLive {
            bringUpToDate(to: EventTime(at: date, uptime: uptime))
            addCheckpoint()
        }
        return current
    }

    // MARK: Rules

    /// A recording that has had an event since the app launched.
    private var isLive: Bool {
        current != nil && lastEvent != nil
    }

    private func startRecording(token: String, with poll: HeatPoll, watchedFromStart: Bool) {
        current = HeatSummary(
            sessionToken: token,
            firstSeenAt: poll.at,
            watchedFromStart: watchedFromStart,
            endedAt: poll.at,
            endedOnOverheating: false,
            secondsAtLeastFair: 0,
            secondsAtLeastSerious: 0,
            secondsCritical: 0,
            highestState: 0,
            secondsWatched: 0,
            samples: 1
        )
        let first = firstEventTime(of: poll)
        lastEvent = first
        lastRunningPollAt = poll.at
        currentState = 0
        checkpoints = []
        if first.uptime > poll.uptime {
            // The state before the poll's, so that a finish before the
            // moved first event goes back to it.
            addCheckpoint()
        }
        setState(poll.thermalState)
        addCheckpoint()
    }

    /// A recording's first event since launch: the poll's read start, or
    /// the last sleep, wake or thermal change, the latest of them, when it
    /// came after the read started, by uptime. A read that started before
    /// a sleep can arrive during a dark wake, for which no wake is posted,
    /// or after the wake. A read that started during a dark wake can arrive
    /// after the wake, and a read that a thermal change came during carries
    /// the state after the change. Nothing before that event is then
    /// counted for it, and the poll's thermal state, read after it, counts
    /// only from there. The event's clock time goes with it, so the time up
    /// to an end at `last_completed_at` is measured from it.
    ///
    /// The uptime stands still while asleep, so a wake has its sleep's
    /// uptime: the wake, listed first, is then the one used.
    private func firstEventTime(of poll: HeatPoll) -> EventTime {
        var first = EventTime(at: poll.at, uptime: poll.uptime)
        for event in [lastWake, lastThermalChange, lastSleep] {
            if let event = event, event.uptime > first.uptime {
                first = event
            }
        }
        return first
    }

    /// The same session still runs. For a recording loaded at launch this
    /// is its first event, so the time the app was not running is skipped.
    ///
    /// A read that started before the previous event, by uptime, but
    /// arrived after it, as when a thermal change or sleep came during the
    /// read, adds no time and leaves the previous event where it is: that
    /// time is already counted. Its thermal state, read when the poll was
    /// built, still applies. It does not clear the checkpoints after its
    /// read start, as the session may have ended before those events.
    private func continueRecording(with poll: HeatPoll) {
        var alreadyCounted = false
        var keepsFirstCheckpoint = false
        if let lastEvent = lastEvent {
            alreadyCounted = poll.uptime < lastEvent.uptime
            if !alreadyCounted {
                bringUpToDate(to: EventTime(at: poll.at, uptime: poll.uptime))
            }
        } else {
            let first = firstEventTime(of: poll)
            bringUpToDate(to: first)
            if first.uptime > poll.uptime {
                // The saved state, before the poll's, so that a finish
                // before the moved first event goes back to it.
                checkpoints = []
                addCheckpoint()
                keepsFirstCheckpoint = true
            }
        }
        lastRunningPollAt = poll.at
        setState(poll.thermalState)
        // A damaged saved count stops at the largest Int rather than trap.
        if var recording = current, recording.samples < Int.max {
            recording.samples += 1
            current = recording
        }
        if alreadyCounted {
            // The poll shows the session was running when its read started,
            // so only the checkpoints before the newest one at or before then
            // can go. The later ones must stay, so a finish can still take
            // back the events that came after the session ended.
            if let keep = checkpoints.lastIndex(where: { $0.event.uptime <= poll.uptime }) {
                checkpoints.removeFirst(keep)
            }
        } else if !keepsFirstCheckpoint {
            checkpoints = []
        }
        addCheckpoint()
    }

    /// Ends the recording in progress: at `last_completed_at` when the poll
    /// says this session finished, or, for a recording that has had an
    /// event since launch, when it shows no finished token and that time is
    /// no earlier than the last poll that showed the session running;
    /// otherwise when the recording was last brought up to date.
    private func finishRecording(with poll: HeatPoll) -> HeatSummary? {
        guard let recording = current else {
            return nil
        }
        var end = recording.endedAt
        var endIsCompletion = false
        var overheated = false
        if let finishedToken = poll.finishedToken, finishedToken == recording.sessionToken {
            if let completedAt = poll.lastCompletedAt {
                end = Date(timeIntervalSince1970: TimeInterval(completedAt))
                endIsCompletion = true
            }
            overheated = poll.lastCompletionReason == "overheated"
        } else if poll.finishedToken == nil, let lastRunningAt = lastRunningPollAt,
                  let completedAt = poll.lastCompletedAt,
                  TimeInterval(completedAt) >= lastRunningAt.timeIntervalSince1970.rounded(.down) {
            // Normally only the recorded session can have ended since the
            // last poll that showed it running. A session that started and
            // ended between two polls is not seen, and its end is then taken
            // as this one's. Not so for a recording loaded at launch: other
            // sessions may have come and gone while the app was not running.
            end = Date(timeIntervalSince1970: TimeInterval(completedAt))
            endIsCompletion = true
            overheated = poll.lastCompletionReason == "overheated"
        }
        // The events that came after the session ended, before this poll,
        // are taken back: neither their time nor their thermal state counts.
        // `last_completed_at` is rounded down to whole seconds, so an event
        // later in the second of the end is taken back too.
        let asleepNow = asleep
        if endIsCompletion, let point = restorePoint(before: end) {
            let restored = point.checkpoint
            current = restored.summary
            currentState = restored.state
            lastEvent = restored.event
            asleep = restored.asleep
            // The end is a clock time, so the time up to it is measured by
            // the clock, but it is no more than the uptime until the first
            // event taken back, as the state gone back to held only until
            // then, or, when none is, until this poll's read started, which
            // came after the end.
            var limit = poll.uptime
            if let takenBack = point.takenBackUptime, takenBack < limit {
                limit = takenBack
            }
            let byClock = restored.event.uptime + end.timeIntervalSince(restored.event.at)
            let endUptime = min(max(byClock, restored.event.uptime), limit)
            bringUpToDate(to: EventTime(at: end, uptime: endUptime))
        }
        asleep = asleepNow
        var summary = current ?? recording
        summary.endedAt = end
        summary.endedOnOverheating = overheated
        finishedTokens.insert(summary.sessionToken)
        current = nil
        lastEvent = nil
        lastRunningPollAt = nil
        checkpoints = []
        return summary
    }

    /// The checkpoint a finish at `end` goes back to, with the uptime of
    /// the first one taken back, if any: the newest one at or before `end`
    /// by the clock, among those before the first one stamped earlier than
    /// the one before it. That one came after the clock was set back, so
    /// whether it came before `end` is unknown, and it is taken back with
    /// those after it. The first checkpoint when none is at or before
    /// `end`: it is from before the end, or is a recording's first event
    /// moved to a sleep, a wake or a thermal change (`firstEventTime`),
    /// with the state from before the poll's. The time up to an end before
    /// that event then comes out as 0, and the poll's thermal state does
    /// not count.
    private func restorePoint(before end: Date) -> (checkpoint: Checkpoint, takenBackUptime: TimeInterval?)? {
        guard var chosen = checkpoints.first else {
            return nil
        }
        var takenBackUptime: TimeInterval? = nil
        for checkpoint in checkpoints.dropFirst() {
            if checkpoint.event.at > end || checkpoint.event.at < chosen.event.at {
                takenBackUptime = checkpoint.event.uptime
                break
            }
            chosen = checkpoint
        }
        return (checkpoint: chosen, takenBackUptime: takenBackUptime)
    }

    /// Counts the time since the previous event, by uptime, at the state in
    /// effect during it, capped at `longestInterval`; nothing while asleep.
    /// An interval that comes out negative counts as 0. A poll whose read
    /// started before the previous event does not come here
    /// (`continueRecording`).
    private func bringUpToDate(to time: EventTime) {
        guard var recording = current else {
            return
        }
        if let lastEvent = lastEvent, !asleep {
            let interval: TimeInterval = min(max(time.uptime - lastEvent.uptime, 0), HeatRecorder.longestInterval)
            recording.secondsWatched += interval
            if currentState >= HeatSummary.fairState {
                recording.secondsAtLeastFair += interval
            }
            if currentState >= HeatSummary.seriousState {
                recording.secondsAtLeastSerious += interval
            }
            if currentState >= HeatSummary.criticalState {
                recording.secondsCritical += interval
            }
        }
        recording.endedAt = time.at
        current = recording
        lastEvent = time
    }

    private func setState(_ state: Int) {
        currentState = state
        if var recording = current, state > recording.highestState {
            recording.highestState = state
            current = recording
        }
    }

    /// Adds the state after an event of a recording that has had one since
    /// the app launched.
    private func addCheckpoint() {
        guard let recording = current, let lastEvent = lastEvent else {
            return
        }
        checkpoints.append(Checkpoint(summary: recording, state: currentState, event: lastEvent, asleep: asleep))
    }
}
