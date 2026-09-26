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

Current version: `2.0.0`. `CHANGELOG.md` in the repository lists what changed in each version.

Example use cases:

- Let a large download, sync, or backup finish during a short lid-closed period.
- Keep a local development server or SSH session alive while the lid is closed for a fixed time window.
- Finish a video export, build, or test run without leaving the MacBook open on the desk.
- Use `Caffeine` from the menu bar to prevent idle sleep during a long talk, presentation, or video call without touching `pmset`.

## What It Does

Depending on which mode you pick, `awake` does one of the following:

- `Awake` (lid-closed): changes `pmset` settings so the Mac can remain awake with the lid closed. In effect, it toggles between `sudo pmset -b sleep 0; sudo pmset -b disablesleep 1` and the normal fallback pair `sudo pmset -b sleep 5; sudo pmset -b disablesleep 0`. The `sleep` change applies to battery power only, but `disablesleep` is a system-wide switch: `pmset` ignores `-b` for it and lists it as `SleepDisabled` under "System-wide power settings". While a session runs, the Mac therefore stays awake with the lid closed on AC power as well. This requires administrator privileges.
- `Caffeine` (lid-open): starts a `caffeinate -i -t <duration>` session in the background. This prevents idle sleep without changing `pmset` and does not require administrator privileges, but it does require the lid to stay open.

In both modes, `awake`:

- lets you choose a duration from the terminal or a GUI dialog,
- starts the chosen session in the background,
- tracks the session in shared per-user state files so any other entry point (terminal or menu bar) sees and can manage it,
- ends the session early when the Mac runs on battery power and the charge drops to 10% or less, and does not start one at that level, so a MacBook is not drained until it shuts down (on AC power the charge does not matter). Choose another level from 5% to 50% with `--min-battery N`, or turn the check off with `--min-battery off`; the menu bar app has `Stop at low battery` for this,
- ends the session early when the Mac overheats, so it can sleep and cool down: at once when macOS reports the `critical` thermal state, and when it reports `serious` on two checks in a row (30 seconds apart) while the lid is closed. A busy Mac on the desk with the lid open keeps its session at `serious`. A session does not start at `critical`, and a lid-closed session cannot be extended then either. The thermal state is the one macOS gives apps (`NSProcessInfo.thermalState`), read with `osascript`; if it cannot be read, this check is skipped. Turn the check off with `--thermal-guard off`, or `Stop when too hot` in the menu bar app,
- posts macOS Notification Center messages when a session starts, is stopped, finishes, ends on low battery or overheating, or fails (`Awake started`, `Awake extended`, `Awake stopped`, `Awake finished`, `Awake stopped: the battery is low`, `Awake stopped: the Mac got too hot`, `Awake failed`, or the same with `Caffeine` for lid-open sessions). When `Awake.app` is installed, these notifications are posted through it and show the Awake icon; a CLI-only install posts them with `osascript`; with `--sound`, also plays the system alert sound on start and stop. Terminal starts are confirmed in the terminal instead and only post the start notification together with `--sound`.

In `Awake` mode, `awake` additionally:

- runs the session in a small root-owned helper, `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`, which the installer sets up with your administrator password once; the `awake` script itself never runs as root (see Security Notes),
- asks for your administrator password when a session starts, with the native macOS prompt by default or `awake`'s own dialog via `--gui-custom`, unless you turn on password-free mode; stopping a session never asks for a password,
- saves the previous battery sleep settings and restores them automatically when the timer ends or when you stop the session early,
- runs a guard process next to the helper's timer, which still ends the session on time or on request if the timer is interrupted,
- falls back to safe defaults if awake-like sleep settings are still active without a running session, recovering from a stuck state.

The script ships with a native macOS menu bar app (`Awake.app`) for users who prefer click-to-toggle access and persistent settings from the menu bar.

## Safety Warnings

The following warnings apply to `Awake` (lid-closed) mode. `Caffeine` mode keeps the lid open and does not change sleep settings, so it does not trigger these specific risks.

- Keeping a MacBook awake with the lid closed can cause significant heat buildup, higher battery drain, and unexpected shutdown if the battery runs low. `awake` ends a session when the battery drops to 10% on battery power (unless you choose another level or turn it off), but a hot, fast-draining Mac can still get there sooner than you expect. It also ends the session when the Mac overheats, but that check reacts only once macOS itself reports the Mac as seriously hot; it does not make a bag, bed, or sofa safe.
- Use it only on a hard, flat, well-ventilated surface.
- Never use it in a bag, bed, sofa, or on your lap.
- The session is not limited to battery power. Only the idle-sleep timer change (`pmset -b sleep 0`) is battery-specific; `disablesleep` is system-wide, so the Mac also stays awake with the lid closed while it is plugged in, until the session ends.
- `awake` restores the previous battery sleep settings automatically. The helper's guard process ends the session as a backup if the timer has been interrupted; if the saved values cannot be read, it falls back to safe defaults (`pmset -b sleep 5; pmset -b disablesleep 0`). Restoration can still fail in pathological cases (for example, if both helper processes are killed). If the Mac restarts during a session, the sleep settings stay changed: the menu bar icon shows `Awake is on with no end time` afterwards and the app posts a notification about it once. Clicking the icon, or running `awake --stop`, restores the settings from before the session, which the helper keeps in a folder that survives a restart.
- Password-free mode and the custom password dialog are off by default. Each trades some security for convenience; read Security Notes before turning either on.
- Use at your own risk.
- This script is provided as-is, without warranty, and the author accepts no liability for overheating, data loss, battery drain, hardware damage, or other loss or damage arising from its use.

## Security Notes

`Awake` (lid-closed) mode changes system power settings, which needs administrator (root) rights. Only one small program ever runs as root: the helper at `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`. The installer puts it there owned by `root`, so your user account, and anything else running as you, cannot change it without an administrator password. The `awake` script and the menu bar app run as you and ask the helper to start a session or restore the settings. Before running the helper with administrator rights, `awake` checks that the helper and its folder are owned by `root` and not writable by anyone else. `Caffeine` mode never uses the helper.

This protects the helper, but not the password prompt. The `awake` script and the menu bar app are installed in your own folders, so a program running as you could change them. When Awake asks for your administrator password (to start a session without password-free mode, to install or update the helper, or to turn password-free mode on or off), the command that then runs as root is prepared by that user-owned copy of Awake. A program that had changed it could use your password to run something else as root. This is true of any tool that you install as a user and that asks for an administrator password, and it only matters if something on your Mac already runs code as you. With password-free mode on, starting and stopping sessions no longer involves a password prompt at all; the other operations above still do.

The helper accepts only a few commands with numeric arguments (start a session of a given length for a given user, restore the settings) and does not use its environment. To stop a session early, `awake` creates a stop-request file in your runtime folder; the helper only checks whether that file exists, which is why stopping never needs a password.

### Password-free mode

By default, starting a lid-closed session asks for your administrator password. If you turn on password-free mode, with `Start without password` in the menu bar menu, `awake --passwordless on`, or `bash install-awake.sh --passwordless`, Awake adds the file `/private/etc/sudoers.d/awake-<your user ID>`. It lets your account run the helper, and nothing else, without a password.

The trade-off: any program running as you can then change the sleep settings the way Awake does (keep the Mac awake for up to 9 hours at a time, or restore normal sleep) without asking you. It cannot use the rule to gain any other administrator rights. Turn password-free mode off in the same places; that asks for your password once more.

### Custom password dialog

By default, Awake asks for your password with the standard macOS administrator dialog, so the password stays inside macOS. The custom password dialog (`--gui-custom`, or `Use custom password dialog` in the menu bar app) is Awake's own dialog instead, so you trust Awake with the password:

- Awake hands the password to `sudo -S -v`. That starts an ordinary `sudo` session, which lasts for `sudo`'s usual few minutes, exactly as if you had typed the password for `sudo` yourself.
- The menu bar app keeps the password in memory for up to 2 minutes, so a quick stop and restart does not ask again. It is never written to disk, put in an environment variable, or stored in Awake's state files.
- Any program can show a dialog that looks like Awake's. Type your password only into a dialog that appeared right after you clicked the Awake icon or ran `awake` yourself.

The `GUI authentication` section under Usage has more detail.

## Requirements

- macOS
- Bash
- `caffeinate` (used by `Caffeine` mode and required for it)
- `pmset` (used by `Awake` mode and required for it)
- `osascript` for GUI mode and notifications
- `afplay` for `--sound` (part of macOS)
- Administrator privileges to change and restore `pmset` settings when using `Awake` mode. `Caffeine` mode does not need administrator privileges.
- Apple's free Command Line Tools, for the installer, which builds the menu bar app from source with `swiftc`. See Get the files below.

## Installation

### Get the files

Awake is installed from a copy of this repository on your Mac. The commands below go in Terminal (in `Applications` → `Utilities`): paste them in and press Return.

First, install Apple's Command Line Tools if you do not have them yet. They are free and include `git`, which downloads the files, and the Swift compiler, which the installer uses to build the app:

```bash
xcode-select --install
```

A dialog asks you to confirm the download; wait until the installation finishes. If the tools are already installed, the command just says so.

Then download Awake into a folder named `awake` in your home folder and run the installer:

```bash
cd ~
git clone https://github.com/anttikaenmaki/awake.git
cd awake
bash install-awake.sh
```

Keep the `awake` folder: it is where you update Awake and where the uninstaller lives. To update to a newer version later, fetch the changes and run the installer again:

```bash
cd ~/awake
git pull
bash install-awake.sh
```

Without `git`, you can also click `Code` → `Download ZIP` on the GitHub page and double-click the downloaded file to unpack it. macOS then treats the files as downloaded from the internet and may refuse to open `Install Awake.app` until you allow it under System Settings → Privacy & Security. Running `bash install-awake.sh` in Terminal from the unpacked folder works either way.

### User-friendly install from the repository

The easiest supported installation flow is to run the installer that ships in the repository. It builds and installs all user-facing pieces in user-writable locations:

- `Awake.app` is built from the repository sources and installed to `~/Applications/Awake.app`.
- The managed CLI is installed to `~/Library/Application Support/Awake/bin/awake`.
- A small wrapper command named `awake` is installed so that your shell can run the managed CLI from a normal `PATH` location.
- The privileged helper for lid-closed mode is installed to `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`, owned by `root`. This is the one step that asks for your administrator password: in Terminal, or with the macOS password dialog when you use `Install Awake.app`. Reinstalling the same version skips it.
- If `Awake.app` is running, the installer stops any session, quits the app before replacing it, and starts the new version afterwards (even with `--no-launch`), so the update takes effect right away.

The wrapper path is chosen as follows:

- If your login-shell `PATH` already contains `~/bin`, the installer places the wrapper at `~/bin/awake`.
- Otherwise, if your login-shell `PATH` already contains `~/.local/bin`, the installer places the wrapper at `~/.local/bin/awake`.
- Otherwise, if `~/bin` already exists and is writable, the installer uses `~/bin/awake`.
- Otherwise, the installer uses `~/.local/bin/awake`.

If the chosen directory is not yet on your login-shell `PATH`, the installer appends

```bash
export PATH="$HOME/.local/bin:$PATH"
```

(or the same line for `$HOME/bin`) to `~/.zprofile` for Zsh or `~/.bash_profile` for Bash. In that case, open a new Terminal window after the install so the wrapper becomes visible on `PATH`. The installer also records the installed paths in `~/Library/Application Support/Awake/install-info.sh` so that `uninstall-awake.sh` can later remove the same app, managed CLI, wrapper, and any PATH line that the installer added.

The project root contains the user-facing install and uninstall entry points:

- `Install Awake.app` and `Uninstall Awake.app` for Finder
- `install-awake.sh` and `uninstall-awake.sh` for Terminal

From Finder, double-click `Install Awake.app`. It is built for Macs with Apple silicon; on an Intel Mac, use the Terminal command below.

From Terminal, you can also run:

```bash
bash install-awake.sh
```

Add `--passwordless` to also turn on password-free mode (see Security Notes). The installer first stops a running session of the previously installed version, and it launches `Awake.app` once at the end so the menu bar item becomes available immediately.

To remove the installed app and wrapper later from Finder, double-click `Uninstall Awake.app`.

From Terminal, you can also run:

```bash
bash uninstall-awake.sh
```

The uninstaller also removes the helper and any password-free rules, which asks for your administrator password once.

### Manual CLI-only install

If you only want the shell command and do not want the menu bar app, place `bin/awake` somewhere on your `PATH` and make it executable yourself. For example, into a user-writable directory on `PATH`:

```bash
mkdir -p "$HOME/.local/bin"
cp bin/awake bin/awake-helper "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/awake" "$HOME/.local/bin/awake-helper"
```

Or, into the system-wide `/usr/local/bin` (requires administrator privileges):

```bash
sudo cp bin/awake bin/awake-helper /usr/local/bin/
sudo chmod +x /usr/local/bin/awake /usr/local/bin/awake-helper
```

Lid-closed mode also needs the privileged helper. Keep `bin/awake-helper` next to the installed `awake` and run `awake --install-helper` once; it copies the helper to `/Library/PrivilegedHelperTools/` with your administrator password. `Caffeine` mode works without it.

Note that the GUI duration picker uses a small Swift helper called `awake-gui-picker` that lives next to the managed CLI in the user-friendly install. In a manual CLI-only install, GUI mode falls back to a pure-AppleScript picker that is functionally equivalent for everyday use.

## Menu Bar App

`Awake.app` is a small native macOS menu bar app that wraps the same managed `awake` command described above. From the user's perspective, it offers the same modes, the same picker, the same notifications, and the same stop semantics as the terminal CLI in GUI mode.

- A click on the menu bar icon does what the icon shows: while Awake is off, it opens the same native GUI picker that `awake --gui` and `awake --gui-custom` use and starts a session; while Awake is on, it stops the session. The `Keep laptop awake with lid closed` checkbox in the picker decides between `Awake` and `Caffeine`, and it starts with the choice you made last time. If a session was started elsewhere (for example in Terminal) since the icon last updated, the click never stops it: the time you pick is added to it instead.
- If a lid-closed session ends because the battery ran low or the Mac got too hot, the stop notification says so.
- The icon shows the current state: a regular `A` when Awake is off and a bold `A` while a session runs. Like the other menu bar icons, it turns black on a light menu bar and white on a dark one.
- Hovering over the icon, and the first line of the Ctrl-click menu, show the current status: `Awake is off`, `Awake is on and has 25 minutes left`, or `Awake has been off for 2 hours` (in minutes, hours, days, weeks, months, or years). `Caffeine` sessions add `(keep the lid open)`. While a start or stop is in progress, the line reads `Starting Awake…` or `Stopping Awake…`.
- A Ctrl-click opens a settings and help menu with:
  - `Add 1 hour`: shown only while a session runs; adds an hour to it, up to 9 hours left. For a lid-closed session this asks for your password like a start, unless password-free mode is on.
  - `About / Instructions...`: opens a rendered, human-readable copy of this `README.md` inside the app.
  - `Launch at login`: toggles whether `Awake.app` starts automatically when you log in.
  - `Use custom password dialog`: switches GUI authentication for `Awake` mode between the native macOS administrator prompt and `awake`'s own custom password dialog. If you type a wrong password in the custom dialog, it says so and asks again. `Caffeine` mode never asks for a password regardless of this setting. The item is dimmed while `Start without password` is on, since no password is asked for then.
  - `Start without password`: turns password-free mode on or off (see Security Notes). Changing it asks for your administrator password.
  - `Install Helper…`: shown only when the privileged helper is missing or out of date; installs it with your administrator password.
  - `Sound on`: toggles whether start and stop notifications also play a system alert sound.
  - `Stop at low battery`: the battery charge at which a session ends on battery power: `Never`, `10%` (the default), `20%`, or `30%`. Applies to sessions started afterwards.
  - `Stop when too hot`: ends a session when the Mac overheats (on by default). Applies to sessions started afterwards.
  - `Quit`: quits the app. While a session is active, the item reads `Stop Awake and Quit`: the app first runs the normal Awake stop flow and only quits after that stop succeeds.

A session started from the menu bar app can be inspected with `awake --status`, stopped with `awake --stop`, and vice versa: a session started from the terminal can be stopped by clicking the menu bar icon.

## Usage

```bash
awake [options]
```

Running `awake` with no options opens the terminal picker when both standard input and standard output are connected to a TTY, and the GUI picker when at least one of them is not.

Without session options, `awake` toggles: running it again while a session is active stops it and restores normal sleep mode. The session options `--start`, `--duration-seconds`, and `--backend` never stop a session. While one is running, they add time to it instead: `awake --duration-seconds 7200` during a session adds 2 hours (`Added 2 hours. Awake is on and has 2 hours 48 minutes left.`), and `awake --start` asks how much to add, in the terminal or with a GUI list. A session never runs for more than 9 hours from now; if the addition would go past that, `awake` adds what fits and says so. Adding time to a lid-closed session needs your password, like starting one, unless password-free mode is on; a `Caffeine` session needs none. Time cannot be added across modes: `--backend caffeinate` during a lid-closed session (or the reverse) is refused, and `awake --stop` comes first.

Run `awake` as your own user, not with `sudo`: it asks for the administrator password itself when it needs it, and refuses to run as `root` (except for `--status` and `--status-json`).

When the helper is missing or out of date (for example after an update of the script alone), starting a lid-closed session installs or updates it in the same step, with a single password prompt.

### Choosing a backend

In GUI mode, the picker has a checkbox `Keep laptop awake with lid closed`:

- If checked, `awake` uses the lid-closed `Awake` backend and may ask for an administrator password.
- If unchecked, `awake` uses the lid-open `Caffeine` backend and never asks for a password.

The checkbox starts with the lid mode of the last session (checked when there is none, for example after a restart); `--backend` sets it explicitly.

In terminal mode, the interactive prompt starts the `Awake` backend, since users who only need lid-open behavior can simply run `caffeinate` directly. The `--backend caffeinate` flag still works from the command line if you want a managed `Caffeine` session with the same status tracking and notifications as the GUI offers; the prompt then describes `Caffeine` instead of showing the lid-closed warning. For example:

```bash
awake --backend caffeinate --duration-seconds 1800
```

### GUI authentication

Starting a lid-closed session needs your administrator password unless password-free mode is on. In GUI mode, `awake` asks with macOS's standard administrator dialog by default. Pass `--gui-custom` (which implies `--gui`) to use `awake`'s own hidden-input password dialog instead; in the menu bar app, this is the `Use custom password dialog` setting. If you type a wrong password in `awake`'s own dialog, it says the password was incorrect and asks again; after three wrong attempts it shows an error.

Stopping a session never asks for a password, whichever interface started it: `awake` asks the helper's timer to end the session. Only if the helper's processes are gone (for example after a crash) does restoring the settings run the helper directly, which asks for the password the same way a start does.

`awake --gui` is the more conservative choice because password entry stays inside macOS's native authentication UI. The custom dialog asks you to trust `awake` itself with the password briefly in memory before it is handed to `sudo`. The password is read into a shell variable by the CLI prompt, or checked by the menu bar app and supplied once over standard input, and is then piped to `sudo -S -v`. It is never written to disk, exported as an environment variable, or stored in the state files. The askpass helper at `$STATE_DIR/askpass` contains only the dialog code and is created with mode `700`.

`Caffeine` mode does not use `sudo` at all, so none of this applies to it: it can always be started and stopped without a password.

### Concurrency and stop semantics

`awake` serializes state-changing invocations with a `mkdir`-based lock under `$STATE_DIR/lock`. If another `awake` is in the middle of a state change, the second one exits with `Another awake command is already changing the session state. Please try again.`. `--status` and `--status-json` skip the lock and are read-only, so they are safe to run alongside an active session.

`--stop` is idempotent: if no session is active, terminal mode prints `Awake mode is not active.` and GUI mode shows an `Awake is off` notification.

### Debug logging

By default, `awake` writes no debug log. Pass `--debug` (or set `AWAKE_DEBUG=true` in the environment) to enable detailed logging to the per-user temporary runtime directory, for example `/tmp/keep-awake-lid-closed-$UID/awake-debug.log` or `/tmp/keep-awake-lid-closed-dry-run-$UID/awake-debug.log`. The privileged helper does not write a debug log.

## Options

- `-h`, `--help`: show help and exit.
- `-v`, `--version`: show the version and exit.
- `-g`, `--gui`: force GUI mode even when run from a terminal.
- `--gui-custom`: imply `--gui` and use the custom GUI password dialog instead of the native macOS administrator prompt. Has no effect on `Caffeine` mode, which never asks for a password.
- `--backend awake|caffeinate`: explicitly select the backend and start a session. `awake` is the default in terminal mode; in GUI mode the picker's checkbox starts with the last session's choice. `caffeinate` prevents idle sleep only and does not keep the Mac awake with the lid closed.
- `-t`, `--terminal`: force terminal mode; requires an interactive terminal unless combined with `--duration-seconds`, `--stop`, or `--status`.
- `--duration-seconds N`: start a session with an exact duration in seconds (1 to 32400, that is, up to 9 hours), without the picker. While a session runs, add N seconds to it instead, up to 9 hours from now.
- `--start`: start a session. Unlike plain `awake`, it never stops a running session; it asks how much time to add to it instead.
- `-s`, `--stop`: stop the active session and restore normal sleep mode if needed, then exit; safe to run when no session is active.
- `--status`: show whether a session is active and the time remaining; lock-free and read-only.
- `--status-json`: show the same status as machine-readable JSON for app integration; lock-free and read-only.
- `--sound`: play a system alert sound with start and stop notifications.
- `--no-notifications`: suppress Awake's own GUI notifications.
- `--min-battery N|off`: end the session when the Mac runs on battery power and the charge drops to `N` percent (5 to 50; the default is 10), and refuse to start one at that level. `off` turns the check off. Applies to the session this command starts.
- `--thermal-guard on|off`: end the session when the Mac overheats (the default is `on`), and refuse to start one while it is at the `critical` thermal state. Applies to the session this command starts.
- `--dry-run`: simulate awake mode without changing real sleep settings.
- `--debug`: enable detailed debug logging to the per-user temporary runtime directory.
- `--install-helper`: install or update the privileged helper for lid-closed mode; asks for your administrator password once.
- `--uninstall-helper`: remove the privileged helper and any password-free rules; if a lid-closed session is still running, it restores normal sleep first.
- `--passwordless on|off`: turn password-free mode on or off (see Security Notes); asks for your administrator password.

## Terminal Input

At the terminal prompt:

- Press `Enter` for the default duration of 20 minutes.
- Type one digit (`1`-`9`) for hours.
- Type two digits (`01`-`99`) for minutes.
- Press `Esc`, `q`, or `Ctrl+C` to cancel.

The terminal prompt only asks for the duration. By default, terminal sessions use the lid-closed `Awake` backend, since lid-open use is already covered by the standalone `caffeinate` command. To run the lid-open `Caffeine` backend with the same managed lifecycle as the GUI offers, pass `--backend caffeinate`, with or without `--duration-seconds`.

Without a terminal to ask in (for example from a script with `--terminal`), pass `--duration-seconds`; lid-closed sessions then also need password-free mode or a recent `sudo` ticket, since there is nowhere to type the password.

## GUI Input

The same native GUI picker is used in all GUI entry points: `awake --gui`, `awake --gui-custom`, and the menu bar icon's left-click action (which uses `awake --gui` or `awake --gui-custom` under the hood depending on the `Use custom password dialog` setting). It shows the fixed duration list together with the `Keep laptop awake with lid closed` checkbox in the same window:

- `10 minutes`, `20 minutes` (default), `30 minutes`, `40 minutes`, `50 minutes`
- `1 hour`, `2 hours`, `3 hours`, `4 hours`, `6 hours`, `8 hours`

- The checkbox starts with the lid mode of the last session, and is checked when there is none.
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

Force GUI mode and start a lid-closed `Awake` session for one hour without the picker:

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

`awake` keeps per-user state in a temporary runtime directory, with mode `700` for the directory and `600` for its files:

- `/tmp/keep-awake-lid-closed-$UID/`: per-user runtime directory
  - `state`: the running `Caffeine` session (process IDs, deadline, session token)
  - `status`: written when a `Caffeine` session ends; carries the completion `reason` (`timeout`, `stopped`, `cancelled`, `low_battery`, `overheated`, or `failed`)
  - `session`: metadata about the current session (mode, sound setting, session token) used for status and notifications
  - `stop-request`: created to ask a running session to stop
  - `askpass`: shell helper that displays the custom GUI password dialog (only used by `--gui-custom`)
  - `lock/`: mutex preventing concurrent state changes
  - `awake-debug.log`: created only when `--debug` is set or `AWAKE_DEBUG=true` is exported

The privileged helper keeps the lid-closed session state in a folder that only `root` can change and everyone can read:

- `/var/run/net.kaenmaki.awake/`
  - `session`: the running lid-closed session (session token, user ID, deadline, the original `pmset` values, the timer and guard process IDs, and the battery level and thermal-guard setting)
  - `last`: the most recent finished lid-closed session (reason: `timeout`, `stopped`, `low_battery`, `overheated`, or `failed`; completion time; and whether the settings were restored)
- `/var/db/net.kaenmaki.awake/saved`: the `pmset` values from before the running session, kept until they are restored. macOS empties `/var/run` when it starts, so this copy lets `awake --stop` restore them after a restart during a session.
- `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`: the helper itself
- `/private/etc/sudoers.d/awake-$UID`: only while password-free mode is on

The dry-run mode uses the same user paths with `-dry-run` inserted into the basename, for example `/tmp/keep-awake-lid-closed-dry-run-$UID/`. In dry-run mode the helper runs unprivileged from `bin/awake-helper` next to the script and keeps its state in `/tmp/keep-awake-lid-closed-control-dry-run-$UID/`.

## Dry-Run and Self-Test

`--dry-run` uses a separate temporary runtime directory and does not change real `pmset` settings.

Run the self-test from the repository directory with:

```bash
bash tests/cli/awake-self-test
```

The self-test runs only against `awake --dry-run`, so it does not touch real `pmset` settings and does not need the installed helper. Run it as a normal user: the helper refuses dry-run mode as `root`. It exercises the main lifecycle paths by:

- starting and stopping dry-run sessions through the terminal and GUI entry points, for both `Awake` and `Caffeine` backends,
- waiting for timed sessions to finish automatically,
- confirming that `--status` and `--status-json` stay read-only when completion metadata is pending,
- verifying notification-suppression behavior for the menu bar app integration,
- verifying that stale state does not terminate an unrelated process,
- stopping a session through the helper's guard after its timer has been killed,
- checking that start options never stop a running session, and that a lid-closed session does not start, or ends, when a simulated battery runs low or a simulated Mac overheats, the `--min-battery` and `--thermal-guard` settings, and the same guardrails in `Caffeine` mode,
- and running additional sourced regression checks for helper matching, password retries, prompt behavior, CLI parsing, and failure handling.

It exits immediately on the first failure, and on success it ends with `All dry-run lifecycle and regression checks passed.`.

## License

This project is licensed under the GNU Affero General Public License version 3.

See `LICENSE` for the full license text.

## Author

Copyright (C) 2026 Antti Käenmäki, <antti@kaenmaki.net>.
