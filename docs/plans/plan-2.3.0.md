# Plan for 2.3.0: Esc closes Settings and Help, on/off boxes, the menu's default session and time to add, and a Homebrew tap

- Status: phases 1 and 2 done (the code, the check and the docs; green on CI, then fixed after a multi-agent review, 10), and the addenda 11 to 14, 16 and 17; phase 4 done: released as 2.3.0 on 2026-09-30, at the owner's choice before phase 3; phase 3, the Mac QA of 6, 11 to 14, 16 and 17 and the 2.1.0 and 2.2.0 checklists of 15, still to do, in one session with plan-2.4.0's 6 and faster-start-stop.md's 8, and 2.4.0 carries what it finds. The Homebrew tap waits for the owner's one-time setup (17)
- Target version: 2.3.0 (the changelog rule: Added and Changed make a minor version); no helper or picker change; the CLI and the installer are unchanged, and a Homebrew tap is added (17)
- Written: 2026-09-30, against 2.2.0 (commit `f5f29dd`); the owner's review then removed `Clear` for good and added the Help window
- Scope: `app/AwakeStatusApp`, `tests/app/start-shortcut-check.swift`, `tools/homebrew/`, `scripts/homebrew-uninstall.sh`, `.github/workflows/`, `README.md`, `CHANGELOG.md`

## Earlier plans

The plans for 2.1.0 and 2.2.0 are no longer in the repository. `git show v2.2.0:docs/plans/NAME.md` shows each: `flexible-sessions.md` (2.1.0), `unplug-guard.md`, `session-heat-report.md` and `start-shortcut.md` (2.2.0). Their Mac QA checklists, which were never run, are in 15, and their open points in 9. Below, "the 2.2.0 shortcut plan" means `start-shortcut.md`.

## How this plan was checked

- It was written on Linux, from the code, without a Swift compiler. Key routing, focus and the keyboard layout lookup need a real Mac, so they are in the QA checklist (6). Claims about macOS that could not be checked from here are marked there and in 9.

## 1. Goals

1. Esc closes the Settings window and the Help window (`About / Instructions...` until 14), as it closes most macOS settings and utility windows. Today only the close button and ⌘W do.
2. The keyboard shortcut gets a checkbox that turns it on or off, off by default. There is then always a key combination to show: `⇧⌘A` until another is recorded.
3. The shortcut button and the `Mode` pop-up keep their left edges lined up, as they are now.
4. Nothing changes for anyone who does not turn the shortcut on, and a shortcut recorded in 2.2.0 stays on after the update.

Not in scope:

- a shortcut that is on out of the box, which the 2.2.0 shortcut plan (1) also left out;
- any change to what a press does, the allowed combinations, or the `Mode` choices.

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | How Esc closes the window | A small `NSWindow` subclass, `EscapeClosableWindow`, in its own file and used by the Settings and Help windows (decision 11), whose `cancelOperation(_:)` calls `performClose(_:)`. It ignores an auto-repeated Esc (decision 2). AppKit sends `cancelOperation:` for Esc and ⌘. when no view in the key window takes Esc as its key equivalent, starting at the first responder and going up the responder chain, which always ends at the window. So it works whatever has focus, and ⌘. closes the window too, as macOS convention has it. Rejected: a local event monitor, which would have to be ordered against the recording monitor, and a hidden button with Esc as its key equivalent. |
| 2 | Esc while recording a shortcut | It still only cancels recording. The recording monitor returns nil for Esc, so the window never sees it. A second Esc closes the window. The monitor is gone once recording ends, so the repeats of an Esc held down would reach the window: `cancelOperation(_:)` ignores a key-down that `isARepeat`, and only a fresh press closes. |
| 3 | The default combination | `⇧⌘A`, as the owner asked. It passes every rule of the 2.2.0 shortcut plan (5): two modifiers, one of them ⌘, not one of macOS's, and not one of the standard shortcuts. |
| 4 | Which physical key | The key that types A in the keyboard layout in use when the box is first turned on, stored then like a recorded shortcut. Carbon hot keys go by key code, not character, and on a French or Belgian AZERTY layout the key with code 0 (`kVK_ANSI_A`) types Q: a fixed key code would show `⇧⌘A`, react to ⇧⌘Q, and so take Log Out from every app. Code 0 is the fallback when the layout cannot be read. On US, Finnish, Swedish, German, UK, Dvorak and Colemak layouts it is code 0 anyway. |
| 5 | When the default is stored | When the box is turned on and no shortcut is stored. Until then `startShortcut` stays absent and the window shows `StartShortcut.defaultShortcut()`, whose label is `A` whatever the key code. Once stored, the shortcut keeps its key when the layout changes, as a recorded one does. |
| 6 | The on/off setting | A new Bool, `startShortcutEnabled`. When it has never been stored, it counts as on if a shortcut is stored, so a 2.2.0 shortcut stays on, and as off otherwise. Turning the box off keeps the stored shortcut, so turning it on again brings back the same combination. |
| 7 | `Clear` and Delete | `Clear` goes, as the owner confirmed: with a combination always shown, "no shortcut" is no longer a state, and the box turns the shortcut off. No `Default` button takes its place: recording ⇧⌘A does the same. Delete and Forward Delete alone, which cleared the shortcut while recording, become ordinary keys: without modifiers they get the rule's text, "Use two or more modifier keys, including ⌃ or ⌘." |
| 8 | Controls while off | The shortcut button is dimmed while the box is off, as macOS dims controls that depend on a checkbox. `Mode` was dimmed too until 12 made it the mode of the menu's `Start default session` as well, which works while the shortcut is off. The note stays, in grey, so it still says what turning it on does. |
| 9 | Turning it on fails | The box stays on, the shortcut is not registered, and the note says why in red, as it does today when a stored shortcut cannot be registered at launch: "Another app uses ⇧⌘A. Choose another shortcut." The button is enabled, so another can be recorded at once. At the next launch, a failure posts the `Awake needs attention` notification, as now. |
| 10 | Layout of the group | The checkbox takes the `Shortcut` label's place. The `Mode` row is indented to the checkbox's title, as the heat note under `Stop when too hot` is, and its label is as much narrower than the checkbox, so the pop-up starts where the button does (3.2). |
| 11 | The Help window | Esc closes it too, as the owner asked, with the same window class. Its web view passes an Esc that the page does not handle on to AppKit, which turns it into `cancelOperation:`. |
| 12 | Version | 2.3.0, as `tools/release.sh` suggests from an Added and a Changed entry. 2.2.1 (`tools/release.sh patch`) if the owner prefers to call these fixes. |

## 3. What the user sees

### 3.1 Esc

- Esc or ⌘. closes the Settings window, as ⌘W and the close button do, whatever control has focus.
- While a shortcut is being recorded, the first Esc cancels recording (decision 2); a second one closes the window.
- With the add-a-length popover open, Esc closes the popover only: the popover's window is then the key window.
- With a pop-up menu open, Esc closes the menu only: menu tracking takes it.
- With the error sheet open (a `Launch at login` failure), Esc goes to the sheet, and the window stays.
- The Help window closes on Esc as well. Whether it also does in the plain-text message it shows when the bundled guide cannot be read is left to QA 3 (9).

### 3.2 The Keyboard shortcut group

```
Keyboard shortcut
[✓] Shortcut  [      ⇧⌘A      ]
    Mode      [ Lid-closed   ▾ ]
From any app, starts a session of the default length, now 20 minutes,
or stops the running one, like a click on the icon. Start default session
in the Ctrl-click menu does the same, also while the shortcut is off.
Lid-closed mode asks for your password unless Start without password is on.
```

- **Alignment.** Both rows keep a spacing of 8 after their first view. The `Mode` row has a left inset of `titleIndent(of: shortcutBox)`, the helper the heat note already uses, and the `Mode` label is `shortcutBox`'s width minus that inset. The pop-up then starts at the checkbox's width plus 8, where the button starts, and `Mode` lines up with the checkbox's title.
- **Off** (the state after installing, unless a 2.2.0 shortcut was recorded). The box is clear, the button shows `⇧⌘A` (or the stored shortcut) dimmed, and the note is grey. `Mode` stays available (12). ⇧⌘A reaches other apps as before.
- **Turning it on.** The stored shortcut, or else `⇧⌘A` for the current layout (decisions 4 and 5), is registered at once. The default is first checked against macOS's own shortcuts, as a recorded one is; a problem is shown as in decision 9.
- **Recording.** As in 2.2.0, but only while the box is on (decision 8), and Delete no longer clears (decision 7). A recorded shortcut is registered and stored as before.
- **Turning it off.** Ends any recording first, then unregisters the shortcut. The stored combination and `Mode` stay. The box's new state is read before recording ends, as ending it redraws the box as stored.
- **The note.** Unchanged texts, but for the sentence 12 adds. The red problem text is shown only while the box is on.
- **Tooltips.**
  - The box: "Turns the keyboard shortcut on or off. It starts or stops Awake from any app while Awake.app is running."
  - The button: "Click and press keys to record another shortcut." It keeps its accessibility label, "Keyboard shortcut".
  - The pop-up: unchanged.
- **A default that breaks a rule.** Should macOS itself use ⇧⌘A (a shortcut the user set in System Settings), the default is not stored, the note says "macOS uses ⇧⌘A. Choose another shortcut." in red, and no launch notification is posted for it.
- **Accessibility.** The box's accessibility label is "Use keyboard shortcut", so VoiceOver does not read two elements both called "Shortcut". The button's value is the spoken shortcut, or "Recording" while one is being recorded; there is no longer a "None".

## 4. Code changes

- **`EscapeClosableWindow.swift`** (new, about 20 lines): the `NSWindow` subclass of decisions 1 and 2, used by the Settings and Help windows.
- **`ReadmeWindowController.swift`** (1 line): creates an `EscapeClosableWindow`.
- **`StartShortcut.swift`** (about 20 lines):
  - `static func defaultShortcut(keyCode: Int? = nil) -> StartShortcut`: `⇧⌘` with label `A`, and `keyCode`, or `ansiAKeyCode` (0) for nil or for a key code that fails `basicProblem`.
  - `static func isEnabled(storedFlag: Bool?, hasStoredShortcut: Bool) -> Bool`, the rule of decision 6: `storedFlag ?? hasStoredShortcut`. It lives here, not in `PreferencesStore`, so the check covers it.
  - `deleteKeyCode` and `forwardDeleteKeyCode` go, and `ansiAKeyCode` comes; the label table keeps ⌫ and ⌦.
- **`StartShortcutHotKey.swift`** (about 35 lines): `static func keyCode(typing character: String) -> Int?`. It reads `TISCopyCurrentASCIICapableKeyboardLayoutInputSource()`, whose `kTISPropertyUnicodeKeyLayoutData` gives the `UCKeyboardLayout`, and runs `UCKeyTranslate` for key codes 0 to 127 without modifiers, with `kUCKeyActionDisplay`, `LMGetKbdType()` and `kUCKeyTranslateNoDeadKeysMask`. It returns the first key code, skipping the modifier keys, whose output, lowercased, is `character`. The ASCII-capable source is the one macOS uses for ⌘ shortcuts: on a Russian layout it is the Latin layout used with it. Carbon stays in this file only.
- **`InstallSupport.swift`** (about 10 lines): the key `startShortcutEnabled`, and `PreferencesStore.startShortcutEnabled: Bool`, read with `StartShortcut.isEnabled(storedFlag: defaults.object(forKey:) as? Bool, hasStoredShortcut: startShortcut != nil)`, stored as a Bool.
- **`StatusBarController.swift`** (about 30 lines):
  - `registerStoredStartShortcut(notifyOnFailure:)` unregisters and returns when the shortcut is off. When it is on and none is stored, it checks `StartShortcut.defaultShortcut(keyCode: StartShortcutHotKey.keyCode(typing: "a"))` with `problem(macOSShortcuts: StartShortcutHotKey.macOSShortcuts())`: a problem is kept in `startShortcutFailure` with `message(for:)`, and nothing is stored or registered. Otherwise it stores the default and registers it.
  - New `SettingsHost` member `setStartShortcutEnabled(_:)`: stores the setting, then calls `registerStoredStartShortcut(notifyOnFailure: false)`, and `onStateChange`. Turning it off also clears `startShortcutFailure`.
  - `setStartShortcut(_:)` takes a `StartShortcut`, not an optional: its nil case served `Clear` and Delete only.
  - `pauseStartShortcut(false)` needs no change: it goes through `registerStoredStartShortcut`, which now checks the setting.
- **`SettingsWindowController.swift`** (about 40 lines changed, 25 removed):
  - an `EscapeClosableWindow`, created in `init(host:)` in place of `NSWindow`.
  - `shortcutBox = NSButton(checkboxWithTitle: "Shortcut", …)`, whose action reads its new state, ends any recording, and calls `host?.setStartShortcutEnabled(_:)`, then `reloadShortcut()`.
  - `shortcutModeLabel`, the `Mode` label, kept for its width constraint.
  - The shortcut row is `[shortcutBox, shortcutButton]`, and the `Mode` row is inset and sized as in 3.2, in place of the label-width constraint. The width constraint is activated after `group(…)`, which is the first view the two rows share: AppKit raises an exception for a constraint between views without a common ancestor.
  - `clearShortcutButton`, `clearShortcut(_:)` and the Delete branch of `handleRecordingEvent(_:)` go.
  - `reloadShortcut()` sets the box, shows `preferences.startShortcut ?? StartShortcut.defaultShortcut()`, enables the button only while on, and shows the host's problem only while on. (Until 12, it also dimmed the `Mode` pop-up and label.)
  - The `SettingsHost` protocol and the class comment follow.
- **Not changed:** `bin/awake`, `bin/awake-helper`, the picker, `tools/build-awake-app.sh` (Carbon is linked already), CI's steps (the check builds from the same files), and the uninstaller, which removes the whole preferences domain.

The new code keeps to Swift 5.7, like the 2.2.0 work: no `if` or `switch` expressions, and no implicit `self` after `guard let self`.

## 5. Tests

`tests/app/start-shortcut-check.swift` gains:

- `defaultShortcut()`: key code `kVK_ANSI_A` (and `ansiAKeyCode` against it), modifiers ⇧⌘, label `A`, `displayText` `⇧⌘A`, `spokenText` "Shift Command A", `carbonModifiers` `shiftKey | cmdKey`, `problem(macOSShortcuts: [])` nil, and the property-list round trip;
- `defaultShortcut(keyCode: kVK_ANSI_Q)`, the AZERTY case: label still `A`, still no problem; key codes that cannot be part of a shortcut (-1, 128, Esc, ⌘, fn) give the ANSI A key;
- `isEnabled(storedFlag:hasStoredShortcut:)` for the four combinations and for no stored flag with and without a shortcut;
- that ⌫ and ⌦ alone get `.needsModifiers`, now that Delete is an ordinary key;
- the two `deleteKeyCode` and `forwardDeleteKeyCode` comparisons with Carbon go with the constants. The label table's comparison still covers `kVK_Delete` and `kVK_ForwardDelete`.

`keyCode(typing:)` is not in the check: a CI runner has no logged-in session whose keyboard layout could be trusted. The app build compiles it, and QA 9 tests it.

## 6. macOS QA checklist

1. **Esc.** Open Settings and press Esc: the window closes. Again with Full Keyboard Access on and focus on a checkbox, the `Mode` pop-up, the session lengths list, and the `Default session` pop-up. ⌘. closes it too.
2. **Esc and recording.** Click the shortcut button, press Esc: recording ends and the old shortcut is shown. Again, holding Esc for two seconds: recording ends and the window stays. Press Esc again: the window closes. Click the shortcut button, then uncheck the box: recording ends and the shortcut is off at once.
3. **Esc elsewhere.** With the add-a-length popover open, Esc closes only the popover. With the `Mode` menu open, Esc closes only the menu.
   - **Help window.** Open Help from the Ctrl-click menu and press Esc, before and after clicking into the page: the window closes. Also in full screen, where it should close the window and leave the space. If the plain-text message can be forced (a build without `README.md` in its Resources), note whether Esc closes it too.
4. **Fresh install.** `defaults delete net.kaenmaki.awake.statusbar startShortcut` and `… startShortcutEnabled`, then relaunch and open Settings. The box is off, and `⇧⌘A` is dimmed; `Mode` is not (12). ⇧⌘A in Finder opens Applications.
5. **On.** Check the box. ⇧⌘A in another app starts a session, and again stops it; Finder no longer gets it. `defaults read net.kaenmaki.awake.statusbar` shows `startShortcut = { keyCode = 0; keyLabel = A; modifiers = 12; }` and `startShortcutEnabled = 1`.
6. **Off and on.** Record ⌃⌥⌘A, uncheck the box: neither ⌃⌥⌘A nor ⇧⌘A does anything in Awake, and the button still shows `⌃⌥⌘A`, dimmed. Check it again: ⌃⌥⌘A works.
7. **Delete.** While recording, Delete alone shows "Use two or more modifier keys, including ⌃ or ⌘." and recording goes on.
8. **Upgrade.** Install over 2.2.0 with a recorded shortcut: the box is on and the shortcut works. Over 2.2.0 without one: the box is off.
9. **AZERTY.** With the French layout, on a fresh install (item 4), check the box. The key labelled A with ⇧⌘ toggles Awake; ⇧⌘Q still logs out. `defaults read` shows `keyCode = 12`. Switch to a US layout: the same physical key, which now types Q, still toggles Awake, so ⇧⌘Q does too (9).
10. **Conflict.** With a second copy of Awake.app holding ⇧⌘A (it shares this copy's settings, so the box here then reads on), uncheck and check the box: it stays on, and the note reads "Another app uses ⇧⌘A. Choose another shortcut." in red. A launcher that holds ⇧⌘A may not register it exclusively, and then no note appears (9). Recording another combination clears the note.
11. **Alignment.** The left edges of the shortcut button and the `Mode` pop-up line up, and `Mode` lines up with the checkbox's title, in light and dark appearance. Take a screenshot for the record.
12. **Relaunch.** Quit and reopen with the box on and off: the state is kept, and with the box off no launch notification is posted even while another app holds the shortcut.
13. **VoiceOver.** The box reads "Use keyboard shortcut, checkbox"; the button reads "Keyboard shortcut, Shift Command A", and dimmed while off.

## 7. Docs

- **README, Settings window:** a clause in its introduction: "and Esc or Command-W closes it". **README, Ctrl-click menu:** `Help` (`About / Instructions...` until 14) gets "Esc or Command-W closes it."
- **README, `Keyboard shortcut` group:** "It is off until you check `Shortcut`, and it is `⇧⌘A` (Shift-Command-A) until you record another". `Shortcut`: the box turns it on or off, and a click on the button records another combination while it is on, with the existing rules; "Esc cancels" stays, "Delete or `Clear` removes the shortcut" goes. `⇧⌘A` goes on the key that types A when the box is first checked, and stays on that key after a layout switch. `Mode`: dimmed while the shortcut is off (until 12; it now stays available). A note that while it is on, the shortcut no longer reaches other apps, for example Finder's `⇧⌘A` for `Go` → `Applications`, so record another if you use that.
- **README, Menu bar app:** "A keyboard shortcut, once you record one in Settings" becomes "once you turn it on in Settings".
- **CHANGELOG `[Unreleased]`:**
  - Added: Esc closes the Settings and Help windows.
  - Changed: the keyboard shortcut has a `Shortcut` checkbox that turns it on or off, off by default, and is `⇧⌘A` until you record another, using the key that types A in your keyboard layout. `Clear` is gone, and Delete or Forward Delete no longer clears it while one is being recorded. A shortcut recorded in 2.2.0 stays on. This goes under Changed, not Removed, which `tools/release.sh` would read as a major version.

## 8. Phases

1. Esc in both windows (decisions 1, 2 and 11, QA 1 to 3) and its README and CHANGELOG lines.
2. The shortcut box: `StartShortcut.swift` and its check, then the app and the docs. Phases 1 and 2 went in as one commit, as they touch the same Settings code.
3. QA on a real Mac: 6, the lists in 11 to 14, and the 2.1.0 and 2.2.0 checklists of 15.
4. Version 2.3.0 with `tools/release.sh minor`. Done before phase 3, as the owner chose; the QA follows on the released version.

## 9. Risks and open points

- **`⇧⌘A` in other apps.** While the shortcut is on, Carbon takes ⇧⌘A from every app: Finder's `Go` → `Applications`, and ⇧⌘A in apps such as Chrome. It is off by default, the README says so, and the combination can be changed. Accepted.
- **Unverified here** (QA 1 to 3, 9 and 10):
  - that Esc reaches `cancelOperation(_:)` with every control focused, the documented behaviour, and from the Help window's web view;
  - that `NSApp.currentEvent` in `cancelOperation(_:)` is the repeated key-down of a held Esc (QA 2). Where it is not, a held Esc closes the window, as before the fix;
  - `UCKeyTranslate` with the ASCII-capable layout on macOS 12.5 and later, and on AZERTY;
  - that `kEventHotKeyExclusive` reports another app's ⇧⌘A, as the 2.2.0 shortcut plan (11) also left to QA (15.3, item 9).
- **Open, from the 2.2.0 heat report plan (11).** Whether the heat note, how long the Mac was hot, should also appear briefly in the `Awake stopped` notification when the thermal guard ended the session.
- **Open, from the 2.2.0 unplug plan (12).** Whether `Stop when unplugged` should be on by default for lid-closed sessions in a later major version.
- **Losing Delete and `Clear`.** A day after 2.2.0, few users will have learnt them, and the box does what they did. Accepted.
- **Switching between AZERTY and another layout.** Once stored, `⇧⌘A` stays on its physical key, as every recorded shortcut does (the 2.2.0 shortcut plan, 11). Someone who turns it on with AZERTY and later types with a US layout presses that key as ⇧⌘Q, so Awake then takes Log Out's keys and not ⇧⌘A; the other way round, the ANSI A key becomes AZERTY's Q. Looking the key up again at every launch would follow the layout, but would make the stored default behave unlike a recorded shortcut, and would still go wrong for a layout switch while Awake runs. Accepted: the README says the shortcut stays on its key, and recording it again moves it.
- **The Settings window's height.** Sections 11 to 13 made it taller than a 1280×800 display allows. It now scrolls there (16).
- **The Help window's plain-text message.** When the bundled guide cannot be read, the window shows a plain `NSTextView`. That view may answer Esc with its own `cancelOperation:` (text completion) and not pass it on, so Esc may not close the window then. Normal installs never show it. Left to QA 3.

## 10. Review

A multi-agent review of the first commit (five reviewers, each finding checked by a skeptic, and a completeness critic) found, besides doc fixes:

- **The `Mode` label's width constraint** was activated before the two rows shared a superview. AppKit raises an exception for that, so Settings would not have opened. Fixed as in 4.
- **Unchecking the box while recording** read the box's state after ending the recording, which redraws the box as stored, so the click only cancelled the recording. Fixed as in 3.2.
- **Holding Esc** to cancel a recording let its repeats close the window. Fixed as in decision 2.
- **The `Mode` label** stayed at full contrast while its pop-up was dimmed. It was dimmed too, until 12 stopped dimming `Mode` at all.

## 11. Addendum: a checkbox for Stop at low battery

Asked by the owner after trying the shortcut box: `Stop at low battery` gets a checkbox like the other guardrails, and its `Never` level goes.

- **What the user sees.** `[✓] Stop at low battery [5% ▾]` in place of the label and the pop-up. The pop-up offers `5%` (the default) to `30%`, and a level set with `defaults write` that the list does not offer, as before. It is dimmed while the box is off. The box is on by default, as the check was.
- **Storage.** A new Bool, `lowBatteryGuardEnabled`, next to the level in `minBatteryPercent`, so that turning the box off keeps the level, as the shortcut box keeps the shortcut. When the Bool has never been stored, the box counts as on unless `minBatteryPercent` is 0, the `Never` of 2.2.0 and earlier. The level now reads 5 to 50 only, so a stored 0 shows the default, 5%.
- **The CLI.** Unchanged. `PreferencesSnapshot.minBatteryPercent` is 0 while the box is off, and `AwakeCLI` already passes `--min-battery off` for 0, so a session gets the same arguments as before.
- **Code.** `InstallSupport.swift`: the key, `lowBatteryGuardEnabled`, the 5 to 50 range, the choices without 0, and the snapshot. `SettingsWindowController.swift`: `batteryBox` in a row with the pop-up, `batteryBoxChanged(_:)`, the pop-up enabled only while the box is on, and no `Never` item. The rule is two lines in `PreferencesStore`, which the checks do not build, so it is left to QA.
- **Docs.** README's `Stop at low battery` item, and a Changed entry in the CHANGELOG.
- **QA.**
  1. After an update from 2.2.0 with `Never` chosen: the box is off and the dimmed pop-up shows `5%`. With `10%` chosen before: the box is on at `10%`.
  2. Turn the box off and on again: the level stays. With the box off, the pop-up is dimmed and cannot be opened.
  3. Unplug the Mac and choose a level above the charge (`defaults write net.kaenmaki.awake.statusbar minBatteryPercent -int 50` when the charge is above 30%). With the box on, a start from the menu bar is refused with `Awake failed`, naming the battery. With the box off, the session starts.

## 12. Addendum: Start default session in the menu

Asked by the owner, from the open point in the 2.2.0 shortcut plan (11): a menu item that does what the keyboard shortcut does, so that the shortcut can be found.

- **Where.** In the Ctrl-click menu's first group, which acts on the session: after the status line and `Add …`, before the separator above `Help` and `Settings…`, which open windows.

  ```
  Awake is off                              Awake is on and has 25 minutes left
  Start default session   ⇧⌘A               Add 1 hour
  ────────────────────────                  Stop session   ⇧⌘A
  Help                                      ────────────────────────
  Settings…               ⌘,                …
  ```

- **Title.** `Start default session` while Awake is off, and `Stop session` while it is on, as a press of the shortcut (and a click on the icon) starts or stops. Written in sentence case, as the owner asked.
- **What it does.** What a press of the shortcut does (the 2.2.0 shortcut plan, 3.2): `startDefaultSession()` or `stopAwake()`, through the intent `.defaultStart`, the renamed `.shortcutStart`. It is dimmed while a command runs, and does nothing if one is still running when it is chosen. The item's tag keeps what its title offered, so it never does the opposite: a `Start default session` chosen after Awake started meanwhile only says `Awake is already on` (`startOnlyIfOff`), and a `Stop session` chosen after Awake stopped does nothing.
- **Its mode.** The shortcut's `Mode`, also while the shortcut is off. So `Mode` is no longer dimmed with the shortcut button (decision 8). The note under the shortcut and the pop-up's tooltip say so.
- **The shortcut beside it.** Shown only while the hot key is registered: the item's `keyEquivalent` and `keyEquivalentModifierMask` come from `StartShortcut.menuKeyEquivalent` and `Modifiers.cocoaFlags`. A special key uses AppKit's character (`menuKeyCharacters`, compared with AppKit's constants in the check); another key its one-character label, lowercased; a `Key 42` label shows nothing.
- **A press while the menu is open.** The hot key takes the press, as the 2.2.0 shortcut plan (4) registers it exclusively on the dispatcher target, so the menu's key equivalent never fires. The press closes the menu with `cancelTracking()`, as a key equivalent of the menu's own would; otherwise the menu would stay open with a stale title. Should the menu act on its key equivalent after all, the second action finds a command running and does nothing (the handler's `pendingCommand` guard, or the shortcut's beep). QA 2 below.
- **Tooltip.** "Starts a session of 20 minutes, in the mode set under Keyboard shortcut in Settings.", or "without an end time" for Indefinitely.
- **QA.**
  1. With Awake off, the menu shows `Start default session` with `⇧⌘A` beside it while the shortcut is on, and without it while off. Choosing it starts a session of the default length in `Mode`'s mode, also with the shortcut off.
  2. With the menu open, press ⇧⌘A: the menu closes, one session starts, and no second action follows.
  3. With a session running, the item reads `Stop session` below `Add …`, and stops it.
  4. With `Mode` at `Lid-closed` and password-free mode off, the item asks for the password as the shortcut does.
  5. The Settings window, now a row and two note lines taller, fits on the smallest display in use, for example 1280×800, or scrolls there (16).

## 13. Addendum: the time to add

Asked by the owner: `Add 1 hour` should add a time chosen in Settings.

- **Settings.** `Time to add` in the `Session lengths` group, below `Default session`, with its pop-up lined up with that one (the label-width constraint is activated after `group(…)`, as 10 requires). It offers the session lengths, without `Indefinitely`, and keeps the chosen time in the list when that length is removed, so that removing a length never changes it (`PickerSettings.addChoices`). The note below says what it is for.
- **Storage.** `addTimeSeconds` in the app's preferences, read with `PickerSettings.resolvedAddSeconds`: a length the picker could list (1 minute to 365 days, whole minutes), otherwise an hour. The CLI does not read it. `Restore defaults` sets it back to an hour.
- **The menu.** `Add` followed by the time, from `PickerSettings.lengthLabel(seconds:)`: `Add 1 hour`, `Add 30 minutes`, `Add 1 hour 30 minutes`. `addTime(_:)`, the renamed `addOneHour(_:)`, passes it as `--duration-seconds`; the CLI already adds what fits within 365 days, and says so.
- **Checks.** `resolvedAddSeconds` and `addChoices` are in `PickerSettings.swift`, which the start shortcut check builds, so it checks them.
- **Not done.** A submenu with several times to add (for example the session lengths). One configurable item keeps the menu short; the owner can ask for more.
- **QA.**
  1. Choose `30 minutes` under `Time to add`: the menu of a running session reads `Add 30 minutes`, and it adds 30 minutes.
  2. Remove `30 minutes` from the list: `Time to add` still shows it. Choose another time: `30 minutes` leaves the pop-up.
  3. `Restore defaults`: `Time to add` is `1 hour` again.
  4. The `Default session` and `Time to add` pop-ups line up.

## 14. Addendum: sentence case

Asked by the owner: text capitalizes only the first word of a sentence and names. A scan of every string literal in the app, the picker, the launchers and the scripts, and of the README, found these in title case, now in sentence case:

- the Ctrl-click menu: `Install helper…`, `Stop Awake and quit`;
- Settings: `Restore defaults`, and the window's title, `Awake settings`;
- the hidden main menu: `Select all`;
- the installer and uninstaller: `Awake installation complete`, `Awake installation failed`, `Awake uninstall complete`, `Awake uninstall failed`;
- the README's level-2 headings, such as `Menu bar app`, `Security notes` and `GUI input`, and the text that points to them.

Kept, as names and titles: `Awake`, `Mac`, macOS's and Apple's names, key names such as `Ctrl` and `Esc`, and a title named in a sentence: a UI element such as `Start without password` or `Settings`, a section such as `Security notes` in "see Security notes", or the picker's `Indefinitely` row in `Include Indefinitely`. Past CHANGELOG entries and the older plans keep the names the UI had then.

- **The launchers.** `Install Awake.app` and `Uninstall Awake.app` hold binaries built from `tools/gui-app-launcher.swift` and committed. They are rebuilt with `tools/build-gui-launchers.sh` on a Mac before the release; until then they show the old titles.
- **Default session.** `Default selection`, the row the picker starts on, is now `Default session`, as the owner asked, so that it matches `Start default session` in the menu (12), which starts a session of that length. The session's mode is the shortcut's `Mode`, which the menu item's tooltip names. The picker and the terminal prompt show no label, so only Settings, the README and this plan change.
- **Help.** `About / Instructions...` joined two alternative titles. As the owner chose, the menu item is now `Help`, without an ellipsis, as it opens its window without asking anything, and the window is titled `Awake help` instead of `About Awake`. The window shows the whole README: what Awake does, how to use it, and its version, license and author.
- **QA.** The Ctrl-click menu, with a session running and with the helper missing; the Settings window; and a run of `Install Awake.app` after rebuilding the launchers. Also `Help`, and the title of the window it opens.

## 15. QA carried over from the 2.1.0 and 2.2.0 plans

These checklists come from the deleted plans (see Earlier plans) and were never run on a Mac. They are run in phase 3 with 6 and the addenda's lists, and changed here where 2.3.0 changed the app. Items that 2.3.0's own lists already cover are left out. If some 2.1.0 items were run for 2.1.0, skip those.

### 15.1 Stop when unplugged (2.2.0)

1. **The output.** `pmset -g batt` on an Apple silicon MacBook, and on an Intel one if available, starts with `Now drawing from 'AC Power'` on the adapter and `Now drawing from 'Battery Power'` after unplugging. On a desktop with a UPS connected by USB, if one is available, it shows `'UPS Power'` while the UPS runs on its battery.
2. **Lid closed.** With `Stop when unplugged` on, start a 30-minute lid-closed session on the adapter, close the lid, and unplug. The Mac sleeps within about 10 seconds: `pmset -g log` afterwards shows the sleep that soon after the switch to battery. After waking, the notification says `Awake stopped: the Mac was unplugged`.
3. **Reconnecting.** Pull the MagSafe connector and put it back within a second or two: the session goes on. The same with a dock that is unplugged and plugged back quickly.
4. **Started on battery.** Start on battery with the option on: the session goes on. Plug in, then unplug: it ends.
5. **Option off.** With the option off, unplugging changes nothing.
6. **Lid open.** A lid-open session with the option on ends when unplugged with the lid open, and the Mac is not put to sleep.
7. **External display.** With the lid closed and an external display connected, unplugging ends the session and leaves the Mac to macOS, as the other guardrails do.
8. **Updating.** From 2.1.0, the update asks for the password once, for the helper (protocol 9), and the next lid-closed start does not ask again; `Stop when unplugged` is off afterwards. From 2.2.0 nothing is asked, as 2.3.0 changes no helper.

### 15.2 The heat note (2.2.0)

1. **Measuring.** Start a 20-minute lid-open session on AC. In another Terminal window, log the thermal state every 5 seconds as the reference, since `pmset -g therm` and Activity Monitor do not show it: `while :; do printf '%s %s\n' "$(date +%T)" "$(osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState')"; sleep 5; done`. Load every core for 10 minutes: `for i in $(seq $(sysctl -n hw.ncpu)); do yes > /dev/null & done`, then `killall yes`. The seconds at each level in the saved summary (`defaults read net.kaenmaki.awake.statusbar lastSessionHeat`), including `secondsAtLeastFair`, should match the log to within a poll or two. Unless the log reached serious (`2`), the note stays hidden. A MacBook Air heats up sooner; on a MacBook Pro this load may not leave nominal.
2. **Nothing to report.** Run a 10-minute idle session, and one while charging from a low charge, unplugging and plugging the adapter in between. The note stays hidden both times.
3. **Lid closed.** Run a 30-minute lid-closed session on battery with the lid closed. Afterwards, `samples` should be about 180 and `secondsWatched` about 1,800, proving App Nap did not stop the recording. The note appears if the Mac got hot.
4. **Guard ending.** A session ended by the guard reads `…, so Awake ended it.` The guard counts serious only with the lid closed, so a MacBook Air under the load of item 1, with its lid closed, is the likeliest way to get there. If the Mac cannot be made hot enough safely, the heat report check covers it instead.
5. **Mid-session start.** With the app quit, start `awake --duration 10m` in Terminal, then open the app. Afterwards `lastSessionHeat` has `watchedFromStart = 0`, and the note, if shown, begins `Last session (from HH:MM):`.
6. **Relaunch during a session.** During a 10-minute session, run `killall AwakeStatusBar`, wait two minutes, and open the app again. Afterwards `watchedFromStart` is still 1, and `secondsWatched` is about two to three and a half minutes short of the session's length: the two minutes, up to about a minute the app had not saved before it was killed, and up to a poll at the start and at the end.
7. **Quitting and updating.** End a session with `Stop Awake and quit`, then open the app again. Separately, run the installer during a session. Each time, `lastSessionHeat` holds that session's token with `endedAt` at the session's end, and `sessionHeatInProgress` is gone.
8. **CLI session with the app running.** A session started with `awake --duration 15m` in Terminal is recorded too.
9. **Settings window.** Open Settings with a report and without one, and keep it open while a session with a report ends. The note appears under `Stop when too hot`, lined up with its title, the window grows and shrinks with it without clipping or a blank strip, and the right margin stays as it is.

### 15.3 The keyboard shortcut (2.2.0)

With the `Shortcut` box on. Delete, `Clear`, turning the shortcut on and off, conflicts with a second Awake.app, relaunching with the box on and off, and VoiceOver are in 6.

1. **Recording.** Record ⌃⌥⌘A: the button shows `⌃⌥⌘A`.
   - ⌘W during recording does not close the window.
   - ⌘D, ⌥⇧A and plain A are refused with the rule's text, and ⇧⌘3 with the macOS text.
   - Click outside the window while recording: recording ends.
2. **Start from another app.** With Safari frontmost and `Mode` at `Lid-open, display on`, press the shortcut.
   - The session starts without the picker, and the icon turns on.
   - The notification reads "The Mac will stay awake while the lid remains open for 20 minutes."
   - Safari does not receive the key press.
   - `awake --status` shows 20 minutes (or the `Default session`).
3. **Stop.** Press it again: the session stops and `Awake stopped` appears.
4. **Lid-closed.**
   - With `Mode` at `Lid-closed` and password-free mode off, the macOS administrator dialog comes to the front with keyboard focus. Cancel starts nothing; the password starts the session.
   - The same with `Use custom password dialog`, which then shows Awake's dialog.
   - With password-free mode on, the press alone starts the session.
5. **Display.** `Lid-open, display can sleep` starts a session whose status ends `(keep the lid open; the display may sleep)`.
6. **Indefinitely.** With `Default session` at `Indefinitely`, the note says "without an end time", and the notification "until you stop it".
7. **Started elsewhere.** Start `awake --backend caffeinate --duration 5m` in Terminal and press the shortcut within 10 seconds. `Awake is already on` appears, and the session still has about 5 minutes left.
8. **Busy.** Press it while the administrator dialog of item 4 is open: a beep, and no second dialog after it closes.
9. **Another app's shortcut.** Record a shortcut that another running app, such as a launcher or a window manager, already uses, and write down what happens: Awake refuses it (`Another app uses …`), or both apps react. Then quit and reopen Awake while the other app holds it, and check for the launch notification.
10. **Menus and secure input.** Press it while another app's menu is open, and while a password field in Safari has focus. Write down whether it fires; nothing else should happen. (Awake's own menu is 12, QA 2.)
11. **macOS versions.** On the owner's macOS, and on 15 if available, ⇧⌘A and ⌃⌥⌘A register. On 12.5, if available, the app builds and the shortcut works.
12. **Layout.** With a Finnish or German layout, record ⌃⌥⌘ with the key right of L: the label shows `Ö`.
13. **Relaunch and quit.** Quit Awake from the menu: the shortcut does nothing. Open Awake again: it works without a new recording. Run the installer: afterwards it still works, with no permission prompt.
14. **The picker.** After a start with the shortcut, or with `Start default session`, in lid-open mode, a click on the icon opens the picker with the lid checkbox as last chosen there.
15. **Notifications off.** With Awake's notifications turned off in System Settings, a press still starts and stops. The icon, and the sound if `Sound on` is set, show it.

### 15.4 Flexible sessions (2.1.0)

1. **The sleep step.** Lid closed, once on battery and once on AC, with another process holding `caffeinate -i`: after a `--duration-seconds 60` session times out, the Mac sleeps within seconds (`pmset -g log`).
2. **Indefinite lid-closed.** `pmset -g` shows `SleepDisabled 1` throughout, and `--stop` restores it. After `kill -STOP` of the timer, the guard takes over after 60 s.
3. **Until across sleep.** An Until session that spans system sleep ends within seconds of waking.
4. **Lid-open indefinite.** After `kill -9` of the runner, the assertion is gone within seconds (`pmset -g assertions`).
5. **Low battery.** With `--min-battery 50` and the lid closed, the session ends, `SleepDisabled` is 0, and the Mac sleeps.
6. **From 2.0.0.** With 2.0.0 lid-closed and lid-open sessions running, replace only `bin/awake`, then check `--status`, `--status-json`, `--duration-seconds 60` and `--stop`. Lid-closed: one password prompt that updates the helper, then the exit 6 text. Lid-open: time is added.
7. **Forced restart.** Hold the power button during an indefinite lid-closed session: after startup `pmset -g` shows the values from before the session, and `awake --status` shows `Awake has been off …`, with the reason `restart` in `--status-json`. Repeat with the LaunchDaemon unloaded: the status shows the leftover sentence, `leftover_settings` is true, the app notifies once, and `--stop` restores the values from before the session.
8. **Time zones.** Change the time zone during `-w` sessions in both modes: they keep running. The menu and `awake --status` show the same Until clock time.
9. **Battery default.** With no battery settings stored, `Stop at low battery` is on at 5% (11 covers the older stored values).
10. **The picker.**
    - 1 and 16 rows without clipping;
    - three buttons side by side;
    - double-click starts;
    - keyboard-only use and VoiceOver;
    - `Custom…` For (the 365-day limit), Until (the hint, the minute rollover, 12- and 24-hour systems) and While (apps, terminal commands, shells excluded, a process that exits before Start);
    - Back keeps the state.
11. **Custom password dialog.** Each end mode with `Use custom password dialog`, including a password dialog left open past the Until time.
12. **Settings.**
    - add, remove, `Include Indefinitely` and `Restore defaults`;
    - every setting survives a relaunch;
    - `Launch at login` and `Start without password`, including a cancelled prompt;
    - `defaults write` from Terminal is picked up by the next picker;
    - ⌘W closes Settings and Help, and the `+` field supports ⌘C and ⌘V;
    - a session that ends while the password-free prompt is open gives one `Awake stopped` notification.
13. **Add.** `Add …` appears and disappears correctly for each end mode.
14. **Installing during a session.** Installing over a running older app with an active session shows the stop line.
15. **Tied to a process.** `awake -- vim`, then Ctrl+Z and `fg`: the session keeps counting. With the lid closed on battery, `awake -- sleep 30` ends and the Mac sleeps.

## 16. Addendum: a scrolling Settings window

Asked by the owner after 12 and 13 made the window taller: the Settings window scrolls when it would be taller than the screen.

- **Layout.** The sections' stack is the document of an `NSScrollView`, which is the window's content view. The document is a flipped view, so the content starts at the top; the stack is pinned to its edges, and it is pinned to the clip view's top, left and width. The scroll view draws no background, and its scroller shows only while there is something to scroll.
- **Size.** `fitWindowToContent()` still sizes the window to the stack's fitting size, rounded up, but at most to the screen's visible frame (below the menu bar, above the Dock) minus the title bar. When that cuts the height, and the user has scroll bars always shown (`NSScroller.preferredScrollerStyle == .legacy`), the window grows by the scroller's width, so that the content keeps its width. The window keeps its top edge, and is then moved to stay within the visible frame.
- **When.** At build, whenever the heat note or the shortcut note changes (as before), each time Settings is shown (after centering, which can put a tall window's top under the menu bar), when the window moves to another screen, when a screen's size changes, and when the scroll bar setting changes.
- **Unchanged.** The window does not resize by hand. On screens where it fits, it looks as before.
- **QA.**
  1. On a 1280×800 display (or with a larger display set to a resolution with that height), open Settings: the window reaches from below the menu bar to the Dock, and the content scrolls down to the `Session lengths` note. Esc still closes it.
  2. With System Settings → Appearance → Show scroll bars at `Always`, the scroll bar does not cover the content's right edge. Switching the setting while Settings is open resizes it.
  3. On a large display, the window has no scroll bar and looks as in the owner's screenshots.
  4. Drag the window from a large display to a small one: it shrinks to fit and scrolls; back on the large one, it grows again.
  5. Tab through the controls with Full Keyboard Access on: the focused control scrolls into view.
  6. Scrolling over the session lengths list scrolls the list; elsewhere it scrolls the window.

## 17. Addendum: a Homebrew tap

Asked by the owner: an easy install with Homebrew, updated at each release without manual steps.

- **Why a tap and a cask.** The official Homebrew repositories need a well-known project, and their casks an app signed with a Developer ID and notarized; a formula there cannot install the root helper. A tap of the owner's own, `anttikaenmaki/homebrew-awake`, has no such rules, and `brew install anttikaenmaki/awake/awake` finds it by its name. A cask, unlike a formula, can run an installer script outside Homebrew's sandbox, so it runs `install-awake.sh` unchanged: the app is built on the user's Mac, as from a git clone, and needs no signing. Homebrew requires the Command Line Tools, so the build's one prerequisite is always there.
- **The cask** (`tools/homebrew/awake.rb`, a template with `@VERSION@` and `@SHA256@`):
  - `url`: the release's source archive, `awake-X.Y.Z.tar.gz`, attached to the GitHub release; its top folder is `awake-X.Y.Z`;
  - `depends_on macos: ">= :monterey"`; the installer checks for Swift 5.7, that is macOS 12.5;
  - `preflight`: removes `com.apple.quarantine` from the unpacked sources. Homebrew quarantines them, and the app built from them would inherit the attribute through its copied files, which a git clone never has;
  - `installer script`: `install-awake.sh`. Without a terminal it asks for the helper's password in the macOS dialog;
  - `uninstall script`: `scripts/homebrew-uninstall.sh`;
  - `zap trash`: the preferences and `~/Library/Application Support/Awake`;
  - `caveats`: where Awake goes, and what upgrade and uninstall do.
- **Upgrades keep Awake.** Homebrew runs a cask's uninstall step also before an upgrade or a reinstall (not verified here). The uninstaller removes the settings and the helper, which would ask for passwords and turn off password-free mode and Launch at login at every upgrade. So `homebrew-uninstall.sh` reads the brew command from the command line of its `brew.rb` ancestor and runs `uninstall-awake.sh` only for `uninstall`, `remove` and `rm`. For `upgrade` and `reinstall`, and when it cannot tell, it leaves Awake in place, and the new version's installer updates it as it does from a git clone. The safe side is kept on purpose: should Homebrew change how it runs the script, Awake stays installed rather than losing its settings.
- **Publishing** (`.github/workflows/homebrew-tap.yml`): the release workflow calls it after publishing a release, as a release made with the workflow's own token starts no other workflow. It can also be run by hand for a version. It attaches `git archive --prefix=awake-X.Y.Z/` of the tag to the release unless the release has the archive already, and takes the archive's SHA-256. With the secret `HOMEBREW_TAP_TOKEN`, it clones the tap, writes `Casks/awake.rb` with `tools/homebrew/render-cask.sh` from the tag's template, checks it with `ruby -c`, copies `tools/homebrew/README.md`, and commits and pushes if anything changed; an empty tap gets its first commit on `main`. Without the secret, it attaches the archive and says that the tap was not updated.
- **First release.** The tap serves 2.3.0 and later: 2.2.0 has no uninstall step for it, and the workflow refuses a tag without the template, the README or the script.
- **CI.** Shell syntax of `tools/homebrew/*.sh`; the template rendered and checked with `ruby -c`; and the uninstall step under a stand-in `brew.rb`, for `uninstall`, `uninstall --zap`, `rm`, `upgrade`, `--verbose upgrade`, `reinstall`, and outside brew.
- **The owner's one-time setup,** also in the workflow's header:
  1. Create the public repository `anttikaenmaki/homebrew-awake`; it may stay empty.
  2. Create a fine-grained personal access token for that repository only, with Contents: Read and write.
  3. Add it to this repository as the Actions secret `HOMEBREW_TAP_TOKEN`, and renew it before it expires.
- **QA** (after 2.3.0 is released and the tap has its cask):
  1. On a Mac with Homebrew and without Awake, `brew install anttikaenmaki/awake/awake`: the installer's output appears, the helper's password dialog comes up, Awake.app starts, and `awake --status` works in a new Terminal window. `xattr ~/Applications/Awake.app` shows no `com.apple.quarantine`, and the app opens without a Gatekeeper warning.
  2. Change some settings, then `brew reinstall awake`: the output says that Awake is kept, the installer runs again, and the settings, password-free mode and Launch at login stay.
  3. After 2.4.0 or a test release, `brew upgrade`: the same as item 2, with the new version installed.
  4. `brew uninstall awake`: the uninstaller runs and asks for the password to remove the helper; the app, the command and the settings are gone.
  5. Over an Awake installed from a git clone, `brew install`: it installs over it and keeps the settings.
  6. Run the Homebrew tap workflow by hand for the released version: it finds the archive and says that the tap already has it.

