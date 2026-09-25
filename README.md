# awake

`awake` is a macOS shell script with a companion menu bar app that keeps a MacBook awake for a chosen duration. It offers two modes:

- `Awake` (lid-closed): temporarily relaxes the battery sleep settings so the Mac can stay awake even with the lid closed, then attempts to restore the previous settings automatically.
- `Caffeine` (lid-open): runs the built-in `caffeinate` without administrator privileges to prevent idle sleep while the lid stays open.

macOS's built-in `caffeinate` prevents idle sleep but does not override sleep when the lid is closed. `awake` keeps both cases available behind a single GUI: pick `Awake` for lid-closed sessions and `Caffeine` for simpler lid-open sessions.

There are two equivalent user-facing entry points:

- the `Awake.app` menu bar app, and
- the `awake` command-line tool, which can either show a terminal duration prompt or open the same GUI dialog as the app via `--gui` / `--gui-custom`.

The two interfaces are technically distinct programs, but from a user point of view they behave the same: they share the same managed CLI, the same GUI picker, the same session state, and the same start/stop semantics. A session started from one can be inspected or stopped from the other.

A dry-run mode is available for testing. Running `awake` a second time while a session is active stops it immediately and restores normal sleep mode.

Current version: `1.0.0`.

Example use cases:

- Let a large download, sync, or backup finish during a short lid-closed period.
- Keep a local development server or SSH session alive while the lid is closed for a fixed time window.
- Finish a video export, build, or test run without leaving the MacBook open on the desk.
- Use `Caffeine` from the menu bar to prevent idle sleep during a long talk, presentation, or video call without touching `pmset`.

## What It Does

Depending on which mode you pick, `awake` does one of the following:

- `Awake` (lid-closed): applies battery-only `pmset` changes so the Mac can remain awake with the lid closed. In effect, it toggles between `sudo pmset -b sleep 0; sudo pmset -b disablesleep 1` and the normal fallback pair `sudo pmset -b sleep 5; sudo pmset -b disablesleep 0`. This requires administrator privileges.
- `Caffeine` (lid-open): starts a `caffeinate -i -t <duration>` session in the background. This prevents idle sleep without changing `pmset` and does not require administrator privileges, but it does require the lid to stay open.

In both modes, `awake`:

- lets you choose a duration from the terminal or a GUI dialog,
- starts the chosen session in the background,
- tracks the session in shared per-user state files so any other entry point (terminal or menu bar) sees and can manage it,
- posts macOS Notification Center messages on start, stop, and failure (`Awake started`, `Awake stopped`, `Awake failed`); with `--sound`, also plays the system alert sound on start and stop.

In `Awake` mode, `awake` additionally:

- uses the native macOS administrator prompt for GUI authentication by default,
- optionally supports a custom GUI password dialog via `--gui-custom`, which authenticates once at the start of a session and then keeps later managed stops password-free,
- saves the previous battery sleep settings and tries to restore them automatically when the timer ends or when you stop the session early,
- runs a background failsafe process that re-checks the settings shortly after the deadline and restores them as a backup if the main worker has been interrupted,
- falls back to safe defaults if awake-like sleep settings are still active without a saved session, recovering from a stuck state.

The script ships with a native macOS menu bar app (`Awake.app`) for users who prefer click-to-toggle access and persistent settings from the menu bar.

## Safety Warnings

The following warnings apply to `Awake` (lid-closed) mode. `Caffeine` mode keeps the lid open and does not change sleep settings, so it does not trigger these specific risks.

- Keeping a MacBook awake with the lid closed can cause significant heat buildup, higher battery drain, and unexpected shutdown if the battery runs low.
- Use it only on a hard, flat, well-ventilated surface.
- Never use it in a bag, bed, sofa, or on your lap.
- Settings apply to battery power only; on AC power the Mac uses its AC `pmset` settings, so the awake toggle has no effect until you unplug.
- `awake` attempts to restore the previous battery sleep settings automatically. A background failsafe process re-checks them shortly after the deadline and restores them as a backup if the main worker has been interrupted; if the saved values cannot be read, it falls back to safe defaults (`pmset -b sleep 5; pmset -b disablesleep 0`). Restoration can still fail in pathological cases (for example, if the failsafe process is also killed).
- Use at your own risk.
- This script is provided as-is, without warranty, and the author accepts no liability for overheating, data loss, battery drain, hardware damage, or other loss or damage arising from its use.

## Requirements

- macOS
- Bash
- `caffeinate` (used by `Caffeine` mode and required for it)
- `pmset` (used by `Awake` mode and required for it)
- `osascript` for GUI mode and notifications
- `afplay` for `--sound` (part of macOS)
- Administrator privileges to change and restore `pmset` settings when using `Awake` mode. `Caffeine` mode does not need administrator privileges.

## Installation

### User-friendly install from the repository

The easiest supported installation flow is to run the installer that ships in the repository. It builds and installs all user-facing pieces in user-writable locations:

- `Awake.app` is built from the repository sources and installed to `~/Applications/Awake.app`.
- The managed CLI is installed to `~/Library/Application Support/Awake/bin/awake`.
- A small wrapper command named `awake` is installed so that your shell can run the managed CLI from a normal `PATH` location.

The wrapper path is chosen as follows:

- If your login-shell `PATH` already contains `~/bin`, the installer places the wrapper at `~/bin/awake`.
- Otherwise, if your login-shell `PATH` already contains `~/.local/bin`, the installer places the wrapper at `~/.local/bin/awake`.
- Otherwise, if `~/bin` already exists and is writable, the installer uses `~/bin/awake`.
- Otherwise, the installer uses `~/.local/bin/awake`.

If the installer has to use `~/.local/bin` and that directory is not yet on your login-shell `PATH`, it appends

```bash
export PATH="$HOME/.local/bin:$PATH"
```

to `~/.zprofile` for Zsh or `~/.bash_profile` for Bash. In that case, open a new Terminal window after the install so the wrapper becomes visible on `PATH`. The installer also records the installed paths in `~/Library/Application Support/Awake/install-info.sh` so that `uninstall-awake.sh` can later remove the same app, managed CLI, wrapper, and any PATH line that the installer added.

The project root contains the user-facing install and uninstall entry points:

- `Install Awake.app` and `Uninstall Awake.app` for Finder
- `install-awake.sh` and `uninstall-awake.sh` for Terminal

From Finder, double-click `Install Awake.app`.

From Terminal, you can also run:

```bash
bash install-awake.sh
```

The installer launches `Awake.app` once at the end so the menu bar item becomes available immediately.

To remove the installed app and wrapper later from Finder, double-click `Uninstall Awake.app`.

From Terminal, you can also run:

```bash
bash uninstall-awake.sh
```

### Manual CLI-only install

If you only want the shell command and do not want the menu bar app, place `bin/awake` somewhere on your `PATH` and make it executable yourself. For example, into a user-writable directory on `PATH`:

```bash
mkdir -p "$HOME/.local/bin"
cp bin/awake "$HOME/.local/bin/awake"
chmod +x "$HOME/.local/bin/awake"
```

Or, into the system-wide `/usr/local/bin` (requires administrator privileges):

```bash
sudo cp bin/awake /usr/local/bin/awake
sudo chmod +x /usr/local/bin/awake
```

Note that the GUI duration picker uses a small Swift helper called `awake-gui-picker` that lives next to the managed CLI in the user-friendly install. In a manual CLI-only install, GUI mode falls back to a pure-AppleScript picker that is functionally equivalent for everyday use.

## Menu Bar App

`Awake.app` is a small native macOS menu bar app that wraps the same managed `awake` command described above. From the user's perspective, it offers the same modes, the same picker, the same notifications, and the same stop semantics as the terminal CLI in GUI mode.

- A click on the menu bar icon starts or stops the current session. When starting, it opens the same native GUI picker that `awake --gui` and `awake --gui-custom` use, so the same `Keep laptop awake with lid closed` checkbox decides between `Awake` and `Caffeine`.
- The icon shows the current state: a regular `A` when Awake is off and a bold `A` while a session runs. Like the other menu bar icons, it turns black on a light menu bar and white on a dark one.
- Hovering over the icon, and the first line of the Ctrl-click menu, show the current status: `Awake is off`, `Awake is on and has 25 minutes left`, or `Awake has been off for 2 hours` (in minutes, hours, days, weeks, months, or years). `Caffeine` sessions add `(keep the lid open)`. While a start or stop is in progress, the line reads `Starting Awake…` or `Stopping Awake…`.
- A Ctrl-click opens a settings and help menu with:
  - `About / Instructions...`: opens a rendered, human-readable copy of this `README.md` inside the app.
  - `Launch at login`: toggles whether `Awake.app` starts automatically when you log in.
  - `Use custom password dialog`: switches GUI authentication for `Awake` mode between the native macOS administrator prompt and `awake`'s own custom password dialog. `Caffeine` mode never asks for a password regardless of this setting.
  - `Sound on`: toggles whether start and stop notifications also play a system alert sound.
  - `Quit`: quits the app. If a session is active, the app first runs the normal Awake stop flow and only quits after that stop succeeds.

A session started from the menu bar app can be inspected with `awake --status`, stopped with `awake --stop`, and vice versa: a session started from the terminal can be stopped by clicking the menu bar icon.

## Usage

```bash
awake [options]
```

Running `awake` with no options opens the terminal picker when both standard input and standard output are connected to a TTY, and the GUI picker when at least one of them is not.

Running `awake` again while a session is active stops it and restores normal sleep mode.

### Choosing a backend

In GUI mode, the picker has a checkbox `Keep laptop awake with lid closed`:

- If checked, `awake` uses the lid-closed `Awake` backend and may ask for an administrator password.
- If unchecked, `awake` uses the lid-open `Caffeine` backend and never asks for a password.

In terminal mode, only the `Awake` backend is offered through the interactive prompt, since users who only need lid-open behavior can simply run `caffeinate` directly. The `--backend caffeinate` flag still works from the command line if you want a managed `Caffeine` session with the same status tracking and notifications as the GUI offers, for example:

```bash
awake --backend caffeinate --duration-seconds 1800
```

### GUI authentication

In GUI mode, `awake` uses macOS's standard administrator authentication dialog by default when elevated access is needed for `Awake`. Pass `--gui-custom` (which implies `--gui`) to switch to `awake`'s own hidden-input password dialog instead.

With `--gui-custom`, `awake` authenticates once when the lid-closed session starts and then relies on the managed privileged session processes to stop and restore settings later without asking for the password again. The same managed stop path is now preferred for all active lid-closed sessions, regardless of how they were started, so the password-reduction benefit also applies when you switch interfaces between the start and the stop. In particular:

- starting from `awake --gui-custom` in the terminal and stopping from `awake` (terminal), `awake --gui`, `awake --gui-custom`, the menu bar icon, or the menu bar app's `Quit` action does not need a second password,
- and starting from the menu bar app with `Use custom password dialog` enabled and stopping from any of the above interfaces likewise reuses the managed stop and does not re-prompt.

Long-running custom-GUI sessions therefore do not depend on the normal `sudo` timestamp lifetime.

`awake --gui` is the more conservative choice because password entry stays inside macOS's native authentication UI. `--gui-custom` can be convenient for personal use, but it asks you to trust `awake` itself with the password briefly in memory before it is handed to `sudo`. The password is read into a shell variable by the CLI prompt, or supplied once over standard input by the menu bar app, and is then piped to `sudo -S -v` only for the initial privileged start. It is never written to disk, exported as an environment variable, or stored in the state files. The askpass helper at `$STATE_DIR/askpass` contains only the dialog code and is created with mode `700`.

If the managed privileged helpers for a session have already disappeared and only the saved state remains, terminal stops and `awake --gui` stops fall back to a fresh administrator prompt, while `--gui-custom` stops fail with a clear error rather than showing a second password prompt.

`Caffeine` mode does not use `sudo` at all, so none of this applies to it: it can always be started and stopped without a password.

### Concurrency and stop semantics

`awake` serializes state-changing invocations with a `mkdir`-based lock under `$STATE_DIR/lock`. If another `awake` is in the middle of a state change, the second one exits with `Another awake command is already changing the session state. Please try again.`. `--status` and `--status-json` skip the lock and are read-only, so they are safe to run alongside an active session.

`--stop` is idempotent: if no session is active, terminal mode prints `Awake mode is not active.` and GUI mode shows an `Awake is off` notification.

### Debug logging

By default, `awake` writes no debug log. Pass `--debug` (or set `AWAKE_DEBUG=true` in the environment) to enable detailed logging to the per-user temporary runtime directory, for example `/tmp/keep-awake-lid-closed-$UID/awake-debug.log` or `/tmp/keep-awake-lid-closed-dry-run-$UID/awake-debug.log`. The `--debug` flag is propagated to the privileged background worker via `AWAKE_DEBUG` so that all phases of a session log to the same file.

## Options

- `-h`, `--help`: show help and exit.
- `-v`, `--version`: show the version and exit.
- `-g`, `--gui`: force GUI mode even when run from a terminal.
- `--gui-custom`: imply `--gui` and use the custom GUI password dialog instead of the native macOS administrator prompt. Has no effect on `Caffeine` mode, which never asks for a password.
- `--backend awake|caffeinate`: explicitly select the backend. `awake` is the default in terminal mode and the default for the GUI checkbox. `caffeinate` prevents idle sleep only and does not keep the Mac awake with the lid closed.
- `-t`, `--terminal`: force terminal mode; requires an interactive terminal unless combined with `--duration-seconds`, `--stop`, or `--status`.
- `--duration-seconds N`: use an exact duration in seconds (1 to 32400, that is, up to 9 hours).
- `-s`, `--stop`: stop the active session and restore normal sleep mode if needed, then exit; safe to run when no session is active.
- `--status`: show whether a session is active and the time remaining; lock-free and read-only.
- `--status-json`: show the same status as machine-readable JSON for app integration; lock-free and read-only.
- `--sound`: play a system alert sound with start and stop notifications.
- `--no-notifications`: suppress Awake's own GUI notifications.
- `--dry-run`: simulate awake mode without changing real sleep settings.
- `--debug`: enable detailed debug logging to the per-user temporary runtime directory.

## Terminal Input

At the terminal prompt:

- Press `Enter` for the default duration of 20 minutes.
- Type one digit (`1`-`9`) for hours.
- Type two digits (`01`-`99`) for minutes.
- Press `Esc`, `q`, or `Ctrl+C` to cancel.

The terminal prompt only asks for the duration. By default, terminal sessions use the lid-closed `Awake` backend, since lid-open use is already covered by the standalone `caffeinate` command. To run the lid-open `Caffeine` backend with the same managed lifecycle as the GUI offers, pass `--backend caffeinate` together with `--duration-seconds`.

## GUI Input

The same native GUI picker is used in all GUI entry points: `awake --gui`, `awake --gui-custom`, and the menu bar icon's left-click action (which uses `awake --gui` or `awake --gui-custom` under the hood depending on the `Use custom password dialog` setting). It shows the fixed duration list together with the `Keep laptop awake with lid closed` checkbox in the same window:

- `10 minutes`, `20 minutes` (default), `30 minutes`, `40 minutes`, `50 minutes`
- `1 hour`, `2 hours`, `3 hours`, `4 hours`, `6 hours`, `8 hours`

- The checkbox is checked by default.
- If checked, the Mac stays awake with the lid closed (`Awake` mode) and authentication may be required.
- If unchecked, `awake` uses `caffeinate` (`Caffeine` mode), so the lid must stay open and no password is required.

The managed CLI uses a native Swift/AppKit picker helper for this window when it is installed, and falls back to a pure-AppleScript picker that asks the same question if the helper binary is missing.

## Examples

Start with the normal interactive picker (terminal duration prompt in a TTY, otherwise the GUI picker):

```bash
awake
```

Force GUI mode and pick the backend in the dialog:

```bash
awake --gui
```

Force GUI mode and start a lid-open `Awake` session without seeing the picker (skip the duration step):

```bash
awake --gui --backend awake --duration-seconds 3600
```

Force GUI mode with the custom GUI password dialog and sound notifications:

```bash
awake --gui-custom --sound
```

Force terminal mode (lid-closed `Awake`, with an interactive duration prompt):

```bash
awake --terminal
```

Start a managed `Caffeine` session from the terminal (no password prompt, lid must stay open):

```bash
awake --backend caffeinate --duration-seconds 1800
```

Start the default `Awake` mode for exactly 20 minutes:

```bash
awake --duration-seconds 1200
```

Check whether a session is active:

```bash
awake --status
```

Check the app-facing JSON status:

```bash
awake --status-json
```

Show the version:

```bash
awake --version
```

Enable debug logging for troubleshooting:

```bash
awake --debug --duration-seconds 1200
```

Stop an active session:

```bash
awake --stop
```

Test the flow without changing real sleep settings:

```bash
awake --dry-run --duration-seconds 120
```

## Runtime Files

`awake` stores per-user state under temporary runtime directories. All directories are mode `700` and all files mode `600`.

- `/tmp/keep-awake-lid-closed-$UID/`: per-user runtime directory
  - `state`: serialized session state (worker and guard process IDs, original `pmset` values, deadline, session token, selected backend)
  - `status`: written when a session ends; carries the completion `reason` (`timeout`, `stopped`, `cancelled`, or `failed`)
  - `session`: lightweight session metadata used to compute remaining time
  - `askpass`: shell helper that displays the custom GUI password dialog (only used by `--gui-custom`)
  - `lock/`: mutex preventing concurrent state changes
  - `awake-debug.log`: created only when `--debug` is set or `AWAKE_DEBUG=true` is exported
- `/tmp/keep-awake-lid-closed-control-$UID/state`: companion control-state file owned by the privileged worker. Used to coordinate password-free stops across the menu bar app, `awake --gui`, `awake --gui-custom`, and terminal invocations.

The dry-run mode uses the same paths with `-dry-run` inserted into the basename, for example `/tmp/keep-awake-lid-closed-dry-run-$UID/`.

## Dry-Run and Self-Test

`--dry-run` uses a separate temporary runtime directory and does not change real `pmset` settings.

Run the self-test from the repository directory with:

```bash
bash tests/cli/awake-self-test
```

The self-test runs only against `awake --dry-run`, so it does not touch real `pmset` settings. It exercises the main lifecycle paths by:

- starting and stopping dry-run sessions through the terminal and GUI entry points, for both `Awake` and `Caffeine` backends,
- waiting for timed sessions to finish automatically,
- confirming that `--status` and `--status-json` stay read-only when completion metadata is pending,
- verifying notification-suppression behavior for the menu bar app integration,
- verifying that stale state does not terminate an unrelated process,
- and running additional sourced regression checks for helper matching, prompt behavior, CLI parsing, and failure handling.

It exits immediately on the first failure, and on success it ends with `All dry-run lifecycle and regression checks passed.`.

## License

This project is licensed under the GNU Affero General Public License version 3.

See `LICENSE` for the full license text.

## Author

Copyright (C) 2026 Antti Käenmäki, <antti@kaenmaki.net>.
