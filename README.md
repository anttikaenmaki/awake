# awake

`awake` is a macOS shell script that temporarily changes battery sleep settings so a MacBook can stay awake with the lid closed for a chosen duration, then attempts to restore the previous settings automatically.

It supports both terminal and GUI prompts, offers a dry-run mode for testing, and treats a second invocation while awake mode is active as a request to restore normal sleep mode.

macOS's built-in `caffeinate` prevents idle sleep but does not override sleep when the lid is closed. `awake` is for that case: it toggles the battery `sleep` and `disablesleep` settings for a bounded duration and tries to put them back.

Current version: `1.0.0`.

Example use cases:

- Let a large download, sync, or backup finish during a short lid-closed period.
- Keep a local development server or SSH session alive while the lid is closed for a fixed time window.
- Finish a video export, build, or test run without leaving the MacBook open on the desk.

## What It Does

- Applies battery-only `pmset` changes so the Mac can remain awake with the lid closed.
- Basically acts as a toggle between `sudo pmset -b sleep 0; sudo pmset -b disablesleep 1` and the normal fallback pair `sudo pmset -b sleep 5; sudo pmset -b disablesleep 0`.
- Lets you choose a duration from the terminal or a GUI dialog.
- Starts the privileged session in the background.
- Uses the native macOS administrator prompt for GUI authentication.
- Optionally supports a custom GUI password dialog via `--gui-custom`, which can reduce repeated password queries.
- Saves the previous battery sleep settings and tries to restore them automatically when the timer ends or when you stop the session early.
- Runs a background failsafe process that re-checks past the deadline and restores the settings as a backup if the main worker is interrupted.
- Recovers from a stuck state: if awake-like sleep settings are active without a saved session, it falls back to safe defaults.
- Posts macOS Notification Center messages on start, stop, and failure (`Awake started`, `Awake stopped`, `Awake failed`); with `--sound`, also plays the system alert sound on start and stop.
- Offers `--status`, `--stop`, `--dry-run`, `--debug`, and optional sound notifications.

## Safety Warnings

- Keeping a MacBook awake with the lid closed can cause significant heat buildup, higher battery drain, and unexpected shutdown if the battery runs low.
- Use it only on a hard, flat, well-ventilated surface.
- Never use it in a bag, bed, sofa, or on your lap.
- Settings apply to battery power only; on AC power the Mac uses its AC `pmset` settings, so the awake toggle has no effect until you unplug.
- `awake` attempts to restore the previous battery sleep settings automatically. A background failsafe process re-checks them past the deadline and restores them as a backup if the main worker is interrupted; if the saved values cannot be read, it falls back to safe defaults (`pmset -b sleep 5; pmset -b disablesleep 0`). Restoration can still fail in pathological cases (for example, if the failsafe process is also killed).
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

Place `awake` somewhere on your `PATH` and make it executable.

Example:

```bash
cp awake /usr/local/bin/awake
chmod +x /usr/local/bin/awake
```

## Usage

```bash
awake [options]
```

Running `awake` with no options opens the terminal picker when run from an interactive terminal, or a GUI picker otherwise.

Running `awake` again while a session is active restores normal sleep mode.

### GUI authentication

In GUI mode, macOS displays its standard administrator authentication dialog by default when elevated access is needed. If you prefer the custom GUI password dialog for personal use, pass `--gui-custom`; this implies `--gui`. Compared with `awake --gui`, this asks for the administrator password in `awake`'s own hidden-input dialog instead of the standard macOS administrator prompt. `awake` then passes that password to `sudo` to refresh the normal `sudo` timestamp, which can reduce repeated prompts during the session.

From the user's perspective, `awake --gui` is the more conservative choice because password entry stays inside macOS's native authentication UI. `--gui-custom` can be convenient for personal use, but it requires trusting `awake` itself with the password briefly in memory before it is handed to `sudo`. The password is read into a shell variable, piped to `sudo -S -v` to refresh the normal `sudo` timestamp, and is never written to disk or exported as an environment variable. The askpass helper at `$STATE_DIR/askpass` only contains the dialog code and is created with mode `700`. The script does not store the password in its state files, but the custom dialog still has a broader trust surface than the native prompt.

### Concurrency and stop semantics

`awake` serializes state-changing invocations with a `mkdir`-based lock under `$STATE_DIR/lock`. If another `awake` is in the middle of a state change, the second one exits with `Another awake command is already changing the session state. Please try again.`. `--status` skips the lock and is read-only, so it is safe to run alongside an active session.

`--stop` is idempotent: if no session is active, terminal mode prints `Awake mode is not active.` and GUI mode shows an `Awake is off` notification.

### Debug logging

By default, `awake` writes no debug log. Pass `--debug` (or set `AWAKE_DEBUG=true` in the environment) to enable detailed logging to the per-user temporary runtime directory, for example `/tmp/keep-awake-lid-closed-$UID/awake-debug.log` or `/tmp/keep-awake-lid-closed-dry-run-$UID/awake-debug.log`. The `--debug` flag is propagated to the privileged background worker via `AWAKE_DEBUG` so that all phases of a session log to the same file.

## Options

- `-h`, `--help`: show help and exit
- `-g`, `--gui`: force GUI mode even when run from a terminal
- `--gui-custom`: imply `--gui` and use the custom GUI password dialog instead of the native macOS administrator prompt
- `--sound`: play a system alert sound for start/stop notifications
- `-t`, `--terminal`: force terminal mode; requires an interactive terminal unless combined with `--duration-seconds`, `--stop`, or `--status`
- `--duration-seconds N`: use an exact duration in seconds (1 to 32400, that is, up to 9 hours)
- `-s`, `--stop`: restore normal sleep mode if awake mode is active, then exit; safe to run when no session is active
- `-v`, `--version`: show the version and exit
- `--status`: show whether awake mode is on and the time remaining; lock-free and read-only
- `--dry-run`: simulate awake mode without changing real sleep settings
- `--debug`: enable detailed debug logging to the per-user temporary runtime directory

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

The repository also includes `awake-self-test`, which is intended for development and verification. Run it from the repository directory:

```bash
bash awake-self-test
```

The self-test runs only against `awake --dry-run`, so it does not touch real `pmset` settings. It checks the main lifecycle paths by starting and stopping a dry-run session, waiting for a timed session to finish automatically, confirming that `--status` stays read-only when completion metadata is pending, verifying that stale state does not terminate an unrelated process, and running additional sourced regression checks for internal helper matching and failure handling. It exits immediately on the first failure, and on success it ends with `All dry-run lifecycle and regression checks passed.`.

## License

This project is licensed under the GNU Affero General Public License version 3.

See `LICENSE.md` for the full license text.

## Author

Antti Kùenmùki, <antti@kaenmaki.net>.
