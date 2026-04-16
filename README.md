# awake

`awake` is a macOS shell script that temporarily changes battery sleep settings so a MacBook can stay awake with the lid closed for a chosen duration, then attempts to restore the previous settings automatically.

It supports both terminal and GUI prompts, offers a dry-run mode for testing, and treats a second invocation while awake mode is active as a request to restore normal sleep mode.

Example use cases:

- Let a large download, sync, or backup finish during a short lid-closed period.
- Keep a local development server or SSH session alive while the lid is closed for a fixed time window.
- Finish a video export, build, or test run without leaving the MacBook open on the desk.

## What It Does

- Applies battery-only `pmset` changes so the Mac can remain awake with the lid closed.
- Lets you choose a duration from the terminal or a GUI dialog.
- Starts the privileged session in the background.
- Uses the native macOS administrator prompt for GUI authentication.
- Optionally supports a custom GUI password dialog via `--gui-askpass`, which can reduce repeated password queries.
- Tries to restore the previous battery sleep settings automatically when the timer ends or when you stop the session early.
- Offers `--status`, `--stop`, `--dry-run`, and optional sound notifications.

## Safety Warnings

- Keeping a MacBook awake with the lid closed can cause significant heat buildup, higher battery drain, and unexpected shutdown if the battery runs low.
- Use it only on a hard, flat, well-ventilated surface.
- Never use it in a bag, bed, sofa, or on your lap.
- Settings apply to battery power only.
- `awake` attempts to restore the previous battery sleep settings automatically, but restoration can still fail if the process is interrupted.
- Use at your own risk.
- This script is provided as-is, without warranty, and the author accepts no liability for overheating, data loss, battery drain, hardware damage, or other loss or damage arising from its use.

## Requirements

- macOS
- Bash
- `pmset`
- `osascript` for GUI mode and notifications
- Administrator privileges to change and restore `pmset` settings

## Installation

Place `awake` somewhere on your `PATH` and make it executable.

```bash
chmod +x awake
```

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

In GUI mode, macOS displays its standard administrator authentication dialog by default when elevated access is needed. If you prefer the older custom GUI password dialog for personal use, pass `--gui-askpass`; this implies `--gui`.

## Options

- `-h`, `--help`: show help and exit
- `-g`, `--gui`: force GUI mode even when run from a terminal
- `--gui-askpass`: imply `--gui` and use the custom GUI password dialog instead of the native macOS administrator prompt
- `-t`, `--terminal`: force terminal mode
- `-s`, `--stop`: restore normal sleep mode if awake mode is active, then exit
- `-v`, `--version`: show the version and exit
- `--status`: show whether awake mode is on and the time remaining
- `--dry-run`: simulate awake mode without changing real sleep settings
- `--duration-seconds N`: use an exact duration in seconds
- `--sound`: play a system alert sound for start/stop notifications

## Terminal Input

At the terminal prompt:

- Press `Enter` for the default duration of 1 hour.
- Type one digit (`1`-`9`) for hours.
- Type two digits (`01`-`99`) for minutes.
- Press `Esc`, `q`, or `Ctrl+C` to cancel.

## Examples

Start with the normal interactive picker:

```bash
awake
```

Force GUI mode:

```bash
awake --gui
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

Stop an active session:

```bash
awake --stop
```

Test the flow without changing real sleep settings:

```bash
awake --dry-run --duration-seconds 120
```

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
