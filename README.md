# awake

Awake keeps a MacBook awake, also with the lid closed, on battery and with no external display. It ends the session by itself, so the Mac can sleep, when the battery drops to 5% or the Mac overheats (both on by default) and, if you turn it on, when you unplug it. These cut-offs do not make a bag safe: use it only on a hard, flat, well-ventilated surface.

There are already well-known tools for this: Amphetamine, KeepingYouAwake and Caffeine. Awake stands out from them in three ways:

- It works with the lid closed, is free and open source (AGPL-3.0) and has a command line: KeepingYouAwake and Caffeine need the lid open, and Amphetamine, which works with the lid closed, is closed source and has no command-line tool.
- It has an overheating cut-off, on by default; none of the three documents one.
- `awake -- make build` keeps the Mac awake, also with the lid closed, while the build runs, then exits with the build's exit status. (macOS's own `caffeinate make build` needs the lid open.)

Install it with Homebrew:

```bash
brew install anttikaenmaki/awake/awake
```

`awake` is a macOS shell script with a companion menu bar app that keeps a MacBook awake for a while, until a time, or until you stop it. It offers two modes:

- Lid-closed mode: temporarily relaxes the battery sleep settings so the Mac can stay awake even with the lid closed, then attempts to restore the previous settings automatically.
- Lid-open mode: runs the built-in `caffeinate` without administrator privileges to prevent idle sleep while the lid stays open.

macOS's built-in `caffeinate` prevents idle sleep but does not override sleep when the lid is closed. `awake` keeps both cases available behind a single GUI: check `Keep laptop awake with lid closed` in the picker for lid-closed sessions, or leave it unchecked for simpler lid-open sessions.

There are two equivalent user-facing entry points:

- the `Awake.app` menu bar app, and
- the `awake` command-line tool, which can either show a terminal prompt or open the same GUI dialog as the app via `--gui` / `--gui-custom`.

The two interfaces are technically distinct programs, but from a user point of view they behave the same: they share the same managed CLI, the same GUI picker, the same session state, and the same start/stop semantics. A session started from one can be inspected or stopped from the other.

A dry-run mode is available for testing. Running `awake` a second time while a session is active stops it immediately and restores normal sleep mode.

Current version: `2.3.0`. `CHANGELOG.md` in the repository lists what changed in each version.

Example use cases:

- Let a large download, sync, or backup finish during a short lid-closed period.
- Keep a local development server or SSH session alive while the lid is closed for a fixed time window.
- Finish a video export, build, or test run without leaving the MacBook open on the desk: `awake -- make build` keeps the Mac awake while the build runs.
- Keep the Mac awake until an already running process finishes: `awake -w <PID>`.
- Use lid-open mode from the menu bar to prevent idle sleep during a long talk, presentation, or video call without touching `pmset`.

## What it does

Depending on which mode you pick, `awake` does one of the following:

- Lid-closed mode: changes `pmset` settings so the Mac can remain awake with the lid closed. In effect, it toggles between `sudo pmset -b sleep 0; sudo pmset -b disablesleep 1` and the normal fallback pair `sudo pmset -b sleep 5; sudo pmset -b disablesleep 0`. The `sleep` change applies to battery power only, but `disablesleep` is a system-wide switch: `pmset` ignores `-b` for it and lists it as `SleepDisabled` under "System-wide power settings". While a session runs, the Mac therefore stays awake with the lid closed on AC power as well. This requires administrator privileges.
- Lid-open mode: runs `caffeinate -di` in the background for as long as the session lasts, and ends it by the clock when the session ends. This prevents idle sleep and keeps the display on, without changing `pmset` and without administrator privileges, but it does require the lid to stay open. With `--keep-display off`, or `Keep the display on` unchecked in the picker, it runs `caffeinate -i` instead: the display can dim and sleep as usual while the Mac stays awake.

In both modes, `awake`:

- lets you choose how long from the terminal or a GUI dialog: a length (up to 365 days), a clock time to stay awake until, no end time at all, or as long as a process runs (`-w PID`, `-- COMMAND`, or `While` in the GUI dialog),
- starts the chosen session in the background,
- tracks the session in shared per-user state files so any other entry point (terminal or menu bar) sees and can manage it,
- ends the session early when the Mac runs on battery power and the charge drops to 5% or less, and does not start one at that level, so a MacBook is not drained until it shuts down (on AC power the charge does not matter). Choose another level from 5% to 50% with `--min-battery N`, or turn the check off with `--min-battery off`; the menu bar app's Settings have `Stop at low battery` for this,
- ends the session early when the Mac overheats, so it can sleep and cool down: at once when macOS reports the `critical` thermal state, and when it reports `serious` on two checks in a row (30 seconds apart) while the lid is closed. A busy Mac on the desk with the lid open keeps its session at `serious`. A session does not start at `critical`, and a lid-closed session cannot be extended then either. The thermal state is the one macOS gives apps (`NSProcessInfo.thermalState`), read with `osascript`; if it cannot be read, this check is skipped. When the menu bar app starts a session or adds time, it passes the state it has already read, so that check needs no `osascript`; running sessions always read it themselves. Turn the check off with `--thermal-guard off`, or `Stop when too hot` in the menu bar app's Settings,
- optionally ends the session early when the Mac is unplugged, so a closed Mac that you carry off goes to sleep instead of staying awake. Unplugged means that the Mac switches from the power adapter to battery or UPS power, as the first line of `pmset -g batt` shows. The session ends when two checks in a row (5 seconds apart) find the Mac unplugged, so 5 to 10 seconds after unplugging; a MagSafe connector that is pulled and put back at once does not end it. A session started on battery power is affected only after the Mac has been plugged in during it, and a power source that cannot be read never ends a session. On a desktop Mac this matters only with a UPS connected by USB. The check is off by default: turn it on with `--unplug-guard on`, or `Stop when unplugged` in the menu bar app's Settings,
- posts macOS Notification Center messages when you pass `--notifications` (or set `AWAKE_NOTIFICATIONS=true`, see Notifications below): when a session starts, is stopped, finishes, ends on low battery, overheating, or unplugging, or fails (`Awake started`, `Awake extended`, `Awake stopped`, `Awake finished`, `Awake stopped: the battery is low`, `Awake stopped: the Mac got too hot`, `Awake stopped: the Mac was unplugged`, `Awake finished: the process it waited for exited`, or `Awake failed`). Without it, `awake` posts none, with one exception: a request to start or add time that `awake` refuses, for example for a low battery or a session already running, while no terminal shows `awake`'s output (from a shortcut or a `launchd` job, or typed with its output sent elsewhere, such as `awake --duration 1h > log` or `awake -- make 2>&1 | tee log`) still posts `Awake failed` with the reason; `--no-notifications` turns that off too, and `-t` never posts it, as it always prints. They name the program, Awake, in both modes, as do all of `awake`'s messages. When `Awake.app` is installed, these notifications are posted through it and show the Awake icon (if notifications for Awake are turned off in System Settings, none are posted); a CLI-only install posts them with `osascript`. A failure notification has the reason as its text, under the title `Awake failed`. A session's end is announced only when the command that started it had `--notifications`, wherever it is stopped from. In terminal mode, starts, added time, and failures are printed instead, so there `--notifications` adds the notifications for how the session ends, and `Awake started` only together with `--sound`. `--sound` plays the system alert sound when a session starts and when it ends, with or without notifications. The menu bar app posts its own notifications for the sessions it starts, whatever these options say.

In lid-closed mode, `awake` additionally:

- runs the session in a small root-owned helper, `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`, which the installer sets up with your administrator password once; the `awake` script itself never runs as root (see Security notes),
- asks for your administrator password when a session starts, with the native macOS prompt by default or `awake`'s own dialog via `--gui-custom`, unless you turn on password-free mode; stopping a session never asks for a password,
- saves the previous battery sleep settings and restores them automatically when the timer ends or when you stop the session early,
- runs a guard process next to the helper's timer, which still ends the session on time or on request if the timer is interrupted,
- falls back to safe defaults if awake-like sleep settings are still active without a running session, recovering from a stuck state. `awake` cannot tell `sleep 0` together with `disablesleep 1` that you set yourself apart from settings a crashed session left behind: it reports them as left over, and a session started from them restores the safe defaults (`sleep 5`, `disablesleep 0`) when it ends. Any other combination you had before a session is restored as it was.

The script ships with a native macOS menu bar app (`Awake.app`) for users who prefer click-to-toggle access from the menu bar, with its settings in a Settings window.

## Safety warnings

The following warnings apply to lid-closed mode. Lid-open mode requires the lid to stay open and does not change sleep settings, so it does not trigger these specific risks.

- Keeping a MacBook awake with the lid closed can cause significant heat buildup, higher battery drain, and unexpected shutdown if the battery runs low. `awake` ends a session when the battery drops to 5% on battery power (unless you choose another level or turn it off), but a hot, fast-draining Mac can still get there sooner than you expect. It also ends the session when the Mac overheats, but that check reacts only once macOS itself reports the Mac as seriously hot; it does not make a bag, bed, or sofa safe.
- Use it only on a hard, flat, well-ventilated surface.
- Never use it in a bag, bed, sofa, or on your lap.
- `Stop when unplugged` in the menu bar app's Settings, or `--unplug-guard on`, is a further safety net for a Mac that you carry off: it ends the session within seconds of unplugging, and a Mac with a closed lid then goes to sleep. It is off by default, and it does not make a bag safe, as it acts only when the Mac is unplugged during a session.
- The session is not limited to battery power. Only the idle-sleep timer change (`pmset -b sleep 0`) is battery-specific; `disablesleep` is system-wide, so the Mac also stays awake with the lid closed while it is plugged in, until the session ends.
- A session without an end time (`awake --indefinite`, `i` at the terminal prompt, `Indefinitely` in the picker, or a session tied to a process without a time limit, such as `While` in the picker) keeps the Mac awake until you stop it or its process exits. The battery, heat, and unplug guardrails still apply to it; with all three turned off, only a stop, its process exiting, or a restart or shutdown ends it.
- When a lid-closed session ends on its own (at its end time, on low battery, when the Mac overheats or is unplugged, or when its process exits) while the lid is closed, the helper puts the Mac to sleep with `pmset sleepnow`. Clearing `disablesleep` alone would leave a Mac with a closed lid awake. A Mac in closed-display mode with an external display is left alone, and so is one whose `disablesleep` was already on before the session (unless a guardrail ended the session, see the next point): that setting keeps a closed Mac awake on purpose.
- If `disablesleep` was already on before the session and the session ends on low battery, overheating, or unplugging, the helper turns it off anyway, so macOS can put the Mac to sleep. `awake --status` then says so.
- `awake` restores the previous battery sleep settings automatically. The helper's guard process ends the session as a backup if the timer has been interrupted; if the saved values cannot be read, it falls back to safe defaults (`pmset -b sleep 5; pmset -b disablesleep 0`). Restoration can still fail in pathological cases (for example, if both helper processes are killed). If the Mac crashes or loses power during a session, the helper restores the settings from before the session at the next startup; it keeps them in a folder that survives a restart. Until then, or if that fails, the menu bar icon shows `Sleep is still turned off, but no Awake session is running` and the app posts a notification about it once. Clicking the icon, or running `awake --stop`, restores the settings.
- Password-free mode and the custom password dialog are off by default. Each trades some security for convenience; read Security notes before turning either on.
- Use at your own risk.
- This script is provided as-is, without warranty, and the author accepts no liability for overheating, data loss, battery drain, hardware damage, or other loss or damage arising from its use.

## Security notes

Lid-closed mode changes system power settings, which needs administrator (root) rights. Only one small program ever runs as root: the helper at `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`. The installer puts it there owned by `root`, so your user account, and anything else running as you, cannot change it without an administrator password. The `awake` script and the menu bar app run as you and ask the helper to start a session or restore the settings. Before running the helper with administrator rights, `awake` checks that the helper and its folder are owned by `root` and not writable by anyone else. Lid-open mode never uses the helper, except to restore sleep settings that a lid-closed session left behind (see GUI authentication).

This protects the helper, but not the password prompt. The `awake` script and the menu bar app are installed in your own folders, so a program running as you could change them. When Awake asks for your administrator password (to start a session without password-free mode, to install or update the helper, or to turn password-free mode on or off), the command that then runs as root is prepared by that user-owned copy of Awake. A program that had changed it could use your password to run something else as root. This is true of any tool that you install as a user and that asks for an administrator password, and it only matters if something on your Mac already runs code as you. With password-free mode on, starting and stopping sessions no longer involves a password prompt at all; the other operations above still do.

The helper accepts only a few commands with strictly checked arguments (start a session for a given user that ends after a length, at a time, or not at all; change the end of the running session; restore the settings) and does not use its environment. A LaunchDaemon, `/Library/LaunchDaemons/net.kaenmaki.awake.boot-restore.plist`, runs it once at startup to restore the settings of a session that a crash or power loss cut short; it does nothing otherwise. To stop a session early, `awake` creates a stop-request file in your runtime folder; the helper only checks whether that file exists, which is why stopping never needs a password. `awake` then writes one byte to `wake`, a FIFO that the helper makes for you in its own folder for each session, so that the helper looks at once; the helper reads single bytes from it and does nothing else with them.

### Password-free mode

By default, starting a lid-closed session asks for your administrator password. If you turn on password-free mode, with `Start without password` in the menu bar app's Settings, `awake --passwordless on`, or `bash install-awake.sh --passwordless`, Awake adds the file `/private/etc/sudoers.d/awake-<your user ID>`. It lets your account run the helper, and nothing else, without a password.

The trade-off: any program running as you can then change the sleep settings the way Awake does (keep the Mac awake for up to 365 days, or without an end time, or restore normal sleep) without asking you. It cannot use the rule to gain any other administrator rights. Turn password-free mode off in the same places; that asks for your password once more.

### Custom password dialog

By default, Awake asks for your password with the standard macOS administrator dialog, so the password stays inside macOS. The custom password dialog (`--gui-custom`, or `Use custom password dialog` in the menu bar app's Settings) is Awake's own dialog instead, so you trust Awake with the password:

- Awake hands the password to `sudo -S -v`. That starts an ordinary `sudo` session, which lasts for `sudo`'s usual few minutes, exactly as if you had typed the password for `sudo` yourself.
- The menu bar app keeps the password in memory for up to 2 minutes, so a quick stop and restart does not ask again. Turning the setting off forgets it at once. It is never written to disk, put in an environment variable, or stored in Awake's state files.
- Any program can show a dialog that looks like Awake's. Type your password only into a dialog that appeared right after you clicked the Awake icon, pressed your Awake keyboard shortcut, or ran `awake` yourself.

The `GUI authentication` section under Usage has more detail.

## Requirements

- macOS 12.5 (Monterey) or later
- Bash
- `caffeinate` (used by lid-open mode and required for it)
- `pmset` (used by lid-closed mode and required for it)
- `osascript` for GUI mode and notifications
- `afplay` for `--sound` (part of macOS)
- Administrator privileges to change and restore `pmset` settings when using lid-closed mode. Lid-open mode does not need administrator privileges.
- Apple's free Command Line Tools, for the installer, which builds the menu bar app from source with `swiftc`. See Quick installation below. They need Swift 5.7 or later, the version that comes with macOS 12.5.

## Installation

### With Homebrew

If you use [Homebrew](https://brew.sh), one command installs Awake:

```bash
brew install anttikaenmaki/awake/awake
```

Homebrew downloads the release and runs Awake's own installer (see What the installer does), which builds the app on your Mac and asks for your administrator password, in a macOS dialog, to install the helper. Homebrew already needs Apple's Command Line Tools, which the installer builds with, so there is nothing else to install first. `brew upgrade` updates Awake in place and keeps its settings; `brew uninstall awake` removes it, as the uninstaller does (see Uninstall).

### Quick installation

Without Homebrew, Awake is installed from a copy of this repository on your Mac. The commands below go in Terminal (in `Applications` → `Utilities`): paste them in and press Return.

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

Instead of the last command, you can also double-click `Install Awake.app` in the `awake` folder in Finder. It runs the same installer and asks for your administrator password with the macOS password dialog. It is built for Macs with Apple silicon; on an Intel Mac, use `bash install-awake.sh`.

Keep the `awake` folder: it is where you update Awake and where the uninstaller lives. To update to a newer version later, fetch the changes and run the installer again:

```bash
cd ~/awake
git pull
bash install-awake.sh
```

If you would rather not use `git`, click `Code` → `Download ZIP` on the GitHub page, double-click the downloaded file to unpack it, and install from the unpacked folder as above. macOS treats these files as downloaded from the internet and may refuse to open `Install Awake.app` until you allow it under System Settings → Privacy & Security; `bash install-awake.sh` in Terminal works either way. To update, download the ZIP again and install from the new folder.

### What the installer does

`install-awake.sh` and `Install Awake.app` run the same installer. It builds and installs all user-facing pieces in user-writable locations:

- `Awake.app` is built from the repository sources and installed to `~/Applications/Awake.app`.
- The managed CLI is installed to `~/Library/Application Support/Awake/bin/awake`.
- A small wrapper command named `awake` is installed so that your shell can run the managed CLI from a normal `PATH` location.
- The privileged helper for lid-closed mode is installed to `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`, owned by `root`, together with the LaunchDaemon that runs its boot-time restore. This is the one step that asks for your administrator password: in Terminal, or with the macOS password dialog when you use `Install Awake.app`. Reinstalling the same version skips it.
- The installer stops a running session of the previously installed version, and says so first with `Installing stops the running session:` and the session's status. It then quits the running `Awake.app` it installed before replacing it (other copies, such as a build run from the repository, keep running). At the end it starts the new `Awake.app`, so the menu bar item is available right away. `--no-launch` skips that step, unless the app was running before the update.

The wrapper path is chosen as follows:

- If your login-shell `PATH` already contains `~/bin`, the installer places the wrapper at `~/bin/awake`.
- Otherwise, if your login-shell `PATH` already contains `~/.local/bin`, the installer places the wrapper at `~/.local/bin/awake`.
- Otherwise, if `~/bin` already exists and is writable, the installer uses `~/bin/awake`.
- Otherwise, the installer uses `~/.local/bin/awake`.

A folder that you cannot write to is skipped. If neither `~/bin` nor `~/.local/bin` can be used, the installer stops before it changes anything.

If the chosen directory is not yet on your login-shell `PATH`, the installer appends

```bash
export PATH="$HOME/.local/bin:$PATH"
```

(or the same line for `$HOME/bin`) to `~/.zprofile` for Zsh, or for Bash to the first of `~/.bash_profile`, `~/.bash_login`, and `~/.profile` that exists (`~/.bash_profile` if none does), since a Bash login shell reads only that one. In that case, open a new Terminal window after the install so the wrapper becomes visible on `PATH`. The installer also records the installed paths in `~/Library/Application Support/Awake/install-info.sh` so that `uninstall-awake.sh` can later remove the same app, managed CLI, wrapper, and any PATH line that the installer added. A reinstall keeps the record of a PATH line that an earlier install added. If an earlier version created `~/.bash_profile` for the line although `~/.profile` or `~/.bash_login` existed, which Bash then stopped reading, an update removes that file when it holds nothing but the line, and adds the line to the file that Bash reads.

Add `--passwordless` to `bash install-awake.sh` to also turn on password-free mode (see Security notes). The same password prompt then covers the helper.

Before it builds anything, the installer checks for the Command Line Tools and Swift 5.7 or later, and says what to install if they are missing.

### Uninstall

If you installed Awake with Homebrew, remove it with `brew uninstall awake`, which runs the uninstaller below.

Otherwise, to remove Awake, double-click `Uninstall Awake.app` in the `awake` folder (on a Mac with Apple silicon), or run in Terminal:

```bash
cd ~/awake
bash uninstall-awake.sh
```

The uninstaller removes the app, the managed CLI, the wrapper, any `PATH` line that the installer added, the menu bar app's preferences (including the picker's session lengths), the helper with its LaunchDaemon, and any password-free rules. Removing the helper asks for your administrator password once. The `awake` folder itself stays; delete it yourself if you no longer need it.

It removes only what is Awake's: an `Awake.app` at the recorded app path, and a wrapper that runs the managed CLI, as the installer writes it. A startup file that the installer created for the PATH line is removed once nothing else is in it. If `install-info.sh` is missing or cannot be read, the uninstaller removes Awake from its default places and tells you to remove any PATH line yourself.

### Manual CLI-only installation

If you only want the shell command and do not want the menu bar app, copy `bin/awake` and `bin/awake-helper` from the `awake` folder (see Quick installation for how to download it) to a directory on your `PATH` and make them executable yourself. For example, into a user-writable directory on `PATH`:

```bash
cd ~/awake
mkdir -p "$HOME/.local/bin"
cp bin/awake bin/awake-helper "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/awake" "$HOME/.local/bin/awake-helper"
```

Or, into the system-wide `/usr/local/bin` (requires administrator privileges):

```bash
cd ~/awake
sudo cp bin/awake bin/awake-helper /usr/local/bin/
sudo chmod +x /usr/local/bin/awake /usr/local/bin/awake-helper
```

Lid-closed mode also needs the privileged helper. Keep `bin/awake-helper` next to the installed `awake` (or, if you put a symlink to `bin/awake` on your `PATH` instead of a copy, next to the file it points to) and run `awake --install-helper` once; it copies the helper to `/Library/PrivilegedHelperTools/` and adds the LaunchDaemon that runs its boot-time restore, with your administrator password. Lid-open mode works without it. When you update, copy both files again and run `awake --install-helper` again: it replaces the installed helper when the new copy differs, with one password prompt, and does nothing when it is the same. A lid-closed start updates the helper by itself only when the new `awake` cannot use the installed one, which not every update brings.

Note that the GUI duration picker uses a small Swift helper called `awake-gui-picker` that lives next to the managed CLI when you use the installer. In a manual CLI-only install, GUI mode falls back to a pure-AppleScript picker. It offers the same list and a `Custom…` text field, but no `While` choice for waiting on an app or command.

## Menu bar app

`Awake.app` is a small native macOS menu bar app that wraps the same managed `awake` command described above. From the user's perspective, it offers the same modes, the same picker, and the same stop semantics as the terminal CLI in GUI mode. It posts notifications for the sessions it starts; `awake` posts them only when asked (see Notifications), apart from `Awake failed` for a refused start without a terminal.

- A click on the menu bar icon does what the icon shows: while Awake is off, it opens the same native GUI picker that `awake --gui` and `awake --gui-custom` use and starts a session; while Awake is on, it stops the session. The `Keep laptop awake with lid closed` checkbox in the picker decides between lid-closed and lid-open mode, and it starts with the choice you made last time. If a session was started elsewhere (for example in Terminal) since the icon last updated, the click never stops it: the time you pick is added to it instead, if it runs in the mode the picker starts with (with `Use custom password dialog`, the mode you pick); time is not added across modes, so for a session in the other mode the app posts `Awake failed` with the reason.
- A keyboard shortcut, once you turn it on in Settings, does what a click does from any app, without the picker: while Awake is off, a press starts a session of the default length (`Default session` in Settings) in the shortcut's own mode, with the Guardrails settings; while Awake is on, it stops the session. The `Awake started` notification names the length. If a session was started elsewhere since the icon last updated, a press adds no time to it: the app says `Awake is already on` instead. The shortcut works while `Awake.app` is running, and needs no Accessibility permission. `Start default session` in the Ctrl-click menu does the same, also while the shortcut is off.
- If a session ends because the battery ran low, the Mac got too hot or was unplugged, or the app or command it waited for exited, the stop notification says so.
- The icon shows the current state: a regular `A` when Awake is off and a bold `A` while a session runs. Like the other menu bar icons, it turns black on a light menu bar and white on a dark one. It changes as soon as you click it, press the keyboard shortcut, or choose `Start default session` or `Stop session`, before the start or stop is done: a lid-open start shows the bold `A` at once, and a stop the regular one. A lid-closed start shows the bold `A` dimmed until the session runs, so wait until it is solid before you close the lid. While the start picker or a macOS password dialog is open, the icon keeps its state, dimmed, as you can still cancel; with `Use custom password dialog`, Awake's own picker and password dialog come first, and the icon changes once they close. If the start or stop fails, the icon changes back and a notification says why.
- Hovering over the icon, and the first line of the Ctrl-click menu, show the current status: `Awake is off`, `Awake is on and has 25 minutes left`, `Awake is on until 18:30, with 2 hours 5 minutes left`, `Awake is on until you stop it`, `Awake is on until make (PID 4242) exits`, or `Awake has been off for 2 hours` (in minutes, hours, days, weeks, months, or years). Lid-open sessions add `(keep the lid open)`, or `(keep the lid open; the display may sleep)` when they let the display sleep. While a start, added time, a stop, or a helper change is in progress, the line reads `Starting Awake…`, `Adding time…`, `Stopping Awake…`, or `Updating Awake’s helper…`, and VoiceOver reads the same for the icon; otherwise VoiceOver reads `Awake is on` or `Awake is off`.
- A Ctrl-click (or right-click) opens a menu with:
  - `Add 1 hour`: shown only while a session with an end time runs; adds the `Time to add` from Settings to it, up to 365 days from now, and names it, for example `Add 30 minutes`. It is an hour until you choose another. For a lid-closed session this asks for your password like a start, unless password-free mode is on.
  - `Start default session`: while Awake is off, does what the keyboard shortcut does: starts a session of the default length in the shortcut's `Mode`, without the picker. While the shortcut is on, the menu shows it next to the item. While Awake is on, the item reads `Stop session` and stops the session.
  - `Help`: opens a rendered, human-readable copy of this `README.md` inside the app, in a window titled `Awake help`. Esc or Command-W closes it.
  - `Settings…` (Command-comma): opens the Settings window, described below.
  - `Install helper…`: shown only when the privileged helper is missing or is a version this `awake` cannot use; installs it with your administrator password.
  - `Quit`: quits the app. While a session is active, the item reads `Stop Awake and quit`: the app first runs the normal Awake stop flow and only quits after that stop succeeds.

The Settings window applies each change at once, and Esc or Command-W closes it. On a screen too short for it, its content scrolls. Its `General` group has:

- `Launch at login`: whether `Awake.app` starts automatically when you log in.
- `Start without password`: turns password-free mode on or off (see Security notes). Changing it asks for your administrator password; the box shows the new state once that is done, and stays as it was if you cancel.
- `Use custom password dialog`: switches GUI authentication for lid-closed mode between the native macOS administrator prompt and `awake`'s own custom password dialog. If you type a wrong password in the custom dialog, it says so and asks again. Lid-open mode never asks for a password regardless of this setting. It is dimmed while `Start without password` is on, since no password is asked for then.
- `Sound on`: whether start and stop notifications also play a system alert sound.

The `Keyboard shortcut` group sets the shortcut that starts or stops Awake from any app. It is off until you check `Shortcut`, and it is `⇧⌘A` (Shift-Command-A) until you record another:

- `Shortcut`: the checkbox turns the shortcut on or off. Turning it off keeps the shortcut, so turning it on again brings it back. While it is on, click the button next to it and press the keys to record another, for example Control-Option-Command-A, shown as `⌃⌥⌘A`. A shortcut needs two or more modifier keys, one of them Control or Command. It cannot be one that macOS uses, such as `⇧⌘3`, or a standard one: `⇧⌘Z`, `⇧⌘Q`, `⌥⇧⌘Q`, `⌃⌘F`, `⌃⌘Q`, or `⌃⌘Space`. If another app already uses it, Awake says so. Esc cancels recording. `⇧⌘A` uses the key that types A in your keyboard layout when you first turn the shortcut on, and stays on that key if you switch layouts later; record it again to move it. While the shortcut is on, other apps no longer get it: Finder's `⇧⌘A`, for `Go` → `Applications`, for example. Record another shortcut if you use that one.
- `Mode`: what a press starts: `Lid-open, display on` (the default), `Lid-open, display can sleep`, or `Lid-closed`. The picker keeps its own choice. In lid-closed mode, a press asks for your password unless `Start without password` is on. It also sets the mode of `Start default session` in the Ctrl-click menu, so it stays available while the shortcut is off.

The `Guardrails` group applies to sessions started afterwards:

- `Stop when too hot`: ends a session when the Mac overheats (on by default). After a session in which the Mac got hot, a note below this box says for how long, and whether Awake ended the session, for example `Last session: hot for 3 minutes, so Awake ended it.` Hot means macOS's `serious` or `critical` thermal state, so most sessions have nothing to report. The note does not depend on this setting. Only sessions that end while `Awake.app` is running are recorded, and `defaults read net.kaenmaki.awake.statusbar lastSessionHeat` shows the numbers behind the note.
- `Stop at low battery`: ends a session on battery power when the charge drops to the level next to it: `5%` (the default), `10%`, `15%`, `20%`, `25%`, or `30%`. It is on by default; turning it off keeps the level, which is dimmed meanwhile.
- `Stop when unplugged`: ends a session when the Mac switches from the power adapter to battery power (off by default). A session started on battery power is affected only after the Mac has been plugged in during it.

The `Session lengths` group sets the picker's list (see GUI input):

- The list of lengths, sorted, from 1 to 15 of them. `+` adds one, in minutes, hours, or days up to 365 days; `−` removes the selected one.
- `Include Indefinitely`: whether the list ends with `Indefinitely`.
- `Default session`: the row the picker starts on, which is also what `Enter` picks at the terminal prompt, and the length that `Start default session` in the Ctrl-click menu and the keyboard shortcut start. If the default is removed from the list, it becomes 20 minutes when that is listed, and the first length otherwise.
- `Time to add`: what `Add` in the Ctrl-click menu adds to a running session, one of the lengths above; 1 hour by default. Removing that length from the list does not change it.
- `Restore defaults`: goes back to the built-in list, default and time to add, without changing the other settings.

A session started from the menu bar app can be inspected with `awake --status`, stopped with `awake --stop`, and vice versa: a session started from the terminal can be stopped by clicking the menu bar icon.

## Usage

```bash
awake [options]
```

Running `awake` with no options opens the terminal picker when both standard input and standard output are connected to a TTY, and the GUI picker when at least one of them is not.

Without session options, `awake` toggles: running it again while a session is active stops it and restores normal sleep mode. The session options `--start`, `--backend`, and the time options `--duration`, `--duration-seconds`, `--until`, and `--indefinite` never stop a session. Neither do `--min-battery`, `--thermal-guard`, `--unplug-guard`, and `--keep-display`: they apply to new sessions only, so a running session keeps the settings it started with. Given without a time option or `--start` while a session runs, they are refused with a note; given with one, the time is added and `awake` notes that the settings did not change. While a session is running, the time options change it instead:

- A length adds time: `awake --duration 2h` during a session adds 2 hours (`Added 2 hours. Awake is on and has 2 hours 48 minutes left.`). A session never runs for more than 365 days from now; if the addition would go past that, `awake` adds what fits and says so.
- A later end time moves the end: `awake --until 19:00` (`Awake now runs until 19:00.`). An earlier one changes nothing; run `awake --stop` to end a session sooner.
- `awake --indefinite` removes the end time (`Awake now runs until you stop it.`).
- A session without an end time has nothing to add to: `awake` says `Awake already runs until you stop it.` and changes nothing. To give a session tied to a process a time limit, stop it and start it again with `--duration` or `--until`.
- `awake --start` asks how much to add, in the terminal (where a clock time or `i` works too) or with a GUI list.

Changing a lid-closed session needs your password, like starting one, unless password-free mode is on; a lid-open session needs none. Nothing is asked when there is nothing to change, or when the session's guardrails would refuse more time (the battery is at its `--min-battery` level, or the Mac is at the `critical` thermal state); `awake` then says why. Time cannot be added across modes: `--backend caffeinate` during a lid-closed session (or the reverse) is refused, and `awake --stop` comes first.

Only one lid-closed session can run on a Mac at a time, as the sleep settings are shared by all accounts. When another account's lid-closed session is running (for example with fast user switching), `--status` says `Another user's lid-closed Awake session is running on this Mac.` (`--status-json` reports `other_user_session`), and `awake` refuses to start or change a lid-closed session before asking for any password. `awake --stop`, or plain `awake`, can end that session with an administrator password, and says so first; in password-free mode, which lets your account run the helper, no password is asked for. Lid-open sessions belong to each account and are not affected.

Run `awake` as your own user, not with `sudo`: it asks for the administrator password itself when it needs it, and refuses to run as `root` (except for `--status` and `--status-json`, which under `sudo` report on the user who ran `sudo`).

When the helper is missing, or is a version this `awake` cannot use (for example after an update of the script alone), starting a lid-closed session or adding time to one installs or updates it in the same step, with a single password prompt. A changed helper that this `awake` can still use is replaced only by the installer, `brew upgrade`, `awake --install-helper` or `awake --passwordless on`.

### Choosing lid-closed or lid-open mode

In GUI mode, the picker has a checkbox `Keep laptop awake with lid closed`:

- If checked, `awake` uses lid-closed mode and may ask for an administrator password.
- If unchecked, `awake` uses lid-open mode and never asks for a password.

The checkbox starts with the lid mode of the last session (checked when there is none, for example after a restart); `--backend` sets it explicitly.

In terminal mode, the interactive prompt starts a lid-closed session, since users who only need lid-open behavior can simply run `caffeinate` directly. The `--backend caffeinate` flag still works from the command line if you want a managed lid-open session with the same status tracking as the GUI offers (and, with `--notifications`, the same notifications); the prompt then describes lid-open mode instead of showing the lid-closed warning. For example:

```bash
awake --backend caffeinate --duration-seconds 1800
```

### GUI authentication

Starting a lid-closed session needs your administrator password unless password-free mode is on. In GUI mode, `awake` asks with macOS's standard administrator dialog by default. Pass `--gui-custom` (which implies `--gui`) to use `awake`'s own hidden-input password dialog instead; in the menu bar app, this is the `Use custom password dialog` setting. If you type a wrong password in `awake`'s own dialog, it says the password was incorrect and asks again; after three wrong attempts it shows an error.

Stopping a session never asks for a password, whichever interface started it: `awake` asks the helper's timer to end the session. Only if the helper's processes are gone (for example after a crash) does restoring the settings run the helper directly, which asks for the password the same way a start does.

`awake --gui` is the more conservative choice because password entry stays inside macOS's native authentication UI. The custom dialog asks you to trust `awake` itself with the password briefly in memory before it is handed to `sudo`. The password is read into a shell variable by the CLI prompt, or checked by the menu bar app and supplied once over standard input, and is then piped to `sudo -S -v`. It is never written to disk, exported as an environment variable, or stored in the state files. The askpass helper at `$STATE_DIR/askpass` contains only the dialog code and is created with mode `700`.

Lid-open mode does not use `sudo` at all, so none of this applies to it: it can always be started and stopped without a password. The one exception: when sleep settings that a lid-closed session left behind (after a crash, for example) are still in effect, a lid-open start restores them first, through the helper and with a password prompt like a lid-closed start, because they would keep the Mac awake with the lid closed. The terminal prompt says so before it asks how long.

### Concurrency and stop semantics

`awake` serializes state-changing invocations with a `mkdir`-based lock under `$STATE_DIR/lock`. If another `awake` is in the middle of a state change, the second one exits with `Another awake command is already changing the session state. Please try again.`. `--status` and `--status-json` skip the lock and are read-only: they do not even create the runtime directory, so they are safe to run alongside an active session.

While `awake` waits for you to answer the terminal prompt, the start picker, or the add-time list, it does not hold the lock, so a prompt left open does not block `awake --stop` or the menu bar. If a session started, ended, or changed before you answered, the answer is not applied and `awake` says so. The password prompt is different: `awake` holds the lock until it is answered, and `sudo` gives up after 5 minutes by default.

`--stop` is idempotent: if no session is active, it prints `Awake mode is not active.` in terminal mode and when a terminal shows the output of `--gui`; otherwise it posts `Awake is off` with `--notifications`, and exits silently without it.

### Debug logging

By default, `awake` writes no debug log. Pass `--debug` (or set `AWAKE_DEBUG=true` in the environment) to enable detailed logging to the per-user temporary runtime directory, for example `/tmp/keep-awake-lid-closed-$UID/awake-debug.log` or `/tmp/keep-awake-lid-closed-dry-run-$UID/awake-debug.log`. The privileged helper does not write a debug log.

### Notifications

Notifications from `awake` are off by default. Pass `--notifications`, or, to get them in every run, set `AWAKE_NOTIFICATIONS=true` in the environment: for shells and Shortcuts, for example in `~/.zshenv`; for a launchd job, under its `EnvironmentVariables`. `--no-notifications` or `AWAKE_NO_NOTIFICATIONS=true` turns off even the `Awake failed` notification of a request to start or add time that fails without a terminal. Errors in the command line itself, a busy lock, an unknown `-w` process, and a command after `--` that cannot be found are reported on standard error only, as before. On the command line the last of the two options counts, an option beats either variable, and `AWAKE_NO_NOTIFICATIONS=true` beats `AWAKE_NOTIFICATIONS=true`. Versions before 2.4.0 refuse `--notifications` but ignore the variable, so scripts that may meet an older `awake` should use the variable; in an interactive shell, `alias awake='awake --notifications'` also works. A running session keeps the choice of the command that started it. The menu bar app is not affected.

## Options

- `-h`, `--help`: show help and exit.
- `-v`, `--version`: show the version and exit.
- `-g`, `--gui`: force GUI mode even when run from a terminal.
- `--gui-custom`: imply `--gui` and use the custom GUI password dialog instead of the native macOS administrator prompt. Has no effect on lid-open mode, which never asks for a password.
- `--backend awake|caffeinate`: explicitly select the mode and start a session: `awake` for lid-closed mode, `caffeinate` for lid-open mode. `awake` is the default in terminal mode; in GUI mode the picker's checkbox starts with the last session's choice. `caffeinate` prevents idle sleep only and does not keep the Mac awake with the lid closed.
- `-t`, `--terminal`: force terminal mode; requires an interactive terminal unless combined with a time option, `-w`, `--`, `--stop`, or `--status`.
- `--duration SPEC`: start a session of this length, without the picker. A unit is required: `90m`, `2h30m`, `1d`, `45s`, or words such as `2 hours`, up to 365 days. While a session runs, add the length to it instead, up to 365 days from now.
- `--until TIME`: start a session that ends at a time: a clock time such as `18:30`, `18.30`, `6:30pm`, or `7am` (the next time the clock shows it, today or tomorrow), a date and time such as `"2026-09-28 07:00"`, or `@EPOCH`. A time that has passed, or is more than 365 days away, is refused. While a session with an end time runs, a later time moves its end.
- `--indefinite`: start a session without an end time; it runs until you stop it (the battery, heat, and unplug guardrails still apply). While a session runs, remove its end time instead.
- `--duration-seconds N`: start a session with an exact duration in seconds (1 to 31536000, that is, up to 365 days), without the picker. While a session runs, add N seconds to it instead. Use only one of the four time options.
- `--start`: start a session. Unlike plain `awake`, it never stops a running session; it asks how much time to add to it instead.
- `-s`, `--stop`: stop the active session and restore normal sleep mode if needed, then exit; safe to run when no session is active.
- `--status`: show whether a session is active and the time remaining; lock-free and read-only.
- `--status-json`: show the same status as machine-readable JSON for app integration; lock-free and read-only.
- `--sound`: play the system alert sound when a session starts and when it ends (not when it fails), with or without `--notifications`; give it to the command that starts the session.
- `--notifications`: post notifications when a session starts, ends, or fails (see What it does); off by default. A running session keeps the choice it started with; like `--sound`, `--notifications` is not a session option, so `awake --notifications` alone stops a running session, as plain `awake` does; with a time option or `--start` it adds time instead.
- `--no-notifications`: post none at all, not even `Awake failed` for a request to start or add time that fails without a terminal; given together with `--notifications`, the last one counts.
- `--min-battery N|off`: end the session when the Mac runs on battery power and the charge drops to `N` percent (5 to 50; the default is 5), and refuse to start one at that level. At 15% or less the charge is checked every 20 seconds instead of every minute, also while the Mac is plugged in, so that unplugging the charger at a low charge is noticed just as soon. `off` turns the check off. Applies to the session this command starts; a running session keeps its own setting.
- `-w`, `--wait-pid PID`: start a session that ends when process `PID` exits. It has no time limit unless you add `--duration`, `--duration-seconds`, or `--until`. The process must be one of your own. The session runs in the background, and `awake` returns at once.
- `-- COMMAND [ARGS...]`: run `COMMAND` in the foreground and keep the Mac awake while it runs (with no time limit unless you add a time option). When the command exits, `awake` ends the session and exits with the command's exit status, so `awake -- make && deploy` works as expected. Ctrl+C reaches the command; when the command ends because of it, `awake` ends the same way, so a script or a shell loop that runs `awake --` stops too, as it would without `awake`. Suspending the command with Ctrl+Z does not suspend the session: it still ends on time, and its guardrails keep working. If `awake` itself is killed with `kill -9`, the session still ends within seconds; other signals sent to `awake` alone wait until the command exits, so to stop the command early, stop it (`--status` shows its process ID). If a guardrail ends the session first, the command keeps running and `awake` says so when it finishes. If the session cannot start (for example, the password prompt was cancelled or the battery is too low), the command does not run and `awake` exits with status 1. A command that cannot be found or run is refused before any session starts or password is asked for, with exit status 127 or 126, as in a shell. `awake`'s own messages go to standard error, so the command's output stays clean, and a terminal session stays one when the output is redirected: `awake -- make | tee build.log` asks for the password in the terminal.
- Both `-w` and `--` start a new session and never add time to a running one: with a session already running they refuse, so stop it first. Like plain `awake` in a terminal, they use lid-closed mode unless you pass `--backend caffeinate`, and the other session options (`--min-battery`, `--thermal-guard`, `--unplug-guard`, `--keep-display`) apply. `--status` then reads `Awake is on until make (PID 4242) exits.`, or with a time limit `Awake is on until make (PID 4242) exits, with at most 1 hour 59 minutes left.`, and `--status-json` reports `watch_pid` and `watch_command` (for `--`, the process ID and name of the command itself). Adding `--indefinite` is refused, since such a session has no time limit anyway. A session that ends because its process exited records the reason `process_exited`.
- `--keep-display on|off`: lid-open mode only. `on` (the default) keeps the display on; `off` lets it dim and sleep as usual while the Mac stays awake. When the GUI picker is shown, it opens with this choice and the picker's choice wins. A lid-closed session ignores it, and `awake` says so.
- `--thermal-guard on|off`: end the session when the Mac overheats (the default is `on`), and refuse to start one while it is at the `critical` thermal state. Applies to the session this command starts; a running session keeps its own setting.
- `--unplug-guard on|off`: end the session when the Mac is unplugged, that is, when it switches from the power adapter to battery or UPS power (the default is `off`). A session started on battery power is affected only after the Mac has been plugged in during it. Applies to the session this command starts; a running session keeps its own setting.
- `--dry-run`: simulate a session, in either mode, without changing real sleep settings or running `caffeinate`.
- `--debug`: enable detailed debug logging to the per-user temporary runtime directory.
- `--install-helper`: install or update the privileged helper for lid-closed mode, and the LaunchDaemon that runs its boot-time restore; asks for your administrator password once.
- `--uninstall-helper`: remove the privileged helper, its LaunchDaemon, and any password-free rules; if a lid-closed session is still running, it restores normal sleep first.
- `--passwordless on|off`: turn password-free mode on or off (see Security notes); asks for your administrator password.
- Use only one of `--install-helper`, `--uninstall-helper`, and `--passwordless` at a time, and without session options.

## Terminal input

At the terminal prompt:

- Press `Enter` for the default shown in brackets. It is the picker's default (see GUI input): 20 minutes unless you changed the list or its default.
- Type one digit (`1`-`9`) for hours, or two digits (`01`-`99`) for minutes.
- Type a length such as `2h30m`, `90m`, `1d`, `2h 30m`, or `2 hours` (units `d`, `h`, `m`, or the words `day`, `hour`, `hr`, `min`, `minute`).
- Type a clock time such as `18:30`, `18.30`, `6:30pm`, or `7am` to stay awake until the next time the clock shows it.
- Type `i` to stay awake until you stop it.
- Press `Esc`, `q`, `Ctrl+C`, or `Ctrl+\` to cancel. Arrow keys are ignored.

Case and spaces do not matter. `1.5h` or `1,5h` (use `1h30m`), `24:00`, `13pm`, zero lengths, three or more bare digits (`1230` could be a time or minutes), anything more than 365 days away, and answers with other characters are refused with a hint, and the prompt asks again. The line that starts the session always shows how `awake` read the answer, for example `Starting awake until 18:30 (2 hours 5 minutes).`, before any password prompt.

The terminal prompt only asks how long. By default, terminal sessions use lid-closed mode, since lid-open use is already covered by the standalone `caffeinate` command. To use lid-open mode with the same managed lifecycle as the GUI offers, pass `--backend caffeinate`, with or without `--duration-seconds`.

Without a terminal to ask in (for example from a script with `--terminal`), pass `--duration`, `--until`, `--indefinite`, or `--duration-seconds`; lid-closed sessions then also need password-free mode or a recent `sudo` ticket, since there is nowhere to type the password.

## GUI input

The same native GUI picker is used in all GUI entry points: `awake --gui`, `awake --gui-custom`, and the menu bar icon's left-click action (which uses `awake --gui` or `awake --gui-custom` under the hood depending on the `Use custom password dialog` setting). It shows a list of session lengths together with the `Keep laptop awake with lid closed` and `Keep the display on` checkboxes in the same window. Hovering over a checkbox shows what it does. Out of the box the list is:

- `10 minutes`, `20 minutes` (default), `30 minutes`, `40 minutes`, `50 minutes`
- `1 hour`, `2 hours`, `3 hours`, `4 hours`, `6 hours`, `8 hours`
- `Indefinitely`: no end time, until you stop the session

Double-clicking a row starts the session, like `Start`. `Custom…` opens a second step with three choices, and `Back` or `Esc` returns to the list:

- `For`: a length in hours and minutes, up to 365 days.
- `Until`: a clock time; the line next to it says whether that is today or tomorrow and how long it is from now. The time follows your Mac's 12- or 24-hour setting.
- `While`: an app or a command running in Terminal. The session ends when it exits. Apps show with their icons; commands show with their process ID, for example `rsync (PID 4812)`. Shells are left out.

`For` and `Until` open with the values you chose last time.

- The checkbox starts with the lid mode of the last session, and is checked when there is none.
- If checked, `awake` uses lid-closed mode, so the Mac can stay awake with the lid closed, and authentication may be required.
- If unchecked, `awake` uses `caffeinate` (lid-open mode), so the lid must stay open and no password is required.
- `Keep the display on` applies to lid-open mode only. While the lid checkbox is checked, it shows unchecked and greyed out; unchecking the lid checkbox brings back your display choice. Checked (the default), the display stays on, for presentations, video calls, or watching a long task. Unchecked, the display can dim and turn off as usual while the Mac stays awake. The menu bar app opens the picker with the choice you made last time; `awake --gui --keep-display off` opens it unchecked.

The managed CLI uses a native Swift/AppKit picker helper for this window when it is installed, and falls back to a pure-AppleScript picker if the helper binary is missing. The fallback asks the same questions in up to three dialogs. Its `Custom…` adds one more, with a text field that reads the same answers as the terminal prompt. It has no `While` choice.

The list and its default are set in the menu bar app's Settings, under Session lengths. For CLI-only use, set them with `defaults`: lengths in seconds (whole minutes, up to 365 days, at most 15 of them) and `indefinite`, separated by spaces, and the default as one of them. For example:

```bash
defaults write net.kaenmaki.awake.statusbar pickerDurations -string "900 1800 3600 7200 14400 indefinite"
defaults write net.kaenmaki.awake.statusbar pickerDefault -string "3600"
```

A value that `awake` cannot read gives the built-in list. When the default is not listed, it is 20 minutes if that is listed, and otherwise the first entry. The terminal prompt's `Enter` uses the same default. When a session is running, `awake --gui --start` asks how much time to add with the same lengths, without `Indefinitely`; the list, and `Enter` at the terminal, start with the default when it is a length, and with 1 hour otherwise.

## Examples

Start with the normal interactive picker (terminal prompt in a TTY, otherwise the GUI picker):

```bash
awake
```

Keep the Mac awake, also with the lid closed, while a build runs, and pass on its exit status:

```bash
awake -- make build
```

Keep the Mac awake during a build and get a notification when it ends:

```bash
awake --notifications -- make build
```

Run the tests with the lid open, without a password, and let the display sleep:

```bash
awake --backend caffeinate --keep-display off -- npm test
```

Stay awake until an already running process exits, for at most 2 hours:

```bash
awake -w "$(pgrep -n ollama)" --duration 2h
```

Stay awake until 18:30, or for 2 hours 30 minutes:

```bash
awake --until 18:30
awake --duration 2h30m
```

Stay awake until you stop it, then stop it:

```bash
awake --indefinite
awake --stop
```

While a session runs, move its end to the next 7:00, or remove its end time:

```bash
awake --until 7am
awake --indefinite
```

Force GUI mode and pick lid-closed or lid-open mode in the dialog:

```bash
awake --gui
```

Force GUI mode and start a lid-closed session for one hour without the picker:

```bash
awake --gui --backend awake --duration-seconds 3600
```

Force GUI mode with the custom GUI password dialog, notifications, and sounds:

```bash
awake --gui-custom --notifications --sound
```

Force terminal mode (a lid-closed session, with an interactive prompt):

```bash
awake --terminal
```

Start a managed lid-open session from the terminal (no password prompt, lid must stay open):

```bash
awake --backend caffeinate --duration-seconds 1800
```

Start a lid-closed session (the default mode) for exactly 20 minutes:

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

## Runtime files

`awake` keeps per-user state in a temporary runtime directory, with mode `700` for the directory and `600` for its files:

- `/tmp/keep-awake-lid-closed-$UID/`: per-user runtime directory
  - `state`: the running lid-open session (process IDs, how it ends in `end_mode` and `deadline_at`, session token)
  - `status`: written when a lid-open session ends; carries the completion `reason` (`timeout`, `stopped`, `cancelled`, `low_battery`, `overheated`, `unplugged`, `process_exited`, or `failed`). It stays as the record of the last lid-open session until the next one ends.
  - `session`: metadata about the current session (mode, sound setting, session token) used for status and notifications
  - `stop-request`: created to ask a running session to stop (for a lid-open session, only when `awake` cannot signal it)
  - `command-finished`: created when the command after `--` finishes, to end its session as `process_exited`
  - `command`: the command after `--` while it runs (its name and process ID, for `--status`)
  - `deadline-lock/`: held for a moment while a lid-open session's end is checked or changed
  - `askpass`: shell helper that displays the custom GUI password dialog (only used by `--gui-custom`), mode `700`
  - `start-error`, `extend-error`: the helper's error output, kept only while a start or an extension runs
  - `lock/`: mutex preventing concurrent state changes. Its `pid` file names the holder and when it started, so a lock whose holder is gone is taken over.
  - `lock-takeover/`: held for a moment by the one command that takes over such a lock
  - `awake-debug.log`: created only when `--debug` is set or `AWAKE_DEBUG=true` is exported

The privileged helper keeps the lid-closed session state in a folder that only `root` can change and everyone can read:

- `/var/run/net.kaenmaki.awake/`
  - `session`: the running lid-closed session (session token, user ID, how it ends in `end_mode` and `deadline_at`, the original `pmset` values, the timer and guard process IDs, the battery level and the thermal-guard and unplug-guard settings, and the process the session waits for, if any)
  - `heartbeat`: written by the helper's timer every few seconds, so its guard can take over from a timer that stopped responding
  - `wake`: a FIFO, owned by you with mode `600`, while a lid-closed session runs; `awake` writes a byte to it after it creates `stop-request` or `command-finished`, so the helper's timer looks at once
  - `last`: the most recent finished lid-closed session (reason: `timeout`, `stopped`, `low_battery`, `overheated`, `unplugged`, `process_exited`, `restart` after a boot-time restore, or `failed`; completion time; whether the settings were restored; and `disablesleep_forced` when a guardrail end turned `disablesleep` off)
- `/var/db/net.kaenmaki.awake/saved`: the `pmset` values from before the running session, kept until they are restored. macOS empties `/var/run` when it starts, so this copy lets the helper restore them at the next startup, or `awake --stop` afterwards.
- `/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`: the helper itself
- `/Library/LaunchDaemons/net.kaenmaki.awake.boot-restore.plist`: runs the helper's boot-time restore once at startup
- `/private/etc/sudoers.d/awake-$UID`: only while password-free mode is on

`/tmp` is shared by all accounts, so another account could create this directory first. `awake` never uses a runtime directory that it does not own; it says so and shows the command an administrator can use to remove it (`sudo rm -rf /tmp/keep-awake-lid-closed-$UID`).

The dry-run mode uses the same user paths with `-dry-run` inserted into the basename, for example `/tmp/keep-awake-lid-closed-dry-run-$UID/`. In dry-run mode the helper runs unprivileged from `bin/awake-helper` next to the script and keeps its state in `/tmp/keep-awake-lid-closed-control-dry-run-$UID/`.

## Dry-run and self-test

`--dry-run` uses a separate temporary runtime directory and does not change real `pmset` settings. It also ignores `pickerDurations` and `pickerDefault`, using the built-in list and default, and does not remember `Custom…` values.

Run the self-test from the repository directory with:

```bash
bash tests/cli/awake-self-test
```

The self-test runs only against `awake --dry-run`, so it does not touch real `pmset` settings and does not need the installed helper. Run it as a normal user: the helper refuses dry-run mode as `root`. It exercises the main lifecycle paths by:

- starting and stopping dry-run sessions through the terminal and GUI entry points, in both lid-closed and lid-open mode,
- waiting for timed sessions to finish automatically,
- confirming that `--status` and `--status-json` stay read-only when completion metadata is pending, and that a start, added time, or stop run the way the menu bar app runs it writes the same status as `--status-json` for the state it leaves, and, before it changes anything, for the state it found,
- verifying that notifications are off by default, that `--notifications`, `--no-notifications`, `AWAKE_NOTIFICATIONS`, and `AWAKE_NO_NOTIFICATIONS` combine as documented, that a failed start or added time without a terminal is still posted, and that the menu bar app's suppression still wins,
- verifying that stale state does not terminate an unrelated process,
- stopping a session through the helper's guard after its timer has been killed, and at once through the FIFO that wakes the helper's timer,
- checking that start options never stop a running session, and that a lid-closed session does not start, or ends, when a simulated battery runs low or a simulated Mac overheats, and ends when a simulated Mac is unplugged, the `--min-battery`, `--thermal-guard`, and `--unplug-guard` settings, the same guardrails in lid-open mode, the display choice, and sessions tied to a process with `-w` and `--`, and that the thermal state the menu bar app passes counts only for the start checks and never reaches a session's processes,
- checking end times, sessions without an end time, and lengths up to 365 days, in the helper and from the command line: the terminal grammar with a fixed time zone (including DST changes), moving and removing a running session's end, the sleep step after an unattended end with a simulated closed lid, and the boot-time restore,
- and running additional sourced regression checks for helper matching, password retries, password-free helper runs, prompt behavior, CLI parsing, and failure handling.

It exits immediately on the first failure, and on success it ends with `All dry-run lifecycle and regression checks passed.`.

## License

This project is licensed under the GNU Affero General Public License version 3.

See `LICENSE` for the full license text.

## Author

Copyright (C) 2026 Antti Käenmäki, <antti@kaenmaki.net>.
