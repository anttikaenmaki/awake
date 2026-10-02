# Plan for 2.4.0: notifications from the command line only with --notifications

- Status: proposed, not implemented. Waiting for the owner's answers to the four questions below; decisions 1, 2, 3 and 21 follow the recommended answers, and 11, 13 and 19 follow from them, so all seven are provisional until then
- Target version: 2.4.0 (the changelog rule: Added and Changed make a minor version; question 4); the helper, the picker, the menu bar app, the installer and Homebrew behave as before
- Written: 2026-10-02, against 2.3.0 (commit `0502b69`), from the owner's request: "gui notifications from the command line should be off by default and there should be an option —notification to have them"
- Scope: `bin/awake`, `tests/cli/awake-self-test`, `README.md`, `CHANGELOG.md`, `docs/plans/` (this plan as `plan-2.4.0.md`; plan-2.3.0.md's status line and its 17, QA 3 if question 4 folds the release in), and comments in `app/AwakeStatusApp/Sources/` and `scripts/`

## Questions for the owner

The plan follows the recommended answer to each question. Each says what changes if the owner chooses another.

1. **The option's name** (decision 3). The owner wrote `—notification`, and `—nonotification` for today's `--no-notifications`.
   - (a) `--notifications`, plural. **Recommended:** it pairs with `--no-notifications`, which stays (decision 4), and with the variable `AWAKE_NOTIFICATIONS`.
   - (b) `--notification`, as written. The pair then differs in more than `no-`.
   - (c) Both, the singular as a second spelling. No long option has one today.
   - Otherwise: (b) renames the option everywhere this plan writes `--notifications`, in code, comments, tests, QA and docs; in T1 and T2 the plural becomes the unknown option. (c) adds `|--notification` to the `parse_cli_args` arm and the prescan test, and a case to T1 and T2. The variable keeps its name.
2. **What "from the command line" covers** (decision 1).
   - (a) Every `awake` run that Awake.app did not make: a terminal, `--gui` typed in one, and runs without a terminal, such as Shortcuts, Automator, Raycast or Alfred, cron or launchd, `ssh host awake`, or output sent to a file. **Recommended.**
   - (b) Only runs whose output a terminal shows (`verbose`, bin/awake:6421-6423): terminal mode, and `--gui` typed in a terminal. Runs without a terminal keep every 2.3.0 notification.
   - (c) Only terminal mode. `--gui` typed in a terminal keeps its notifications too.
   - Why (a): one rule that is easy to say, "`awake` posts no notifications unless asked". It does not depend on the UI mode, so the prescan sets it, and the detached processes get it from the environment like the other settings. Under (b) and (c), `awake --duration 1h > log` typed in a terminal runs in GUI mode and still posts, and the setting waits for the UI mode, which is decided after the exports at 6359-6362.
   - Otherwise: the default is set only once the UI mode is known, after bin/awake:6423: on for runs whose output no terminal shows (b), or for every run outside terminal mode (c). The two exports of 4, item 9, move there, still before the notifier starts at 7039. Question 3 then falls away, and with it the `report_start_failure` edit. The "No terminal" rows of 3 stay as in 2.3.0; T7 and L4 expect posts for GUI runs; the README, the usage text and the CHANGELOG say "in a terminal". Under (c), decision 13 is not needed either.
3. **What is posted without `--notifications`** (decision 2).
   - (a) Nothing at all.
   - (b) Only `Awake failed`, when a start or an add-time request fails and `awake` does not print to a terminal. **Recommended.** It never fires in terminal mode (`-t` included) or for `--gui` typed in a terminal, and `--no-notifications` turns it off too. A command typed in a terminal that sends `awake`'s output to a pipe or a file runs in GUI mode and still posts it, for example `awake -- make 2>&1 | tee build.log` while a session runs (9).
   - (c) As (b), and also the ends a guardrail causes and failed ends, through a notifier started for every session.
   - Why (b): without a terminal, the notification is the only sign that a start from a shortcut or a launchd job was refused. That was a documented 2.0.0 feature (CHANGELOG.md:505-507). (a) is the literal reading, but such a failure then leaves no trace. (c) keeps a background process per session, checking once a second (bin/awake:74), and brings banners back in terminals. A narrower (b) is possible: in the default state, also skip the post when standard error is a terminal (`[[ -t 2 ]]` in `report_start_failure`, and a T4 row). It covers `> log`, but not `2>&1 | tee`.
   - If (a): `report_start_failure` stays as in 2.3.0 and only its comment changes (4, item 7); the README's exception and the CHANGELOG's "Without a terminal…" sentence go; the usage line becomes `--no-notifications     Post no notifications (the default)`; T4's first row and T7's `--gui` low-battery row expect no post; QA 7 and 12 expect nothing. `NOTIFICATIONS_SETTING` then only feeds the exports.
   - If (c): `start_gui_completion_notifier` starts the notifier for every session again, which reverses decision 11 and makes decision 19 moot, and `announce_completion` posts the guardrail and failed ends in the default state: a new gate of about 10 lines, rows in T5 and T6, and a README sentence.
4. **Release level and order** (decision 21).
   - Level: (a) 2.4.0, **recommended**; (b) 3.0.0.
   - Why 2.4.0: options, exit statuses, runtime files, `--status-json` and output (but for the one line of decision 13) stay, so no script breaks. A default changes, with an Upgrade note, as 2.1.0 changed two defaults in a minor version (CHANGELOG.md:127-129, 176-178). Against it: the CHANGELOG keeps a major version for "changes that can break existing use" (CHANGELOG.md:5-7), someone who relied on the end notification of a long `awake -- make` loses it, and 2.0.0 marked a change to what existing commands do as `**Breaking:**` (CHANGELOG.md:485-487: `--start`, `--duration-seconds` and `--backend` always mean start).
   - If 3.0.0: the Changed entry starts with `**Breaking:**`, as in 2.0.0, so `tools/release.sh` suggests major. The open point of plan-2.3.0 (9), whether `Stop when unplugged` is on by default "in a later major version", is then due too.
   - Order: (a) folded in: one Mac session runs plan-2.3.0's phase 3 and this plan's QA, and 2.4.0 carries what the 2.3.0 QA finds, under Fixed. **Recommended**, unless that QA finds something urgent. (b) 2.3.1 first. `tools/release.sh` makes releases on `dev` (tools/release.sh:31), so the 2.3.1 is made there before this change's entries reach `[Unreleased]` on `dev`; this work waits on its own branch meanwhile. Once Added and Changed entries are in Unreleased, a 2.3.1 needs `tools/release.sh patch`, which overrides the suggestion with a note (tools/release.sh:230-234) and would ship the new default as a patch.
   - If folded in, plan-2.3.0.md:3 says "2.4.0 carries what it finds" in place of 2.3.1, and QA 3 of its 17 ("After 2.3.1 or a test release") uses 2.4.0.

## Earlier plans

`plan-2.3.0.md` stays in the repository until its phase 3, the Mac QA, is done (plan-2.3.0.md:3). Unlike the 2.1.0 and 2.2.0 checklists, which cf8517b moved into plan-2.3.0, its checklists are not moved here: they are still pending under that plan. Both QA lists can be run in one session on the Mac (8, phase 3).

## How this plan was checked

- It was written on Linux, from the code, without macOS, `osascript` or a Swift compiler. Real banners, sounds, the app, Shortcuts and upgrades need a Mac, so they are in the QA checklist (6), and what could not be checked here is listed in 9.
- Line numbers without a file name are lines of `bin/awake` 2.3.0, and in 5 of `tests/cli/awake-self-test`; a section of this plan is named by its number alone, such as 6 or 9.
- The `bin/awake` part (4) was prototyped on a scratch copy of 2.3.0, which is not committed. It passes `bash -n`, and `--help` stays within 80 columns.
- A probe ran 36 combinations of environment and arguments through the prescan, `parse_cli_args` and a detached `--notify-wait` child: all three reach the same state in every case. It also ran 12 behaviour states (default, on and off; with and without the app's suppression; with and without `--sound`) through `notify_gui`, `start_gui_completion_notifier`, `announce_completion` and `report_start_failure`.
- The existing notification checks (tests/cli/awake-self-test:999-1110) pass on the prototype and on 2.3.0. The proposed checks T1 to T7 (5) pass on the prototype and fail on 2.3.0. T7 ran as an unprivileged user, with Linux stand-ins for the BSD `stat` call and the main lock.
- The lifecycle checks (9a, P1, P1b, P2) and the installer assertions run the whole script, which stops at `require_macos` on Linux (bin/awake:624-629). They run on macOS CI only.
- The CHANGELOG text of 7 is within 79 columns, and `suggest_level` from `tools/release.sh` returns `minor` for it.

## Why the owner sees notifications today

- Every successful start calls `start_gui_completion_notifier` (bin/awake:7039), in every UI mode. It starts a detached `awake --notify-wait` process (3204-3228, through `start_detached`, 3061-3067), which waits for the session to end and posts `Awake finished`, `Awake stopped`, `Awake stopped: the battery is low` and the others, or `Awake failed` (`announce_completion`, 4800-4825). Only the app's suppression, or `--no-notifications` without `--sound`, stops it (3212-3220).
- This is the "always a GUI notification" in a terminal: the start is printed, and the end is posted, however it ends. `Awake started` is posted in a terminal only with `--sound` (7040-7041), a rule from 1.0.0.
- Without a terminal (no TTY on standard input or output), the replies a terminal would print are posted instead: `Awake started`, `Awake extended` (5873), `Awake is already on` (6628), `Awake is off` (6751) and `Awake failed` (3960). With `--gui` typed in a terminal they are printed, and only `Awake started` (7040) and `Awake is off` (6748) are posted.
- `--no-notifications` came with the menu bar app (d85eb41), for callers that show their own feedback: the README then called it "intended for the native menu bar app". The installer and uninstaller still use its variable; the app uses `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY` (AwakeCLI.swift:579-581).
- Every notification goes through `notify_gui` (3164-3202). Its gates already give the new default once `SUPPRESS_NOTIFICATIONS` defaults to true: a requested sound still plays (3173-3175), no notifier starts without `--sound` (3216-3220), and a session's end plays only the sound (4785-4791).

## 1. Goals

1. A plain `awake` run posts no Notification Center message: in a terminal, with `--gui` typed in one, or without a terminal. The one exception is decision 2, which never fires where `awake` itself prints to a terminal (terminal mode, or `--gui` typed in one); a terminal command that sends `awake`'s output to a pipe or a file runs in GUI mode and can still post it (9).
2. `--notifications`, or `AWAKE_NOTIFICATIONS=true`, brings back exactly the 2.3.0 notifications. The only other visible change is the printed line of decision 13.
3. `--sound` works on its own: the alert sound when a session starts and when it ends, without a banner.
4. Nothing breaks across versions: Awake.app, the installer, the uninstaller, Homebrew, older installed CLIs and existing scripts keep working. No option and no variable is removed.

Not in scope:

- any change to how Awake.app behaves, or the app announcing sessions it did not start;
- the helper and its protocol (version 9, bin/awake:106), the `--notify-wait` arguments, the session, state and status files, `--status-json` (schema 1), and notification titles;
- a `defaults` key or a Settings switch for the CLI's notifications;
- `--status` naming why the last session ended (a possible follow-up, 9);
- the 6-hourly touch of the session file (4899-4903), which long lid-closed sessions without a notifier go without (9);
- cleanups: the redundant prescan entry for `--no-notifications`, and the obsolete `--notify-status` names (1178).

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | What "from the command line" covers | Provisional (question 2). Every `awake` run that Awake.app did not make: a terminal, `-t`, `--gui` or `--gui-custom` typed in one, and runs without a terminal. App runs stay as they are, because the app's `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY` is checked first (3173-3184, 3212-3215). Rejected: terminal mode only, and runs a terminal shows only. Both would still post for `awake --duration 1h > log`, and both wait for the UI mode, which is set after the exports. |
| 2 | Is anything posted by default? | Provisional (question 3). Only `Awake failed` from `report_start_failure` (3952-3962), and only when `verbose` is false, that is, when `awake` does not print to a terminal: never in terminal mode, also when `-t` forces it without a terminal (6405-6414), nor for `--gui` typed in one (6421-6423). A terminal command whose output goes to a pipe or a file runs in GUI mode and does post it (9). It covers 31 start and add-time failures, all ending in exit status 1; the five in `extend_running_session` reach it through 6652-6654. `--no-notifications` and `AWAKE_NO_NOTIFICATIONS=true` turn it off, as in 2.3.0. Rejected: nothing at all, which leaves a refused start from Shortcuts without a trace; keeping every reply without a terminal (`Awake started`, `Awake is off` and the others), which is the noise the owner wants gone; and a notifier for every session. |
| 3 | The option's name | Provisional (question 1). `--notifications`, plural, the pair of `--no-notifications`. `--notification` stays an unknown option: exit status 1 and the usage (521-525). Rejected: the singular only, or both spellings. |
| 4 | `--no-notifications` and `AWAKE_NO_NOTIFICATIONS` | Both stay, documented and not deprecated. They are the explicit off: no banners at all, the failure notice included; a requested `--sound` still plays. Rejected: removing them, which `tools/release.sh` reads as a major version (`### Removed`, 184-185), makes scripts fail with `Unknown option`, and breaks the installer's calls to older CLIs; deprecating them, while they still mean something. |
| 5 | A way to keep notifications on | `AWAKE_NOTIFICATIONS=true`, documented as `AWAKE_DEBUG` is (README.md:326). A shell alias also works in interactive shells. Rejected: `AWAKE_NO_NOTIFICATIONS=false` as the opt-in, a double negative that 2.3.0 exported on every default run (6361), also to the `-- COMMAND` child, so an environment inherited from 2.3.0 would opt in silently; a `defaults` key, which costs a `defaults read` per run and is a CLI setting the Settings window does not show. |
| 6 | Precedence | (1) The last of `--notifications` and `--no-notifications` counts, in the prescan and in `parse_cli_args` alike. (2) An option beats either variable. (3) `AWAKE_NO_NOTIFICATIONS=true` beats `AWAKE_NOTIFICATIONS=true`. (4) The app's `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY=true` beats everything: no banner and no notifier, but the sound still plays. (5) Only the value `true` counts. Both options together are not an error. All 36 combinations were probed. Rejected: an error for both options, which breaks an alias plus a one-off override; off always winning, which breaks `alias awake='awake --no-notifications'` followed by `awake --notifications`; the environment beating options. |
| 7 | How the state is kept | `NOTIFICATIONS_SETTING=default\|on\|off`, and `SUPPRESS_NOTIFICATIONS`, which now defaults to true and is false only when the setting is on. `notify_gui`, `start_gui_completion_notifier` and `announce_completion` keep their gates. Rejected: new gates and a `kind` argument for `notify_gui`, more code that also lets the lid-open title check pass without testing anything (self-test:1089-1110); flipping only the default, which cannot tell an explicit off from the default, as decision 2 and the exports need. |
| 8 | How detached processes learn the choice | They skip `parse_cli_args` (6263-6328) and read the environment at the top of the script. `main` exports two variables in place of the one at 6361: `AWAKE_NOTIFICATIONS` (true only when on) and `AWAKE_NO_NOTIFICATIONS` (true only when off). `--notify-wait` keeps its four arguments (6292 counts five words with the option). If only the default were flipped, the notifier would silently ignore `--notifications`; T2, T7 and L2 catch that. Rejected: a fifth `--notify-wait` argument, which changes the dispatch at 6292-6296, the call at 3227 and `wait_for_gui_completion`; a field in the session file, which the stop paths delete (6685-6745) while the notifier may still need it. |
| 9 | `--sound` without `--notifications` | The sound only. At the start it comes from the suppressed branch of `notify_gui` (3173-3175), reached through 7040-7041. At the end the notifier starts just for the sound (3216-3220) and plays it in the suppressed branch of `announce_completion` (4785-4791). Awake.app's start sound uses the same path. Rejected: `--sound` implying `--notifications`, which brings terminal banners back; `--sound` doing nothing alone, which silences the app's start sound, as the app's `postNotification` ignores sound (InstallSupport.swift:523). |
| 10 | The start banner in a terminal | The rule at 7040 stays: in a terminal, `Awake started` is posted only with `--sound`. So `--notifications --sound` gives what `--sound` gave in 2.3.0. Rejected: posting it for `--notifications` alone, which repeats the printed start and delays `-- COMMAND`, since the first `AwakeStatusBar --notify` can wait about 120 s for permission (InstallSupport.swift:494-519) before `run_bound_command` (7043-7044). |
| 11 | When the completion notifier starts | Only with `--notifications` or `--sound`, and never under the app's suppression. No code change: 3212-3220 already does this once `SUPPRESS_NOTIFICATIONS` defaults to true. Rejected: a notifier for every session, a process per session that checks once a second (74, 4943). |
| 12 | Whose choice announces a session's end | The command that started it, as in 2.3.0. The stopping command never announces: `handle_pending_completion_notification` is only called with `false` (6528). `--notifications` on `--stop` or when adding time changes only that command's own replies. It is not a session setting: it sets neither `start_intent` nor `SESSION_SETTING_GIVEN` (6336-6340), so `awake --notifications` toggles like plain `awake` (T7). A `--sound` on the stopping command still reaches a lid-open session's status record when the stop goes through `caffeinate_stop` (5546-5548, 6688, 6741), as in 2.3.0; it is heard only if that session has a notifier, that is, if it was started with `--notifications` or `--sound`. Rejected: the stopping command announcing the end, which needs a recorded "has a notifier" field and protection against double posts. |
| 13 | `awake --gui --stop` typed in a terminal, with nothing running | Line 6748 tests `verbose` in place of `ui_mode == terminal`, so the command prints `Awake mode is not active.` there, also with `--notifications`: it prints or posts, never both, as `report_extend_result` does (5865-5875). Without a terminal it still calls `notify_gui "Awake is off"`, which posts only with `--notifications`. Rejected: no change, which leaves no feedback at all; printing and posting. |
| 14 | A failed end with `--sound` while notifications are off | No sound, as with notifications on, where `failed` never plays it (4822-4823). One condition in the suppressed branch of `announce_completion`, which every CLI session with `--sound` now goes through. Listed under Fixed. Rejected: keeping the 2.3.0 quirk of `--no-notifications --sound`. |
| 15 | `Awake is already on` when the add-time list cannot be shown (6628) | Opt-in like the other replies: it exits 0 and is not a failure. |
| 16 | Awake.app | Unchanged. It keeps setting `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY=true` and removing `AWAKE_NO_NOTIFICATIONS` (AwakeCLI.swift:579-581), and never passes `--notifications`. Two comments change (4). Rejected: removing `AWAKE_NOTIFICATIONS` in `AwakeCLI.environment`, not needed since the app's suppression wins; the app announcing CLI sessions (dropping `isAppSession` at StatusBarController.swift:449 and 532-534), which brings the banners back whenever the app runs. |
| 17 | Installer, uninstaller and Homebrew | They keep `AWAKE_NO_NOTIFICATIONS=true` on the calls that pass it today (install-awake.sh:377, 395; uninstall-awake.sh:90, 206); the installer's helper calls at 519 and 522 never had it and never post, as maintenance actions exit at 6429-6438. They get no new option: an older CLI exits 1 on an unknown option. Each gets a comment saying why. Rejected: dropping the variable, which lets an installed 2.3.0 post `Awake is off` (6751). |
| 18 | Prescan | It mirrors `parse_cli_args`: both options, in argument order, and it still stops at `--` (44-46). Rejected: leaving `--notifications` out, so that the two parsers could disagree. |
| 19 | Session files left behind | Accepted. Without a notifier, the session file stays until the next command removes it (4785-4791, 6528), as with `--no-notifications` and app sessions today. The self-test pins that it is kept (1060-1063). |
| 20 | The self-test's 38 `AWAKE_NO_NOTIFICATIONS=true` prefixes | They stay: they test the explicit off that the installer relies on. The self-test unsets the three notification variables at its top, so the caller's shell cannot change what it sees (T0). |
| 21 | Version | Provisional (question 4). 2.4.0, with Upgrade notes, Added, Changed and Fixed, folded in with what plan-2.3.0's QA finds. No `**Breaking` text and no `### Removed` heading, so `tools/release.sh` (183-191) suggests minor; checked on the text of 7. Rejected: 3.0.0 with a `**Breaking:**` entry; a 2.3.1 first, unless that QA finds something urgent. |

## 3. What the user sees

"Banner" is a Notification Center message, posted through Awake.app or `osascript` (3125-3162). "Tink" is the sound of `--sound`. "Printed" is a line in the terminal. 2.3.0 → 2.4.0; changes are in bold. The "No terminal" rows assume no `-t`: with it, `awake` runs in terminal mode and prints to an output nobody may see, and posts as the "Terminal" rows do.

| Who and how | Start succeeds | Session ends (stopped anywhere, finished, guardrail, process exited, failed) | Time added, or already on | Start or add-time fails | `--stop` with nothing running |
|---|---|---|---|---|---|
| Terminal, no options (`awake`, `--duration 1h`, `-w PID`, `-- make`) | printed | **banner → nothing** (no notifier) | printed | stderr | printed |
| Terminal, `--sound` | **banner + Tink → Tink** | **banner + Tink → Tink** (failed: banner → nothing) | printed | stderr | printed |
| Terminal, `--notifications` (2.3.0: `Unknown option`) | printed, no banner (7040) | banner | printed | stderr | printed |
| Terminal, `--notifications --sound` | banner + Tink | banner + Tink | printed | stderr | printed |
| `--gui` or `--gui-custom` typed in a terminal | **banner + printed → printed** | **banner → nothing** | printed | stderr | **banner, nothing printed → printed** |
| The same with `--notifications` | banner + printed | banner | printed | stderr | **banner → printed** |
| No terminal (Shortcuts, Raycast, cron or launchd, ssh, output to a file) | **banner → nothing** | **banner → nothing** | **banner → nothing** | stderr + banner (kept, question 3) | **banner → nothing** |
| No terminal, `--sound` | **banner + Tink → Tink** | **banner + Tink → Tink** (failed: banner → nothing) | **banner → nothing** | stderr + banner (kept) | **banner → nothing** |
| No terminal, `--notifications` | banner | banner | banner | stderr + banner | banner |
| `--no-notifications` or `AWAKE_NO_NOTIFICATIONS=true` | unchanged: no banner; Tink with `--sound` | unchanged (failed: **no Tink**) | unchanged | unchanged: stderr only | unchanged |
| `AWAKE_NOTIFICATIONS=true` | as `--notifications` | as `--notifications` | as `--notifications` | as `--notifications` | as `--notifications` |
| Awake.app (`--gui`, with the app's suppression) | unchanged: the app posts; the CLI plays Tink when Sound is on | unchanged: no CLI notifier; the app announces its own sessions | unchanged | unchanged: the app posts from stderr | unchanged: silent |
| Installer and uninstaller | — | a running 2.3.0 session's old notifier may post one `Awake stopped` (unchanged) | — | — | silent |
| `--dry-run` | never posts or plays (3085-3088, 3186-3189) | same; the notifier starts only with `--notifications` or `--sound` | same | stderr | same |

- **Sessions started without `--notifications`.** Nobody announces their end, whether it is stopped from the app, another terminal or a shortcut, or ends by its timer or a guardrail: the app skips sessions it did not start (StatusBarController.swift:447-449, 532-534). With `--notifications`, one banner, wherever it is stopped; the app stays silent.
- **`--notifications` only on `--stop` or when adding time.** The end follows the command that started the session (decision 12). That command's own reply is posted if no terminal shows it.
- **Never post, before or after:** `--status`, `--status-json` and the maintenance options (6429-6438, 6476-6518).
- **Not a notification, so unchanged:** the `display alert` after three wrong passwords in `--gui-custom` (935, 3964-3976).
- **Child processes:** an `awake` run inside `awake -- CMD` inherits the parent's choice through the two exported variables.

## 4. Code changes

### `bin/awake` (about 40 lines of code and 25 of comments)

1. **Defaults and environment, 28 and 36-38.** `SUPPRESS_NOTIFICATIONS=false` becomes the block below, and the variable test at 36-38 reads `AWAKE_NOTIFICATIONS` first. This is how `--notify-wait`, `--caffeinate-start` and `--caffeinate-runner` learn the choice. The block at 39-41 is unchanged.
   ```bash
   # Notifications are off by default: "default" posts none, apart from a start
   # failure that no terminal shows (report_start_failure). --notifications or
   # AWAKE_NOTIFICATIONS=true turns them "on"; --no-notifications or
   # AWAKE_NO_NOTIFICATIONS=true turns them "off", that failure notice included.
   # On the command line the last of the two options counts, an option beats the
   # environment, and AWAKE_NO_NOTIFICATIONS=true beats AWAKE_NOTIFICATIONS=true.
   # SUPPRESS_NOTIFICATIONS is false only when they are on.
   NOTIFICATIONS_SETTING=default
   SUPPRESS_NOTIFICATIONS=true
   …
   if [[ "${AWAKE_NOTIFICATIONS:-false}" == "true" ]]; then
       NOTIFICATIONS_SETTING=on
       SUPPRESS_NOTIFICATIONS=false
   fi
   # Read second, so that an explicit off wins. The installer and the
   # uninstaller pass it, also to older versions, which notify by default.
   if [[ "${AWAKE_NO_NOTIFICATIONS:-false}" == "true" ]]; then
       NOTIFICATIONS_SETTING=off
       SUPPRESS_NOTIFICATIONS=true
   fi
   ```
2. **Prescan, 53-55.** A `--notifications` test before the `--no-notifications` one, which also sets `NOTIFICATIONS_SETTING=off`. The comment: "The last of the two counts, as in parse_cli_args." The loop still stops at `--`.
3. **`show_usage`.** `--sound` (264-265) and `--no-notifications` (279) change, and one option is added, in the style of "(default off)" at 284; every line stays within 80 columns:
   ```
     --sound                Play a sound when a session starts and when it ends,
                            also without --notifications
     --notifications        Post notifications, for example when a session ends
                            (default off)
     --no-notifications     Post none, not even for a failure no terminal shows
   ```
4. **`parse_cli_args`, 374-376.** A `--notifications)` arm that sets `NOTIFICATIONS_SETTING=on` and `SUPPRESS_NOTIFICATIONS=false`; the `--no-notifications)` arm also sets `NOTIFICATIONS_SETTING=off`. No cross-option check (535-574): like `--no-notifications`, both are accepted with `--status` and the maintenance options, where they have no effect, and with `--stop`, where they decide only whether `Awake is off` is posted when nothing runs and no terminal shows the reply (decision 13).
5. **`start_gui_completion_notifier`, 3216.** Comment only: "With notifications off (the default), the notifier still plays a requested sound."
6. **The comment above `exit_start_cancelled`, 3935-3937.** It ends "…also posted as a notification, unless --no-notifications asked for none at all."
7. **`report_start_failure`, 3952-3962** (decision 2):
   ```bash
   report_start_failure() {
       local message=$1
       local verbose=${2:-false}
       # Seen by notify_gui below, which still applies the menu bar app's
       # suppression and dry run. Without a terminal, the notification is the
       # only sign of the failure, so notifications off by default do not stop
       # it; only --no-notifications does.
       local SUPPRESS_NOTIFICATIONS=$SUPPRESS_NOTIFICATIONS

       printf '%s\n' "$message" >&2
       if [[ "$verbose" != "true" && "$NOTIFICATIONS_SETTING" != "off" ]]; then
           SUPPRESS_NOTIFICATIONS=false
           # A short title and the explanation as the body: macOS cuts long
           # notification titles to one line.
           notify_gui "Awake failed" false "$message"
       fi
   }
   ```
   The `local` relies on Bash's dynamic scope, which 3.2 has: `notify_gui` sees it, and the global keeps its value (T4).
8. **`announce_completion`, 4787** (decision 14). In the suppressed branch:
   ```bash
           # As with notifications on, a failed session plays no sound.
           if [[ "$sound_notifications" == "true" && "$reason" != "failed" ]]; then
   ```
9. **`main`, the exports, 6361.** `export AWAKE_NO_NOTIFICATIONS="$SUPPRESS_NOTIFICATIONS"` becomes:
   ```bash
       # The detached processes (the notifier, the Caffeine worker and runner)
       # learn the choice only from these two.
       if [[ "$NOTIFICATIONS_SETTING" == "on" ]]; then
           export AWAKE_NOTIFICATIONS=true
       else
           export AWAKE_NOTIFICATIONS=false
       fi
       if [[ "$NOTIFICATIONS_SETTING" == "off" ]]; then
           export AWAKE_NO_NOTIFICATIONS=true
       else
           export AWAKE_NO_NOTIFICATIONS=false
       fi
   ```
   They can stay before the UI mode is decided, as the state does not depend on it, and they run before the notifier starts (7039).
10. **`main`, `--stop` with nothing running, 6748** (decision 13). `if [[ "$ui_mode" == "terminal" ]]` becomes `if [[ "$verbose" == "true" ]]`, under the comment "Printed wherever a terminal shows it, also for --gui run from one." The `else` branch with `notify_gui "Awake is off"` stays. `verbose` includes terminal mode (6421-6423), so terminal output is unchanged.
11. **`main`, the start banner, 7039-7040.** Comment only: "A terminal shows the start, so it is posted there only with --sound. Without --notifications, notify_gui then only plays the sound."

**Not changed:** `notify_gui` (3164-3202), `post_notification` and `awake_app_executable` (3106-3162), `play_notification_sound` (3082-3102), the logic of `start_gui_completion_notifier` (3204-3228), `wait_for_gui_completion` (4848-4949) and the `--notify-wait` dispatch (6289-6297), `report_extend_result` (5865-5875) and 6628, the rule at 7040, `write_session_file` (2558-2572) and every runtime file format, `print_status_json` (2933-3056), `handle_pending_completion_notification` (4828-4846), the main-lock exclusions (1171-1178), `bin/awake-helper`, and the version number, which only `tools/release.sh` sets.

### `app/AwakeStatusApp/Sources` (comments only)

- `InstallSupport.swift:112-113`: "The app only posts stop notifications for its own sessions; the CLI announces the rest only when they were started with `awake --notifications`."
- `StatusBarController.swift:447-448`: "A session started elsewhere is announced by the process that started it, if that had --notifications, so only confirm the app's own sessions."

### `scripts` (comments only)

- `install-awake.sh:394` adds: "Versions before 2.4.0 post notifications unless AWAKE_NO_NOTIFICATIONS=true says otherwise, and refuse options they do not know, so this passes no new option."
- `uninstall-awake.sh`, above 90 and 206: "The installed version may be older than 2.4.0, which posts notifications unless told not to."
- The arguments stay exactly as they are; the self-test pins them (2457-2466, 2512-2524).

New code keeps to Bash 3.2, which CI's `/bin/bash` is (ci.yml:20-25): only `[[ ]]`, `local`, `case` and `export`.

## 5. Tests

All in `tests/cli/awake-self-test`, in dry-run, on macOS CI (ci.yml:107-108). T1 to T7 go in `run_sourced_regression_checks` (385-1724).

- **T0, the environment.** After line 3, `unset AWAKE_NOTIFICATIONS AWAKE_NO_NOTIFICATIONS AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY`, so that a developer's exported opt-in does not change the default-path checks.
- **The real `notify_gui`.** After `source "$AWAKE_SCRIPT_PATH"` (389), `eval "saved_$(declare -f notify_gui)"`, since 1199 replaces it with a stand-in that fails.
- **T1, parsing, after 784.** Each case in a `( … )` subshell that starts from `default/true`, as parse errors exit: `--status-json --notifications` gives `on/false`; `--status-json --no-notifications` gives `off/true` (the check at 775-783 stays); `--notifications --no-notifications` gives `off/true` and the reverse `on/false`; `--terminal -- /bin/echo --notifications` gives `default/true` with `RUN_COMMAND=(/bin/echo --notifications)`; `--notification` exits 1 with `Unknown option: --notification`.
- **T2, prescan, environment and child.** A fresh shell per case, since `bin/awake` declares readonly variables: `env -u AWAKE_NOTIFICATIONS -u AWAKE_NO_NOTIFICATIONS AWAKE_DRY_RUN=true ENV /bin/bash -c 'source "$1" "${@:2}"; printf "%s/%s" "$NOTIFICATIONS_SETTING" "$SUPPRESS_NOTIFICATIONS"' _ "$AWAKE_SCRIPT_PATH" ARGS`.

  | Environment | Arguments | Expected |
  |---|---|---|
  | none | none | `default/true` |
  | none | `--notifications` | `on/false` |
  | none | `--no-notifications`, or `--notifications --no-notifications` | `off/true` |
  | none | `--terminal -- /bin/echo --notifications` | `default/true` |
  | `AWAKE_NOTIFICATIONS=true` | none | `on/false` |
  | `AWAKE_NO_NOTIFICATIONS=true`, or both `true` | none | `off/true` |
  | `AWAKE_NO_NOTIFICATIONS=false`, or `AWAKE_NOTIFICATIONS=1` | none | `default/true` |
  | `AWAKE_NO_NOTIFICATIONS=true` | `--notifications` | `on/false` |
  | `AWAKE_NOTIFICATIONS=true` | `--no-notifications` | `off/true` |

  The child: `--notify-wait 60 awake tok false` under the exported pairs (true, false), (false, true) and (false, false) gives `on`, `off` and `default`.
- **T3, `notify_gui`, after 1026.** In a subshell with `DRY_RUN=false` and `post_notification` stubbed, as at 1699-1705: one post when on, none by default.
- **T4, `report_start_failure`.** The same setup:

  | State | `verbose` | App's suppression | Expected |
  |---|---|---|---|
  | default | false | off | posts `Awake failed` with the message as body; the global is still `true` afterwards |
  | default | true | off | no post |
  | off | false | off | no post |
  | default | false | on | no post |
  | on | false | off | posts |

- **T5, `start_gui_completion_notifier`.** `start_detached` stubbed to print on stderr, as the call sends stdout to `/dev/null` (bin/awake:3227). Default without sound: nothing starts. Default with sound: `--notify-wait 60 awake tok true`. On without sound: `… false`. Off with sound: `… true`. On with sound and the app's suppression: nothing starts.
- **T6, `announce_completion`, extending 1028-1110.** Default state with sound: `failed` gives no sound and no post, `timeout` only the sound; 1047-1062 still checks that the files are kept. On: the session file is removed, then the title is posted. The check at 1102-1106 gets a stand-in that prints `called` when the title matches, and asserts it: today it passes even if `notify_gui` is never reached.
- **T7, what `main` decides.** After the stand-ins at 1252-1263 (which follow `reset_main_flags` and `settings_*` at 1212-1251), in a subshell, with `notify_gui() { saved_notify_gui "$@"; }`, and `start_gui_completion_notifier` stubbed to print `NOTIFIER sound=$4 NOTIF=${AWAKE_NOTIFICATIONS-unset} NO=${AWAKE_NO_NOTIFICATIONS-unset}` (the sourced checks run under `set -u`, and T0 unsets both), `play_notification_sound` to print `SOUND`, and `log_debug` to print `LOG $1`, all on stderr. It also stubs `battery_percent_on_battery` and `thermal_state`. `reset_main_flags` gains `NOTIFICATIONS_SETTING=default`, `SUPPRESS_NOTIFICATIONS=true` and `SUPPRESS_GUI_NOTIFICATIONS_ONLY=false`. Every start gives a time option: without one, `--terminal` refuses a captured run (bin/awake:6405-6413) and `--gui` opens the real picker (bin/awake:6779-6787), which nothing stubs.

  | Command (`main …`) | Expected |
  |---|---|
  | `--terminal --duration-seconds 1` | `NOTIFIER sound=false NOTIF=false NO=false`, and no `message=Awake started` |
  | `--terminal --notifications --duration-seconds 1` | `NOTIF=true` (catches a missing export), and no `message=Awake started` |
  | `--terminal --sound --duration-seconds 1` | `notify_gui notification_suppressed message=Awake started`, `SOUND`, `NOTIFIER sound=true NOTIF=false` |
  | `--gui --duration-seconds 1` (captured, so not interactive) | `notification_suppressed message=Awake started` |
  | `--gui --notifications --duration-seconds 1` | `notify_gui dry_run_skipped message=Awake started` and `NOTIF=true` |
  | `--gui --no-notifications --duration-seconds 1` | `NO=true` |
  | `--gui --notifications --sound --duration-seconds 1`, app's suppression on | `gui_only_suppressed message=Awake started` and `SOUND` |
  | a start refused for low battery (as at 1456-1457): `--gui --duration-seconds 60` | `notify_gui dry_run_skipped message=Awake failed` |
  | the same with `--no-notifications` / app's suppression / `--terminal` in place of `--gui` | no `message=Awake failed` / `gui_only_suppressed message=Awake failed` / no `message=Awake failed` |
  | `--gui --stop`, nothing running | `notification_suppressed message=Awake is off`, nothing printed |
  | `--gui --stop --notifications` | `dry_run_skipped message=Awake is off` |
  | `--notifications`, a helper session running and `request_helper_session_stop` stubbed (as at 1389 and 1444-1449) | `STOP_REQUESTED` and no `message=` post (decision 12) |

- **Lifecycle 9a, after step 9 (2379-2391),** so after step 4's "no debug log without `--debug`" (2274-2276). Each case uses `--debug` and `DRY_RUN_LOG_FILE`, and waits for the session, and any notifier it started, to end before `cleanup_state`.
  - L1: `run_awake --debug --terminal --duration-seconds 2`, then `Awake is off.`: the log has `start_gui_completion_notifier suppressed` and no `wait_for_gui_completion start`.
  - L2: the same with `--notifications`, with the default backend and with `--backend caffeinate`: within 15 s the log has `notify_gui dry_run_skipped message=Awake finished`. This proves end to end that the opt-in reaches the detached notifier.
  - L3: `--terminal --sound`: `notify_gui notification_suppressed message=Awake started`, `announce_completion notification_suppressed reason=timeout sound_notifications=true` and `play_notification_sound dry_run_skipped`, and no `dry_run_skipped message=Awake finished`.
  - L4: `run_awake --debug --gui --duration-seconds 2` without a terminal logs `notify_gui notification_suppressed message=Awake started`; with `--notifications`, `notify_gui dry_run_skipped message=Awake started`.
  - L5: `AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY=true` with `--gui --notifications --sound --duration-seconds 2` logs `start_gui_completion_notifier gui_only_suppressed`.
  - L6: `--terminal -- /bin/echo --notifications` prints `--notifications`, and the log has `start_gui_completion_notifier suppressed`.
- **Real terminal, next to 12j (3755-3789), with `run_in_pty`.**
  - P1: with nothing running, `--dry-run --gui --stop` shows `Awake mode is not active.` and `exit=0` (decision 13).
  - P1b: the same with `--debug --notifications`: the same output, and the log has no `notify_gui start message=Awake is off`.
  - P2: a default start in a real terminal without `-t`, `--dry-run --debug --duration-seconds 2`, shows `Awake activated`, and the log has `start_gui_completion_notifier suppressed`.
- **Installer and uninstaller (11 and 11b).** The stand-in awake of step 11 (2402-2409) also writes `${AWAKE_NO_NOTIFICATIONS:-unset}` to `${HOME}/stop-env.log`, and the installer's stand-in (2475-2493) to `${INSTALLER_TEST_DIR}/env`. Every call must record `true`. The exact-argument assertions stay.
- **Help (step 13, 3987-3994).** The 80-column check covers the new lines; a new assertion checks that `--help` contains `--notifications`.
- **Unchanged:** the checks at 771-784, 999-1086 and 1173-1209, step 7 (2351-2362), which still tests the explicit off, the 38 prefixes (decision 20), and `tests/app/*.swift`, which have no notification code. The new steps add about a minute to CI's 20-minute limit (ci.yml:16).

## 6. macOS QA checklist

1. **Terminal default.** `awake --duration 1m`: no banner at the start or the end, and `pgrep -fl -- '--notify-wait'` prints nothing while it runs.
2. **Opt-in.** `awake --notifications --duration 1m`: no start banner, then `Awake finished` with the Awake icon, posted through `AwakeStatusBar --notify`.
3. **Sound only.** `awake --sound --duration 1m`: Tink at the start and the end, no banners.
4. **Both.** `awake --notifications --sound -- sleep 20`, after permission was granted once: banner and Tink at the start and the end, and the command starts without a noticeable delay.
5. **`--gui --stop`.** In Terminal with nothing running: prints `Awake mode is not active.` and posts nothing, also with `--notifications`.
6. **Stopped from the app.** A terminal session started without `--notifications`, stopped from the menu bar icon: nothing is posted. One started with it: `Awake stopped` once, and the app stays silent.
7. **Shortcuts,** Run Shell Script: `awake --duration 1h` starts silently; with `--notifications` it posts `Awake started`, and later `Awake finished`; while a session runs, `awake -- /bin/sleep 5` posts `Awake failed` with "A session is already running…" (bin/awake:6539); with `--no-notifications` nothing is posted. Note what Shortcuts itself shows for exit status 1 and stderr.
8. **The variable.** With `export AWAKE_NOTIFICATIONS=true` in `~/.zshenv`, the Shortcuts run of `awake --duration 1m` posts as with `--notifications`. If it does not, the README's `~/.zshenv` hint is reworded (9).
9. **Awake.app with Sound on.** Start: one Tink (from the CLI) and the app's `Awake started` once. Stop: one Tink (from the app) and `Awake stopped` once. `pgrep -fl -- '--notify-wait'` shows no CLI notifier. The same after `launchctl setenv AWAKE_NOTIFICATIONS true` and relaunching the app.
10. **Upgrade.** Run the installer over 2.3.0 while a terminal session runs: the session stops, at most one `Awake stopped` comes from the old notifier, and no `Awake is off` appears. Again with `brew upgrade` once the tap is set up (plan-2.3.0, 17).
11. **Uninstall.** The new uninstaller against an installed 2.3.0 posts no `Awake is off`.
12. **launchd.** On battery power below 50%, a launchd agent or cron job runs `awake --duration 1h --min-battery 50`: `Awake failed` is posted; with `--no-notifications`, or with `-t`, nothing.
13. **Help.** `awake --help` reads well, and the Help window shows the changed README bullets as single lines.

## 7. Docs

Every README bullet stays one line: the Help window renders only one-line `- ` bullets (ReadmeWindowController.swift:197-257). The app shows the new text after a reinstall (tools/build-awake-app.sh:60).

- **README, What it does (44):** the bullet becomes:
  > - posts macOS Notification Center messages when you pass `--notifications` (or set `AWAKE_NOTIFICATIONS=true`, see Notifications below): when a session starts, is stopped, finishes, ends on low battery, overheating, or unplugging, or fails (`Awake started`, `Awake extended`, `Awake stopped`, `Awake finished`, `Awake stopped: the battery is low`, `Awake stopped: the Mac got too hot`, `Awake stopped: the Mac was unplugged`, `Awake finished: the process it waited for exited`, or `Awake failed`). Without it, `awake` posts none, with one exception: a request to start or add time that `awake` refuses, for example for a low battery or a session already running, while its output does not go to a terminal (from a shortcut, a `launchd` job, or `… | tee log`) still posts `Awake failed` with the reason, unless it runs with `-t`, which always prints (`--no-notifications` turns that off too). They name the program, Awake, in both modes, as do all of `awake`'s messages. When `Awake.app` is installed, these notifications are posted through it and show the Awake icon (if notifications for Awake are turned off in System Settings, none are posted); a CLI-only install posts them with `osascript`. A failure notification has the reason as its text, under the title `Awake failed`. A session's end is announced only when the command that started it had `--notifications`, wherever it is stopped from. In a terminal, starts, added time, and failures are printed instead, so there `--notifications` adds the notifications for how the session ends, and `Awake started` only together with `--sound`. `--sound` plays the system alert sound when a session starts and when it ends, with or without notifications. The menu bar app posts its own notifications for the sessions it starts, whatever these options say.
- **README, Menu bar app (224):** "…the same modes, the same picker, and the same stop semantics as the terminal CLI in GUI mode. It posts notifications for the sessions it starts; `awake` posts them only with `--notifications`."
- **README, Choosing lid-closed or lid-open mode (300):** "…with the same status tracking as the GUI offers (and, with `--notifications`, the same notifications); …"
- **README, Concurrency and stop semantics (322):** "`--stop` is idempotent: if no session is active, it prints `Awake mode is not active.` in terminal mode and when a terminal shows the output of `--gui`; otherwise it posts `Awake is off` with `--notifications`, and exits silently without it."
- **README, a new `### Notifications` after Debug logging (326):** "Notifications from `awake` are off by default. Pass `--notifications`, or, to get them in every run, set `AWAKE_NOTIFICATIONS=true` in the environment: for shells and Shortcuts, for example in `~/.zshenv`; for a launchd job, under its `EnvironmentVariables`. `--no-notifications` or `AWAKE_NO_NOTIFICATIONS=true` turns off even the `Awake failed` notification of a request to start or add time that fails without a terminal. Errors in the command line itself, a busy lock, an unknown `-w` process, and a command after `--` that cannot be found are reported on standard error only, as before. On the command line the last of the two options counts, an option beats either variable, and `AWAKE_NO_NOTIFICATIONS=true` beats `AWAKE_NOTIFICATIONS=true`. Versions before 2.4.0 refuse `--notifications` but ignore the variable, so scripts that may meet an older `awake` should use the variable; in an interactive shell, `alias awake='awake --notifications'` also works. A running session keeps the choice of the command that started it. The menu bar app is not affected."
- **README, Options (344-345),** three bullets:
  - "`--sound`: play the system alert sound when a session starts and when it ends, with or without `--notifications`; give it to the command that starts the session."
  - "`--notifications`: post notifications when a session starts, ends, or fails (see What it does); off by default. A running session keeps the choice it started with; like `--sound`, `--notifications` is not a session option, so `awake --notifications` alone stops a running session, as plain `awake` does; with a time option or `--start` it adds time instead."
  - "`--no-notifications`: post none at all, not even `Awake failed` for a request to start or add time that fails without a terminal; given together with `--notifications`, the last one counts."
- **README, Examples (468-472):** "Force GUI mode with the custom GUI password dialog, notifications, and sounds:" with `awake --gui-custom --notifications --sound`; and a new example, "Keep the Mac awake during a build and get a notification when it ends:" with `awake --notifications -- make build`.
- **README, Dry-run and self-test (576):** "- verifying that notifications are off by default, that `--notifications`, `--no-notifications`, `AWAKE_NOTIFICATIONS`, and `AWAKE_NO_NOTIFICATIONS` combine as documented, that a failed start or added time without a terminal is still posted, and that the menu bar app's suppression still wins,"
- **README, unchanged:** lines 13, 15, 103, 104, 228, 244, 273, 353 and 535. The version (19) is set by `tools/release.sh`.
- **Usage text:** as in 4, item 3.
- **CHANGELOG `[Unreleased]`.** Never `**Breaking` or `### Removed` anywhere in Unreleased, which `tools/release.sh` reads as a major version (184), unless the owner chooses 3.0.0 (question 4).

  ```
  ### Upgrade notes

  - `awake` no longer posts notifications unless you ask for them. Pass
    `--notifications`, or set `AWAKE_NOTIFICATIONS=true` in the environment, to
    get them as before. Versions before 2.4.0 refuse the option but ignore the
    variable, so use the variable in scripts that may meet an older `awake`.
    The menu bar app posts its notifications as before.

  ### Added

  - `--notifications` makes `awake` post notifications, as it did by default
    before: `Awake started` (in GUI mode, or with `--sound` in a terminal),
    how the session ends (`Awake finished`, `Awake stopped` and the others),
    and, when no terminal shows them, `Awake extended`, `Awake is already on`,
    `Awake is off` and `Awake failed`. `AWAKE_NOTIFICATIONS=true` in the
    environment does the same. Given together with `--no-notifications`, the
    last one counts.

  ### Changed

  - `awake` posts no notifications by default. A session's end is announced
    only when the command that started it had `--notifications`, wherever the
    session is stopped from. Without a terminal, for example from a shortcut,
    a request to start or add time that fails still posts `Awake failed` with
    the reason, since nothing else would show it; `--no-notifications` turns
    that off too.
  - `--sound` plays its sound when a session starts and when it ends, also
    without `--notifications`. In a terminal it no longer posts `Awake started`
    by itself.
  - `awake --gui --stop` run in a terminal prints `Awake mode is not active.`
    when no session runs. It posted `Awake is off` instead.

  ### Fixed

  - With `--sound` and notifications off, a session that fails no longer plays
    the sound, as it never did with notifications on.
  ```

## 8. Phases

1. Code and tests, after the owner's answers: `bin/awake` and the self-test (4 and 5), until macOS CI is green.
2. Docs: README, CHANGELOG, `docs/plans/plan-2.4.0.md`, the comments in the app and the scripts, and, if 2.4.0 is folded in (question 4), the release named in plan-2.3.0.md:3 and in its 17, QA 3. Phases 1 and 2 can go in as one commit.
3. QA on a real Mac: 6, in the same session as plan-2.3.0's phase 3.
4. Version 2.4.0 with `tools/release.sh minor`, the level it suggests, if the owner confirms question 4.

## 9. Risks and open points

- **Nobody announces a CLI session started without `--notifications`:** its timer, a guardrail (low battery, too hot, unplugged), or a stop from the app or a shortcut. The app skips sessions it did not start (StatusBarController.swift:447-449, 532-534). The Upgrade note and the README say so, `--notifications` or the variable bring it back, and a guardrail still lets the Mac sleep. A possible follow-up: `--status` naming why the last session ended. Accepted.
- **A failed end is silent by default.** When the helper cannot restore sleep (bin/awake-helper:800-803), sleep may stay off with no notification in a CLI-only install. The app's "needs attention" check covers it while the app runs (StatusBarController.swift:510-520), and `--status` prints "Sleep is still turned off, but no Awake session is running." (bin/awake:2807). Accepted.
- **Runs without a terminal lose their confirmations.** Shortcuts, launchd, Raycast and Alfred users no longer see `Awake started`, `Awake is off`, `Awake extended` or `Awake is already on`; only `Awake failed` stays (question 3).
- **The opt-in can be lost silently.** If the exports of 4, item 9, are left out, or moved after the notifier starts (7039), `--notifications` starts a notifier that sees the default and posts nothing. T2, T7 and L2 catch this; today's self-test would not, as it stubs the notifier (self-test:1255, 1911).
- **The `local` in `report_start_failure`.** A refactor that moves the post elsewhere loses the exception. T4 pins the post and the unchanged global.
- **Session files are left more often** (4785-4791, cleared at 6528), and long lid-closed sessions without a notifier lose the 6-hourly touch (4899-4903). `--status-json` can then report a stale `session_mode` or `sound_notifications` for an ended lid-closed session (2978-2982). The app ignores both (AwakeCLI.swift:16-18, 65-67), and this already happens for app sessions. Accepted.
- **A visible stderr can still come with a banner.** A command typed in a terminal whose output goes to a pipe or a file runs in GUI mode with `verbose` false (6391-6396, 6421-6423), so a refused start or added time is printed to the visible stderr and also posted: `awake --duration 1h > log`, and `awake -- make 2>&1 | tee build.log` while a session runs. `ssh host awake` without `-t` posts on the remote Mac. All as in 2.3.0, and the narrower (b) of question 3 would cover only `> log`. Accepted.
- **A slow first notification.** The first `AwakeStatusBar --notify` can wait about 120 s for permission (InstallSupport.swift:494-519) before `-- COMMAND` starts. Unchanged, and now only with `--notifications`: in GUI mode, or in a terminal together with `--sound` (decision 10).
- **Test ordering.** The `--debug` lifecycle checks can race a notifier that still logs after `cleanup_state`, so they come after step 4 and wait for the notifier to exit.
- **Unverified here** (QA 1 to 13): real banners and sounds (dry-run never posts, 3186-3189), the app, Shortcuts, launchd, upgrades and Homebrew; whether Shortcuts' Run Shell Script reads `~/.zshenv` (QA 8); Bash 3.2, as the prototype ran on Bash 5.2; the lifecycle checks 9a, P1, P1b and P2, which need macOS.
- **Open, from plan-2.3.0 (9).** Its open points stay there: the heat note in the `Awake stopped` notification, and `Stop when unplugged` on by default in a later major version, which question 4's 3.0.0 would bring due.

## 10. Compatibility

- **`--no-notifications` and `AWAKE_NO_NOTIFICATIONS=true`** keep the meaning they have had since 1.0.0: no banners, a requested `--sound` still plays. The installer and uninstaller pass the variable to whatever CLI is installed (install-awake.sh:377 and 395, run before the files are replaced at 499-507; uninstall-awake.sh:90, 206): redundant with a new CLI, still needed with an older one.
- **`AWAKE_NO_NOTIFICATIONS=false`** meant on in 2.3.0, the default then. It now means "not explicitly off", the new default, off. It has been undocumented since 2354789.
- **Older CLIs** refuse `--notifications` with `Unknown option` and exit 1 (521-525). The repository's scripts and the app never pass it; scripts that may meet an older `awake` use `AWAKE_NOTIFICATIONS=true`, which older versions ignore.
- **Awake.app with any CLI.** The app's suppression comes first, so app runs post no CLI banner and start no notifier, and the CLI still plays the app's start sound (3173-3175), even with `AWAKE_NOTIFICATIONS=true` inherited from launchd, which the app copies (AwakeCLI.swift:578). The `AwakeStatusBar --notify` contract, with exit statuses 0, 1, 3 and 4 (main.swift:54-63, InstallSupport.swift:480-521), is untouched.
- **Background processes.** The `--notify-wait` arguments, `start_detached`, the helper protocol, the runtime files, `--status-json` (with `sound_notifications` and `session_mode`), exit statuses and titles are unchanged. A notifier already running from a 2.3.0 session keeps the old rules until its session ends.
- **`-- COMMAND`.** Both variables are exported before `run_bound_command` (6359-6362 run before 7043-7044), so a nested `awake` inherits the parent's choice, as `AWAKE_DRY_RUN` and `AWAKE_DEBUG` already do.
- **Output.** The only change is `Awake mode is not active.` on stdout for `awake --gui --stop` in an interactive terminal. `verbose` needs `-t 0 && -t 1` for `--gui` (6391, 6421), so a script's output is unchanged.
- **Homebrew** runs the same installer and uninstaller (tools/homebrew/awake.rb:27-35; scripts/homebrew-uninstall.sh:43-54).
