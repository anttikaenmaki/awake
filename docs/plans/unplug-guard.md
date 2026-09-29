# Plan: stop when unplugged

- Status: proposed, not yet implemented
- Target version: 2.2.0, together with `session-heat-report.md`; helper protocol 9
- Written: 2026-09-29, against `dev` at 2.1.0 as released (commit `8ccd5f6`)
- Scope: `bin/awake`, `bin/awake-helper`, `app/AwakeStatusApp`, `tests/cli/awake-self-test`, `README.md`, `CHANGELOG.md`

## How this plan was checked

- It was written on Linux, from the code. What needs a real Mac, such as `pmset`'s output and when the Mac sleeps, is in the QA checklist (9).

## 1. Goals

1. An option that ends a session when the Mac is unplugged, so that a closed MacBook that is carried off, perhaps into a bag, goes to sleep within seconds instead of staying awake.
2. Off by default: nothing changes for anyone who does not turn it on.
3. The same behaviour for lid-closed and Caffeine sessions, like the other guardrails.

Not in scope:

- starting a session when the Mac is plugged in, which would be an automatic trigger;
- `While plugged in` as an end condition in the picker: `Indefinitely` with this option does the same, and the picker stays as simple as it is;
- a warning at the start that the battery will not last the session: macOS's time-remaining estimate assumes the display is on, so it is wrong for lid-closed sessions;
- checking the charge the moment the Mac is unplugged, for `Stop at low battery`: with this option on, unplugging ends the session anyway, and with it off, the power source is not checked often enough to help.

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Default | Off. Some people unplug a closed Mac on purpose, for example to carry it to another room while a download finishes. |
| 2 | What counts as unplugged | The Mac drawing from its battery, or from a UPS, instead of the power adapter, as the first line of `pmset -g batt` says: `'Battery Power'` or `'UPS Power'` instead of `'AC Power'`. |
| 3 | When it acts | On the switch from the adapter to battery during the session, not merely when the Mac runs on battery. A session started on battery goes on until the Mac has been plugged in once; otherwise the option would end every session started on battery at once. |
| 4 | Brief interruptions | The power source is checked every 5 seconds, and the session ends after two checks in a row on battery, 5 to 10 seconds after unplugging. A MagSafe connector that is pulled and put back, or a dock that reconnects, does not end it. A power source that cannot be read never ends a session, like a thermal state that cannot be read. |
| 5 | How it ends | Like the other guardrails: the completion reason is `unplugged`, `disablesleep` is turned off even if it was on before the session, and with the lid closed the helper puts the Mac to sleep. A Mac in closed-display mode with an external display is left alone, as today. |
| 6 | Release | In 2.2.0, with the heat note. The helper protocol goes from 8 to 9, so updating asks for the administrator password once. |
| 7 | Names | `--unplug-guard on\|off`, like `--thermal-guard`; `Stop when unplugged` in Settings, like `Stop when too hot`; the reason `unplugged`. |

## 3. What the user sees

### 3.1 Settings

The Guardrails group in 2.2.0, with the heat note of `session-heat-report.md`:

```
Guardrails
[x] Stop when too hot
    Last session: hot for 3 minutes, so Awake ended it.
Stop at low battery  [ 5% ▾ ]
[ ] Stop when unplugged
Apply to sessions started afterwards.
```

- The checkbox is off until turned on, and it is stored as `unplugGuardEnabled` in the app's preferences.
- It is shown on every Mac, like `Stop at low battery`. On a desktop it matters only with a UPS (4).
- Its tooltip says: "Ends a session when the Mac switches from the power adapter to battery power, so a closed Mac that you carry off goes to sleep. A session started on battery power is affected only after the Mac has been plugged in. Applies to the next session."

### 3.2 Command line

- `--unplug-guard on|off`: "End the session when the Mac is unplugged (default off)", in the help after `--thermal-guard`, wrapped like the lines around it so that `--help` stays within the 80 columns that self-test 13 checks.
- Like `--min-battery`, `--thermal-guard` and `--keep-display`, it applies to new sessions only. Alone during a session it is refused, and with a time option the running session keeps its settings. The two messages that say so list it with the others.
- When it is on, the lid-closed warning at the terminal prompt gets a line after the battery and heat lines: `- Stops when the Mac is unplugged, so it can sleep`. When it is off, the warning does not change: it is long already, and off is the default.

### 3.3 When a session ends

- Notification, from `awake` and from the app: `Awake stopped: the Mac was unplugged`, or `Caffeine stopped: the Mac was unplugged`. The app's body text is "The Mac was unplugged, so Awake stopped and restored the normal sleep settings." for a lid-closed session, and "The Mac was unplugged, so Awake stopped." for Caffeine.
- `--status-json` reports `last_completion_reason` `unplugged`, and nothing else new.
- `awake -- COMMAND`, when the session ended before the command: "… had already stopped because the Mac was unplugged while it ran; the Mac may have slept."
- When `disablesleep` was on before the session, `--status` afterwards prints the line it already prints after the other guardrails: "Awake turned off pmset disablesleep, which was on before the session, so the Mac could sleep."

## 4. Detection

A new function, `power_source`, in both `bin/awake` and `bin/awake-helper`:

- It prints `ac`, `battery` or `ups` from the first line of `pmset -g batt` (`Now drawing from 'AC Power'`, `'Battery Power'` or `'UPS Power'`), and fails on anything else. `battery_percent_on_battery` already matches `'Battery Power'` in the same output.
- In dry-run mode it reads `power_source` from the mock battery file, which the self-test already writes with `ac` or `battery`.
- `battery` and `ups` count as unplugged. A desktop without a UPS always reads `ac`, so the option never acts there. One with a UPS connected by USB reads `ups` during a power cut, and the option then lets it sleep, which saves the UPS battery.

The check, every 5 seconds while the option is on (every second in dry-run mode, like the other checks), keeps two values:

- `ac`: the guard is armed, and the count of checks on battery is reset;
- `battery` or `ups`: if the guard is armed, the count goes up, and at two the session ends as `unplugged`;
- a failed read: the count is reset.

One `pmset -g batt` every 5 seconds is small next to the loops' pass every second.

## 5. Helper changes (`bin/awake-helper`, protocol 9)

- `HELPER_VERSION=9`, and in `bin/awake` `HELPER_PROTOCOL_VERSION=9`. The CLI replaces an installed helper of another version before a lid-closed start, as it does now, which asks for the password.
- `start UID END [MIN_BATTERY THERMAL_GUARD [UNPLUG_GUARD [WATCH_PID]]]`: counting `start` itself, as the dispatch's `$#` does, the sixth word is now the unplug guard, `on` or `off` (default `off`), and the process to watch moves to the seventh. The protocol number changes with it, so no caller sends the old layout to the new helper. `start` takes 3, 5, 6 or 7 words, and refuses an unplug guard other than `on` or `off` with "the unplug guard must be on or off." (exit status 64). The usage lines name the new argument.
- The session record gets `unplug_guard=on|off`. `read_guard_settings` reads it, with `off` for a record without it.
- The timer (`cmd_run_timer`) runs the check of 4 every `UNPLUG_CHECK_SECONDS` while the option is on, and ends the session with `finish_session "$token" unplugged`.
- The heartbeat file gets `unplug_armed=1` once the timer has seen the adapter. The guard (`cmd_run_guard`), which checks nothing while the timer responds, then runs the same check when it takes over from a timer that died or stopped responding, as it already does for the battery and the heat.
- `finish_session`: `unplugged` joins `low_battery` and `overheated`, which turn `disablesleep` off even if it was on before the session (recorded as `disablesleep_forced`), and joins the ends that put the Mac to sleep when the lid is closed.
- `extend` does not change. An unplugged session ends within seconds, and a session started on battery takes more time as before.

## 6. CLI changes (`bin/awake`)

- `--unplug-guard on|off` sets `UNPLUG_GUARD` (default `off`) and `SESSION_SETTING_GIVEN`. Another value gives "Option --unplug-guard requires 'on' or 'off'." with the usage, like `--thermal-guard`.
- The two running-session messages in the start path list `--unplug-guard` with the other settings.
- Lid-closed start: `helper_start_arguments` becomes `start UID END MIN_BATTERY THERMAL_GUARD UNPLUG_GUARD`, then the process to watch, if any.
- Caffeine start: `--caffeinate-start` (`caffeinate_start`) and `--caffeinate-runner` (`caffeinate_runner`) take the setting after the thermal guard. The runner checks it like the helper's timer and exits with a new `RUNNER_EXIT_UNPLUGGED=13`, which `caffeinate_start` and `record_orphaned_runner_end` map to `unplugged`. These arguments are internal to `bin/awake`, and the installer stops a running session before it updates.
- `unplugged` joins the reasons that `wait_for_requested_stop_completion` accepts, gets its notification title in `announce_completion` (3.3), and its words in `run_bound_command` (3.3).
- The terminal warning line of 3.2.

## 7. App changes (`app/AwakeStatusApp`)

- `PreferencesStore` (`InstallSupport.swift`): `unplugGuardEnabled`, false unless set, and the same field in `PreferencesSnapshot`.
- `AwakeCLI.startArguments`: `--unplug-guard on|off` after `--thermal-guard`, so every session started from the app says which it wants.
- `SettingsWindowController`: the `Stop when unplugged` checkbox after the `Stop at low battery` row, with the tooltip of 3.1, stored at once like `Stop when too hot`. The heat note stays directly under `Stop when too hot`.
- `NotificationController.postStopped`: the title and body texts of 3.3 for `unplugged`.
- The same Swift 5.7 rule as in `session-heat-report.md` (6): no Swift 5.8 or later syntax, which CI's newer compiler would not catch.

## 8. Tests (`tests/cli/awake-self-test`, dry-run)

A new section, "12k. Verifying that a session ends when the Mac is unplugged", after 12j, so that the helpers of 12a, 12b and 12f are defined (`set_mock_battery`, `set_mock_thermal`, `expect_completion_reason`, `expect_still_on`, `sleepnow_count`):

- A lid-closed session with `--unplug-guard on`, started on `ac`: the switch to `battery` ends it with `unplugged`, in the helper's last record and in `--status-json`.
- The same with the mock lid closed: the Mac is put to sleep once (`sleepnow_count`). With `disablesleep` on before the session, it is off afterwards, and `disablesleep_forced` is reported.
- `ups` ends it the same way.
- Without the option, the switch to battery leaves the session on.
- Started on `battery` with the option on, the session is still on after a few seconds. After a switch to `ac` and back to `battery`, it ends with `unplugged`.
- The guard ends an unplugged session whose timer has died, as 12a does for the heat.
- A Caffeine session with the option on ends with `unplugged`, and without it goes on, as 12b does for the other guardrails.
- `--unplug-guard maybe` fails with the message of 6, and `--unplug-guard on` alone during a session is refused like the other settings.
- One check of the helper's arguments pins the new layout (`start UID END 5 on on`, then the process to watch). The existing checks of the arguments (`RUN_HELPER … start …`) match with wildcards, so they keep passing.

There is no test for an interruption shorter than two checks: it would depend on timing, and the count works like the one for the serious thermal state, which is not tested that way either.

## 9. macOS QA checklist

1. **The output.** `pmset -g batt` on an Apple silicon MacBook, and on an Intel one if available, starts with `Now drawing from 'AC Power'` on the adapter and `Now drawing from 'Battery Power'` after unplugging. On a desktop with a UPS connected by USB, if one is available, it shows `'UPS Power'` while the UPS runs on its battery.
2. **Lid closed.** With `Stop when unplugged` on, start a 30-minute lid-closed session on the adapter, close the lid, and unplug. The Mac sleeps within about 10 seconds: `pmset -g log` afterwards shows the sleep that soon after the switch to battery. After waking, the notification says `Awake stopped: the Mac was unplugged`.
3. **Reconnecting.** Pull the MagSafe connector and put it back within a second or two: the session goes on. The same with a dock that is unplugged and plugged back quickly.
4. **Started on battery.** Start on battery with the option on: the session goes on. Plug in, then unplug: it ends.
5. **Option off.** With the option off, unplugging changes nothing, as in 2.1.0.
6. **Caffeine.** A Caffeine session with the option on ends when unplugged with the lid open, and the Mac is not put to sleep.
7. **External display.** With the lid closed and an external display connected, unplugging ends the session and leaves the Mac to macOS, as the other guardrails do.
8. **Updating.** Updating from 2.1.0 asks for the password once, for the helper, and the next lid-closed start does not ask again. The checkbox is off after the update.

## 10. Docs

- **README:**
  - What It Does: a point for the option, after the battery and heat points.
  - Safety Warnings: `Stop when unplugged` as a further net before carrying the Mac off. It does not make a bag safe, as it acts only when the Mac is unplugged during a session. Unplugging joins the ends that put a closed Mac to sleep, and those that turn `disablesleep` off.
  - Menu Bar App: the stop notification also says when the Mac was unplugged, and the Guardrails list gets `Stop when unplugged`.
  - Options: `--unplug-guard on|off`.
  - Runtime Files: `unplugged` in the reasons of `status` and `last`.
- **CHANGELOG `[Unreleased]`:**
  - Upgrade notes: run the installer again; it installs helper protocol 9, which asks for the password once. A manual CLI-only install copies both `bin/awake` and `bin/awake-helper` again.
  - Added: the option, what counts as unplugged, when it acts, and how the session ends.

## 11. Phases

1. The helper and the CLI (5, 6) with the self-test (8), green on CI.
2. The app (7) and the docs (10), green on CI.
3. QA (9) on a real Mac, together with the QA of `session-heat-report.md` (8).
4. Version 2.2.0 with `tools/release.sh minor`, once both plans are done.

## 12. Risks and open points

- **Longer interruptions.** One that lasts for two checks in a row, 5 to 10 seconds, ends a session. An adapter or dock that drops power for that long is rare, and the option is off by default. QA item 3 checks the short ones.
- **`pmset` output.** The source names are the ones macOS's power management uses (`AC Power`, `Battery Power`, `UPS Power`), and `bin/awake` already relies on `'Battery Power'`. Output that cannot be read never ends a session.
- **The password prompt.** 2.2.0 asks for the password once when updating, which the heat note alone would not have. Accepted (decision 6).
- **Open.** Whether the option should be on by default for lid-closed sessions in a later major version.
