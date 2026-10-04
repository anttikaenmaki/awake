# Plan: faster start and stop from the menu bar app and the shortcut

- Status: written 2026-10-03. Phase 1, items A to D (the code, the checks, the timing script and the docs), with the recommended answer to each question below, is done and green on macOS CI; at the owner's request, item E (6.2) joined it. Phase 2, the Mac QA of 8, runs in one session with plan-2.4.0's and plan-2.3.0's phase 3. Then phase 3, the release as 2.4.0, which waits for that QA. Items F to J come later (6), each planned in full when it is picked up
- Target version: 2.4.0, together with plan-2.4.0.md (notifications off by default). A to D add Changed and Fixed entries to the same `[Unreleased]`, which stays a minor version. The helper and its protocol (version 9) do not change, so there is no helper reinstall and no password prompt after the update. E to J: probably 2.5.0 (6.9)
- Written: 2026-10-03, against `dev` (commit `8ef37f3`), from the owner's question: "when clicking shift+cmd+a or the menu bar app, it takes some time for awake to start or stop the session. Is it possible to make it faster?", and, after the research, "Please write a detailed plan for this. After that start with A-D."
- Scope: phase 1 touches `app/AwakeStatusApp/Sources/` (new `StatusIcon.swift`; `StatusBarController.swift`, `AwakeCLI.swift`, `HeatReport.swift`), `tests/app/` (new `status-icon-check.swift`; `heat-report-check.swift`), `bin/awake`, `tests/cli/awake-self-test`, `tools/measure-latency.sh` (new), `.github/workflows/ci.yml`, `README.md`, `CHANGELOG.md`, `docs/plans/` (this plan as `faster-start-stop.md`; plan-2.4.0.md's and plan-2.3.0.md's status lines, as this plan's QA joins their Mac session and the 2.4.0 release waits for it). Later items also touch `bin/awake-helper`

## Questions for the owner

Phase 1 follows the recommended answer to each. Each option says what choosing it would change.

1. **What the icon shows during a lid-closed start** (decision A2).
   - (a) The bold `A`, dimmed, until the session runs. **Recommended:** closing the lid before the helper has turned sleep off lets the Mac sleep, and today the icon is the cue to wait.
   - (b) The bold `A` at once, as for a lid-open start. One rule for every start, but for about 1.5 to 3.5 s (Mac estimate) the icon says "on" while closing the lid would still put the Mac to sleep. It would remove `dimmedOutcome` and one README sentence.
   - (c) Every start and stop dimmed until done: the glyph changes at once and turns solid at the end. The most honest, but it loses most of the "feels instant" effect. `outcome` would be dimmed too.
2. **A click while a command runs.**
   - (a) It does nothing, as today. **Recommended** for now.
   - (b) It beeps, as ⇧⌘A does (StatusBarController.swift:287-290). One line at :148. A quick second click to undo is more likely now that the icon changes at once.
3. **A click start with the default macOS password dialog setting** only dims the icon, as the CLI shows the picker and the app cannot tell when it closes.
   - (a) Keep it so. **Recommended:** decide after trying A to D on a Mac.
   - (b) A follow-up where the app always shows the picker itself, as it does in custom password mode (StatusBarController.swift:171-177, AwakeCLI.swift:299-319). The icon would then change as soon as the picker closes. It blocks the main thread while the picker is open, as custom mode does today, and adds time to a session started elsewhere differently (AwakeCLI.swift:347-351).
4. **The stop-request file in a lid-open stop** (decision B2).
   - (a) Written only when the signal cannot be sent. **Recommended.**
   - (b) Always written first. It adds no safety and costs about 0.05 s per stop on Linux (estimate 0.1 to 0.2 s on a Mac).
5. **The lid-closed stop's 0.2 s check** (decision B8).
   - (a) Checked every 0.05 s in this release, CLI only. **Recommended:** no helper change, and G needs it anyway.
   - (b) Left for G.
6. **`AWAKE_STATUS_JSON_FILE`** (decision C10).
   - (a) Internal to the app, undocumented, like `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY`. **Recommended.**
   - (b) Documented for other tools (Raycast, scripts). Its behaviour then becomes a promise later versions must keep.
7. **The app's thermal state** (decisions D1, D4).
   - Age limit: (a) 30 s, **recommended**, so most picker starts skip `osascript`; (b) 10 s. Safety is the same: the runner and the helper read the state themselves.
   - Name: (a) `AWAKE_APP_THERMAL_STATE`, **recommended**, next to `AWAKE_APP_CUSTOM_PASSWORD_MODE`; (b) `AWAKE_THERMAL_STATE`.
   - README: (a) one sentence at README.md:56 that says what the app does, without naming the variable, **recommended**; (b) a code comment only.

The questions for E to J are in 6.10.

## Earlier plans

`plan-2.4.0.md` and `plan-2.3.0.md` stay in the repository until their phase 3, the Mac QA. This plan's Mac QA (8) runs in the same session, on the build that carries 2.4.0 (10, phase 2). So that nobody releases 2.4.0 from plan-2.4.0's phase 4 without it, the phase 1 commit that adds this plan also updates both status lines, as plan-2.4.0 updated plan-2.3.0's when it folded in:

- plan-2.4.0.md:3: "phase 3, the Mac QA of 6, still to do, in one session with plan-2.3.0's phase 3 and faster-start-stop.md's 8; then phase 4, the release as 2.4.0, which waits for all three";
- plan-2.3.0.md:3: "…still to do, in one session with plan-2.4.0's 6 and faster-start-stop.md's 8, and 2.4.0 carries what it finds".

## How this plan was checked

- It was written on Linux, from the code, without macOS or a Swift compiler. Line numbers without a file name are lines of `bin/awake` at `8ef37f3`, and in 5 of `tests/cli/awake-self-test`; others name the file. A section of this plan is named by its number alone, such as 4.2.
- Every line number was re-read in the tree at `8ef37f3`. Corrections to the research: `HELPER_PROTOCOL_VERSION` is line 128, not 113; the helper's `check` is awake-helper:1446-1447; main's first `state_session_is_active` is line 6550; `run_helper` calls `run_as_admin` at 3633 and 3645.
- **Measurements.** A research pass ran the app's exact command sequence in a macOS emulation on Linux, with stand-ins for `pmset`, `caffeinate`, `osascript`, `afplay`, `stat` and `date`, in real mode for lid-open sessions and in dry-run for lid-closed ones. Linux times are measured. Every Mac time is an estimate. The counts of programs, sleeps and check intervals are the same on a Mac.
- **A** was prototyped (`StatusIcon.swift`, the check, the controller changes). It has never been compiled: CI is the first compile. The prototype predates A9's last change: its `changesSession` also pauses polls during added time, and its `refreshStatus` drops the condition at :500. Rename it `pausesPolls`, true for starts and stops only, keep :500 as it is, and change the check's added-time case to match (5.1).
- **B, C and D** were prototyped on scratch copies of `bin/awake` and the self-test. Their new checks pass on the prototypes and fail on `8ef37f3`.
  - B: self-test steps 1 to 9a, 12 to 12g and 12i to 13 pass, and section 10 (the sourced checks) up to the `plutil` check at 2099, which cannot run on Linux; B's new sourced checks come before it.
  - C: sections 1, 1a, 2, 2a, 2b, 3, 3b, 3c, 5, 5a, 5b, 5c, 6, 8, 12f and 12i pass, and section 10 up to the `plutil` check at 2099, including C's new sourced check (it fails on `8ef37f3` with "a cancelled password prompt did not write the status"). Stdout, stderr and exit statuses are the same byte for byte on 29 exit paths.
  - D: 12, 12a, 12b and the new 12l pass. Three deliberate mistakes in the code were each caught by 12l. The prototype's check at exactly 30 s has no retry yet; 5.4, T2 adds it.
- **Not run here:** Bash 3.2 (the download was blocked; CI runs `/bin/bash` 3.2), steps 11 to 11c and 12h (they need `defaults`, zsh, `plutil` or `launchctl`), the rest of section 10 from the `plutil` check at 2099, and the sourced end-time checks (they need BSD `date -j`, and fail on `8ef37f3` in the emulation too). Anything that needs a Mac is in the QA checklist (8) and in 11.
- The CHANGELOG text of 9 is within 79 columns, and `suggest_level` from `tools/release.sh` (183-191) still returns `minor`.

## Why it is slow

**Three runs for every action.** Every click and every ⇧⌘A runs three `bin/awake` processes in a row on the app's command queue (AwakeCLI.swift:230), each a new bash that reads the 7,160-line script:

1. `awake --status-json` (AwakeCLI.swift:339 for a start, :378 for a stop);
2. the action, `--gui --start …` or `--gui --stop` (:420-424, arguments at :431-470);
3. `awake --status-json` again (:425).

Only then does `handleCommandResult` set `currentStatus` (StatusBarController.swift:403) and redraw (:407). The image follows only `currentStatus.active` (:690). Meanwhile only the tooltip and the menu's first line change, to `Starting Awake…` and the like (:694-699).

**Measured on Linux** (mean of 5 runs; lid-open in real mode with stand-ins, lid-closed in dry-run):

| Action | Status before | Action | Status after | Icon changes at |
|---|---|---|---|---|
| Lid-open start (the shortcut's default mode, StartShortcut.swift:413-415) | 84 ms | 397 ms | 159 ms | 645 ms |
| Lid-open stop | 165 ms | 1,714 ms | 89 ms | 1,974 ms |
| Lid-closed start | 95 ms | 242 ms | 164 ms | 506 ms |
| Lid-closed stop | 166 ms | 762 ms | 93 ms | 1,027 ms |

**Estimated on a Mac**, until the icon changes: lid-open start 1.5 to 3 s, lid-open stop 2 to 3.5 s, lid-closed start 1.5 to 3.5 s, lid-closed stop 1.3 to 2.5 s. These assume 5 to 20 ms per small program (`/bin/ps`, setuid root, at the high end), 20 to 100 ms per `pmset`, and 0.1 to 0.4 s per `osascript` with the JavaScript bridge.

**Where the time goes:**

| Contributor | Where | Linux, measured | Mac, estimate | Item |
|---|---|---|---|---|
| The icon waits for all three runs | StatusBarController.swift:403-407, :690 | the whole action | 1.5 to 3.5 s | A |
| Fixed waits in a lid-open stop: the stop-request monitor checks every 0.5 s; the runner sits in a foreground `/bin/sleep 1`, and bash runs its TERM trap only after it, while the worker waits for it; the stop command checks every 0.2 s | 95 and 3293; 5435, 5306 and 5516; 93 and 3345 | monitor 0.05 to 0.46 s (mean 0.32), runner 0.48 to 0.99 s (mean 0.80), CLI check mean 0.13 s | about 0.85 s on average, up to 1.7 s | B |
| The "after" status run | AwakeCLI.swift:425 | about 25 to 40 ms of process overhead (see C) | 0.05 to 0.15 s, plus 0.05 to 0.2 s after a start | C |
| The thermal check runs `osascript` before every start: the app passes `--thermal-guard on` by default | AwakeCLI.swift:451-452 → 6966-6967 → 2153, under `run_with_timeout` (2162-2183) | +0.26 s with a 0.25 s stand-in | 0.15 to 0.45 s | D |
| The start sound: with Sound on, `afplay` plays before the CLI exits | 7149-7150 → 3211-3212 → 3130 | 400 → 900 ms with a 0.5 s stand-in | 0.3 to 0.7 s | E |
| Small programs: `id`, `dirname`, `stat`, `awk` per key, `ps` | throughout | 55 in a lid-open start command, 155 with its worker and runner | 0.3 to 0.8 s per action over the three runs | F |
| The lid-closed stop waits for the helper's 1 s loop | awake-helper:1283, :1334; CLI check at 3769 | 0.15 to 0.99 s (mean 0.45), plus a CLI check mean of 0.12 s | about 0.5 s on average, up to 1 s | G |
| The "before" status run | AwakeCLI.swift:339, :378 | 84 to 166 ms | 0.25 to 0.5 s | H |
| Lid-closed starts check twice: `sudo -n helper check` then `sudo -n helper start`; battery and thermal state in the CLI and again in the helper | 3636-3637; 6957-6974 and awake-helper:903-908 | — | 0.3 to 1.0 s | I |
| A lid-open start launches a second bash, the worker, which runs about 57 programs before the session counts as ready; the start checks every 0.2 s and the first check always misses | 3095-3101, 5439-5555; 7030 → 4222 | 168 ms of worker work, then about 56 ms idle | 0.5 to 1.0 s | J |
| Status polls overlap commands: an extra bash competes for the CPU in about 20 to 30% of actions, and a stale result can flip the icon back | StatusBarController.swift:476-506 | — | — | A |

**Counts** (strace, real mode with stand-ins):

| CLI run | Programs | `pmset` | Notable |
|---|---|---|---|
| `--status-json`, no session | 13 | 2 | |
| `--status-json`, a session running | 37 | 2 | 19 `awk`, 5 `date`, 1 `ps` |
| `--gui --start`, lid-open | 69 | 3 | 7 `ps`, two `sleep 0.2`; on a Mac also 1 `osascript` |
| `--gui --stop`, lid-open | 71 | 2 | 4 `ps`, four `sleep 0.2` |

- With the helper installed, every run adds 7 more: 6 `stat` and a `dirname` in `helper_is_ready` (3424-3440).
- Per action: 3 bash processes, about 120 to 135 programs, 6 or 7 `pmset`, and 1 `osascript` per start. A lid-open start also starts the worker and the runner: 2 more bash processes and about 88 programs before the CLI exits.
- Fixed intervals: the CLI's checks 0.2 s (93), the stop-request monitor 0.5 s (95), the runner 1 s (5435), the helper's timer 1 s (awake-helper:1334), the app's poll 10 s with 2 s tolerance (StatusBarController.swift:136-139).

## 1. Goals

1. The icon answers a click, ⇧⌘A or a menu choice at once, before any process starts. When the command fails or is cancelled, the icon goes back.
2. The result comes sooner (Mac estimates, from Why it is slow):

   | Action | Icon | Result sooner by |
   |---|---|---|
   | Lid-open start, the shortcut's default | at once | 0.25 to 0.8 s (C and D) |
   | Lid-open stop | at once | about 1 s on average, up to about 2 s (B and C) |
   | Lid-closed start | at once, dimmed until it runs | 0.25 to 0.8 s (C and D) |
   | Lid-closed stop | at once | 0.1 to 0.25 s (B8 and C) |

3. Nothing else changes: messages, exit statuses, `--status` and `--status-json` output, notifications, sounds, completion reasons, the runtime files (but for when `stop-request` is written, 3), the helper and its protocol.
4. Mixed versions keep working: a new app with an older CLI, an older app with the new CLI, and a session started by the previous version.
5. The owner can time a start and a stop on the Mac before and after the update (7).

Not in scope:

- E to J (6), which keep their own gains after A to D;
- a persistent daemon or a compiled helper in place of bash;
- the work custom password mode does on the main thread (6.11, K), and the app showing the picker itself in the default mode (question 3);
- a delay in `waitUntilExit` that the research could not verify (6.11, L);
- the older race in which a stop that meets the session's own end replaces its recorded reason with `stopped` (6.11, M).

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| A1 | What the icon shows while a start or a stop runs | The state it leads to, when that is known and showing it early does no harm: a lid-open start shows the bold `A`, and a stop the regular `A`. Rejected: waiting for the result, as today. |
| A2 | A lid-closed start | The bold `A`, dimmed, until the session runs (question 1). |
| A3 | When the outcome is not known | The state before, dimmed. **The CLI's picker:** a click while off with the macOS password dialog setting passes no end option (`endArguments` stays empty, StatusBarController.swift:166, :192-198). **A possible macOS password dialog:** a lid-closed start, or a stop that runs the helper (settings left behind or another account's session, :355). The CLI asks unless password-free mode is on and the helper is current, which the status JSON says (3020-3025, `helper_is_ready` 3424-3440, `passwordless_is_configured` 3442-3444); unknown values count as asking. In custom password mode the app asks before the command runs (:171-188, :309-318, :353-367), so the CLI never asks. In both cases the user can cancel and nothing changes. |
| A4 | The dimmed look | `NSStatusBarButton.appearsDisabled` (macOS 10.10 and later). It works with the template images on light and dark menu bars, and the button stays clickable. Rejected: a third image (new assets at both scales), an animation (a timer while a dialog may stay open), a text label (takes width). |
| A5 | Added time and helper changes | The icon neither changes nor dims. The tooltip still says `Adding time…` or `Updating Awake’s helper…`. |
| A6 | The tooltip, the menu's first line, the menu items | Unchanged. The items keep their titles from the last status and stay disabled while a command runs (:717, :747, :760, :781). |
| A7 | VoiceOver | The button's accessibility label is the status text while a command runs, and `Awake is on` or `Awake is off` otherwise, the images' descriptions today (:73, :78, :1047). VoiceOver never reads a state the icon only previews. |
| A8 | Failure, cancel, another outcome | Nothing new. When the command ends, `pendingCommand` becomes nil and the icon follows the status read (:392, :397, :403-407). A failed start goes back to the regular `A` and posts `Awake failed` (:399, :413). A cancelled picker or password dialog exits 0 and posts nothing (6909-6916, `exit_start_cancelled` 3981-3990, 6829-6834). `Awake is already on` keeps the bold `A` (:438-442). A failed `Stop Awake and quit` keeps the app running (:465-472). |
| A9 | The icon-flip race | Fixed in A, by three rules. (1) No poll starts while a start or a stop runs: the command's own result brings the status. (2) A poll result that arrives while a start or a stop runs is dropped. (3) A poll result whose read started before the read of the status shown is dropped, comparing `fetchedUptime` (AwakeCLI.swift:54-57), as the heat recorder already does (HeatReport.swift:305-311). Added time and helper changes keep their polls, under rule 3 alone. Added time does not change whether the icon is bold, and a lid-closed one can wait minutes on a macOS password dialog (`extend_running_session` → `run_helper` → `run_as_admin`, 6105-6107, 3645); if the session ends meanwhile, the next poll turns the icon regular, as today. During a helper change a session that ends is still announced (the comment at :497-499). Notifications from polls stay held back during a start, added time or stop, as today (:500 is unchanged), so a stop is never announced twice. Rejected: polls on `commandQueue` (AwakeCLI.swift:230), where they would wait behind an open picker; rule 3 alone for starts and stops, which leaves a second bash competing with the command. |
| A10 | Where the logic lives | A new Foundation-only `StatusIcon.swift`, which `PendingCommand` moves into from :33-51. Its check builds that file alone, like `start-shortcut-check` (ci.yml:69-78). |
| B1 | The runner's pause | `/bin/sleep 1 &` and `wait`, and its cleanup ends that pause. bash interrupts the builtin `wait` for a trapped signal, but not a foreground command; this is in bash 3.2's manual, and the worker's `wait` at 5568 already relies on it. Still one `/bin/sleep` per pass. Rejected: `read -t 1` on a FIFO (one more file), a shorter sleep (more wake-ups for the whole session). |
| B2 | How the stop reaches the session | The stop command sends TERM to the worker right after checking it with `session_pid_matches`, and writes the request file only when the signal cannot be sent (question 4). The worker is the same user's (the runtime folder is checked by `validate_managed_runtime_path`), and TERM is what the monitor sends anyway (3290), handled by every version since 1.0.0. The monitor stays as it is, so that an older `awake` copy can still stop a newer session. That case arises only with a copy made by hand or an older copy elsewhere on `PATH`: the installer, which the Homebrew cask also runs, stops the running session before it replaces anything (scripts/install-awake.sh:384-402, :496; tools/homebrew/awake.rb:24-28). Rejected: always writing the file first; removing the monitor. |
| B3 | How often the stop command checks | Every 0.05 s, at most 600 times and for 30 s at most, which keeps the 30 s limit (the checks take time of their own, so the count alone would not). Only while a stop runs, which now ends within a check or two. |
| B4 | A worker that dies during the stop | The wait ends at the first check after the worker is gone, with the builtin `kill -0`, as 5abc543 did for starts. The worker is looked at before the status file, so an end it recorded still counts. Today this costs 30 s before the fallback. |
| B5 | Returning before the record is gone | The wait counts an end only once the session's record is gone too, or the worker is. The worker writes the status (5529) just before it removes the state file (5530); with 0.05 s checks a stop could return in between, and a `--status`, or C's report, would still say "on" (with a 0.6 s pause added there, 3 of 3 reports did). It costs one `awk`, on the last check only. This is also C's race fix. Rejected: reordering the worker's cleanup, which leaves a moment with neither file. |
| B6 | Signals during cleanup | Both cleanups ignore further INT, TERM and QUIT (`trap - EXIT; trap '' INT TERM QUIT`) instead of resetting them. On bash 5.2, with `trap -` a second TERM during cleanup killed the process (exit 143) and the end went unrecorded; with `trap ''` the cleanup finished. The worker already sends the runner two TERMs (5542, 5515), and B2 adds a second source. Programs started in cleanup inherit the ignore; all are short (`kill`, `mktemp`, `mv`, `rm`). |
| B7 | Checks before the signal | `request_active_session_stop` checks the worker itself (a positive PID, then `session_pid_matches`) instead of calling `state_session_is_active`, and main drops its own check at 6786. One `ps` fewer per stop. The PID must be positive: `kill 0` signals the whole process group. |
| B8 | The lid-closed stop check | 3759 and 3769 use the same 0.05 s and 600 limits (question 5). CLI only. |
| C1 | How the CLI hands over the status | Through a file the app names in a new environment variable, `AWAKE_STATUS_JSON_FILE`. Rejected: a last line on stdout (`normalizedErrorMessage` would show the JSON when stderr is empty, StatusBarController.swift:871-881); a new option (an older CLI exits 1 with `Unknown option`); a file descriptor (Foundation's `Process` passes only the three standard ones); writing it only on success (failures also leave a state the app shows). |
| C2 | What is written | Exactly the object `--status-json` prints (schema 1). Both come from one new function, `print_current_status`, so they cannot drift apart, and the app decodes it with the same `AwakeStatus`. |
| C3 | Which runs write it | Every run that took the state-change lock (6532): start, added time, stop, the toggle, `--install-helper`, `--uninstall-helper`, `--passwordless`, on every exit after that point, including the cancelled picker (6916), `exit_start_cancelled`, "already on" (6690, 6721, 6746), each failure, `caffeinate_stop`'s exit 1 (5631, 5636) and `set -e`. **Not written:** `--status` and `--status-json`; runs that end before the lock (option errors, the root refusal at 6426-6428, a `-w` process already gone at 6485-6495, a busy lock at 1286-1288); `awake -- COMMAND`, which lets go of the lock at 3874 and whose session has ended by the time it exits. The app falls back for these (C7). |
| C4 | When it is written | In the EXIT trap, before the lock is let go: a new `finish_main_run` replaces `release_main_lock` in the traps at 1304 and 1455. Exit statuses stay as they are (checked with `exit 3`, `set -e`, `exit` in a function, and running off the end). |
| C5 | The status is final | It is written after the command's own checks: `wait_for_session_start` (7030), `wait_for_helper_session_start` (7102), `request_active_session_stop` (6787) and `request_helper_session_stop` (6815). The helper writes `last` before it removes its session file (awake-helper:805, :809). The lid-open stop's gap is closed by B5. |
| C6 | `pmset` in the status read | Read only when no session runs, which is the only case that uses it (6601-6621). The output is the same. It saves 2 `pmset` and 2 `awk` in the report after a start, and in every poll while a session runs. |
| C7 | A missing or bad report | The app runs `fetchStatus`, as today: an older CLI, the exits before the lock, `--`, a CLI killed by a signal. When no session runs and `pmset` cannot be read, the report is `--status-json`'s error object (`print_status_json_error`, 2947-2965); `\|\| true` drops the status 1, and the app decodes it as `fetchStatus` would, which also ignores the exit status (AwakeCLI.swift:288-299): an `AwakeStatus` with `error` set. |
| C8 | App and CLI out of step | An older CLI ignores the variable; an older app never sets it. |
| C9 | Safety | The CLI writes only into a file that exists, is a regular file, is not a symlink and is this user's (`-f`, `-L`, `-O`, all Bash builtins). It never creates one. The variable is read once at the top and unset, so the worker, runner, notifier, helper and the command after `--` never see it. State-changing runs refuse root (6426-6428). |
| C10 | Name and documentation | `AWAKE_STATUS_JSON_FILE`, internal (question 6): not in `--help` or the README options, like `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY` and `AWAKE_APP_CUSTOM_PASSWORD_MODE`. Comments explain it in `bin/awake` and AwakeCLI.swift. |
| C11 | `fetchedAt` and `fetchedUptime` of the report | The moment the app sees the process exit, taken right after `waitUntilExit` (AwakeCLI.swift:567). That is a few ms after the CLI read the state, and it keeps A9's rule 3 true on its own. The doc comments of both fields (AwakeCLI.swift:51-57, "when the read started") are updated to say so. |
| D1 | Name | `AWAKE_APP_THERMAL_STATE` (question 7), next to the app-only `AWAKE_APP_CUSTOM_PASSWORD_MODE` that the same function sets (AwakeCLI.swift:586). |
| D2 | Value | One digit, `0` to `3`, on macOS's scale, which the CLI and the helper also read (`NSProcessInfo.thermalState`, 2154, awake-helper:555). No timestamp: the CLI measures the age with bash's `SECONDS`, so no clock and no `date` call (bash 3.2 has no `EPOCHSECONDS`). |
| D3 | Reading it | Once, at the top after line 57, before the first program (136), and unset at once in every run, so nothing launched later inherits it. A literal `case 0\|1\|2\|3` check; anything else is ignored and still unset. The raw value never reaches `(( ))`, where text like `a[$(cmd)]` would run a command. |
| D4 | How long it counts | 30 s after the CLI started, `0 <= age <= 30` (question 7). A click start shows the picker inside the same CLI, before the check; 30 s covers a normal pick and matches the guardrails' own 30 s. Older, or a negative age, falls back to `osascript`. |
| D5 | Who uses it | Only a new `foreground_thermal_state`, called from the two foreground checks: the start refusal (6967) and `helper_extend_guard_message` (6068), which runs before adding time to a lid-closed session "so that no password is asked for in vain" (6102-6104). `thermal_state` (2147) and `mac_is_overheating` (2217), which the runner calls (5398), are unchanged. |
| D6 | Dry-run | The app's value beats the mock file, so the self-test can prove it is used. |
| D7 | Where the app sets it | In `runManagedCommand`, for every state-changing command, read right before `process.run()`. `runProcess` (status reads and the picker) removes it. A thermal state a later macOS might add is not passed. |
| D8 | The helper | Unchanged, and no protocol bump. The helper runs as root and does not use the environment (awake-helper:15); sudo resets it, and the password-free rule has no `SETENV` (4139). In dry-run the helper runs without sudo (3613-3614), but the value is gone by then (D3). |
| X1 | Order | A, B, C, D, one commit each. A before C, as C's report relies on A9's rule 3; B before C, as both touch the stop waiter; C before D, as both touch AwakeCLI.swift. A and B are independent. |
| X2 | Version | 2.4.0, with plan-2.4.0's change: Changed and Fixed entries, no `**Breaking` and no `### Removed`, so `tools/release.sh` suggests minor. |
| X3 | E (the start sound) in phase 1 | No: the owner asked for A to D. E is small and app-only, and can follow in 2.4.0 if the owner wants it (6.10). |

## 3. What the user sees

### 3.1 The icon (A)

"Bold" and "regular" refer to the `A`. "Dimmed" is the disabled look. "At once" means when the click, key press or menu choice is handled, before any process starts. While a command runs, VoiceOver reads the same line as the tooltip; otherwise it reads `Awake is on` or `Awake is off` (A7).

| Action | Icon at once | Tooltip and the menu's first line | When the command ends |
|---|---|---|---|
| ⇧⌘A or `Start default session`, lid-open mode (the default) | bold | `Starting Awake…` | Stays bold. `Awake is already on` stays bold. A refusal (battery, heat) goes back to regular, with `Awake failed`. |
| The same, lid-closed, password-free mode on with a current helper | bold, dimmed | `Starting Awake…` | Solid bold once the session runs; regular on failure. |
| The same, lid-closed, custom password dialog | unchanged while the app's dialog is open, then bold, dimmed | `Starting Awake…` | As the row above. |
| The same, lid-closed, macOS dialog, with password-free mode off or the helper missing or out of date | regular, dimmed | `Starting Awake…` | Bold once running. Regular, not dimmed, on Cancel, with nothing posted. |
| A click while off, macOS dialog setting (the default), so the CLI shows the picker | regular, dimmed | `Starting Awake…` | Bold once running. Regular on Cancel, with nothing posted. |
| A click while off, custom dialog: the app's picker, then its password dialog if lid-closed | unchanged while those are open, then bold (lid-open) or bold, dimmed (lid-closed) | `Starting Awake…` | As the shortcut rows. |
| `Add 1 hour` | bold, unchanged | `Adding time…` | Bold. Polls go on meanwhile (A9), so a session that ends while a macOS password dialog is open turns the icon regular at the next poll, within about 12 s, as today. |
| A click, ⇧⌘A or `Stop session` while on | regular | `Stopping Awake…` | Regular. On failure, bold again, with `Awake failed`. |
| The same, restoring sleep left off or another account's session, macOS dialog, password-free mode off | bold, dimmed | `Stopping Awake…` | Regular. Bold again on Cancel. |
| `Stop Awake and quit` | regular (bold, dimmed in the case of the row above) | `Stopping Awake…` | The app quits. On failure or Cancel the icon is bold and the app stays, as today. |
| `Install helper…`, `Start without password` | unchanged | `Updating Awake’s helper…` | Unchanged. |

- **Clicks during a command.** A click still does nothing, and ⇧⌘A still beeps (:148, :287-290; question 2).
- **Custom password mode.** The app's own picker, password dialog and `sudo -n` check run on the main thread before the icon can change (:171-188, :910), as today.
- **The icon never flips back** after a start or stop because of a status check that was still running (A9).

### 3.2 Starts and stops (B, C, D)

- A lid-open stop takes about a quarter of a second of CLI time on Linux, instead of 0.85 to 1.85 s; on a Mac about a second sooner on average (estimate). This covers the menu bar, ⇧⌘A, `awake` and `awake --stop`. In lid-open mode, `awake -- COMMAND` exits sooner after the command ends, and so does a `-w PID` start that finds the process already gone (7042).
- Every start, stop and added time from the app is one process shorter (C), and every start or added time from the app with `Stop when too hot` on (the default) runs no `osascript` in the CLI (D), as fast as with the setting off.
- A lid-open stop no longer creates `stop-request`, unless the signal cannot be sent; lid-closed stops always do (README.md:561).
- `--status-json` no longer runs `pmset` while a session runs. Its output is the same.
- If the Mac reaches `critical` within the 30 s after the app read the state, a lid-open session starts and its runner ends it within about a second as `overheated`, instead of the start being refused. A lid-closed start is still refused by the helper, then `Failed to enable awake mode.`
- Nothing else changes: messages, exit statuses, completion reasons, notifications and sounds.

## 4. Code changes

### 4.1 A: the icon changes at once

**New `app/AwakeStatusApp/Sources/StatusIcon.swift`** (about 155 lines with doc comments, Foundation only). It starts like every file in Sources, with `// Copyright (C) 2026 Antti Käenmäki`, a blank line and `import Foundation`; the sketch below leaves those out. Nothing needs to list it: `tools/build-awake-app.sh:50-56` and the installer (`scripts/install-awake.sh:488`, through that script) compile every file in Sources, and the macOS 12.5 CI build uses `Sources/*.swift` (ci.yml:53-56).

```swift
/// A start, added time, stop, or helper change that the menu bar app runs.
enum PendingCommand: Equatable {
    case starting(StatusIcon.Preview)
    case extending
    case stopping(StatusIcon.Preview)
    case configuring

    /// The four texts of StatusBarController.swift:39-50, unchanged.
    var statusText: String { ... }

    /// True for a start or a stop: no poll runs or counts meanwhile, as the
    /// command's result brings the status (A9, rules 1 and 2). Added time and
    /// helper changes keep their polls.
    var pausesPolls: Bool { ... }

    static func pollResultApplies(
        readStartedAt: TimeInterval,
        shownReadStartedAt: TimeInterval,
        pending: PendingCommand?
    ) -> Bool {
        if pending?.pausesPolls == true {
            return false
        }
        return readStartedAt >= shownReadStartedAt
    }
}

struct StatusIcon: Equatable {
    enum Preview: Equatable {
        case outcome        // what it leads to: a lid-open start, a stop
        case dimmedOutcome  // the same, dimmed until done: a lid-closed start
        case dimmedCurrent  // the state before, dimmed: picker or macOS password dialog
    }

    static let onLabel = "Awake is on"
    static let offLabel = "Awake is off"

    let showsOn: Bool
    let dimmed: Bool
    let accessibilityLabel: String

    init(active: Bool, pending: PendingCommand?) {
        var preview: Preview?
        var target = active
        switch pending {
        case let .starting(chosen)?:
            preview = chosen
            target = true
        case let .stopping(chosen)?:
            preview = chosen
            target = false
        case .extending?, .configuring?, nil:
            break
        }
        switch preview {
        case .outcome?:
            showsOn = target
            dimmed = false
        case .dimmedOutcome?:
            showsOn = target
            dimmed = true
        case .dimmedCurrent?:
            showsOn = active
            dimmed = true
        case nil:
            showsOn = active
            dimmed = false
        }
        accessibilityLabel = pending?.statusText ?? (active ? StatusIcon.onLabel : StatusIcon.offLabel)
    }

    /// Unknown values (before the first status, or after a failed one) count as asking.
    static func cliMayAskForPassword(
        runsHelper: Bool,
        customPasswordDialog: Bool,
        passwordless: Bool?,
        helperInstalled: Bool?
    ) -> Bool {
        guard runsHelper, !customPasswordDialog else {
            return false
        }
        return passwordless != true || helperInstalled != true
    }

    static func startPreview(lengthChosen: Bool, lidClosed: Bool, cliMayAskForPassword: Bool) -> Preview {
        if !lengthChosen || cliMayAskForPassword {
            return .dimmedCurrent
        }
        return lidClosed ? .dimmedOutcome : .outcome
    }

    static func stopPreview(cliMayAskForPassword: Bool) -> Preview {
        cliMayAskForPassword ? .dimmedCurrent : .outcome
    }
}
```

Swift 5.7, the oldest the installer accepts (scripts/install-awake.sh:345-350), which builds the app on the user's Mac: explicit `self.` inside escaping closures (implicit `self` after `guard let self` is 5.8, SE-0365), no `if` or `switch` expressions (5.9), no `consume` or macros, and each `let` property set in every `case`. CI cannot catch these: it compiles with the runner's much newer `swiftc` in Swift 5 mode, and `-target arm64-apple-macos12.5` checks API availability only. The existing `refreshStatus` (StatusBarController.swift:477-505) already writes `self.` after `guard let self`; keep it so.

**`StatusBarController.swift`** (about 80 lines added, 50 removed):

1. Remove the nested `private enum PendingCommand` (:33-51).
2. In `onImage` and `offImage` (:70-79), pass `description: StatusIcon.onLabel` and `StatusIcon.offLabel`.
3. In `startAwake`, at :190, where `endArguments` is empty exactly when the CLI will show its picker (:166, :175):
   ```swift
   pendingCommand = .starting(StatusIcon.startPreview(
       lengthChosen: !endArguments.isEmpty,
       lidClosed: backend == .awake,
       cliMayAskForPassword: cliMayAskForPassword(runsHelper: backend == .awake, preferencesSnapshot)
   ))
   ```
4. In `startDefaultSession` (:320), the same with `lengthChosen: true, lidClosed: mode.isLidClosed`.
5. `addTime` (:226, `.extending`) and `runMaintenance` (:840, `.configuring`) stay as they are.
6. `stopAwake()` (:335-345) becomes `stopAwake(intent: CommandIntent = .stop)`:
   - it sets `pendingCommand = .stopping(StatusIcon.stopPreview(cliMayAskForPassword: cliMayAskForPassword(runsHelper: stopRunsHelper, preferencesSnapshot)))`;
   - it passes `intent` to `handleCommandResult`;
   - `stopThenQuitIfNeeded` calls `stopAwake(intent: .stopAndQuit)` in place of its own copy (:379-387);
   - the callers at :157, :292 and :816 do not change.
7. Two helpers next to `customPasswordForStop`, whose guard (:354-355) then uses `stopRunsHelper`:
   ```swift
   private var stopRunsHelper: Bool {
       currentStatus.leftoverSettings == true || currentStatus.otherUserSession == true
   }

   private func cliMayAskForPassword(runsHelper: Bool, _ preferencesSnapshot: PreferencesSnapshot) -> Bool {
       StatusIcon.cliMayAskForPassword(
           runsHelper: runsHelper,
           customPasswordDialog: preferencesSnapshot.useCustomPasswordDialog,
           passwordless: currentStatus.passwordless,
           helperInstalled: currentStatus.helperInstalled
       )
   }
   ```
8. `updateStatusItem` (:682-692):
   ```swift
   let icon = StatusIcon(active: currentStatus.active, pending: pendingCommand)
   button.image = icon.showsOn ? onImage : offImage
   button.appearsDisabled = icon.dimmed
   button.setAccessibilityLabel(icon.accessibilityLabel)
   button.toolTip = statusText()
   ```
9. `refreshStatus` (:476-506):
   - First line: `if pendingCommand?.pausesPolls == true { return }` (rule 1).
   - The error placeholder (:486): take `startedAt` and `startedUptime` before `fetchStatus()` and stamp them on the placeholder, built in a local `var failed`, so `status` stays a `let` (a captured `var` warns in the `@Sendable` closure of newer SDKs).
   - First in the main-queue block (rules 2 and 3):
     ```swift
     guard PendingCommand.pollResultApplies(
         readStartedAt: status.fetchedUptime,
         shownReadStartedAt: self.currentStatus.fetchedUptime,
         pending: self.pendingCommand
     ) else {
         return
     }
     ```
   - :500 stays as it is (`pendingCommand == nil || pendingCommand == .configuring`): a poll applied during added time moves the icon, but its notification is held back, as today, so a stop is announced once, by the command's result.
10. The comment at :396 becomes: "Back to the last known state from what the icon showed while the command ran; the poll below corrects it."

Command results are still always applied (:403, :851). No poll starts during a start or a stop (rule 1) or is applied during it (rule 2). A poll that started before a command, or during added time or a helper change, and arrives after the command's result, read the state earlier than the command's status did, so rule 3 drops it. `currentStatus` starts as `inactivePlaceholder`, whose `fetchedUptime` is set when the controller first reads it (AwakeCLI.swift:57, :86, StatusBarController.swift:81), before the first poll, so the first poll always applies.

**`.github/workflows/ci.yml`**, after line 78:

```yaml
      # StatusIcon.swift uses Foundation only, so its check builds with that
      # file alone.
      - name: Check the menu bar icon
        run: |
          swiftc -target arm64-apple-macos12.5 -parse-as-library \
            app/AwakeStatusApp/Sources/StatusIcon.swift tests/app/status-icon-check.swift \
            -o "$RUNNER_TEMP/status-icon-check"
          "$RUNNER_TEMP/status-icon-check"
```

### 4.2 B: a lid-open stop without fixed waits (`bin/awake` only)

1. **After line 93:**
   ```bash
   # A stop the user asked for usually takes a fraction of a second, so it is
   # checked on more often, for the same 30 seconds at most.
   readonly STOP_WAIT_MAX_CHECKS=600
   readonly STOP_WAIT_POLL_SECONDS=0.05
   ```
2. **Replace `wait_for_requested_stop_completion` (3304-3351)** (B3, B4, B5). The case block moves one level in; a status of another session now falls through to the shared check at the end instead of having its own sleep and `continue`.
   ```bash
   # Waits until the Caffeine session in state file $1 has recorded its end in
   # the status file, with token $4: $2 checks, $3 seconds apart. $5 is the
   # PID of the session's worker, which records the end before it exits: once
   # it is gone, the wait ends at the next check.
   wait_for_requested_stop_completion() {
       local state_file=$1
       local max_checks=${2:-$STARTUP_WAIT_MAX_CHECKS}
       local sleep_seconds=${3:-$STARTUP_WAIT_POLL_SECONDS}
       local expected_token=${4:-}
       local worker_pid=${5:-}
       local worker_gone=false
       local waited=0
       local status_file=""
       local status_reason=""
       local status_restore_result=""

       validate_managed_runtime_path "$state_file" state
       status_file="$(dirname -- "$state_file")/status"
       validate_managed_runtime_path "$status_file" status

       while (( waited < max_checks )); do
           # Looked at before the status file, so that the checks below see the
           # end it recorded. The builtin kill: the worker is this user's.
           if is_positive_integer "$worker_pid" && ! kill -0 "$worker_pid" 2>/dev/null; then
               worker_gone=true
           fi
           if [[ -f "$status_file" ]]; then
               if [[ -n "$expected_token" ]] &&
                   ! status_file_token_matches "$status_file" "$expected_token"; then
                   log_debug "wait_for_requested_stop_completion ignoring_mismatched_status state_file=$state_file status_file=$status_file checks=$waited"
               else
                   status_reason=$(read_state_value reason "$status_file" 2>/dev/null || true)
                   case "$status_reason" in
                       stopped|cancelled|timeout|low_battery|overheated|unplugged|process_exited)
                           status_restore_result=$(read_state_value restore_result "$status_file" 2>/dev/null || true)
                           if [[ "$status_restore_result" == "failed" ]]; then
                               log_debug "wait_for_requested_stop_completion failed_restore state_file=$state_file status_file=$status_file reason=$status_reason checks=$waited"
                               return 1
                           fi
                           # The worker removes the session's record just after it
                           # writes this one; until then --status still sees it.
                           if [[ "$worker_gone" == "true" ]] || ! state_token_matches "$state_file" "$expected_token"; then
                               log_debug "wait_for_requested_stop_completion ready state_file=$state_file status_file=$status_file reason=$status_reason checks=$waited"
                               return 0
                           fi
                           ;;
                       failed)
                           log_debug "wait_for_requested_stop_completion failed state_file=$state_file status_file=$status_file checks=$waited"
                           return 1
                           ;;
                   esac
               fi
           fi
           if [[ "$worker_gone" == "true" ]]; then
               log_debug "wait_for_requested_stop_completion failed worker_gone worker_pid=$worker_pid state_file=$state_file checks=$waited"
               return 1
           fi

           /bin/sleep "$sleep_seconds"
           ((waited += 1))
       done

       log_debug "wait_for_requested_stop_completion timed_out state_file=$state_file checks=$waited"
       return 1
   }
   ```
3. **Replace `request_active_session_stop` (3353-3377)** (B2, B7). It also drops the unused `local status_file`.
   ```bash
   # Ends the Caffeine session in state file $1 through its worker, which
   # records why it ended, and waits for that record. Fails at once when the
   # worker is gone, as only the worker answers, and when the session did not
   # end in time; the caller then ends it directly.
   request_active_session_stop() {
       local state_file=$1
       local session_token=""
       local worker_pid=""

       validate_managed_runtime_path "$state_file" state
       worker_pid=$(read_state_value pid "$state_file")
       # Never 0, which kill takes as the whole process group.
       if ! is_positive_integer "$worker_pid" || ! session_pid_matches "$worker_pid" "$state_file"; then
           return 1
       fi

       session_token=$(read_state_value session_token "$state_file")
       if [[ -z "$session_token" ]]; then
           return 1
       fi

       # The worker is this user's, and its command line was checked just now:
       # TERM ends the session at once, as the stop-request monitor would at
       # its next look. The request file is for when the signal cannot be sent.
       log_debug "request_active_session_stop signal worker_pid=$worker_pid state_file=$state_file"
       if ! kill -TERM "$worker_pid" 2>/dev/null &&
           ! write_stop_request_file "$state_file" "$session_token"; then
           return 1
       fi
       if wait_for_requested_stop_completion "$state_file" "$STOP_WAIT_MAX_CHECKS" "$STOP_WAIT_POLL_SECONDS" "$session_token" "$worker_pid"; then
           return 0
       fi

       remove_stop_request_file "$state_file" || true
       return 1
   }
   ```
4. **The runner** (B1, B6). After line 5248 add `local nap_pid=0`. `cleanup_caffeinate_runner` (5295-5301) becomes:
   ```bash
       cleanup_caffeinate_runner() {
           trap - EXIT
           # A second TERM (the worker sends one from its trap and one from its
           # cleanup) must not cut this short.
           trap '' INT TERM QUIT
           # The pause between passes, when the trap ran during it. Not yet
           # waited for, so its ID is still this process's child's.
           if (( nap_pid > 0 )); then
               kill -TERM "$nap_pid" 2>/dev/null || true
           fi
           if is_nonnegative_integer "$child_pid" && (( child_pid > 0 )); then
               /bin/kill -TERM "$child_pid" >/dev/null 2>&1 || true
               wait "$child_pid" >/dev/null 2>&1 || true
           fi
       }
   ```
   Line 5435, `/bin/sleep 1`, becomes:
   ```bash
           # bash runs a trap only after a command in the foreground ends, but
           # it interrupts wait for one: so TERM ends the runner at once, not
           # after up to a second. Still one /bin/sleep per pass.
           /bin/sleep 1 &
           nap_pid=$!
           wait "$nap_pid" 2>/dev/null || true
           nap_pid=0
   ```
5. **The worker's cleanup** (B6). Line 5506, `trap - EXIT INT TERM QUIT`, becomes:
   ```bash
           trap - EXIT
           # The session is ending already. A stop that comes now (the stop
           # command's TERM, or its monitor's) must not cut this short, or the
           # end would go unrecorded.
           trap '' INT TERM QUIT
   ```
6. **main, 6783-6787** (B7):
   ```bash
           # Only the worker answers a stop request. When it was killed and
           # only the runner is left, the request fails at once, and the
           # session is stopped directly instead.
           if request_active_session_stop "$STATE_FILE"; then
   ```
7. **B8:** 3759 uses `STOP_WAIT_MAX_CHECKS`, and 3769 `STOP_WAIT_POLL_SECONDS`.

**Unchanged:** the monitor (3269-3302) and `STOP_MONITOR_POLL_SECONDS` (95); the worker's traps (5540-5542) and `caffeinate_stop_reason` (3848-3854); `caffeinate_stop` (5604-5658) and `terminate_pid_and_wait` (2372-2399); the order in the worker's cleanup, the status first and then the record; the dry-run `caffeinate` stand-in (5320); the start path; `bin/awake-helper`.

**Notes for the implementer:**

- `wait "$stop_monitor_pid"` at 5510 returns at once: the monitor is started inside `$(...)` (5561), so it is not the worker's child.
- `nap_pid` goes back to 0 after every normal `wait`. The trap can only run during that `wait`, so cleanup never signals a PID already reaped.
- The other callers of `request_active_session_stop` keep working: `run_bound_command` (3897) writes the command-finished file first, so the worker's TERM trap still records `process_exited`; the start at 7042 now fails at once when the worker is gone, where it took 30 s.
- Bash 3.2 has everything used: `&`, `$!`, `wait PID`, the builtins `kill -0` and `kill -TERM`, `trap ''`, `(( ))`. Nothing uses `BASHPID`, `EPOCHREALTIME` or `wait -n`. macOS `/bin/sleep` takes fractions; 0.1, 0.2 and 0.25 are used already.
- Each pause is a background job that `wait` reaps, and bash remembers at most `CHILD_MAX` exit statuses, so a 365-day session should not grow (QA 22).

### 4.3 C: the command reports the status it leaves

**`bin/awake`** (about 105 lines added, 45 removed):

1. **After line 57**, read and unset the variable (D's block follows it, 4.4):
   ```bash
   # Awake.app names a file here for its start, stop, and setup commands. A run
   # that takes the state-change lock writes the --status-json object for the
   # state it leaves into it as it exits (write_status_report), so the app need
   # not run --status-json again. Not passed on to the processes awake starts.
   STATUS_REPORT_FILE=${AWAKE_STATUS_JSON_FILE:-}
   unset AWAKE_STATUS_JSON_FILE
   ```
2. **After `release_main_lock` (1151-1159):**
   ```bash
   # The EXIT trap of a run that took the state-change lock. The status is
   # written first, while the lock still keeps other awake commands from
   # changing the state. The exit status stays the one the run exited with, as
   # nothing here calls exit or fails.
   finish_main_run() {
       write_status_report || true
       release_main_lock
   }
   ```
3. **Lines 1304 and 1455:** `trap 'release_main_lock' EXIT` becomes `trap 'finish_main_run' EXIT`. The terminal prompt's traps (1477-1482) stay; the app never shows that prompt.
4. **After `print_status_json` (2967-3090)**, two functions.
   - `print_current_status` prints what `--status`, or `--status-json` with `STATUS_JSON_OUTPUT`, shows for the state now, read afresh and read-only. Its body is main's status block, moved, with these differences:
     - locals `caffeinate_active`, `helper_state`, `helper_foreign`, `current_sleep`, `current_disablesleep`, `remaining_seconds`;
     - `caffeinate_active=true` when the state file exists, is a Caffeine one and `state_session_is_active` (6547-6551), without the removal of an older version's file at 6553-6557, which stays in main;
     - `helper_state=$(helper_session_state)`, then `HELPER_SESSION_FOREIGN=false` and the foreign check of 6564-6567;
     - the Caffeine branch (6583-6590) and the running helper branch (6591-6600), each ending in `return 0`;
     - only then the sleep settings, as at 6569-6570 (C6). When they cannot be read, the error of 6601-6607, then `return 1` in place of `exit 1`;
     - then 6608-6621: leftover settings when `helper_state` is `stale` or `keep_awake_is_enabled "$current_sleep" "$current_disablesleep"`, otherwise off.
   - `write_status_report`:
   ```bash
   # Writes the --status-json object for the state this run leaves into the
   # file Awake.app named in AWAKE_STATUS_JSON_FILE: an existing regular file
   # of this user, not a symlink. Called by finish_main_run. Not for the
   # command after --, whose session has ended by then. When the sleep
   # settings cannot be read, it writes the error object, as --status-json
   # would print it. Nothing is written when no whole object comes out; the
   # app then runs --status-json.
   write_status_report() {
       local report=""

       if [[ -z "$STATUS_REPORT_FILE" || ${#RUN_COMMAND[@]} -gt 0 ]] ||
           [[ ! -f "$STATUS_REPORT_FILE" || -L "$STATUS_REPORT_FILE" || ! -O "$STATUS_REPORT_FILE" ]]; then
           return 0
       fi
       report=$(STATUS_JSON_OUTPUT=true; print_current_status) || true
       if [[ "$report" == "{"*"}" ]]; then
           { printf '%s\n' "$report" > "$STATUS_REPORT_FILE"; } 2>/dev/null || true
       fi
   }
   ```
5. **In `main`:**
   - 6531-6533 become:
     ```bash
         # Read-only, without the lock.
         if [[ "$STATUS_ONLY" == "true" ]]; then
             print_current_status || exit 1
             exit 0
         fi
         acquire_main_lock
     ```
   - 6553, `elif [[ "$STATUS_ONLY" != "true" ]]; then`, becomes `else`.
   - The status block at 6582-6624 goes. No other `STATUS_ONLY` test remains after the lock. Everything before 6531 (the runtime-folder check at 6474-6481, the UI mode) still runs for `--status`, as today.
6. **No change to `wait_for_requested_stop_completion`:** C's race fix (C5) is B5, which is in already (X1).

**`AwakeCLI.swift`** (about 40 lines added, 6 removed; merged with D in 4.4):

- After `ProcessResult` (153-157):
  ```swift
  /// A state-changing command's result, with the status it reported for the
  /// state it left, if it reported one.
  private struct ManagedCommandResult {
      let processResult: ProcessResult
      let reportedStatus: AwakeStatus?
  }
  ```
- The end of `runCommand` (420-426):
  ```swift
          let result = try runManagedCommand(
              arguments: arguments,
              customPassword: customPassword,
              appCustomPasswordMode: appCustomPasswordMode
          )
          // The command reports the status it left. Without that report (an
          // older CLI, or one that stopped before its checks) it is read.
          let after = try result.reportedStatus ?? fetchStatus()
          return AwakeCommandOutcome(before: before, after: after, processResult: result.processResult)
  ```
- `runManagedCommand` (506-572):
  - the doc comments of `fetchedAt` and `fetchedUptime` (51-57) become, for example: "When the read of this status started, or, for a status a command reported, when that command exited (after its read), so that no poll that started earlier counts as newer." (C11);
  - returns `ManagedCommandResult`; its doc comment adds "The CLI writes the status it leaves to a third file, named in `AWAKE_STATUS_JSON_FILE`, as `--status-json` would print it."
  - after 520: `let statusURL = captureDirectory.appendingPathComponent("awake-statusbar-status-\(UUID().uuidString)")`, removed in the `defer` at 521-524 with the others;
  - at 529-530 also `fileManager.createFile(atPath: statusURL.path, contents: Data())`, under the comment "The CLI writes only into a file that exists.";
  - 550-553: the environment, as merged in 4.4;
  - after `waitUntilExit()` (567), and as the new return (569-571):
    ```swift
    // The CLI read the status just before it exited.
    let exitedAt = Date()
    let exitedUptime = ProcessInfo.processInfo.systemUptime
    let stdout = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
    let stderr = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
    var reportedStatus: AwakeStatus?
    if let data = try? Data(contentsOf: statusURL), !data.isEmpty,
       var status = try? decoder.decode(AwakeStatus.self, from: data) {
        status.fetchedAt = exitedAt
        status.fetchedUptime = exitedUptime
        reportedStatus = status
    }
    return ManagedCommandResult(
        processResult: ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr),
        reportedStatus: reportedStatus
    )
    ```
- `environment()` removes `AWAKE_STATUS_JSON_FILE` ("Set by runManagedCommand alone"), so `fetchStatus` and the picker never pass a stale value.
- `StatusBarController.swift`: no change for C. `outcome.after` keeps its type and fields.

### 4.4 D: the app passes its thermal state

**`bin/awake`** (about 25 lines of code, 15 of comments):

1. **After line 57**, after C's block:
   ```bash
   # The thermal state Awake.app read just before it ran this command: 0
   # nominal, 1 fair, 2 serious, 3 critical. Only this process's own checks
   # before a start or added time use it (foreground_thermal_state), and only
   # while it is fresh. It leaves the environment here, before anything else
   # runs, so that what a start leaves running (the Caffeine worker and runner,
   # the notifier, the command after --) and the helper never get it: a stale
   # value there would quietly break the thermal guard for the whole session.
   APP_THERMAL_STATE=""
   APP_THERMAL_STATE_SECONDS=0
   if [[ -n "${AWAKE_APP_THERMAL_STATE+set}" ]]; then
       case "$AWAKE_APP_THERMAL_STATE" in
           0|1|2|3)
               APP_THERMAL_STATE=$AWAKE_APP_THERMAL_STATE
               APP_THERMAL_STATE_SECONDS=$SECONDS
               ;;
       esac
       unset AWAKE_APP_THERMAL_STATE
   fi
   ```
2. **After line 109:**
   ```bash
   # The app's thermal state counts for this long after awake started; the
   # guardrails themselves read the state every 30 seconds.
   readonly APP_THERMAL_STATE_MAX_AGE_SECONDS=30
   ```
3. **After line 2158**, the end of `thermal_state`:
   ```bash
   # The thermal state for this command's own checks before a start or added
   # time: the one Awake.app passed, while it is fresh, otherwise
   # thermal_state's. Running sessions never use it: the Caffeine runner calls
   # thermal_state, and the helper reads the state itself.
   foreground_thermal_state() {
       local age=$((SECONDS - APP_THERMAL_STATE_SECONDS))

       if [[ -n "$APP_THERMAL_STATE" ]] && (( age >= 0 && age <= APP_THERMAL_STATE_MAX_AGE_SECONDS )); then
           log_debug "foreground_thermal_state source=app state=$APP_THERMAL_STATE age=$age"
           printf '%s' "$APP_THERMAL_STATE"
           return 0
       fi
       thermal_state
   }
   ```
4. **6068 and 6967:** `thermal=$(thermal_state)` becomes `thermal=$(foreground_thermal_state)`.
5. **Unchanged on purpose:** `thermal_state` (2147), `mac_is_overheating` (2217), and the internal dispatch at 6358-6423.

**`app/AwakeStatusApp/Sources`** (about 20 lines):

6. **`HeatReport.swift`, after :118**, in `HeatSummary`. Foundation only, so the heat-report check still builds this file alone:
   ```swift
   /// macOS's thermal state on this scale, which is also bin/awake's and the
   /// helper's (they read NSProcessInfo.thermalState too). Nil for a state a
   /// later macOS might add; the CLI then reads the state itself.
   static func number(for state: ProcessInfo.ThermalState) -> Int? {
       switch state {
       case .nominal: return 0
       case .fair: return fairState
       case .serious: return seriousState
       case .critical: return criticalState
       @unknown default: return nil
       }
   }
   ```
7. **`AwakeCLI.swift`**, `environment(...)` (574-592), with C's line, in full:
   ```swift
   private func environment(
       suppressNotifications: Bool,
       appCustomPasswordMode: Bool,
       passThermalState: Bool = false
   ) -> [String: String] {
       var environment = ProcessInfo.processInfo.environment
       // … the notification and custom password lines, as at 579-589 …
       // A start or added time checks the thermal state first; the app's reading
       // spares the CLI an osascript run. Read here, right before the command
       // starts, as the CLI trusts it only for 30 seconds and never hands it on.
       if passThermalState, let state = HeatSummary.number(for: ProcessInfo.processInfo.thermalState) {
           environment["AWAKE_APP_THERMAL_STATE"] = String(state)
       } else {
           environment.removeValue(forKey: "AWAKE_APP_THERMAL_STATE")
       }
       environment.removeValue(forKey: "AWAKE_GUI_CUSTOM_PASSWORD")
       // Set by runManagedCommand alone.
       environment.removeValue(forKey: "AWAKE_STATUS_JSON_FILE")
       return environment
   }
   ```
   And in `runManagedCommand`, 550-553 become (C and D):
   ```swift
   // A new name: `environment` would shadow the method in its own initializer.
   var commandEnvironment = environment(
       suppressNotifications: true,
       appCustomPasswordMode: appCustomPasswordMode,
       passThermalState: true
   )
   commandEnvironment["AWAKE_STATUS_JSON_FILE"] = statusURL.path
   process.environment = commandEnvironment
   ```
   `runProcess` (489-492) keeps the default, so status reads and the picker never carry the variable, not even one the app itself was started with.

### 4.5 `tools/measure-latency.sh` (new, about 150 lines)

The timing script of 7.1. It goes in with phase 1, so the owner can time the installed version before the update and the new one after. It is not installed. Like every script in `tools/`, it starts with `#!/bin/bash` and `# Copyright (C) 2026 Antti Käenmäki`, and is committed with mode 755 (`git ls-files -s tools/*.sh` shows 100755 for each), as the CI step below runs it directly. CI already runs `bash -n` on `tools/*.sh` (ci.yml:23). A CI step after the self-test runs it once in dry-run, to catch breakage, not to time anything:

```yaml
      # Runs the timing script once against the dry run, so that it keeps
      # working; the times on a CI runner mean nothing.
      - name: Check the timing script
        run: tools/measure-latency.sh --dry-run --rounds 1 --cli bin/awake
```

Its contract:

- `tools/measure-latency.sh [--rounds N] [--lid-closed] [--sound] [--cli PATH] [--dry-run]`. Defaults: 5 rounds, the installed `~/Library/Application Support/Awake/bin/awake`.
- It runs the CLI as the app does: the same arguments (AwakeCLI.swift:431-470), the app's environment (574-592: `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY=true` for the action only; `AWAKE_NOTIFICATIONS`, `AWAKE_NO_NOTIFICATIONS`, `AWAKE_APP_CUSTOM_PASSWORD_MODE` and `AWAKE_GUI_CUSTOM_PASSWORD` unset), standard input from `/dev/null`, and output to files, never pipes (AwakeCLI.swift:506-509).
- The action also gets `AWAKE_STATUS_JSON_FILE` (an existing empty file, C) and `AWAKE_APP_THERMAL_STATE` (read once with `osascript`, outside the timing, D). Older versions ignore both, so the same script times both versions.
- Each round: a lid-open start (`--gui --start --duration-seconds 1200 --backend caffeinate --min-battery 5 --thermal-guard on --unplug-guard off --keep-display on`, plus `--sound` with `--sound`), a 2 s pause, then `--gui --stop`. With `--lid-closed`, the same with `--backend awake`, but only in dry-run or when `sudo -n <helper> check` passes, as a password prompt would be timed too.
- Each of the three runs (status before, action, status after) is timed with the bash `time` keyword (`TIMEFORMAT=%3R`): no extra process, and it works in bash 3.2.
- It refuses to run while a session is on, checks that each start started and each stop stopped, and stops a session it started when it fails or is interrupted.
- It prints a first line with the version, the Mac model, the macOS version and the rounds; then min, median and max per step in ms; then, per action, three sums of medians: "today" (before + action + after), "with C" (before + action) and "with C and H" (the action alone). The raw times go to `./awake-latency-YYYYMMDD-HHMMSS.tsv`.
- In dry-run, `--sound` times nothing: dry-run skips `afplay` (3123-3126).

### 4.6 Where the items meet

- **After line 57:** C's block, then D's. Both unset their variable before anything runs.
- **`AwakeCLI.swift`:** C changes `runCommand` (414-427) and `runManagedCommand`; D changes `environment()` and the one call at 550-553. The merged code is in 4.4, item 7.
- **The stop waiter:** B rewrites it (4.2, item 2), and C needs nothing more there.
- **A and C:** the report's `fetchedUptime` is the exit time (C11), so a poll that started during the command is older and dropped (A9, rule 3). Without a report the app reads the status as today, whose `fetchedUptime` is the start of that read, which is also newer.
- **A and D:** D only shortens how long the preview is shown.
- **The self-test's top line (6):** `unset AWAKE_NOTIFICATIONS AWAKE_NO_NOTIFICATIONS AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY AWAKE_STATUS_JSON_FILE AWAKE_APP_THERMAL_STATE`, so a developer's shell cannot change what the checks see.

## 5. Tests

All self-test checks run in dry-run on macOS CI with `/bin/bash` 3.2 (ci.yml:107-108). The app checks build and run on CI too.

### 5.1 A: `tests/app/status-icon-check.swift` (new, about 135 checks)

It follows `start-shortcut-check`: a log class, `@main`, exit 1 on any failure. The CI step is in 4.1.

- **Idle:** on and off, not dimmed, labelled `Awake is on` or `Awake is off`.
- **Every command:** each `starting` and `stopping` preview, plus `extending` and `configuring`, from off and from on: bold or not, dimmed or not, and VoiceOver reads the status text.
- **The password rule:** never asks for lid-open, nor in custom password mode, for every value of `passwordless` and `helperInstalled`, nil included; asks for nothing only when password-free mode is on and the helper is current; an out-of-date helper asks, also in password-free mode; unknown values ask.
- **Previews:** `startPreview` and `stopPreview` for every input.
- **The rows of 3.1,** each chosen the way the controller chooses it.
- **Texts:** the four status texts, exactly as README.md:244 quotes them, and the two labels.
- **Polls:** `pausesPolls` for each command (true for `starting` and `stopping` only); a newer and an equal read apply; an older read is dropped (the race); every poll is dropped during each start and stop; polls are kept during added time and a helper change, unless older.

CI compiles the controller changes in the app build (ci.yml:30-31) and the macOS 12.5 build (:53-56). That is their first compile.

### 5.2 B: the stop

1. **Sourced checks,** in `run_sourced_regression_checks`, after the `caffeinate_start` check that ends at line 1150 and before `sound_calls=0` (1152), each in the `if ! ( … ); then exit 1; fi` style with stand-ins:
   - the waiter: with PID 999999 gone and no status, it fails, logging `worker_gone … checks=0`; an end the worker recorded before it died still counts; a final status while the state file still has the token and the worker (`$$`) runs does not succeed within 3 checks (`timed_out checks=3`);
   - the request: a stand-in worker (a subshell that writes `reason=stopped` on TERM) stops within 5 s, and `write_stop_request_file` (a counting stand-in) is not called; with PID 999999, the request file is written once and the stop fails within 5 s; with a worker whose command line does not match, neither happens;
   - the worker's cleanup: `caffeinate_start` with a runner that exits 0 and a `write_status_file` stand-in that first runs `/bin/sh -c 'kill -TERM "$PPID"'`: the recorded reason is `timeout`. On `8ef37f3` the subshell dies with 143 and nothing is written.
2. **Step 12d,** at 3521-3524: the `--` check also requires `sh finished (exit status 7). Awake stopped.` and `"last_completion_reason":"process_exited"`, for both backends, now that the worker gets TERM directly.
3. **Step 12i, after line 4203: the "frozen" check.** It starts an indefinite Caffeine session and stops two processes with SIGSTOP: the runner's pause (`pgrep -P <sleep_pid> -x sleep`, confirmed by `ps -o stat=` showing `T`) and the monitor (the other `pgrep -f -- "--caffeinate-start <state file>"` match, skipping the worker and any fork whose parent is also a match). It times `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY=true awake --gui --stop`, resumes both with SIGCONT, and requires: 10 s or less, `Awake is off.`, `last_completion_reason` `stopped`, no stop-request file, and the worker and runner gone. It is deterministic, not a race against the clock:

   | Code | Stop time |
   |---|---|
   | B | 0 to 1 s |
   | `8ef37f3` | 38 s |
   | B1 alone | 31 s |
   | All but B1 | 38 s |

B's checks add about 3 s. Existing checks that guard it: 1a (2558-2575), 3b (2649-2660), 3c (2662-2670, a timeout through B6's cleanup), 5b (2723-2737, a stop from another copy), 12b (3389-3410) and 12k (from 4517), the Caffeine guardrail ends; 12d (3488-3555); 12g (3977-4035); 12i (4181-4314: a killed worker, a stop with a killed worker, now through B7, a bound command, an unrecorded runner); 12j (4338-4350); the sourced checks at 1092-1112, 1118-1150 and 2472-2478.

### 5.3 C: the report

- **New section "5c. Verifying the status that starts, stops, and added time write for Awake.app",** after 5b (after line 2736). It uses only helpers defined before line 2527, so it writes the mock battery file directly (`set_mock_battery` comes at 3321). `expect_status_report RC ARGS…` runs `run_awake ARGS` with `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY=true` and the variable set, and checks the exit status, that stdout is empty, and that the file equals a `--status-json` read right after; only `remaining_seconds` (within 2 s) and `status_text` may differ. The comparison is a short python3 check, like `json_field_equals` (224-247). For `caffeinate`, then `awake`:
  - start `--duration-seconds 1200`: exit 0, active, the right backend;
  - add `600`: exit 0, `duration_seconds` 1800;
  - add time in the other mode: exit 1, still active;
  - stop: exit 0, inactive, `last_completion_reason` `stopped`; stop again: exit 0;
  - a start with the battery mocked at 4%: exit 1, inactive.
- `run_awake --backend caffeinate -- /bin/sh -c 'printf "%s" "${AWAKE_STATUS_JSON_FILE-unset}"'` prints `unset`, and the file stays empty.
- A symlink is not written through: its existing target stays empty.
- `APP_STATUS_REPORT_FILE=""` joins the globals at 30-34, and `cleanup()` (290-295) removes it and its `-target`.
- **New sourced check,** after 1691, with `STATUS_REPORT_FILE` set to a temporary file, each case in a `$( … )` subshell: `run_helper` reports a cancelled password, then `main --gui --duration-seconds 60`; and `prompt_start_gui() { return 1; }`, then `main --gui --start --backend caffeinate`. Both exit 0 and write `"active":false`.
- **Existing checks** cover the move of the status block: sections 5, 5a, 5b, 6 and 12i (read-only status, the untrusted runtime folder at 4145-4147, another account's session), and the sourced `pmset` failure checks at 633-654.
- No new app check: AwakeCLI.swift cannot be built alone (it needs InstallSupport.swift, which uses AppKit). The decode is the one `fetchStatus` uses, and 5c pins the bytes.

### 5.4 D: the thermal state

- **New section "12l. Verifying that the app's thermal state is used only by the start checks",** before 13 (line 4569). It reuses `set_mock_thermal` (3261), `ensure_alt_awake_copy` (44) and `cleanup_state`, and takes about 11 s.

  | Check | What it does | Expected |
  |---|---|---|
  | T1 | A fresh `bash -c 'source …'` with each of `0 1 2 3 "" 4 -1 03 " 3" "3 " 1.0 critical $'3\n' 0x1` | `APP_THERMAL_STATE` is the digit or empty; `AWAKE_APP_THERMAL_STATE` is unset, and `/usr/bin/env` does not list it |
  | T2 | A sourced shell started with the value 2, `DRY_RUN=false`, `run_with_timeout` replaced by a stand-in that counts `osascript` runs | Fresh, at 29 s and at exactly 30 s: 2, no `osascript`. At 31 s, with a negative age, and absent: one `osascript`. `SECONDS` counts whole seconds, so a second can tick between setting the age and the function's own read (an age of 31 in 6 of 3000 Linux runs). The exact-30 case therefore reads `SECONDS` before setting `APP_THERMAL_STATE_SECONDS` and after the call, and tries again, up to 5 times, when it changed. The other cases need no retry: a tick only moves 29 to 30 and 31 or a negative age further out of range |
  | T3 | The same shell, `APP_THERMAL_STATE=0`, the stand-in returns 3 | `mac_is_overheating` reports overheating, with one `osascript` |
  | T4 | Dry-run, mock state 0, value 3 | The lid-open start is refused with "too hot for a lid-open session", the lid-closed one with "too hot for a lid-closed session"; the status stays off. Mock 3 with the value `7`: refused (the mock counts). Value 3 with `--thermal-guard off`: starts |
  | T4b | A lid-closed session running, value 3 | `--gui --start --duration-seconds 60` is refused with "too hot to keep it awake longer"; `deadline_at` is unchanged |
  | T5 | Copies of `awake` and `awake-helper` in `$ALT_AWAKE_TEMP_DIR/thermal-probe/`, each with one line after its first `set -euo pipefail` that logs `"${1:-} ${2:-} ${AWAKE_APP_THERMAL_STATE-unset}"` | A Caffeine run with `AWAKE_NOTIFICATIONS=true`, value 1, `--gui --backend caffeinate -- /bin/sh -c '<log>; sleep 2'`: the foreground logs `1` (the probe works); `--caffeinate-start`, `--caffeinate-runner`, `--notify-wait` and the command log `unset`. The same lid-closed: `--dry-run start`, `run-timer`, `run-guard` and the command log `unset` |

- The existing sourced checks that replace `thermal_state` (1564, 2311) keep working: without a value, the new function falls through to their stand-in.
- **`tests/app/heat-report-check.swift`:** `checkThermalNumbers(log)` joins the list at 41-54. For `.nominal`, `.fair`, `.serious` and `.critical` it asserts that `HeatSummary.number(for:)` is 0, 1, 2 and 3, and that `rawValue` equals it, which checks on the CI SDK that the app's scale is the CLI's. No change to ci.yml.

## 6. Later items: E to J

After A the icon changes at once, so E to J shorten the time until the result is confirmed: the banner and the sound, the icon losing its dimmed look, and the window in which a second press only beeps. Each item is planned in full when it is picked up. Mac gains are estimates; Linux figures were measured in the emulation.

### 6.1 Summary

| # | Change | Applies to | Gain (Mac, estimate) | Risk | Helper reinstall |
|---|---|---|---|---|---|
| E | The app plays the start sound; it passes no `--sound` | starts with Sound on (off by default) | 0.3 to 0.7 s | low | no |
| F | Builtins in place of small programs | every run | 0.15 to 0.4 s per action once C and H are in | low to medium (security checks) | no |
| G1 | The helper wakes on a FIFO instead of its `sleep 1` | lid-closed stop | about 0.5 s on average, up to 1 s | medium (root code) | needed for the gain, not for correctness |
| H | No "before" status run (`--if-off`, a report from before the action) | every app start and stop | 0.15 to 0.4 s net | medium (notification logic) | no |
| I1 | No `sudo -n helper check` when the password-free rule exists | each helper call in password-free mode | 0.05 to 0.15 s | medium | no |
| I2 | `pmset` read only when no session runs | stops, and runs during a session | 0.04 to 0.2 s | low | no |
| I3 | The helper trusts the CLI's start checks | lid-closed start | 0.15 to 0.5 s | medium | yes (protocol 10) |
| J1 | A faster check that a lid-open start is ready | lid-open start | about 0.1 s on average, up to 0.2 s | low | no |
| J2 | A forked worker instead of a new bash | lid-open start | 0.05 to 0.2 s | high | no; **not recommended** |

G0, the CLI's 0.05 s check for a lid-closed stop, is B8 in phase 1 (question 5).

### 6.2 E. The app plays the start sound

- **Done in phase 1**, at the owner's request (2026-10-03), as specified here, with the recommended answer to 6.10, question 1. Its QA is 8, 37 to 39.
- **Today.** With Sound on, the app passes `--sound` on a start (AwakeCLI.swift:457-459). Under the app's suppression, `notify_gui` plays Tink in the foreground before the CLI exits (7149-7150 → 3211-3212 → `afplay` at 3130), which adds the sound's length to every start. The stop sound already comes from the app (`playStopSoundIfNeeded`, StatusBarController.swift:1031-1036, called at :451 and :543).
- **Change.** `startArguments` stops passing `--sound` (AwakeCLI.swift:457-459), and `stopArguments` too (466-468): on a stop it does nothing for app sessions, which have no notifier (3250-3252), and only sets `sound_notifications` in the record of the `caffeinate_stop` fallback (5641). `playStopSoundIfNeeded` becomes `playSoundIfNeeded` and is also called in the start branch of `handleCommandResult`, before `postStarted` (:417-427). "Already on", added time and failures play nothing, today and after.
- **Gain.** 0.3 to 0.7 s per start with Sound on. On Linux a 0.5 s `afplay` stand-in took a start from about 400 to 900 ms.
- **Risks.** Low. `--status-json` then reports `"sound_notifications":false` for app sessions; the app decodes the field but never uses it (AwakeCLI.swift:18, :67). Terminal `--sound` is unchanged.
- **Tests and QA.** The CI app build. On the Mac: a start with Sound on plays Tink once, as the banner appears; a stop once; "already on" and added time play nothing; Sound off plays nothing; a lid-closed start in password mode plays it once the session runs.

### 6.3 F. Builtins in place of small programs

- **Prototype (Linux).** A lid-open start went from 0.39 to 0.22 s, a status read with a session from 0.163 to 0.116 s, with identical JSON. Programs per lid-open start: 155 → 73 (the start command 55 → 33, the worker's critical path 57 → 26).
- These checks guard the runtime folder and process identity, so each change keeps a rule:

  | # | Change | Where | Rule |
  |---|---|---|---|
  | F1 | One `/usr/bin/id -u` per process, in a readonly `CURRENT_UID` next to 136 | 136, 756, 825, 1389, 1429, 3751, 6115, 6426, 6491, 6934, 7050; helper 99, 111, 114-117, 160, 200 | **Not `$EUID`:** bash takes `EUID` and `UID` from the environment when set (`env EUID=0 bash -c 'echo $EUID'` printed 0 as uid 65534), which would change the root refusal (6426), `AWAKE_USER_UID` (136) and the uid check at 3751. |
  | F2 | `${p%/*}` in place of `dirname` | runtime paths only, which already matched the runtime regex (788); `helper_is_ready`'s 3432 becomes a constant; helper `write_kv_file` (awake-helper:187) | Keep `dirname` for `BASH_SOURCE` (175, 189, 194) and the install command. |
  | F3 | A builtin key reader: `IFS= read -r line`, key `${line%%=*}`, value `${line#*=}` | `read_state_value` (2286-2295) and `read_state_value_into` (2300-2312); hot callers move to the `_into` form | It matched `awk -F=` on 18 edge cases. Today's `IFS='=' read` differs in two: it drops a trailing `=`, and finds nothing on a line without `=`. |
  | F4 | The runtime folder checked once per short-lived process | `validate_runtime_dir_path` (685-718), `chmod 700` in `ensure_runtime_dir` (779) | Keep the lstat `stat -f %u`; not `[[ -O ]]`, which follows symlinks. Long-running loops clear the cache every pass. |
  | F5 | `kill -0` in place of `ps -p` for liveness | `lock_pid_is_running` (1161-1169), used at 2532 and 4184 | Only for this user's processes and a positive PID; never for the helper's root processes, where EPERM would read as "gone". Identity checks stay on `ps`. |
  | F6 | No `chmod 600` after `mktemp`, which creates 0600 files | 2585, and the same in `write_state_file` | Keep the check after `mv` (2587). |
  | F7 | Optional: one `date +%s` per process plus `$SECONDS`, as the helper does (awake-helper:1261-1262) | 22 `date` calls | Up to 1 s off, so not for deadline comparisons at the edge. |
  | F8 | Helper: fixed temporary names in its root-owned folders (as `write_heartbeat`, awake-helper:1211-1215); optionally one `pmset -b sleep X disablesleep Y` (644-645) | awake-helper:184-191, 635-648 | Helper-only changes reach installer users without a protocol bump: the installer reinstalls the helper on every run (scripts/install-awake.sh:517-526). |

- **Gain.** 0.3 to 0.8 s per action over today's three runs; 0.15 to 0.4 s once C and H leave one run.
- **Tests.** The full self-test; the builtin reader against `awk` on the edge cases; `env EUID=0 UID=0 awake --dry-run --status-json` works as the user; the `kill -0` helper rejects PID 0; a symlinked or foreign runtime folder is still refused. During development, byte-identical `--status-json` before and after for idle, lid-open running, lid-closed running, just stopped and leftover settings.
- **Order.** After B, C, D and H, once the code paths have settled.

### 6.4 G. The lid-closed stop without the helper's 1 s poll

- **Today.** `request_helper_session_stop` (3729-3776) writes `stop-request` (3754-3757) and checks every 0.2 s (3769; 0.05 s after B8). The root timer looks for the file once per pass (awake-helper:1283), then runs `sleep 1` (:1334). The guard steps in only when the timer is gone or stuck (:1403-1411).
- **G1, a FIFO that wakes the timer.**
  - Helper: `readonly WAKE_FIFO="${STATE_DIR}/wake"` after awake-helper:148. `cmd_start`, under the lock and before `spawn` (:976), runs `rm -f "$WAKE_FIFO"; mkfifo -m 600 "$WAKE_FIFO" && chown "$uid" "$WAKE_FIFO" || rm -f "$WAKE_FIFO"`; without a FIFO the start still succeeds. `cmd_run_timer` (:1218-1336) opens it with `exec 3<>"$WAKE_FIFO"`, only after `[[ -p "$WAKE_FIFO" && ! -L "$WAKE_FIFO" ]]`, and replaces `sleep 1` with `read -r -t 1 -u 3 _` (whole seconds, which bash 3.2 has), or `sleep 1` without a FIFO. A wake that finds neither file still sleeps 1 s, so a flood of writes never spins as root. `finish_session` (:809) and `cmd_restore` (:1152) remove the FIFO with the session file. The timer's TERM trap (:1256) then also runs during the wait.
  - CLI: `readonly HELPER_WAKE_FIFO="${HELPER_STATE_DIR}/wake"` after 148; after the request is written (3757), also for `command-finished`: `[[ -p "$HELPER_WAKE_FIFO" && ! -L "$HELPER_WAKE_FIFO" ]] && { printf 'x\n' 1<>"$HELPER_WAKE_FIFO"; } 2>/dev/null || true`. The `-p` test matters in dry-run, where the helper's folder is the user's own.
  - Security: the FIFO is in the helper's root-owned folder, checked by `ensure_owned_dir` (awake-helper:193-203). Its content is never read, and the helper still never reads or writes outside its own folder (:40-44).
  - Protocol: a bump is **not needed for correctness**: an old helper has no FIFO, and an old CLI never writes, so the timer times out each second as today. Bump to 10 (bin/awake:128, awake-helper:54) only if I3 ships with it.
  - Gain: about 0.5 s on average, up to 1 s; the research prototype went from 0.34 to 1.19 s down to 0.20 to 0.23 s on Linux. It also removes one `/bin/sleep` per second for the whole session.
- **G2, if G1 fails on the Mac.** In password-free mode, for the user's own session, the CLI runs `run_helper restore` (`cmd_restore`, awake-helper:1109-1167). No new right (the rule allows any helper argument, 4139), but one or two `sudo` calls and helper starts, and password mode keeps the poll.
- **Tests.** A dry-run lid-closed stop under 0.5 s (`TIMEFORMAT=%R`); the FIFO exists with mode 600 while a session runs and is gone after; 100 wakes without a request end nothing; with the FIFO removed by hand the stop takes about 1 s; the CLI never creates a regular `wake` file; `awake --backend awake -- true` ends as `process_exited` quickly. On the Mac: `ls -l /var/run/net.kaenmaki.awake/wake` shows `prw-------` owned by the user; the timer's CPU stays near 0; boot-restore still works.

### 6.5 H. No "before" status run

- **Today.** `performStart` and `performStop` run `fetchStatus` first (AwakeCLI.swift:339, :378), without the CLI's lock. It drives `startOnlyIfOff` (:340-346), the picker's backend (:351) and the outcome logic in `handleCommandResult` (StatusBarController.swift:417-473): a start that started, "already on", "stopped" for the app's own sessions, and `recordStopTime` (:404).
- **CLI.** `AWAKE_STATUS_BEFORE_JSON_FILE`, read and unset at the top like C's. A printer that uses main's own computed state (`caffeinate_session_active`, `helper_state`, `helper_foreign`, `pmset_read_ok`, `pmset_session_active`) writes the status after 6580, under the lock, in the same process. A new internal `--if-off`, valid only with `--start`, exits 0 after 6635 without a change when a session is active as `--status-json` defines it (a lid-open session, a helper session of any account, a stale one, or leftover settings).
- **App.** No fetch first: `cachedBefore` is a copy of `currentStatus` from the call sites (StatusBarController.swift:192, :228, :322, :342, :385); `startOnlyIfOff` becomes `--if-off`; `before = reportedBefore ?? cachedBefore`. When `cachedBefore.active` is true and the reported before and after are both inactive, the session ended on its own just before the stop: call `maybeNotifyCompletionTransition(from: cachedBefore, to: after)` (:524-551), which de-duplicates, or "Awake finished" is lost, all the more as A skips polls during starts and stops. The picker's backend comes from `cachedBefore` (6.10, question 3): a Terminal session of the other mode started in the last 10 s then gets the CLI's refusal (6671-6678) instead of the add-time list.
- **Risks.** The notification logic. An exit before the report (bad arguments, the lock timeout at 1287) leaves the cached status, and every such exit is non-zero. Fewer races than today, as "before" is read under the lock. An older CLI refuses `--if-off`, but the app and CLI ship together.
- **Tests.** `--if-off` with a session running exits 0 with the same token and deadline; idle, it starts; without `--start` it is an error. The before report equals a `--status-json` read just before it. Optionally, the outcome classification moves into a pure function with a `tests/app` check. On the Mac: ⇧⌘A within 10 s of a Terminal start says "Awake is already on"; a timed app session that ends just as Stop is clicked still shows "Awake finished".
- **Order.** After A and C.

### 6.6 I. Less duplicate work on lid-closed starts

- **I1.** Today `sudo -n helper check` runs before every `sudo -n helper ARGS` (3636-3637). Only when the password-free rule exists (`passwordless_is_configured`, 3442-3444): run `sudo -n helper ARGS` directly, and on exit 1 ask `sudo -n -l "$helper"` whether sudo refused; if so, take the password path (3645). A new exit code would not do: the helper runs under `set -e` and can exit 1 itself. Needs a Mac check that `sudo -n -l` asks nothing with a NOPASSWD rule.
- **I2.** 6569-6570 read `pmset` on every run, but the values are used only when no session runs (6578, 6601, 6608, 6628, 6804, 6950, 7006), and on the "session ended just now" path (6762-6776), which goes on to a start. A function called at 6569 when needed and at 6775. After C, this touches the same block as C's printer.
- **I3.** The CLI checks battery and heat (6957-6974), then the helper again (awake-helper:903-908: a root `osascript` and a `pmset -g batt`), and the timer's first pass a third time (:1229-1230). A new helper command `start-checked`, with `start`'s arguments, skips the helper's start-time checks; the timer's first pass still checks within a second. The CLI keeps its checks (cheap for app runs after D), so a refused start never asks for a password first. No boundary moves: the caller can already pass `--min-battery off` and `--thermal-guard off` (awake-helper:876-885). Needs protocol 10. Rejected: dropping the CLI's checks and relying on the helper's exit codes 4 and 8, which in password mode asks for the password and then refuses.
- **Tests.** The dry-run helper with a low mock battery and a critical mock state refuses with the CLI's messages; `start-checked` validates its arguments; `--status-json` is unchanged for running sessions and leftovers; leftovers are still restored before a lid-open start. I1 only on the Mac.

### 6.7 J. Starting the lid-open worker

- **J1.** `wait_for_session_start` (4161-4228) checks every 0.2 s (4222), and the first check always misses. Check every 0.05 s for at most 30 s; each pass first uses builtins only (`kill -0` on the worker, the builtin reader on `sleep_pid` and the status file), and runs the full `state_session_is_ready` (2521-2533) once `sleep_pid` is positive. Every exit condition stays. A 0.05 s check without the builtin first step saved only 5 to 20 ms on Linux.
  - **Done in phase 1** (2026-10-04), after the first Mac timing (7.3): the start's own run was 0.12 to 0.16 s slower than 2.3.0's, as it now writes C's report and, since `8ef37f3`, waits until the worker has recorded the runner. As specified, with two choices: `state_session_is_ready` itself reads `sleep_pid` first with the builtin reader, so the self-test's stand-ins for it still count every check; and the constants changed (`STARTUP_WAIT_POLL_SECONDS` 0.05, `STARTUP_WAIT_MAX_CHECKS` 600, a new `STARTUP_WAIT_MAX_SECONDS` 30), so the lid-closed start's check of the helper's session and the wait for a lid-open session that ended just as time was added also check every 0.05 s, for 30 s at most. Its QA is 40.
- **J2, not recommended.** Forking the worker in place of `nohup /bin/bash` (3095-3101) needs its own PID, which bash 3.2 cannot give (`$BASHPID` is 4.0; the worker records `$$` at 5546 and hands it to the monitor at 5561 and to `caffeinate -w` at 5318). Every identity check matches the command line (`session_pid_matches` 2453-2476, `caffeinate_runner_pid_matches` 2478-2494, the lock's check at 1206-1207) and would move to PID and start time (`process_is_same`, 2200-2204). Inherited state (`MAIN_LOCK_HELD`, C's report file, D's `APP_THERMAL_STATE`) would need clearing, and self-test checks that fake the worker by its command line (tests/cli/awake-self-test:418-471, 4238-4247) would need rewriting. 0.05 to 0.2 s for a high risk.
- **Keep:** the runner's immediate first thermal check (`next_thermal_check=0`, 5235) and the helper's own start check (awake-helper:906). They back D up.

### 6.8 The icon flipping back

Fixed in A (A9). H's "before" takes the launch time as its `fetchedUptime`, and H needs the missed-end handling above because A skips polls during starts and stops.

### 6.9 Order and release

1. After A to D, low risk, no helper change: I2. E and J1 rode with 2.4.0 (6.2, 6.7).
2. H: the largest remaining gain per action. Needs A and C.
3. F: a cleanup pass once the code has settled.
4. A helper release: G1, I3, and optionally I1 and F8, with protocol 10 and an Upgrade note about the one password prompt, as 2.2.0 had (CHANGELOG.md:111-116). Mac checks first.
5. J2: not planned.

Each phase is timed with 7.1 before and after.

### 6.10 Questions for the owner, for later

1. **E.** Answered: the app plays the start sound, in 2.4.0 (6.2).
2. **G.** The FIFO (G1, recommended, both password modes, needs Mac checks), or the CLI running `restore` in password-free mode (G2)? And is one password prompt for protocol 10 acceptable, if I3 comes with it?
3. **H.** The picker's lid mode from the app's last status (recommended), or a new app-only `--picker-backend`?
4. **H.** `--if-off` internal like `--prompt-gui-selection` (recommended), or documented for scripts?
5. **I3.** May the helper skip its start-time battery and heat refusal right after the CLI checked? Its timer still checks within a second.
6. **J2.** Drop it (recommended)?
7. **Release.** E in 2.4.0 with A to D, or later; the rest in 2.5.0, with an Upgrade note if the helper protocol changes.

### 6.11 Other findings, not planned

- **K. Custom password mode runs processes on the main thread:** `sudo -n helper check` (StatusBarController.swift:910 → AwakeCLI.swift:234-249) and the `--prompt-gui-selection` picker (:951-971 → AwakeCLI.swift:299-319). About 0.06 to 0.15 s for the check. Not the default mode.
- **L. `waitUntilExit` may notice an exit late** on a background queue. Unverified; 7.2's cross-check shows whether it matters before anyone switches to `terminationHandler`.
- **M. A stop that meets the session's own end can lose its record.** Older than this plan (`8ef37f3` has it), but B and C touch the same path. Main reads the session as active (6550) and checks the worker again later (6786, after B in `request_active_session_stop`). If a deadline or a guardrail ends the session in between, that check fails, and main falls back to `caffeinate_stop` (5604). It first runs `rm -f` on the status file (5618), deleting the end the worker just recorded (`timeout`, `overheated`), then writes `stopped` with an empty session token, as the state file is gone too. With C the app reads that record straight from the report; today it reads the same record a moment later. In the emulation (dry-run, a stop timed against a 2 s session's end or a mock critical state) the token was missing in 2 of 12 deadline runs and 1 of 12 overheating runs with B, and in 1 of 12 deadline runs on `8ef37f3`; no run hung, and nothing was left running. A later fix: when the request fails because the worker is gone, keep a final status that already carries the session's token instead of deleting it. QA 21 is read with this in mind.

## 7. Timing on the Mac

### 7.1 The script

`tools/measure-latency.sh` (4.5) times what the app runs, step by step.

1. **Before installing the update,** from the checkout: `tools/measure-latency.sh --rounds 5`. Add `--lid-closed` if password-free mode is on. Run it once more with `--sound`, which today's app passes when Sound is on; after the update, compare that run with one without `--sound`, as the new app plays the sound itself (E).
2. **After installing,** the same commands again.
3. **Conditions:** the same Mac, plugged in, heavy apps closed. Run each twice and keep the second (warm caches).
4. **Reading it:** "today" is what the old app waits for (three runs); "with C" is what the new app waits for (before + action); "with C and H" is for later. Compare the old "today" with the new "with C", step by step. The lid-open stop's action should drop by about a second (B), and the start's action by the `osascript` time (D).

### 7.2 The stopwatch check

The script cannot see A or the app's own overhead.

1. Sound off, notifications on for Awake, shortcut mode lid-open, plugged in.
2. For clicks, record the menu bar with QuickTime (New Screen Recording, Show Mouse Clicks, 60 fps): start with the menu's `Start default session` (no picker), stop with a plain click. The app acts on mouse-up (StatusBarController.swift:124).
3. For ⇧⌘A, film the keyboard and the screen with a phone in slow motion (240 fps).
4. Five starts and five stops of each. Note t0, the frame of the click or key press; t1, the first frame the icon changes; t2, the first frame of the `Awake started` or `Awake stopped` banner. Keep the medians of t1 − t0 and t2 − t0.
5. Expected: before A, t1 ≈ t2, about 1.5 to 3.5 s (estimate); after A, t1 under 0.1 s.
6. Cross-check t2 − t0 against the script's sum. A gap above about 0.2 s is overhead in the app the script cannot see: main-thread work, `waitUntilExit` (6.11, L), or banner delivery.

### 7.3 Results

Filled in during the Mac QA (medians, ms). For the script, "before" is the old version's "today" sum and "after" the new version's "with C" sum.

The script rows come from the owner's Mac on 2026-10-04: password-free mode, Sound off, run from the home folder. "Before" is `--cli ~/awake-2.3.0/bin/awake`, "after" the dev build at `e9a1490`, before J1. Each cell gives the `--lid-closed` run, which times both modes, with an earlier lid-open-only run in brackets.

| Step | Before (2.3.0) | After (dev, `e9a1490`) |
|---|---|---|
| Lid-open start: script sum | 1083 (1105) | 943 (963) |
| Lid-open stop: script sum | 1293 (1060) | 742 (748) |
| Lid-closed start: script sum | 1232 | 1053 |
| Lid-closed stop: script sum | 1176 | 783 |
| Lid-open start with Sound on: script sum | 2494 (`--sound`) | 963 (the app plays Tink, E) |
| Lid-open start after J1: script sum | | |
| Terminal `time awake --stop` | | |
| Menu start: t1 / t2 | | |
| Click stop: t1 / t2 | | |
| ⇧⌘A start: t1 / t2 | | |
| ⇧⌘A stop: t1 / t2 | | |

- **The stop.** B shows in the stop's own run: lid-open 772 → 458 ms, and 2.3.0's ranged up to 1603 ms where the new one stayed between 452 and 517 ms; lid-closed 663 → 504 ms.
- **The start.** Its own run got slower: lid-open 575 → 737 ms, lid-closed 715 → 834 ms. It now writes C's report, which replaces the "after" status run, and the lid-open start waits since `8ef37f3` until the worker has recorded the runner, which the 0.2 s check rounded up. J1 (6.7) targets that second part.
- **Sound on.** In 2.3.0 `--sound` added about 1.4 s to a start and 0.7 s to a stop (start 2494, stop 1761 ms), as `afplay` played in the foreground. E removes it.

## 8. macOS QA checklist

Run on the 2.4.0 build, in the same session as plan-2.4.0's and plan-2.3.0's checklists.

**Timing**

1. 7.1 before installing and after, and 7.2 before and after; fill in 7.3.

**A: the icon**

2. **Shortcut, lid-open.** While off, press ⇧⌘A: the bold `A` appears with the key press; hovering shows `Starting Awake…`, then the session's line. Press again: the regular `A` at once, with `Stopping Awake…`.
3. **Menu.** `Start default session` and `Stop session` behave as in 2.
4. **Lid-closed, password-free.** Bold and dimmed, then solid. `pmset -g` shows `SleepDisabled 1` by the time it is solid.
5. **Lid-closed, macOS dialog, password-free off.** Regular and dimmed while the dialog is open. Cancel: regular, not dimmed, nothing posted. Again with the password: bold.
6. **Lid-closed, custom dialog.** Nothing changes while the app's dialog is open; then bold and dimmed, then solid.
7. **A click while off.** The icon dims at the click, before the picker appears. Cancel: regular, not dimmed, nothing posted. Choose 20 minutes lid-open: bold once the session runs. With the custom dialog setting, it turns bold as soon as the picker closes.
8. **Add time.** The icon stays bold, not dimmed, with `Adding time…`.
8a. **Add time while the session ends.** Password-free mode off, the macOS dialog setting. Start a lid-closed session of 2 minutes with the password, then choose `Add 1 hour` when about 30 s are left, and leave the password dialog open past the end: the icon turns regular within about 12 s of the end, and no `Awake stopped` is posted while the dialog is open. Cancel: regular, and the end is announced once, as the dialog closes.
9. **A refused start.** On battery below 30%, with `Stop at low battery` at 30%, press ⇧⌘A: bold, then regular, with "The battery is at …%, too low for a lid-open session" (6960). Without a low battery: `chmod -x "$HOME/Library/Application Support/Awake/bin/awake"`, press ⇧⌘A (bold, then regular, with `Awake failed: Awake is not installed at …`), then `chmod +x` the same file.
10. **Already on.** Start `awake --duration 10m` in Terminal and press ⇧⌘A before the icon turns bold on its own: bold at once, stays bold, `Awake is already on`.
11. **Sleep left off.** `sudo pmset -b disablesleep 1` with no session. Click, with the macOS dialog and password-free off: bold and dimmed while the dialog is open. Cancel: solid bold. Click again and enter the password: regular, and `SleepDisabled` is 0.
11a. **The same with Awake's password dialog.** `sudo pmset -b disablesleep 1` again, and turn `Use custom password dialog` on. Click: Awake's dialog appears first, and the icon does not change while it is open. Cancel: bold, nothing posted. Click again and enter the password: regular at once, and `SleepDisabled` is 0.
12. **Stop Awake and quit.** Regular at once, then the app quits.
12a. **Stop Awake and quit with a dialog.** `sudo pmset -b disablesleep 1`, the macOS dialog setting, password-free off. `Stop Awake and quit`: bold and dimmed. Cancel: bold again, not dimmed; the app stays and posts that it did not quit. Then `Stop session` with the password, so that `SleepDisabled` is 0.
13. **Helper.** `Install helper…` (after `awake --uninstall-helper`) and `Start without password`: the icon neither changes nor dims. In Settings, `Start without password` is dimmed while a command runs (SettingsWindowController.swift:462).
14. **During a command.** A click does nothing and ⇧⌘A beeps. Ctrl-click still opens the menu, with `Starting Awake…` as its first line and the items disabled.
15. **The race.** 20 starts and stops with ⇧⌘A a few seconds apart, watching the icon for 10 s after each: it never flips back.
16. **Looks.** Light and dark menu bars, Increase contrast, Reduce transparency, a busy wallpaper, and macOS 26's transparent menu bar: the dimmed icon stays visible, and its bold and regular `A` can be told apart.
17. **VoiceOver.** A lid-open ⇧⌘A start now ends in about a second, and a new label is not announced, so check a pending state that lasts. With Accessibility Inspector, or the VoiceOver cursor on the icon (VO-M, then M):
    - idle: `Awake is off`;
    - click while off, the macOS dialog setting, and leave the picker open (regular, dimmed): the description reads `Starting Awake…`; note whether VoiceOver adds "dimmed" or reads the button as unavailable;
    - cancel the picker: `Awake is off`;
    - a lid-closed ⇧⌘A start with password-free mode on (bold, dimmed): VoiceOver never says `Awake is on` before the start is done, then says it once the icon is solid.

**B: the stop**

18. With a lid-open session, stop from the menu: right after, no `caffeinate` process and no Awake assertion in `pmset -g assertions`. `time awake --stop` takes about 0.3 to 0.6 s (estimate; note the time in 7.3).
19. `awake --debug --stop` logs `request_active_session_stop signal`, then `wait_for_requested_stop_completion ready` with a small count, under 10 (half a second), and no `worker_gone` or `timed_out` line. The worker's cleanup runs several programs after the TERM (5503-5542), so the count is above 0: 2 in each of 6 runs in the emulation, more on a Mac.
20. In lid-open mode, `awake -- sleep 3` exits after about 3 s, with `process_exited` in `--status-json`.
21. `awake --backend caffeinate --duration-seconds 5`, then `awake --stop` close to second 5, several times: always off, with `timeout` or `stopped`, no state file left, no 30 s wait. Now and then `stopped` with no `session_token` is the older race of 6.11, M, not a failure of B.
22. After an hour-long session, the runner's memory (`ps -o rss= -p <sleep_pid>`) is steady, and its CPU in Activity Monitor is as before.
23. **A new CLI stops an old session.** The installer stops the running session before it replaces anything (scripts/install-awake.sh:496), so this needs a manual copy. With 2.3.0 still installed, start a lid-open session (`awake --start --backend caffeinate --duration 10m`), then stop it with the new checkout's `bin/awake --stop`: it stops, the old runner still taking up to a second, `last_completion_reason` is `stopped`, and no `caffeinate` is left.
24. With Sound on, stop from the menu and with ⇧⌘A: the stop sound still plays.

**C: the report**

25. **One process fewer.** Watch launches (`sudo eslogger exec` on macOS 13 and later, or a `pgrep -lf -- --status-json` loop every 0.05 s) and press ⇧⌘A twice: one `--status-json` before each action, none after. The 10 s poll still shows.
25a. **Polls during commands.** With the same watch: click while off and leave the CLI picker open for 30 s: no `--status-json` runs; cancel it. Then start a lid-open session in Terminal, run `awake --uninstall-helper`, choose `Install helper…` and leave its password dialog open, and run `awake --stop` in Terminal: polls go on, and the icon turns regular within about 12 s. Cancel the dialog.
26. **Behaviour.** ⇧⌘A, `Start default session`, a click with the picker, `Add 1 hour`, `Stop session` and `Stop Awake and quit`, in both modes, with password-free mode on and off: `Awake started` and `Awake stopped` once each, the start and stop Tink with Sound on.
27. **Failures.** A lid-closed start below `Stop at low battery` and a cancelled password dialog: the icon stays, `Awake failed` reads as before with no JSON in it, and a cancel posts nothing.
28. **Settings.** Install the helper and turn password-free mode on and off: the window shows the new state at once.
29. **Mixed versions.** A 2.3.0 `bin/awake` in `~/Library/Application Support/Awake/bin/` with the new app: start and stop still work. Then a 2.3.0 app with the new CLI.
30. **Temporary files.** After a few actions, `ls "$TMPDIR" | grep awake-statusbar` prints nothing.

**D: the thermal state**

31. `launchctl setenv AWAKE_DEBUG true`, relaunch the app, press ⇧⌘A (lid-open): `grep foreground_thermal_state /tmp/keep-awake-lid-closed-$UID/awake-debug.log` shows `source=app state=0 age=0`. Then `launchctl unsetenv AWAKE_DEBUG`, relaunch, and delete the log.
32. While that session runs, `for p in $(pgrep -f -- '--caffeinate-(start|runner)'); do ps -E -ww -o command= -p "$p" | grep -c AWAKE_APP_THERMAL_STATE; done` prints only `0`.
33. A lid-closed session from the app: `sudo ps -E -ww -p "$(sudo awk -F= '$1=="timer_pid"{print $2}' /var/run/net.kaenmaki.awake/session)" | grep -c AWAKE_APP_THERMAL_STATE` prints `0`.
34. On a cool Mac, `AWAKE_APP_THERMAL_STATE=3 awake --start --backend caffeinate --duration 1m` refuses at once with "too hot for a lid-open session"; with `=9` it starts. Stop it.
35. `awake --debug --start --backend caffeinate --duration 1m` starts, and the log has no `source=app` line.
36. ⇧⌘A with `Stop when too hot` on feels as fast as with it off (5 presses each).

**E: the start sound**

37. With Sound on, ⇧⌘A and a click start each play Tink once, as `Awake started` appears, and `Stop session` plays it once. With Sound off, neither plays it.
38. `Add 1 hour`, "Awake is already on" and a failed start play nothing. A lid-closed start in macOS password mode plays Tink once the session runs, after the dialog.
39. With the watch of 25, a start or stop from the app shows no `--sound` in its `awake` command line.

**J1: the start check**

40. Five times: `awake --debug --start --backend caffeinate --duration 10m; awake --stop`. Each start logs `wait_for_session_start ready ... checks=N`, with N under 20 (a check every 0.05 s), and no `worker_gone` or `timed_out` line.

## 9. Docs

Every README bullet stays one line: the Help window renders only one-line `- ` bullets. The app shows the new text after a reinstall.

Each line below names the commit that writes it (10, phase 1).

- **README.md:243** (A) gets: "It changes as soon as you click it, press the keyboard shortcut, or choose `Start default session` or `Stop session`, before the start or stop is done: a lid-open start shows the bold `A` at once, and a stop the regular one. A lid-closed start shows the bold `A` dimmed until the session runs, so wait until it is solid before you close the lid. While the start picker or a macOS password dialog is open, the icon keeps its state, dimmed, as you can still cancel; with `Use custom password dialog`, Awake's own picker and password dialog come first, and the icon changes once they close. If the start or stop fails, the icon changes back and a notification says why."
- **README.md:244** (A): its last sentence, "While a start, added time, a stop, or a helper change is in progress, the line reads …, or `Updating Awake’s helper…`.", ends instead: "…, or `Updating Awake’s helper…`, and VoiceOver reads the same for the icon; otherwise VoiceOver reads `Awake is on` or `Awake is off`."
- **README.md:561** (B): "`stop-request`: created to ask a running session to stop (for a lid-open session, only when `awake` cannot signal it)".
- **README.md:600** (C) ends: "…when completion metadata is pending, and that a start, added time, or stop run the way the menu bar app runs it writes the same status as `--status-json`,"
- **README.md:56** (D), after "read with `osascript`; if it cannot be read, this check is skipped.": "When the menu bar app starts a session or adds time, it passes the state it has already read, so that check needs no `osascript`; running sessions always read it themselves." (question 7)
- **README.md:604** (D) ends: "…sessions tied to a process with `-w` and `--`, and that the thermal state the menu bar app passes counts only for the start checks and never reaches a session's processes,"
- `AWAKE_STATUS_JSON_FILE` and `AWAKE_APP_THERMAL_STATE` are not documented as options or settings (questions 6 and 7).
- **CHANGELOG `[Unreleased]`.** No Mac time is promised: every Mac figure is an estimate until 7.3 is filled in (11). Under Changed, after line 41, one bullet per item:

  ```
  - The menu bar icon changes as soon as you click it, press the keyboard
    shortcut, or choose `Start default session` or `Stop session`, rather
    than once the start or stop is done. A lid-closed start shows the bold
    `A` dimmed until the session runs. While the start picker or a macOS
    password dialog is open, the icon keeps its state, dimmed; with Awake's
    own password dialog, it changes once that dialog closes. If the start or
    stop fails, the icon changes back.
  - Stopping a lid-open session is quicker: `awake` signals the session
    directly, and the session no longer finishes a one-second pause first.
    The same goes for a lid-open `awake -- COMMAND` when the command ends.
    A lid-open stop creates `stop-request` only when `awake` cannot signal
    the session.
  - Starting, stopping and adding time from the menu bar app or with the
    keyboard shortcut is quicker: `awake` writes the status it leaves for
    the app, which no longer runs `awake --status-json` after each of them.
    `--status-json` no longer runs `pmset` while a session runs.
  - With `Stop when too hot` on, starting or adding time from the menu bar
    app or with the keyboard shortcut is quicker: the app passes the thermal
    state it already knows, so `awake` no longer runs `osascript` for that
    check.
  ```

  The bullets come from the A, B, C and D commits in turn. First under Fixed, the first from A and the second from B:

  ```
  - After a start or a stop from the menu bar app, a status check that was
    still running could switch the icon back to the old state until the
    next status check, about 10 seconds later.
  - If the worker of a lid-open session died while the session was being
    stopped, `awake` waited 30 seconds before ending the session directly.
    It now does so at once.
  ```

## 10. Phases

1. **A to D, now.** One commit per item, in the order A, B, C, D (X1), each with its checks and the README and CHANGELOG lines that 9 assigns to it:
   - A: README.md:243 and :244, the first Changed bullet, the first Fixed bullet;
   - B: README.md:561, the second Changed bullet, the second Fixed bullet;
   - C: README.md:600, the third Changed bullet;
   - D: README.md:56 and :604, the fourth Changed bullet;
   - E, added at the owner's request after A to D were green: the fifth Changed bullet.

   `tools/measure-latency.sh` (mode 755) and its CI step go in with D or on their own. This plan goes in as `docs/plans/faster-start-stop.md`, in the same commit as the status lines of plan-2.4.0.md and plan-2.3.0.md (Earlier plans). Done once macOS CI is green, which is also the first compile of A's Swift.
2. **Mac QA:** 8, in one session with plan-2.4.0's and plan-2.3.0's phase 3. Fixes it finds go into 2.4.0 under Fixed. 7.3 is filled in here; if the owner wants a figure in the CHANGELOG, it comes from 7.3, not from this plan's estimates.
3. **Release:** 2.4.0 with `tools/release.sh minor`, together with plan-2.4.0's phase 4, once all three plans' QA is done.
4. **Later:** F to J in the order of 6.9, each planned in full first.

## 11. Risks and open points

- **First compile on CI.** A's Swift has never been compiled. CI's app build, the macOS 12.5 build and the new check are the gate for errors and for the macOS 12.5 APIs. They do not prove Swift 5.7: CI compiles with a much newer `swiftc`, which accepts 5.8 to 5.10 syntax in Swift 5 mode. The rules in 4.1 (explicit `self.`, no `if` or `switch` expressions) are what keeps the build working on a Mac with Swift 5.7, which the installer accepts (scripts/install-awake.sh:345-350).
- **The icon leads the session.** For a lid-open start and every stop, the icon shows what is about to be true. A refused start changes back within seconds and posts `Awake failed`, but someone who glanced once may believe Awake is on, and the Mac then sleeps as it would without it. Accepted.
- **A wrong guess about the password dialog.** It comes from the last status. A stale status, a helper timer that died (the stop then runs `run_helper restore`, 6828), or a broken sudoers rule can bring a dialog the app did not expect: a stop then shows the regular `A` behind the dialog, and Cancel brings the bold `A` back. A lid-closed start is dimmed anyway. Cosmetic. Accepted.
- **The dimmed look may be faint** (QA 16), mostly on macOS 26. The fallback is a third template image for "in progress".
- **VoiceOver** may not read `setAccessibilityLabel` on `NSStatusBarButton`, and may add "dimmed" or read the button as unavailable while `appearsDisabled` is true (QA 17). The fallback swaps each image's `accessibilityDescription`; if "unavailable" is read, the dimmed look moves to a third template image (the fallback of the entry above).
- **Fewer status reads.** While a start's picker or password dialog, or a stop's password dialog, stays open for minutes, nothing polls. A session started in Terminal meanwhile shows when the command ends. Added time keeps its polls (A9), so a session that ends behind its password dialog still turns the icon regular (QA 8a). A gap of more than 60 s counts as 60 s in the heat note (HeatReport.swift:250-253). Accepted.
- **Signal handling (B).** Low to medium. B6, the frozen check and CI's bash 3.2 cover it.
- **PID reuse between the check and the kill (B2).** Microseconds, the same user, and macOS hands out PIDs in order; the monitor (3288-3290) and `terminate_pid_and_wait` (2378-2382) have the same gap today.
- **A stop during a runner check.** A stop that lands while the runner runs a check in the foreground waits for it: the `osascript` thermal read every 30 s or the battery read every 60 s. Rarely about 0.5 s more.
- **Old runners.** A session started by an older `awake` keeps its old runner, and its one-second pause, until it ends (QA 23). With the installer or Homebrew this does not arise, as installing stops the running session first (scripts/install-awake.sh:384-402, :496); only a copy made by hand or an older copy on `PATH` meets it.
- **The lock is held a little longer (C).** The report is written under the lock, about 0.1 to 0.3 s on a Mac; another `awake` command waits meanwhile (0.1 s checks, at most 10 s, 1285-1290). After a cancelled picker the lock is already let go (`release_main_lock_for_prompt`, 1316-1319), so that report is read without it; the next poll corrects a change made meanwhile. Accepted.
- **No report on the terminal paths (C).** The terminal prompt's traps (1477-1482) and `run_bound_command` (3939) replace the EXIT trap. The app never takes these paths, and the fallback covers them.
- **`set -e` inside the status read (C).** `print_current_status` runs in a `||` context in both callers, where the old block ran under `set -e`. The 57 functions it reaches read no caller locals, and of the changeable globals only `DRY_RUN`, `HELPER_SESSION_FOREIGN` (which it sets) and `STATUS_JSON_OUTPUT`, so the report depends only on the files and processes.
- **Bash 3.2 (C).** `-O` is new to the script; bash has had it since version 2. CI checks it.
- **A stale thermal value weakening a session's guard (D).** The variable is unset in every run before any child (T1, T5); the runner and the helper never call the foreground function (T3); the helper is unchanged. Backstops: the runner's immediate first check (5235) and the helper's start check (awake-helper:906), which later items must keep (6.7).
- **A wrong value set by hand (D).** It changes only the start refusal, within 30 s; the runner ends the session about a second later, or the helper refuses the start.
- **`SECONDS` set back in the foreground (D).** The age is then negative and the CLI falls back to `osascript`. Today only the notifier (4952) and the runner (5331) set it.
- **No Mac timing yet.** Every Mac figure in this plan is an estimate until 7.3 is filled in.
- **Unverified here:** the Swift build, the icon's look and VoiceOver, real `caffeinate`, `pmset` and `osascript`, Bash 3.2, mixed versions on a Mac, and the self-test steps that need macOS (11 to 11c, 12h, and the new checks' runs under `/bin/bash` 3.2). All are in 8 or on CI.
