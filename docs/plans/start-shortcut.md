# Plan: a keyboard shortcut that starts Awake

- Status: phase 1 written (`StartShortcut.swift` and its check), waiting for CI; phases 2 to 4 to do
- Target version: 2.2.0, together with `unplug-guard.md` and `session-heat-report.md`; no helper, CLI or picker change
- Written: 2026-09-29, against the 2.2.0 work (commit `0d36f57`)
- Scope: `app/AwakeStatusApp`, `tools/build-awake-app.sh`, `.github/workflows/ci.yml`, a new `tests/app/` check, `README.md`, `CHANGELOG.md`

## How this plan was checked

- It was written on Linux, from the code, without a Swift compiler. The Carbon calls, key handling and window focus need a real Mac, so they are in the QA checklist (8). Claims about macOS that could not be checked from here are marked there and in 11.

## 1. Goals

1. One key press, from any app, starts Awake's default session. Today that takes a click on the menu bar icon and Enter in the picker.
2. The same key stops a running session, as a click on the icon does.
3. The user picks the key combination in Settings. There is none until then, so nothing changes for anyone who does not set one.
4. No new permission. There is no Accessibility or Input Monitoring prompt: the installer rebuilds and ad-hoc signs `Awake.app` at every update, so macOS would forget such a grant each time.

Not in scope:

- a shortcut that is on out of the box;
- more shortcuts, such as one that adds an hour or one that opens the picker;
- a Shortcuts app action: App Intents need macOS 13 and an Xcode build, and the app supports 12.5 and is built with `swiftc`;
- an `awake://` URL, which any link could use to start a session;
- the Shortcuts app workaround (a Run Shell Script shortcut) in the README, which the owner declined;
- changes to `bin/awake`, `bin/awake-helper` or the picker.

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Release | 2.2.0, as the owner asked. There is no strong reason to wait. It changes no helper, CLI or protocol, it is off until a shortcut is set, and its QA can run with that of the other two 2.2.0 plans. The cost is about 600 lines of app code and a QA pass, and the release waits for them. |
| 2 | Mechanism | Carbon's `RegisterEventHotKey`, in `Awake.app`. It is the only global shortcut API that needs no permission, it takes the key press so the frontmost app never sees it, and it works on macOS 12.5 and later. Rejected: an `NSEvent` global monitor or event tap needs Accessibility or Input Monitoring (goal 4), cannot take the key press, and stops while a password field has focus. A Services menu item depends on the frontmost app having a Services menu. |
| 3 | What the key does | What a click on the icon does, without the picker. When the icon shows Awake as off, it starts the default session. When it shows Awake as on, it stops the session or restores leftover settings, exactly as a click. While a start, stop or helper update runs, it beeps and does nothing. |
| 4 | Length | The Settings window's `Default selection`, which the picker and the terminal prompt already share: `pickerDefault`, read with `PickerSettings.load()`. `Indefinitely` starts a session without an end time. |
| 5 | Lid mode | The shortcut's own `Mode` pop-up: `Lid-open, display on` (the default), `Lid-open, display can sleep`, or `Lid-closed`. It does not follow the picker's last choice: that would make the key's behaviour depend on something not shown next to it, and a stray press in password-free mode could start a lid-closed session unnoticed. |
| 6 | Allowed shortcuts | A key with two or more of ⌃ ⌥ ⇧ ⌘, one of them ⌃ or ⌘. Also not a shortcut macOS reserves, and not one of a few standard shortcuts that apps use (5). Single-modifier shortcuts such as ⌘D or ⌃A are what apps use most, and a global shortcut would take them from every app. The rule also avoids macOS 15's refusal of shortcuts whose only modifiers are ⌥ or ⌥⇧. |
| 7 | A session started elsewhere | The key never adds time to a session that started, for example in Terminal, since the last poll. Today's click-start does that, but here nothing is chosen for it, and across modes the CLI would refuse with an error. The app says `Awake is already on` instead (3.2). |
| 8 | Feedback | The icon, the `Awake started` or `Awake stopped` notification, and the sound when `Sound on` is set, as for a click. The start notification now names the length (3.3), since it is the only place a key start shows it. |
| 9 | The picker's memory | A key start leaves the picker's remembered lid and display choices (`lastBackend`, `lastKeepDisplay`) as they are, so the picker still opens with the user's last choice there. |
| 10 | Names | A Settings section `Keyboard shortcut`, with `Shortcut` and `Mode`. Preference keys `startShortcut` and `startShortcutMode`. In the docs it is "the keyboard shortcut". |

## 3. What the user sees

### 3.1 Settings

A new section between General and Guardrails:

```
Keyboard shortcut
Shortcut  [ ⌃⌥⌘A ]  [Clear]
Mode      [ Lid-open, display on ▾ ]
From any app, starts a session of the default length, now 20 minutes,
or stops the running one, like a click on the icon.
```

- **No shortcut.** The button reads `Record Shortcut` and `Clear` is dimmed. That is the state after installing or updating.
- **Recording.**
  - A click on the button starts recording. The button then reads `Type the shortcut…`, and while modifier keys are held it shows them, for example `⌃⌥⌘…`.
  - The note becomes the rule: "Press two or more modifier keys, including ⌃ or ⌘, together with a key, for example ⌃⌥⌘A. Esc cancels."
  - A valid combination is saved and used at once, and recording ends.
  - An invalid one keeps recording and shows the reason in the note, in the system's red: "Use two or more modifier keys, including ⌃ or ⌘." / "macOS uses ⇧⌘3. Choose another shortcut." / "⇧⌘Z is a standard shortcut in most apps. Choose another." / "Another app uses ⌃⌥⌘A. Choose another shortcut." / "macOS did not accept ⌃⌥⌘A (error -9868). Choose another shortcut."
  - Recording ends, keeping the previous shortcut, on Esc, on another click on the button, and when the window closes or stops being the key window.
  - Delete or Forward Delete, pressed alone, clears the shortcut, like `Clear`.
  - Key repeats are ignored.
  - While recording, the current shortcut is turned off, so pressing it records it again instead of starting a session.
- **Clear** removes the shortcut and turns it off at once.
- **Mode** is stored as `startShortcutMode`: `lid-open` (the default), `lid-open-display-sleeps`, or `lid-closed`. An unknown stored value counts as `lid-open`. It applies to the next press.
- **The note** follows the setting and the default length:
  - "From any app, starts a session of the default length, now 20 minutes, or stops the running one, like a click on the icon."
  - With `Indefinitely` as the default: "From any app, starts a session without an end time, or stops the running one, like a click on the icon."
  - With `Lid-closed`, it goes on: "Lid-closed mode asks for your password unless Start without password is on."
  - When the stored shortcut could not be turned on at launch, the note says why, in red, as in recording ("Another app uses ⌃⌥⌘A. Choose another shortcut."), and the button still shows it.
- **Tooltips.**
  - The button: "The keyboard shortcut that starts or stops Awake from any app. It works while Awake.app is running."
  - The pop-up: "The mode of a session started with the keyboard shortcut. The picker keeps its own choice."
- **Accessibility.** The button's accessibility label is "Keyboard shortcut". Its value spells the shortcut out, for example "Control Option Command A", or "None".
- The window grows by the section, sized by `fitWindowToContent()` as with the heat note.

### 3.2 Pressing the shortcut

| The icon shows | A press |
|---|---|
| Awake is off | Starts a session of the default length in the shortcut's mode, with the Guardrails settings, without the picker. |
| Awake is on: a session, sleep settings left behind, or another account's lid-closed session | The same as a click: stops the session or restores the settings, with the same password rules. |
| A start, stop or helper update is running | A beep; nothing else. |

Further rules:

- **Passwords.** The start asks for them as a click-start does: nothing for lid-open mode; for lid-closed mode, the macOS administrator dialog, or Awake's own dialog with `Use custom password dialog`, which reuses a password typed in the last 2 minutes; nothing in password-free mode. Cancelling starts nothing, as today.
- **The command.** The app runs what a click-start with a picked length runs, for example `awake --gui --start --duration-seconds 1200 --backend caffeinate --min-battery 5 --thermal-guard on --unplug-guard off --keep-display on`, or `--indefinite` instead of the length. With a length the CLI shows no picker (`bin/awake`, `END_CONDITION_GIVEN`). Every value except the length, the backend and `--keep-display` comes from Settings, as it does for a click.
- **A session started elsewhere** (decision 7): `performStart` reads the status first, as it does now. If a session is running, it runs no command, and the app posts `Awake is already on` with the status text, as it does today when a click-start finds a running session.
- **The app's own dialogs.** A press is ignored while an app-modal alert of Awake's is open (`NSApp.modalWindow`). It is also ignored if it was queued while the main thread waited for one of the app's own synchronous prompts: the picker in custom password mode, the custom password dialog, or an alert. Otherwise a press made while such a prompt was open, and then cancelled, would start a session afterwards (4).
- **Quitting.** The shortcut works only while `Awake.app` runs. `Launch at login` keeps it running.

### 3.3 Notifications

- **Start.** `Awake started`, with the body naming the length as the CLI's own notification does (`started_notification_body`): "The Mac will stay awake while the lid remains open for 20 minutes." Today the app's body for a session with a length says "until the chosen session ends"; this changes for click starts too. The length words come from `PickerSettings.lengthLabel(seconds:)`, which follows the CLI's `format_duration_label`.
- **Stop.** `Awake stopped`, as for a click.
- **Already on.** `Awake is already on`, with the status text (3.2).
- **Failures.** `Awake failed` with the CLI's reason, as for a click. For example, the battery is at or below the `Stop at low battery` level.
- **At launch.** When the stored shortcut cannot be registered, `Awake needs attention` is posted once: "The keyboard shortcut ⌃⌥⌘A is not available, as another app uses it. Choose another in Awake's Settings." When macOS gives another error, the notification says "as macOS did not accept it (error N)" instead.

## 4. Registering the shortcut

A new file, `StartShortcutHotKey.swift`, is the only one that imports Carbon.

- **Handler.** `InstallEventHandler` for `kEventClassKeyboard` / `kEventHotKeyPressed`, installed once. The handler is a closure with no captures, so it converts to a C function pointer. It gets the object through `userData` (`Unmanaged`).
  - It reads the `EventHotKeyID` with `GetEventParameter(kEventParamDirectObject, typeEventHotKeyID)` and ignores other IDs.
  - It reads the press time with `GetEventTime(event)`.
  - It hands both to the controller with `DispatchQueue.main.async`, so no dialog is opened inside the Carbon handler, and returns `noErr`.
- **Registration.** `RegisterEventHotKey` with the key code, `carbonModifiers`, an `EventHotKeyID` whose signature is the four-character code `AWKE` and whose id is 1, and the option `kEventHotKeyExclusive`.
  - The handler and the registration both use `GetEventDispatcherTarget()`, as the KeyboardShortcuts package does, so that a press also arrives while a menu is open (QA 10).
  - `kEventHotKeyExclusive` makes the registration fail with `eventHotKeyExistsErr` when another app holds the same shortcut exclusively. That error gets the "Another app uses …" text. Any other status gets the "macOS did not accept …" text with its number.
- **When.**
  - At launch, in `StatusBarController.start()`.
  - After each change in Settings: the old shortcut is unregistered, and the new one is registered and stored only if that succeeds. Otherwise the old one is registered again.
  - Paused while Settings records.
  - Unregistered on `Clear`.
  - At quit nothing is needed: macOS drops a process's shortcuts when it exits.
- **macOS's own shortcuts.** `CopySymbolicHotKeys` lists them. The entries with `kHISymbolicHotKeyEnabled` set give `kHISymbolicHotKeyCode` and `kHISymbolicHotKeyModifiers`, which are converted to the model's modifiers and passed to its check (5). They are read when a shortcut is recorded, not at launch.
- **Time.** `StartShortcutHotKey.currentEventTime()` wraps `GetCurrentEventTime()`, the same clock as `GetEventTime`. `StatusBarController` stores it when one of its synchronous prompts returns and ignores presses from before then (3.2).
- **Linking.** `import Carbon` in that file, and `-framework Carbon` next to the other frameworks in `tools/build-awake-app.sh`, which the installer also uses, and in CI's macOS 12.5 build. Autolinking may make the flag unnecessary; it is added so the dependency is visible.

## 5. Which shortcuts are allowed

`StartShortcut.swift` (new, Foundation only) holds the model and the rules, so the check (7) can test them without AppKit or Carbon.

- **The model.** `StartShortcut` has `keyCode` (the virtual key code of a physical key, 0–127), `modifiers` (an option set: control 1, option 2, shift 4, command 8), and `keyLabel` (the key as shown when it was recorded). It also has:
  - `displayText`: modifiers in the macOS order ⌃ ⌥ ⇧ ⌘, then the key, for example `⌃⌥⌘A`;
  - `spokenText`, for example "Control Option Command A";
  - `carbonModifiers`: `controlKey` 0x1000, `optionKey` 0x800, `shiftKey` 0x200, `cmdKey` 0x100;
  - `Modifiers(carbonFlags:)`, for `CopySymbolicHotKeys`, and `Modifiers(cocoaFlags:)`, for `NSEvent.modifierFlags`, which keep the four modifiers and ignore Caps Lock, fn and the rest.
- **The rules.** `shortcut.problem(macOSShortcuts:)` returns why a combination cannot be used, or nil. Rules 1 and 4, and the check that the key is a real key and not a modifier, are also `StartShortcut.basicProblem(keyCode:modifiers:)`, which reading a stored value uses:
  1. It needs two or more modifiers, one of them ⌃ or ⌘. Caps Lock and fn are ignored and never stored. fn is part of a function key or arrow on many keyboards, not a choice.
  2. It must not be one of `macOSShortcuts`, the enabled entries of `CopySymbolicHotKeys` (4), such as the screenshot shortcuts ⇧⌘3, ⇧⌘4 and ⇧⌘5.
  3. It must not be one of these standard shortcuts, which apps or macOS use and which that list may not include: ⇧⌘Z (Redo), ⇧⌘Q and ⌥⇧⌘Q (Log Out), ⌃⌘F (Enter Full Screen), ⌃⌘Q (Lock Screen), ⌃⌘Space (Emoji & Symbols). They are matched by the key's label, not its key code, as apps match them by the character a key types: on a French layout, ⇧⌘ with the key that types Z is refused, and the key in the same place as a US Z is not.
  4. Esc cannot be recorded, as it cancels recording.
- **Key labels.**
  - Special keys come from a fixed table: Return ↩, keypad Enter ⌤, Tab ⇥, Space `Space`, Delete ⌫, Forward Delete ⌦, the arrows ← → ↑ ↓, Home ↖, End ↘, Page Up ⇞, Page Down ⇟, and F1 to F20 as `F1` … `F20`.
  - Other keys are labelled with `event.characters(byApplyingModifiers: [])`, uppercased, with the keyboard layout in use when the shortcut was recorded, so a Finnish layout shows `Ö`. This is macOS 10.15 API. A character without a one-letter capital, such as ß, stays as it is.
  - A key without a printable character (none, a control or private-use character, whitespace, or more than four characters) gets `Key 42`.
  - `StartShortcut.label(forKeyCode:characters:)` makes the label.
  - The label is stored with the shortcut and not recomputed.
- **Storage.** `startShortcut` is a dictionary, `{ keyCode = 0; modifiers = 11; keyLabel = A; }`, so `defaults read` shows it readably. A stored value is rejected, and counts as no shortcut, when:
  - the key code is outside 0–127;
  - the modifier bits are outside 0–15, or fail rule 1;
  - the label is empty or longer than 16 characters.

  Rules 2 and 3 are not checked again at launch: macOS's shortcuts can change, and registration reports real conflicts.
- **The mode.** `StartShortcutMode` (`lid-open`, `lid-open-display-sleeps`, `lid-closed`) has its pop-up title, whether it is lid-closed, and its display choice. `StatusBarController` maps it to `AwakeBackend`, which keeps the model free of the app's other files.
- **The length.** `StartShortcut.startRequest(defaultToken:)` returns a `StartRequest` with `durationSeconds: 1200, endArguments: []` for a length and `nil, ["--indefinite"]` for `PickerSettings.indefiniteToken`. A token that is neither, which `PickerSettings.load()` never gives, counts as the picker's fallback, 20 minutes.
- **The texts.** The model also has the texts of 3.1 and 3.3, so the check covers them: `recordingHint`, `message(for:)` for each rule, `registrationFailureMessage(takenByAnotherApp:status:)`, `launchFailureMessage(takenByAnotherApp:status:)`, and `settingsNote(defaultToken:mode:)`.

## 6. Code changes

- **`StartShortcut.swift`** (new, about 180 lines): 5.
- **`StartShortcutHotKey.swift`** (new, about 150 lines): 4. It has `register(_:) -> OSStatus`, `unregister()`, `macOSShortcuts()`, `currentEventTime()`, and an `onPress: (EventTime) -> Void` callback.
- **`StatusBarController.swift`** (about 90 lines):
  - own a `StartShortcutHotKey`, register the stored shortcut in `start()`, and post the launch notification of 3.3 if that fails;
  - `startShortcutPressed(at:)`:
    - ignore a press from before the last prompt ended, or while `NSApp.modalWindow` is set;
    - beep while `pendingCommand` is set;
    - otherwise call `stopAwake()` when `currentStatus.active`, or `startDefaultSession()` when not;
  - `startDefaultSession()`:
    - the length from `StartShortcut.startRequest(defaultToken: PickerSettings.load().defaultToken)`;
    - the backend and display choice from `preferences.startShortcutMode`;
    - for lid-closed mode with the custom dialog, `customAuthorizationForAwakeStart()` as `startAwake()` uses it;
    - then `pendingCommand = .starting` and `cli.performStart(…, startOnlyIfOff: true)`, handled with a new intent `.shortcutStart`;
  - `handleCommandResult`:
    - `.shortcutStart` leaves `lastBackend` and `lastKeepDisplay` alone (decision 9) but sets `appSessionToken`, so the stop notification is posted;
    - it posts `Awake is already on` when the session was running before, like `.start`;
  - store `StartShortcutHotKey.currentEventTime()` when `promptForCustomStartSelection()`, `customAuthorizationForAwakeStart()` (which stops that ask for a password use too) or `showAlert(_:)` returns;
  - the new `SettingsHost` members.
- **`AwakeCLI.swift`** (about 10 lines): `performStart` gets `startOnlyIfOff: Bool = false`. When it is set and the status read first shows `active`, `performStart` returns an outcome with `after` equal to `before` and exit status 0 without running a command.
- **`InstallSupport.swift`** (about 40 lines):
  - `PreferencesStore.startShortcut: StartShortcut?`, stored as the dictionary of 5, nil removing it;
  - `startShortcutMode: StartShortcutMode`;
  - `postStarted` names the length (3.3).
- **`SettingsWindowController.swift`** (about 130 lines):
  - the section of 3.1: the button, `Clear`, the pop-up, and the note;
  - recording through `NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged])`. It handles events only for this window and returns nil for those it consumes, so Command combinations never reach the app's menu (⌘W would otherwise close the window);
  - an observer that ends recording when the window resigns key or closes;
  - `reload()` shows the stored shortcut, the mode, the note, and a registration problem from the host.
  - `SettingsHost` gains:
    - `startShortcutProblem: String?`, why the stored shortcut is not on, or nil;
    - `setStartShortcut(_:) -> String?`, which registers and stores it, or returns why not, and nil clears it;
    - `pauseStartShortcut(_:)`.
- **`tools/build-awake-app.sh`**: `-framework Carbon` (4).
- **`.github/workflows/ci.yml`**: `-framework Carbon` in the macOS 12.5 build, and the check of 7.
- **Not changed:**
  - `bin/awake`, `bin/awake-helper`, the picker and the self-test;
  - the uninstaller, which already removes the app's whole preferences domain.

The new code keeps to Swift 5.7, like the other 2.2.0 work (`session-heat-report.md`, 6): no `if` or `switch` expressions, and no implicit `self` after `guard let self`.

## 7. Tests

- **New: `tests/app/start-shortcut-check.swift`,** a `@main` program built with `-parse-as-library` together with `StartShortcut.swift` and `PickerSettings.swift`. It imports Carbon and AppKit only to compare constants. It checks:
  - rule 1: ⌃⌥⌘A, ⌃⌘A, ⌥⌘A, ⇧⌘A, ⌃⌥A and ⌃⇧F5 pass; A, ⌘A, ⌃A, ⌥A, ⇧A, ⌥⇧A and ⇧F5 fail;
  - rules 2 to 4: a combination in a made-up `macOSShortcuts` list fails, each standard shortcut of rule 3 fails, and Esc with any modifiers fails;
  - `displayText` and `spokenText`, in the ⌃ ⌥ ⇧ ⌘ order, for all 15 modifier sets;
  - the special key labels, and `Key N` for a key without one;
  - `carbonModifiers` against Carbon's `controlKey`, `optionKey`, `shiftKey` and `cmdKey`, `Modifiers(cocoaFlags:)` against `NSEvent.ModifierFlags`, and the key codes of the label table, Esc and the modifier keys against Carbon's `kVK_` constants;
  - that the standard shortcuts are matched by label on another layout;
  - the property-list round trip, and that damaged key codes, modifier bits and labels are rejected;
  - `StartShortcutMode` from each stored value and from an unknown one;
  - `startRequest` for a length, for the longest one, for `indefinite`, and for what `PickerSettings.load()` gives from a stored list;
  - every text of 3.1 and 3.3.
- **CI:** a new step, "Check the start shortcut", after the heat report's:

  ```
  swiftc -target arm64-apple-macos12.5 -parse-as-library -framework AppKit -framework Carbon \
    app/AwakeStatusApp/Sources/StartShortcut.swift app/AwakeStatusApp/Sources/PickerSettings.swift \
    tests/app/start-shortcut-check.swift -o "$RUNNER_TEMP/start-shortcut-check"
  "$RUNNER_TEMP/start-shortcut-check"
  ```

- **Existing checks.** The app build and the macOS 12.5 build cover the Carbon file, the Settings section and the controller. The dry-run self-test does not change, as the CLI does not. Registering, pressing and recording need a logged-in GUI session, which CI does not have, so they are QA items.

## 8. macOS QA checklist

1. **Recording.** In Settings, record ⌃⌥⌘A: the button shows `⌃⌥⌘A`.
   - Esc during recording keeps the old shortcut. Delete clears it.
   - ⌘W during recording does not close the window.
   - ⌘D, ⌥⇧A and plain A are refused with the rule's text, and ⇧⌘3 with the macOS text.
   - Click outside the window while recording: recording ends.
2. **Start from another app.** With Safari frontmost and `Mode` at `Lid-open, display on`, press the shortcut.
   - The session starts without the picker, and the icon turns on.
   - The notification reads "The Mac will stay awake while the lid remains open for 20 minutes."
   - Safari does not receive the key press.
   - `awake --status` shows 20 minutes (or the `Default selection`).
3. **Stop.** Press it again: the session stops and `Awake stopped` appears.
4. **Lid-closed.**
   - With `Mode` at `Lid-closed` and password-free mode off, the macOS administrator dialog comes to the front with keyboard focus. Cancel starts nothing; the password starts the session.
   - The same with `Use custom password dialog`, which then shows Awake's dialog.
   - With password-free mode on, the press alone starts the session.
5. **Display.** `Lid-open, display can sleep` starts a session whose status ends `(keep the lid open; the display may sleep)`.
6. **Indefinitely.** With `Default selection` at `Indefinitely`, the note and the notification say "until you stop it".
7. **Started elsewhere.** Start `awake --backend caffeinate --duration 5m` in Terminal and press the shortcut within 10 seconds. `Awake is already on` appears, and the session still has about 5 minutes left.
8. **Busy.** Press it while the administrator dialog of item 4 is open: a beep, and no second dialog after it closes.
9. **Conflicts.** Record a shortcut another running app already uses, for example a launcher's or window manager's, and write down what happens: Awake refuses it (`Another app uses …`), or both apps react. Then quit and reopen Awake while the other app holds it, and check for the launch notification.
10. **Menus and secure input.** Press it while Awake's Ctrl-click menu is open, while another app's menu is open, and while a password field in Safari has focus. Write down whether it fires; nothing else should happen.
11. **macOS versions.** On the owner's macOS, and on 15 if available, ⌃⌥⌘A registers. On 12.5, if available, the app builds with `-framework Carbon` and the shortcut works.
12. **Layout.** With a Finnish or German layout, record ⌃⌥⌘ with the key right of L: the label shows `Ö`.
13. **Relaunch and quit.** Quit Awake from the menu: the shortcut does nothing. Open Awake again: it works without a new recording. Run the installer: afterwards it still works, with no permission prompt.
14. **The picker.** After a key start in lid-open mode, a click-start opens the picker with the lid checkbox as last chosen there.
15. **Notifications off.** With Awake's notifications turned off in System Settings, a press still starts and stops. The icon, and the sound if `Sound on` is set, show it.
16. **VoiceOver.** The button reads "Keyboard shortcut, Control Option Command A".

## 9. Docs

- **README:**
  - Menu Bar App: a point after the click's. "With a keyboard shortcut set in Settings, the same key starts a session of the default length from any app, without the picker, or stops the running one." Also: it never adds time to a session started elsewhere, its mode is its own setting, and it works while `Awake.app` runs.
  - The Settings window: the `Keyboard shortcut` section, what shortcuts are allowed, and the `Mode` choices.
  - Security Notes: "Type your password only into a dialog that appeared right after you clicked the Awake icon, pressed your Awake keyboard shortcut, or ran `awake` yourself."
- **CHANGELOG `[Unreleased]`:**
  - Added: the keyboard shortcut, off until one is recorded, what it does, its mode, and the allowed combinations.
  - Changed: the app's start notification names the length ("for 20 minutes") instead of "until the chosen session ends".

## 10. Phases

1. `StartShortcut.swift` and its check (5, 7), green on CI.
2. The Carbon registration, the Settings section, the key handling and the notification (3, 4, 6), and the docs (9), green on CI.
3. QA (8) on a real Mac, together with the QA of `unplug-guard.md` (9) and `session-heat-report.md` (8).
4. Version 2.2.0 with `tools/release.sh minor`, once all three plans are done.

## 11. Risks and open points

- **Carbon's age.** `RegisterEventHotKey` is decades old. It is still how apps get a global shortcut without a permission, and the KeyboardShortcuts and HotKey packages use it. In macOS 15.0 Apple restricted it, refusing ⌥-only and ⌥⇧-only shortcuts, rather than removing it. If a later macOS refuses the registration, Settings and the launch notification say so, and the rest of the app is unaffected.
- **Conflicts it cannot see.**
  - Apps' menu shortcuts, and other apps' registrations without `kEventHotKeyExclusive`, are not reported. The shortcut takes that key combination from every app while Awake runs.
  - Rule 1 and the note's example (⌃⌥⌘ and a letter) make a clash unlikely. QA 9 records what happens with a real clash.
- **Unverified here** (QA 9 and 10):
  - that `kEventHotKeyExclusive` reports another app's exclusive registration as `eventHotKeyExistsErr`;
  - that `GetEventDispatcherTarget()` delivers presses while a menu is open;
  - whether a press arrives while a password field has focus;
  - that a local event monitor sees ⌘W before the app's menu does.
- **Accidental stop.** A press ends a running session without asking, as a click does. The key combination is the user's own, which makes a stray press unlikely. Accepted.
- **A password dialog from a key press.** In lid-closed mode without password-free mode, a press brings up the administrator dialog over the frontmost app. The `Mode` pop-up and the note say so, and the Security Notes name the shortcut as a legitimate source. Accepted.
- **Keyboard layouts.** The label is recorded once. After a switch to another layout it can show the old character, while the physical key, which is what counts, stays the same. Accepted.
- **Two copies of Awake.app** (for example a development build next to the installed app). The second one to register gets `Another app uses …`. Accepted.
- **Open.** Whether the Ctrl-click menu should show the shortcut, for example as a `Start Default Session` item with the shortcut beside it, so that it can be discovered. Left out of 2.2.0.
