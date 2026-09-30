# Changelog

All notable changes to Awake are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version numbers
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html): a major
version for changes that can break existing use, a minor version for new
features, and a patch version for fixes.

## [Unreleased]

### Added

- Esc closes the Settings window and the Help window, as Command-W does. While a keyboard shortcut is being recorded, the first Esc
  only cancels the recording.
- `Start default session` in the menu bar menu does what the keyboard
  shortcut does: while Awake is off, it starts a session of the default
  length in the shortcut's `Mode`, also while the shortcut is off, and shows
  the shortcut next to it while the shortcut is on. While Awake is on, it
  reads `Stop session` and stops the session.
- `Time to add` in the Settings window's `Session lengths` group: what `Add`
  in the menu bar menu adds to a running session, one of the session
  lengths, 1 hour by default. The menu item names it, for example
  `Add 30 minutes`.

### Changed

- The keyboard shortcut has a `Shortcut` checkbox in the Settings window
  that turns it on or off. It is off by default, and it is `⇧⌘A` until you
  record another, using the key that types A in your keyboard layout when
  you first turn it on. Turning it off keeps the shortcut, and the
  shortcut's button is dimmed meanwhile. A shortcut recorded in 2.2.0 stays
  on. The checkbox replaces the `Clear` button, and Delete or Forward Delete
  no longer clears the shortcut while one is being recorded.
- `Stop at low battery` in the Settings window is a checkbox, on by default,
  with the level next to it, which is dimmed while the check is off. Its
  `Never` level is gone: a `Never` chosen before counts as the check turned
  off, with the level at 5%. The command-line `--min-battery` is unchanged.
- Menu items, buttons and window titles capitalize only the first word and
  names: `Install helper…`, `Stop Awake and quit`, `Restore defaults`, the
  Settings window's title `Awake settings`, and the installer's
  `Awake installation complete` and its other result titles. So do the
  README's section headings, such as `Menu bar app` and `Security notes`.
- `About / Instructions...` in the menu bar menu is now `Help`, and the
  window it opens is titled `Awake help` instead of `About Awake`.
- The Settings window is at most as tall as the screen's space below the
  menu bar and above the Dock; on a shorter screen, such as a 1280×800
  display, its content scrolls.

## [2.2.0] - 2026-09-29

### Upgrade notes

- Run the installer again. It stops a running session and installs helper
  protocol version 9, which asks for your password once. In a manual CLI-only
  install, copy both `bin/awake` and `bin/awake-helper` again; the next
  lid-closed start then updates the helper in the same step, with one
  password prompt.

### Added

- Sessions can end when the Mac is unplugged, so a closed Mac that you carry
  off goes to sleep: `--unplug-guard on`, or `Stop when unplugged` in the
  Settings window. It is off by default and, like `--thermal-guard`, applies
  to new sessions only. Unplugged means that the Mac switches from the power
  adapter to battery or UPS power; the session ends when two checks in a row,
  5 seconds apart, find the Mac unplugged, so 5 to 10 seconds after
  unplugging. A session started on battery power is affected only after the
  Mac has been plugged in during it, and a power source that cannot be read
  never ends a session. A lid-closed session then ends like one on low
  battery or overheating: the sleep settings are restored, `disablesleep` is
  turned off even if it was on before the session, and a Mac with a closed
  lid is put to sleep, unless it is in closed-display mode. The stop
  notification says `the Mac was unplugged`, and the reason is recorded as
  `unplugged` (helper protocol version 9).
- A note under `Stop when too hot` in the Settings window says how long the
  Mac was hot during the last session, and whether Awake ended it, for
  example `Last session: hot for 3 minutes, so Awake ended it.` It is shown
  only after a session in which macOS reported the `serious` or `critical`
  thermal state, or one that Awake ended because the Mac got too hot. Only
  sessions that end while `Awake.app` is running are recorded, and the note
  does not depend on `Stop when too hot`.
- A keyboard shortcut for the menu bar app, off until you record one in the
  new `Keyboard shortcut` group of the Settings window. From any app, a
  press does what a click on the icon does, without the picker: it starts a
  session of the default length, or stops the running one. It never adds
  time to a session started elsewhere since the icon last updated. Its
  `Mode` is its own: lid-open with the display on (the default), lid-open
  with the display allowed to sleep, or lid-closed. A shortcut needs two or
  more modifier keys, one of them Control or Command, and cannot be one
  that macOS uses or a standard one such as `⇧⌘Z`. It needs no
  Accessibility permission.

### Changed

- Notifications and messages name the program, Awake, also for lid-open
  sessions: `Awake started`, `Awake stopped`, `Awake failed` and the other
  notifications no longer begin with `Caffeine`, and messages at the terminal
  speak of a lid-open session, as in
  `The battery is at 4%, too low for a lid-open session.` The README, too,
  calls the two modes lid-closed mode and lid-open mode.
- The menu bar app's `Awake started` notification names the length of a
  session that has one, as `awake`'s own notification does: "The Mac will
  stay awake while the lid remains open for 20 minutes." It said "until the
  chosen session ends".

## [2.1.0] - 2026-09-29

### Upgrade notes

- Run the installer again. It stops a running session and installs helper
  protocol version 8 with the LaunchDaemon for its boot-time restore, which
  asks for your password once. In a manual CLI-only install, copy both
  `bin/awake` and `bin/awake-helper` again; the next lid-closed start then
  updates the helper in the same step, with one password prompt.
- `-w PID` and `-- COMMAND` sessions no longer stop after 9 hours: without a
  time option they run until the process exits. Pass
  `--duration-seconds 32400` to keep the old limit.
- In `--status-json`, `active: true` with `remaining_seconds: null` no longer
  means that sleep settings were left behind; that is now
  `leftover_settings: true`. A session without an end time has `end_mode`
  `none`, and `null` for `remaining_seconds` and `duration_seconds`.
- If two copies of Awake of different versions are on the Mac, such as an
  installed 2.0.0 and a newer copy in `/usr/local/bin`, each replaces the
  other's helper when a lid-closed session starts from it, with a password
  prompt, also in password-free mode. Update or remove the older copy.

### Added

- Sessions that end at a clock time: `--until 18:30` (also `18.30`, `6:30pm`,
  `7am`, `"2026-09-28 07:00"`, or `@EPOCH`), or a clock time typed at the
  terminal prompt.
- Sessions without an end time: `--indefinite`, or `i` at the terminal
  prompt. They run until you stop them or a guardrail ends them.
- Lengths with units: `--duration 2h30m` (also `90m`, `1d`, `45s`,
  `2 hours`), and the same lengths, except seconds, at the terminal prompt.
- While a session runs, a later end time moves its end, and `--indefinite`
  removes it.
- After a crash or power loss during a lid-closed session, a LaunchDaemon
  restores the sleep settings from before the session at the next startup.
- `--status-json` reports `end_mode`, `deadline_at`, `deadline_label`,
  `leftover_settings`, and `disablesleep_forced`.
- The GUI picker lists `Indefinitely`, starts on a double-click, and has
  `Custom…`: `For` a length in hours and minutes, `Until` a clock time, or
  `While` an app or a Terminal command runs. `For` and `Until` open with the
  values chosen last time, and `Back` or `Esc` returns to the list.
- The AppleScript picker, used when the Swift picker cannot run, shows the
  same list and a `Custom…` text field that reads the same answers as the
  terminal prompt. It has no `While`.
- A Settings window (`Settings…` in the menu bar menu, Command-comma) with
  the app's settings in three groups: General, Guardrails, and Session
  lengths. Session lengths edits the picker's list (`+`, `−`,
  `Include Indefinitely`, and `Restore Defaults`) and its default.
- The picker's list and default are stored as `pickerDurations` and
  `pickerDefault` in the menu bar app's preferences, which `defaults write`
  can also set. The terminal prompt's `Enter` uses the same default.

### Changed

- Sessions can last up to 365 days, instead of 9 hours.
- The README names the oldest supported macOS: 12.5 (Monterey). The
  installer builds the app with Swift 5.7, which needs it.
- Sessions tied to a process have no time limit unless a time option gives
  one.
- The default low-battery level is 5% instead of 10%, and the charge is
  checked every 20 seconds once it is at 15% or less, also while the Mac is
  plugged in, so that unplugging the charger is noticed at once.
- When a lid-closed session ends on its own with the lid closed (at its end
  time, on low battery, when the Mac overheats, or when its process exits),
  the helper puts the Mac to sleep. A Mac in closed-display mode is left
  alone, and so is one whose `disablesleep` was on before the session.
- A lid-closed session that ends on low battery or overheating turns
  `disablesleep` off even if it was on before the session, so macOS can put
  the Mac to sleep. `--status` says so afterwards.
- `Caffeine` sessions hold one `caffeinate` assertion for the whole session
  and end by the clock, so time the Mac spends asleep counts.
- Status texts read `Awake is on until 18:30, with 2 hours 5 minutes left`,
  `Awake is on until you stop it`, `Awake is on until make (PID 4242) exits`,
  and, for sleep settings left without a session,
  `Sleep is still turned off, but no Awake session is running`. Remaining
  times of a day or more read in days and hours.
- `Add 1 hour` in the menu bar menu appears only for sessions with an end
  time.
- The settings moved from the menu bar menu to the Settings window. The menu
  keeps the status, `Add 1 hour`, `About / Instructions...`, `Settings…`,
  `Install Helper…` when needed, and `Quit`. `Launch at login` and
  `Start without password` show their real state, so a cancelled password
  prompt leaves `Start without password` as it was.
- The About and Settings windows close with Command-W, and their text can be
  copied and pasted with the usual shortcuts.
- Before it stops a running session, the installer prints
  `Installing stops the running session:` and the session's status, which
  `Install Awake.app` also shows. If the session keeps running, it says so.
- The add-time prompt asks `Add how much time, or until when?` and takes the
  same answers as the start prompt. `Enter`, and the add-time list, start with
  the default length.
- Refusals from the helper say what happened: the end time has passed, or
  the process has already exited.
- `--min-battery`, `--thermal-guard`, and `--keep-display` no longer stop a
  running session like plain `awake` does. They apply to new sessions only:
  alone during a session they are refused with a note, and with a time
  option or `--start` the time is added and `awake` notes that the running
  session keeps its settings. `--keep-display` for a lid-closed session says
  that it is ignored.
- `--status` for `awake -- COMMAND` names the command's own process ID, which
  a kill should go to, instead of the process ID of `awake`, and keeps a
  command name with spaces whole. `--status-json` reports the same in
  `watch_pid` and `watch_command`.
- When another account's lid-closed session is running (with fast user
  switching, for example), `--status` says so and `--status-json` reports
  `other_user_session`. `awake` refuses to start or change a lid-closed
  session before asking for a password, a `Caffeine` session starts next to
  it without ending it, and `awake --stop` ends it only with an
  administrator password (or in password-free mode), saying so first.
- Adding time to a lid-closed session at its battery level or at the
  `critical` thermal state is refused before the password prompt, with the
  reason.
- `awake -- COMMAND | tee log` in a terminal asks for the password in the
  terminal instead of with the GUI dialog.
- Notifications of failures have the title `Awake failed` (or
  `Caffeine failed`) with the reason as their text, instead of the whole
  reason as a title that macOS cuts short.
- With notifications for Awake turned off in System Settings, `awake` posts
  none, instead of posting them with `osascript`.
- The menu bar app's notifications have the same titles as `awake`'s:
  `Caffeine …` for lid-open sessions, and `finished`, `stopped: the battery
  is low`, `stopped: the Mac got too hot`, or `finished: the process it
  waited for exited` by how the session ended.
- When sleep settings left by a lid-closed session make a `Caffeine` start
  ask for the password first, the terminal prompt says so instead of `No
  password is needed`.
- `awake --gui --start` gives the focus back to the app that had it, as the
  start picker does.
- While a prompt waits for an answer (the terminal prompts, the picker, and
  the add-time list), `awake` no longer holds its lock, so `awake --stop` and
  the menu bar work meanwhile instead of failing with `Another awake command
  is already changing the session state.` If a session started, ended, or
  changed in the meantime, the answer is not applied, and `awake` says so.
- Ctrl+C at the terminal's password prompt counts as cancelling it, like the
  password dialog's Cancel button: `Cancelled.` with exit status 0 (1 with
  `-- COMMAND`), instead of `Failed to enable awake mode.` A session that
  the helper had already started by then is ended too.
- The installer asks for the administrator password in the terminal when run
  from one, as the README says; it always used the password dialog.
  `--passwordless` installs the helper and turns on password-free mode with
  one password prompt instead of two.
- The installer checks for the Command Line Tools and Swift 5.7 before
  building, and says what to install.
- The installer quits only the `Awake.app` it replaces, and the one an
  earlier install put elsewhere, instead of every running copy of the app,
  such as a build from the repository.

### Security

- Password-free mode now also lets programs running as you start sessions
  without an end time.
- The helper checks the length of numeric arguments before doing arithmetic
  with them.

### Fixed

- The uninstaller quits only the app it installed, found by its path. Before,
  it asked any app with Awake's bundle identifier to quit, including a copy
  run from elsewhere.
- `Add` with nothing selected in the add-time list reported a failure.
- `awake -- COMMAND` exited with status 0 when the password prompt was
  cancelled, so `awake -- make && deploy` went on to run `deploy`. It now
  exits with status 1.
- `Install Awake.app` and `Uninstall Awake.app` needed macOS 26. They are
  now built for macOS 12.5 and later.
- An `awake` command or a helper process killed at the moment it took or
  released its lock could leave the lock behind. Later commands then failed
  with `Another awake command is already changing the session state` or
  `another helper command is running` until the Mac restarted. Such a lock
  is now taken over after 5 seconds.
- A huge `--duration-seconds` value wrapped around to a small one.
- `--stop` waited 30 seconds when a session ended at the same moment on low
  battery, overheating, or because its process exited.
- A change of time zone could end a session tied to a process.
- Arrow keys cancelled the terminal prompt.
- Ctrl+Z on `awake -- COMMAND` in a terminal also suspended the session's
  timer and guard (or its `caffeinate`), so the session outlived its end time
  and its guardrails stopped. Session processes now run in a process group of
  their own.
- Ctrl+C on `awake -- COMMAND` in a shell loop or script let the loop go on
  with the next command and a new session. `awake` now ends by the same
  signal as the command.
- `awake -- COMMAND` with a command that does not exist started a session,
  asked for the password, and then failed; one of `awake`'s own function
  names ran that function. The command is now checked first (exit status 127
  or 126, as in a shell) and always runs as a program.
- A `Caffeine` session tied to `awake -- COMMAND` recorded `stopped` instead
  of `process_exited` when the command finished.
- `--passwordless off --install-helper` silently ignored `--passwordless off`
  (the last of the maintenance options won). Combining them, or combining
  one with session options, is now refused.
- `--min-battery` with a huge number could wrap around into the allowed
  range, and `--backend ""` started a lid-closed session.
- `--status` and `--status-json` created the runtime folder; they now write
  nothing. `sudo awake --status` looked at root's own (empty) state and said
  `Awake is off` during a `Caffeine` session; it now reports on the user who
  ran `sudo`.
- A runtime folder in `/tmp` created by another account made every `awake`
  command fail with `Internal error: refusing to use a runtime directory
  owned by another user.`, and `--status-json` printed nothing. `awake` now
  says which folder it is and how an administrator can remove it, and
  `--status-json` reports it in `error`.
- Some of the runtime folder's files and folders, such as the `lock` folder,
  the deadline lock's `pid` file, the helper's error output and the dry-run
  files, were not private (`700` and `600`) like the rest of it.
- With `Use custom password dialog` on, clicking the menu bar icon to restore
  sleep settings left without a session failed with `The administrator
  password was incorrect.` without asking. The app now asks with its dialog
  first, as for a start.
- A click on the menu bar icon for a session started elsewhere in the other
  lid mode was refused instead of adding time to it.
- When a `Caffeine` session's worker was killed, `awake --stop` waited 30
  seconds, and a session that then ended on its own left no record of why.
- The terminal prompt dropped characters such as `,` and `/` without a word,
  so `1,5h` started a 15-hour session. They are now kept, and such an answer
  is refused with a hint; a character that is not ASCII, such as `ä`, shows
  as `?` and is refused the same way. Ctrl+\ at the prompt ended `awake` and
  left the terminal without echo, and a closed terminal took the default
  like Enter; both now cancel. A NUL byte is ignored.
- A start could remove the `session` file just written by the next session,
  when the previous session's notifier finished at the same moment, and then
  fail with `chmod: cannot access`; that session also got no notifications.
- `awake` run through a symlink, such as `/usr/local/bin/awake` pointing to
  the `awake` folder, did not find `awake-helper` next to the real file, so
  `--install-helper` and lid-closed starts failed.
- A reinstall rewrote the installer's record without the `PATH` line that the
  first install added, so the uninstaller left the line behind.
- For Bash, the installer created `~/.bash_profile` even when `~/.profile` or
  `~/.bash_login` existed, which then stopped being read at login. It now
  adds the line to the file that Bash reads, and the uninstaller removes a
  file that the installer created once it is empty again (never a symlink).
  An update removes a `~/.bash_profile` that an earlier version created this
  way, if it holds nothing but Awake's line, and adds the line to the file
  that Bash reads instead.
- A cancelled helper install during the installer was reported as done, and
  `--passwordless` asked for the password a second time.
- The installer stopped halfway when `~/bin` or `~/.local/bin` was not
  writable; it now skips such a folder, and adds a `PATH` line only after the
  wrapper is in place.
- `--app-destination` accepted any folder, which the installer deleted, as
  did the uninstaller later. Only a path ending in `.app` is accepted, and
  only an `Awake.app` is replaced or removed there.
- Running `awake` by a relative path, such as `bin/awake` in the `awake`
  folder, let a second `awake` take its lock while it was busy, because the
  lock holder was recognised by its command line. Two sessions could then
  start at once, and `--status` showed only one of them. The holder is now
  recognised by its process ID and start time.
- Two commands that found the same lock left by a killed `awake` could both
  take it over and start two sessions; the helper's lock had the same race.
  They now take turns and check again.
- A command run when nothing was running, or any start, deleted the record
  of the last `Caffeine` session. Its stop or finish notification was then
  lost when the next command came within a second, such as `awake --stop &&
  awake --backend awake`, and `--status-json` reported an older session. The
  record now stays until the next `Caffeine` session ends.
- Session processes woke up to start other programs several times a second:
  reading their records with `awk`, `/bin/kill`, `ps` every 2 seconds for a
  session tied to a process, and five programs for each helper heartbeat.
  They now use shell builtins for these, and `ps` only every 10 seconds.
- `awake -- COMMAND` in `Caffeine` mode waited 30 seconds after the command
  ended when the session's worker had been killed, and then said it could
  not stop the session. It now ends such a session at once.
- A `Caffeine` session stopped after its worker was killed could be recorded
  and announced as finished (`timeout`) instead of stopped.
- The uninstaller needed `python3`, which is missing without the Command Line
  Tools, and stopped with most of Awake still installed. It also stopped at a
  damaged `install-info.sh`, and asked `sudo` for a read-only wrapper file.
  It now works without `python3`, reads the record without running it in its
  own shell, removes only files that are Awake's, and without a record looks
  in the default places.

## [2.0.0] - 2026-09-26

### Upgrade notes

- Run the installer again. It installs Awake's new privileged helper, which
  asks for your administrator password once, and restarts the menu bar app.
- Lid-closed mode now needs that helper. Without the installer, run
  `awake --install-helper`, or just start a lid-closed session: Awake then
  installs the helper in the same step, with one password prompt.
- Run `awake` as yourself. It no longer runs with `sudo`; it asks for the
  password itself when it needs one.
- `--duration-seconds` and `--backend` no longer stop a running session. Use
  `awake --stop`, or plain `awake`, to stop one.

### Security

- Lid-closed sessions run in a small root-owned helper at
  `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`. Before, the
  `awake` script ran itself as root from a folder your account can change, so
  any program running as you could get root rights the next time a lid-closed
  session started. Now only the helper runs as root. It accepts a few
  commands with numeric arguments and restores the sleep settings when a
  session ends.
- `awake` checks that the helper and its folder are owned by `root` and not
  writable by anyone else before running it with administrator rights.
- Stopping a running session never needs a password: `awake` asks the helper
  to stop through a file in your own runtime folder.
- `awake` refuses to run as `root`, except for `--status` and
  `--status-json`.

### Added

- Password-free mode (optional, off by default): `awake --passwordless on|off`,
  `Start without password` in the menu bar menu, and
  `install-awake.sh --passwordless`. It adds a sudoers rule, checked with
  `visudo`, that lets your account run the helper, and nothing else, without a
  password.
- `--install-helper` and `--uninstall-helper`, plus an `Install Helper…` menu
  item that appears when the helper is missing or out of date.
- `--start`: start a session, or add time to the one that is running.
- Lid-closed sessions end when the Mac runs on battery power and the charge
  drops to 10%, and do not start at that level.
- Lid-closed sessions end when the Mac overheats: at once in the `critical`
  macOS thermal state, and in the `serious` state on two checks in a row
  while the lid is closed. They do not start, and cannot be extended, at
  `critical`. The stop notification says `the Mac got too hot`, and the
  helper records the reason as `overheated` (helper protocol version 5).
- `--min-battery N|off` (5-50%, default 10%) and `--thermal-guard on|off`
  choose these guardrails per session, and the menu bar menu has
  `Stop when too hot` and `Stop at low battery` (Never, 5%, 10%, 15%, 20%,
  25%, 30%). The helper's `start` command takes the two settings (helper
  protocol version 6).
- `Caffeine` sessions get the same guardrails: they do not start, and end
  early, when the battery runs low or the Mac overheats.
- Sessions tied to a process. `awake -- COMMAND [ARGS...]` runs the
  command and keeps the Mac awake while it runs, then ends the session and
  exits with the command's status. `awake -w PID` keeps it awake until an
  already running process of yours exits. Both work in both modes, run for
  at most 9 hours (or `--duration-seconds`), refuse while another session
  runs, and end with the reason `process_exited`, also when `awake` itself
  is killed. The helper's `start` command takes the process to watch and
  tells it apart from a later process that reuses its ID (helper protocol
  version 7). `--status`, `--status-json` (`watch_pid`, `watch_command`),
  and the menu bar status name the process.
- The menu bar tooltip and the first line of the Ctrl-click menu show the
  status: `Awake is off`, `Awake is on and has 25 minutes left`, or
  `Awake has been off for 2 hours`.
- A Finder icon for `Awake.app` and the Install and Uninstall launchers.
- The GUI picker starts with the lid mode you chose last time.
- Notifications when a session ends because the battery ran low or the Mac
  got too hot, when you
  click to start but Awake is already on, and, once, when sleep is still
  turned off but no session is running.
- Security Notes explain that the password prompt is prepared by the
  user-owned copy of Awake, and what that means.
- Continuous integration on macOS that builds the app, checks the icons, and
  runs the self-test with macOS's own `/bin/bash`.
- This changelog, and README instructions for downloading Awake with
  `git clone` and updating it with `git pull`.

- Adding time to a running session: `--duration-seconds N` while a session
  runs adds N seconds, `--start` asks how much to add, and the menu bar menu
  has `Add 1 hour` while a session runs. A session never runs more than 9
  hours from now. The helper gains an `extend` command (protocol version 4).
- Notifications from the `awake` command are posted through `Awake.app`
  when it is installed, so they show the Awake icon instead of the Script
  Editor icon.

### Changed

- `Caffeine` sessions keep the display on (`caffeinate -di`), so a
  presentation or video call no longer goes dark. `--keep-display off`, or
  unchecking `Keep the display on` in the picker, lets the display sleep as
  before. In the picker the display checkbox is greyed out while the lid
  checkbox is checked, and hovering over a checkbox explains it; and
  `--status`, `--status-json` (`keep_display`), and the menu bar status say
  when the display may sleep.
- **Breaking:** `--start`, `--duration-seconds`, and `--backend` always mean
  "start". If a session is already running, they add time to it instead of
  stopping it. Plain `awake` still toggles.
- **Breaking:** lid-closed mode needs the privileged helper (see Upgrade
  notes).
- The menu bar icon turns black on light menu bars and white on dark ones,
  like other menu bar icons, and the bold "on" glyph is redrawn.
- A click on the menu bar icon does what the icon shows. It passes `--start`
  or `--stop` to the CLI, so a session started elsewhere in the meantime is
  never stopped by accident.
- The Quit menu item reads `Stop Awake and Quit` while a session runs.
- `Use custom password dialog` is dimmed while password-free mode is on.
- The menu bar app runs commands in the background, so its menu stays
  available while a start or stop is in progress.
- The installer stops a running session, quits a running menu bar app before
  replacing it, and starts the new version afterwards.
- A lid-closed start replaces sleep settings left behind by a crashed
  session. A Caffeine start restores them first.
- The terminal prompt describes Caffeine correctly when you start it with
  `--backend caffeinate`, and Caffeine starts are confirmed in the terminal.
- Start failures are also posted as notifications when `awake` runs without
  a visible terminal. When there is no terminal to ask for a password or a
  duration in, `awake` explains what to do instead.
- `--uninstall-helper` restores normal sleep first if a lid-closed session is
  still running.
- `--status` uses the same sentences as the menu bar app, and explains how to
  recover when sleep is turned off without a running session.
- `awake --help` fits in 80 columns.
- Background processes wake up less often during a session.
- The uninstaller also removes the menu bar app's preferences.
- The README explains that `disablesleep` is system-wide, so a lid-closed
  session keeps the Mac awake on AC power too, and adds Security Notes.

### Fixed

- `awake` read the system-wide `disablesleep` setting wrongly and always saw
  it as off. As a result, recovery after a crashed session could skip
  restoring the sleep settings, and stuck settings were never detected.
- The state-change lock could be left behind after the terminal prompt.
- The custom password dialog gave no message when the password was wrong. It
  now says so and asks again, up to three times.
- A start command after a crashed session only cleaned up and did not start
  a new session.
- The menu bar app could stop a session when you clicked to start one, if the
  session had started since the last status check.
- Quit reported `Quit cancelled` when the session had already ended on its
  own.
- The menu bar app and the CLI could both announce the same session; the
  stop sound now also plays when a session times out.
- Text in the About window was unreadable in dark mode, the picker icon was
  invisible on light backgrounds, and a picker cell could get the wrong width.
- The installer could mistake part of a `PATH` entry for a whole one.
- A README example called a lid-closed session "lid-open".
- After a restart during a lid-closed session, `awake --stop` restored the
  default sleep settings instead of the ones from before the session, because
  the helper kept them only under `/var/run`, which macOS empties at startup.
  The helper now also keeps them in `/var/db/net.kaenmaki.awake/` until they
  are restored (helper version 3; the installer or the next lid-closed start
  updates the helper).
- `awake --passwordless on` reported success even when another sudoers rule
  for the account overrode Awake's rule, because its check reused the sudo
  ticket from the password prompt. It now checks the rule itself.
- The installer did not record the `PATH` line it added, so the uninstaller
  left it behind and the "open a new Terminal window" hint never appeared. An
  existing `~/bin` that was not on `PATH` got the wrapper without a `PATH`
  line, so `awake` was not found.
- Running `bin/awake` from a checkout on a Mac without the Command Line Tools
  showed an offer to install them and failed, instead of using the AppleScript
  duration picker.
- Without a terminal to ask for a password in, `awake` printed
  `Starting awake for …` before saying so. It now stops before announcing.
- `awake` printed `Starting awake for …` before refusing a start on a low
  battery or unreadable `pmset` settings. It now announces a start only once
  those checks pass.

## [1.0.0] - 2026-05-02

- First versioned release: lid-closed `Awake` and lid-open `Caffeine`
  sessions from the terminal, a GUI picker, and the menu bar app.

[Unreleased]: https://github.com/anttikaenmaki/awake/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/anttikaenmaki/awake/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/anttikaenmaki/awake/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/anttikaenmaki/awake/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/anttikaenmaki/awake/releases/tag/v1.0.0
