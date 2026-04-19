# awake

`awake` is a macOS shell script that temporarily relaxes the battery sleep settings so a MacBook can stay awake with the lid closed for a chosen duration, then attempts to restore the previous settings automatically.

macOS's built-in `caffeinate` prevents idle sleep but does not override sleep when the lid is closed. `awake` is for exactly that case: it toggles the battery `sleep` and `disablesleep` settings for a bounded duration and then tries to put them back.

Both terminal and GUI prompts are supported, along with a dry-run mode for testing. Running `awake` a second time while awake mode is active restores normal sleep mode.

Current version: `1.0.0`.

Example use cases:

- Let a large download, sync, or backup finish during a short lid-closed period.
- Keep a local development server or SSH session alive while the lid is closed for a fixed time window.
- Finish a video export, build, or test run without leaving the MacBook open on the desk.

## What It Does

- Applies battery-only `pmset` changes so the Mac can remain awake with the lid closed. In effect, it toggles between `sudo pmset -b sleep 0; sudo pmset -b disablesleep 1` and the normal fallback pair `sudo pmset -b sleep 5; sudo pmset -b disablesleep 0`.
- Lets you choose a duration from the terminal or a GUI dialog.
- Starts the privileged session in the background.
- Uses the native macOS administrator prompt for GUI authentication.
- Optionally supports a custom GUI password dialog via `--gui-custom`, which can reduce repeated password prompts.
- Saves the previous battery sleep settings and tries to restore them automatically when the timer ends or when you stop the session early.
- Runs a background failsafe process that re-checks the settings shortly after the deadline and restores them as a backup if the main worker has been interrupted.
- Falls back to safe defaults if awake-like sleep settings are still active without a saved session, recovering from a stuck state.
- Posts macOS Notification Center messages on start, stop, and failure (`Awake started`, `Awake stopped`, `Awake failed`); with `--sound`, also plays the system alert sound on start and stop.
- Ships with a native macOS menu bar app for users who prefer click-to-toggle access and settings from the menu bar.

## Safety Warnings

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
- `pmset`
- `osascript` for GUI mode and notifications
- `afplay` for `--sound` (part of macOS)
- Administrator privileges to change and restore `pmset` settings

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

## Menu Bar App

`Awake.app` is a small native macOS menu bar app that wraps the same `awake` command described above.

- A left click on the menu bar icon toggles Awake on or off.
- The icon changes between asleep and awake states to reflect the current session.
- A right click or Ctrl-click opens a settings and help menu with:
  - `About / Instructions...`: opens a rendered, human-readable copy of this `README.md` inside the app.
  - `Launch at login`: toggles whether `Awake.app` starts automatically when you log in.
  - `Use custom password dialog`: switches GUI authentication between the native macOS administrator prompt and `awake`'s own custom password dialog.
  - `Sound on`: toggles whether start and stop notifications also play a system alert sound.
  - `Quit`: quits the app. If a session is active, the app first runs the normal Awake stop flow and only quits after that stop succeeds.

## Usage

```bash
awake [options]
```

Running `awake` with no options opens the terminal picker when both standard input and standard output are connected to a TTY, and the GUI picker when at least one of them is not.

Running `awake` again while a session is active restores normal sleep mode.

### GUI authentication

In GUI mode, `awake` uses macOS's standard administrator authentication dialog by default when elevated access is needed. Pass `--gui-custom` (which implies `--gui`) to switch to `awake`'s own hidden-input password dialog instead. `awake` then passes that password to `sudo` to refresh the normal `sudo` timestamp, which can reduce repeated prompts during a session. In the menu bar app, an active session started with the custom dialog can normally be stopped without asking for that password again.

`awake --gui` is the more conservative choice because password entry stays inside macOS's native authentication UI. `--gui-custom` can be convenient for personal use, but it asks you to trust `awake` itself with the password briefly in memory before it is handed to `sudo`. The password is read into a shell variable, piped to `sudo -S -v` to refresh the normal `sudo` timestamp, and is never written to disk or exported as an environment variable. The askpass helper at `$STATE_DIR/askpass` contains only the dialog code and is created with mode `700`. The script does not store the password in its state files, but the custom dialog still has a broader trust surface than the native prompt.

### Concurrency and stop semantics

`awake` serializes state-changing invocations with a `mkdir`-based lock under `$STATE_DIR/lock`. If another `awake` is in the middle of a state change, the second one exits with `Another awake command is already changing the session state. Please try again.`. `--status` and `--status-json` skip the lock and are read-only, so they are safe to run alongside an active session.

`--stop` is idempotent: if no session is active, terminal mode prints `Awake mode is not active.` and GUI mode shows an `Awake is off` notification.

### Debug logging

By default, `awake` writes no debug log. Pass `--debug` (or set `AWAKE_DEBUG=true` in the environment) to enable detailed logging to the per-user temporary runtime directory, for example `/tmp/keep-awake-lid-closed-$UID/awake-debug.log` or `/tmp/keep-awake-lid-closed-dry-run-$UID/awake-debug.log`. The `--debug` flag is propagated to the privileged background worker via `AWAKE_DEBUG` so that all phases of a session log to the same file.

## Options

- `-h`, `--help`: show help and exit.
- `-v`, `--version`: show the version and exit.
- `-g`, `--gui`: force GUI mode even when run from a terminal.
- `--gui-custom`: imply `--gui` and use the custom GUI password dialog instead of the native macOS administrator prompt.
- `-t`, `--terminal`: force terminal mode; requires an interactive terminal unless combined with `--duration-seconds`, `--stop`, or `--status`.
- `--duration-seconds N`: use an exact duration in seconds (1 to 32400, that is, up to 9 hours).
- `-s`, `--stop`: restore normal sleep mode if awake mode is active, then exit; safe to run when no session is active.
- `--status`: show whether awake mode is on and the time remaining; lock-free and read-only.
- `--status-json`: show the same status as machine-readable JSON for app integration; lock-free and read-only.
- `--sound`: play a system alert sound with start and stop notifications.
- `--no-notifications`: suppress Awake's own GUI notifications. This does not disable `--sound` and is intended for the native menu bar app (equivalent to `AWAKE_NO_NOTIFICATIONS=true`).
- `--dry-run`: simulate awake mode without changing real sleep settings.
- `--debug`: enable detailed debug logging to the per-user temporary runtime directory.

## Terminal Input

At the terminal prompt:

- Press `Enter` for the default duration of 20 minutes.
- Type one digit (`1`-`9`) for hours.
- Type two digits (`01`-`99`) for minutes.
- Press `Esc`, `q`, or `Ctrl+C` to cancel.

## GUI Input

The GUI duration picker offers a fixed list:

- `10 minutes`, `20 minutes` (default), `30 minutes`, `40 minutes`, `50 minutes`
- `1 hour`, `2 hours`, `3 hours`, `4 hours`, `6 hours`, `8 hours`

The dialog is implemented as an AppleScript prompt with a JavaScript-for-Automation fallback that uses an `NSAlert` with a pop-up button.

## Examples

Start with the normal interactive picker:

```bash
awake
```

Force GUI mode:

```bash
awake --gui
```

Force GUI mode with the custom GUI password dialog and sound notifications:

```bash
awake --gui-custom --sound
```

Force terminal mode:

```bash
awake --terminal
```

Start for exactly 20 minutes:

```bash
awake --duration-seconds 1200
```

Check whether awake mode is active:

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
  - `state`: serialized session state (worker and guard process IDs, original `pmset` values, deadline, session token)
  - `status`: written when a session ends; carries the completion `reason` (`timeout`, `stopped`, `cancelled`, or `failed`)
  - `session`: lightweight session metadata used to compute remaining time
  - `askpass`: shell helper that displays the custom GUI password dialog (only used by `--gui-custom`)
  - `lock/`: mutex preventing concurrent state changes
  - `awake-debug.log`: created only when `--debug` is set or `AWAKE_DEBUG=true` is exported
- `/tmp/keep-awake-lid-closed-control-$UID/state`: companion control-state file owned by the privileged worker

The dry-run mode uses the same paths with `-dry-run` inserted into the basename, for example `/tmp/keep-awake-lid-closed-dry-run-$UID/`.

## Dry-Run and Self-Test

`--dry-run` uses a separate temporary runtime directory and does not change real `pmset` settings.

Run the self-test from the repository directory with:

```bash
bash tests/cli/awake-self-test
```

The self-test runs only against `awake --dry-run`, so it does not touch real `pmset` settings. It exercises the main lifecycle paths by:

- starting and stopping dry-run sessions through the terminal and GUI entry points,
- waiting for timed sessions to finish automatically,
- confirming that `--status` and `--status-json` stay read-only when completion metadata is pending,
- verifying notification-suppression behavior for the menu bar app integration,
- verifying that stale state does not terminate an unrelated process,
- and running additional sourced regression checks for helper matching, prompt behavior, CLI parsing, and failure handling.

It exits immediately on the first failure, and on success it ends with `All dry-run lifecycle and regression checks passed.`.

## License

This project is licensed under the GNU Affero General Public License version 3.

See `LICENSE.md` for the full license text.

## Author

Antti Käenmäki, <antti@kaenmaki.net>.
