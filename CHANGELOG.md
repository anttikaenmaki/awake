# Changelog

All notable changes to Awake are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version numbers
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html): a major
version for changes that can break existing use, a minor version for new
features, and a patch version for fixes.

## [2.0.0] - Unreleased

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
  25%). The helper's `start` command takes the two settings (helper
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
  The helper now also keeps them in `/var/db/net.kaenmaki.awake/` until they
  are restored (helper version 3; the installer or the next lid-closed start
  updates the helper).
- Without a terminal to ask for a password in, `awake` printed
  `Starting awake for …` before saying so. It now stops before announcing.
- `awake` printed `Starting awake for …` before refusing a start on a low
  battery or unreadable `pmset` settings. It now announces a start only once
  those checks pass.

## [1.0.0] - 2026-05-02

- First versioned release: lid-closed `Awake` and lid-open `Caffeine`
  sessions from the terminal, a GUI picker, and the menu bar app.
