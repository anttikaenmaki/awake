# Plan: Esc closes Settings and Help, and on/off boxes for the keyboard shortcut and low battery

- Status: phases 1 and 2 done (the code, the check and the docs; green on CI, then fixed after a multi-agent review, 10), and the low battery box of 11; phases 3 and 4 to do
- Target version: 2.3.0 (the changelog rule: Added and Changed make a minor version); no helper, CLI or picker change
- Written: 2026-09-30, against 2.2.0 (commit `f5f29dd`); the owner's review then removed `Clear` for good and added the Help window
- Scope: `app/AwakeStatusApp`, `tests/app/start-shortcut-check.swift`, `README.md`, `CHANGELOG.md`

## How this plan was checked

- It was written on Linux, from the code, without a Swift compiler. Key routing, focus and the keyboard layout lookup need a real Mac, so they are in the QA checklist (6). Claims about macOS that could not be checked from here are marked there and in 9.

## 1. Goals

1. Esc closes the Settings window and the About / Instructions (Help) window, as it closes most macOS settings and utility windows. Today only the close button and ⌘W do.
2. The keyboard shortcut gets a checkbox that turns it on or off, off by default. There is then always a key combination to show: `⇧⌘A` until another is recorded.
3. The shortcut button and the `Mode` pop-up keep their left edges lined up, as they are now.
4. Nothing changes for anyone who does not turn the shortcut on, and a shortcut recorded in 2.2.0 stays on after the update.

Not in scope:

- a shortcut that is on out of the box, which `start-shortcut.md` (1) also left out;
- any change to what a press does, the allowed combinations, or the `Mode` choices.

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | How Esc closes the window | A small `NSWindow` subclass, `EscapeClosableWindow`, in its own file and used by the Settings and Help windows (decision 11), whose `cancelOperation(_:)` calls `performClose(_:)`. It ignores an auto-repeated Esc (decision 2). AppKit sends `cancelOperation:` for Esc and ⌘. when no view in the key window takes Esc as its key equivalent, starting at the first responder and going up the responder chain, which always ends at the window. So it works whatever has focus, and ⌘. closes the window too, as macOS convention has it. Rejected: a local event monitor, which would have to be ordered against the recording monitor, and a hidden button with Esc as its key equivalent. |
| 2 | Esc while recording a shortcut | It still only cancels recording. The recording monitor returns nil for Esc, so the window never sees it. A second Esc closes the window. The monitor is gone once recording ends, so the repeats of an Esc held down would reach the window: `cancelOperation(_:)` ignores a key-down that `isARepeat`, and only a fresh press closes. |
| 3 | The default combination | `⇧⌘A`, as the owner asked. It passes every rule of `start-shortcut.md` (5): two modifiers, one of them ⌘, not one of macOS's, and not one of the standard shortcuts. |
| 4 | Which physical key | The key that types A in the keyboard layout in use when the box is first turned on, stored then like a recorded shortcut. Carbon hot keys go by key code, not character, and on a French or Belgian AZERTY layout the key with code 0 (`kVK_ANSI_A`) types Q: a fixed key code would show `⇧⌘A`, react to ⇧⌘Q, and so take Log Out from every app. Code 0 is the fallback when the layout cannot be read. On US, Finnish, Swedish, German, UK, Dvorak and Colemak layouts it is code 0 anyway. |
| 5 | When the default is stored | When the box is turned on and no shortcut is stored. Until then `startShortcut` stays absent and the window shows `StartShortcut.defaultShortcut()`, whose label is `A` whatever the key code. Once stored, the shortcut keeps its key when the layout changes, as a recorded one does. |
| 6 | The on/off setting | A new Bool, `startShortcutEnabled`. When it has never been stored, it counts as on if a shortcut is stored, so a 2.2.0 shortcut stays on, and as off otherwise. Turning the box off keeps the stored shortcut, so turning it on again brings back the same combination. |
| 7 | `Clear` and Delete | `Clear` goes, as the owner confirmed: with a combination always shown, "no shortcut" is no longer a state, and the box turns the shortcut off. No `Default` button takes its place: recording ⇧⌘A does the same. Delete and Forward Delete alone, which cleared the shortcut while recording, become ordinary keys: without modifiers they get the rule's text, "Use two or more modifier keys, including ⌃ or ⌘." |
| 8 | Controls while off | The shortcut button, the `Mode` pop-up and its label are dimmed while the box is off, as macOS dims controls that depend on a checkbox. The note stays, in grey, so it still says what turning it on does. |
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
- The About / Instructions window closes on Esc as well. Whether it also does in the plain-text message it shows when the bundled guide cannot be read is left to QA 3 (9).

### 3.2 The Keyboard shortcut group

```
Keyboard shortcut
[✓] Shortcut  [      ⇧⌘A      ]
    Mode      [ Lid-closed   ▾ ]
From any app, starts a session of the default length, now 20 minutes,
or stops the running one, like a click on the icon. Lid-closed mode asks
for your password unless Start without password is on.
```

- **Alignment.** Both rows keep a spacing of 8 after their first view. The `Mode` row has a left inset of `titleIndent(of: shortcutBox)`, the helper the heat note already uses, and the `Mode` label is `shortcutBox`'s width minus that inset. The pop-up then starts at the checkbox's width plus 8, where the button starts, and `Mode` lines up with the checkbox's title.
- **Off** (the state after installing, unless a 2.2.0 shortcut was recorded). The box is clear, the button shows `⇧⌘A` (or the stored shortcut) dimmed, the `Mode` pop-up and label are dimmed, and the note is grey. ⇧⌘A reaches other apps as before.
- **Turning it on.** The stored shortcut, or else `⇧⌘A` for the current layout (decisions 4 and 5), is registered at once. The default is first checked against macOS's own shortcuts, as a recorded one is; a problem is shown as in decision 9.
- **Recording.** As in 2.2.0, but only while the box is on (decision 8), and Delete no longer clears (decision 7). A recorded shortcut is registered and stored as before.
- **Turning it off.** Ends any recording first, then unregisters the shortcut. The stored combination and `Mode` stay. The box's new state is read before recording ends, as ending it redraws the box as stored.
- **The note.** Unchanged texts. The red problem text is shown only while the box is on.
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
  - `shortcutModeLabel`, the `Mode` label, kept so that it can be dimmed.
  - The shortcut row is `[shortcutBox, shortcutButton]`, and the `Mode` row is inset and sized as in 3.2, in place of the label-width constraint. The width constraint is activated after `group(…)`, which is the first view the two rows share: AppKit raises an exception for a constraint between views without a common ancestor.
  - `clearShortcutButton`, `clearShortcut(_:)` and the Delete branch of `handleRecordingEvent(_:)` go.
  - `reloadShortcut()` sets the box, shows `preferences.startShortcut ?? StartShortcut.defaultShortcut()`, enables the button and the pop-up only while on, dims the `Mode` label with `.disabledControlTextColor` while off, and shows the host's problem only while on.
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

1. **Esc.** Open Settings and press Esc: the window closes. Again with Full Keyboard Access on and focus on a checkbox, the `Mode` pop-up, the session lengths list, and the `Default selection` pop-up. ⌘. closes it too.
2. **Esc and recording.** Click the shortcut button, press Esc: recording ends and the old shortcut is shown. Again, holding Esc for two seconds: recording ends and the window stays. Press Esc again: the window closes. Click the shortcut button, then uncheck the box: recording ends and the shortcut is off at once.
3. **Esc elsewhere.** With the add-a-length popover open, Esc closes only the popover. With the `Mode` menu open, Esc closes only the menu.
   - **Help window.** Open About / Instructions from the Ctrl-click menu and press Esc, before and after clicking into the page: the window closes. Also in full screen, where it should close the window and leave the space. If the plain-text message can be forced (a build without `README.md` in its Resources), note whether Esc closes it too.
4. **Fresh install.** `defaults delete net.kaenmaki.awake.statusbar startShortcut` and `… startShortcutEnabled`, then relaunch and open Settings. The box is off; `⇧⌘A`, the `Mode` label and its pop-up are dimmed. ⇧⌘A in Finder opens Applications.
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

- **README, Settings window:** a clause in its introduction: "and Esc or Command-W closes it". **README, Ctrl-click menu:** `About / Instructions...` gets "Esc or Command-W closes it."
- **README, `Keyboard shortcut` group:** "It is off until you check `Shortcut`, and it is `⇧⌘A` (Shift-Command-A) until you record another". `Shortcut`: the box turns it on or off, and a click on the button records another combination while it is on, with the existing rules; "Esc cancels" stays, "Delete or `Clear` removes the shortcut" goes. `⇧⌘A` goes on the key that types A when the box is first checked, and stays on that key after a layout switch. `Mode`: dimmed while the shortcut is off. A note that while it is on, the shortcut no longer reaches other apps, for example Finder's `⇧⌘A` for `Go` → `Applications`, so record another if you use that.
- **README, Menu Bar App:** "A keyboard shortcut, once you record one in Settings" becomes "once you turn it on in Settings".
- **CHANGELOG `[Unreleased]`:**
  - Added: Esc closes the Settings and About / Instructions windows.
  - Changed: the keyboard shortcut has a `Shortcut` checkbox that turns it on or off, off by default, and is `⇧⌘A` until you record another, using the key that types A in your keyboard layout. `Clear` is gone, and Delete or Forward Delete no longer clears it while one is being recorded. A shortcut recorded in 2.2.0 stays on. This goes under Changed, not Removed, which `tools/release.sh` would read as a major version.

## 8. Phases

1. Esc in both windows (decisions 1, 2 and 11, QA 1 to 3) and its README and CHANGELOG lines.
2. The shortcut box: `StartShortcut.swift` and its check, then the app and the docs. Phases 1 and 2 went in as one commit, as they touch the same Settings code.
3. QA (6) on a real Mac.
4. Version 2.3.0 with `tools/release.sh minor`.

## 9. Risks and open points

- **`⇧⌘A` in other apps.** While the shortcut is on, Carbon takes ⇧⌘A from every app: Finder's `Go` → `Applications`, and ⇧⌘A in apps such as Chrome. It is off by default, the README says so, and the combination can be changed. Accepted.
- **Unverified here** (QA 1 to 3, 9 and 10):
  - that Esc reaches `cancelOperation(_:)` with every control focused, the documented behaviour, and from the Help window's web view;
  - that `NSApp.currentEvent` in `cancelOperation(_:)` is the repeated key-down of a held Esc (QA 2). Where it is not, a held Esc closes the window, as before the fix;
  - `UCKeyTranslate` with the ASCII-capable layout on macOS 12.5 and later, and on AZERTY;
  - that `kEventHotKeyExclusive` reports another app's ⇧⌘A, as `start-shortcut.md` (11) also leaves to QA.
- **Losing Delete and `Clear`.** A day after 2.2.0, few users will have learnt them, and the box does what they did. Accepted.
- **Switching between AZERTY and another layout.** Once stored, `⇧⌘A` stays on its physical key, as every recorded shortcut does (`start-shortcut.md`, 11). Someone who turns it on with AZERTY and later types with a US layout presses that key as ⇧⌘Q, so Awake then takes Log Out's keys and not ⇧⌘A; the other way round, the ANSI A key becomes AZERTY's Q. Looking the key up again at every launch would follow the layout, but would make the stored default behave unlike a recorded shortcut, and would still go wrong for a layout switch while Awake runs. Accepted: the README says the shortcut stays on its key, and recording it again moves it.
- **The Help window's plain-text message.** When the bundled guide cannot be read, the window shows a plain `NSTextView`. That view may answer Esc with its own `cancelOperation:` (text completion) and not pass it on, so Esc may not close the window then. Normal installs never show it. Left to QA 3.

## 10. Review

A multi-agent review of the first commit (five reviewers, each finding checked by a skeptic, and a completeness critic) found, besides doc fixes:

- **The `Mode` label's width constraint** was activated before the two rows shared a superview. AppKit raises an exception for that, so Settings would not have opened. Fixed as in 4.
- **Unchecking the box while recording** read the box's state after ending the recording, which redraws the box as stored, so the click only cancelled the recording. Fixed as in 3.2.
- **Holding Esc** to cancel a recording let its repeats close the window. Fixed as in decision 2.
- **The `Mode` label** stayed at full contrast while its pop-up was dimmed. It is now dimmed too.

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

