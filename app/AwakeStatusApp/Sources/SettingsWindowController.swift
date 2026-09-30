// Copyright (C) 2026 Antti Käenmäki

import AppKit

/// What the Settings window needs from the status bar controller: the real
/// state of the settings that are more than a stored value, and the way to
/// change them.
protocol SettingsHost: AnyObject {
    /// Whether password-free mode is on, or nil while that is not known.
    var passwordlessSetting: Bool? { get }
    /// True while a start, stop or setup command runs.
    var isCommandPending: Bool { get }
    var isLaunchAtLoginEnabled: Bool { get }
    func setLaunchAtLogin(_ enabled: Bool) throws
    func setPasswordless(_ enabled: Bool)
    func setUseCustomPasswordDialog(_ enabled: Bool)
    /// Why the keyboard shortcut, while on, does not work, or nil.
    var startShortcutProblem: String? { get }
    /// Registers `shortcut` and stores it. Returns why it could not be.
    func setStartShortcut(_ shortcut: StartShortcut) -> String?
    /// Turns the keyboard shortcut on or off, keeping the stored one.
    func setStartShortcutEnabled(_ enabled: Bool)
    /// Turns the stored shortcut off while a new one is recorded, and on
    /// again afterwards.
    func pauseStartShortcut(_ paused: Bool)
}

/// The Settings window: General, Keyboard shortcut, Guardrails, and Session
/// lengths. Changes apply at once. The window shows each setting as it is
/// stored, or for Launch at login and Start without password as it really
/// is, and redraws whenever that changes. Esc closes it. On a screen too
/// short for it, its content scrolls.
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private weak var host: SettingsHost?
    private let preferences = PreferencesStore.shared
    private var hasCenteredWindow = false
    private var configuration = PickerSettings.load()

    private let launchAtLoginBox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let passwordlessBox = NSButton(checkboxWithTitle: "Start without password", target: nil, action: nil)
    private let customDialogBox = NSButton(checkboxWithTitle: "Use custom password dialog", target: nil, action: nil)
    private let soundBox = NSButton(checkboxWithTitle: "Sound on", target: nil, action: nil)
    private let thermalBox = NSButton(checkboxWithTitle: "Stop when too hot", target: nil, action: nil)
    /// How hot the Mac got during the last session, under `Stop when too
    /// hot`, in a row that indents it; hidden when there is nothing to
    /// report.
    private lazy var heatNote: NSTextField = note("")
    private let heatRow = NSStackView()
    private let batteryBox = NSButton(checkboxWithTitle: "Stop at low battery", target: nil, action: nil)
    private let batteryPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let unplugBox = NSButton(checkboxWithTitle: "Stop when unplugged", target: nil, action: nil)
    /// Turns the keyboard shortcut on or off.
    private let shortcutBox = NSButton(checkboxWithTitle: "Shortcut", target: nil, action: nil)
    /// The keyboard shortcut: a click records a new one.
    private let shortcutButton = NSButton(title: StartShortcut.defaultShortcut().displayText, target: nil, action: nil)
    private let shortcutModePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    /// Sized so that the pop-up lines up with the shortcut button.
    private let shortcutModeLabel = NSTextField(labelWithString: "Mode")
    /// What the shortcut does, the rule while recording, or what went wrong.
    private lazy var shortcutNote: NSTextField = note("")
    /// The key monitor while a shortcut is being recorded.
    private var recordingMonitor: Any?
    private let lengthsTable = NSTableView()
    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let removeButton = NSButton(title: "−", target: nil, action: nil)
    private let restoreButton = NSButton(title: "Restore defaults", target: nil, action: nil)
    private let indefiniteBox = NSButton(checkboxWithTitle: "Include Indefinitely", target: nil, action: nil)
    private let defaultPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    /// What Add in the menu bar menu adds to a running session.
    private let addTimePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    /// The window's content: the sections, in a scroll view, so that they
    /// scroll when the window would be taller than the screen.
    private let contentScrollView = NSScrollView()
    private var contentStack: NSStackView?

    // The popover that adds a length: [ 90 ] [minutes ▾] [Add].
    private let addPopover = NSPopover()
    private let amountField = NSTextField(string: "90")
    private let amountStepper = NSStepper()
    private let unitPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let addLengthButton = NSButton(title: "Add", target: nil, action: nil)
    private let addErrorLabel = NSTextField(labelWithString: "")
    private let units: [(title: String, seconds: Int)] = [("minutes", 60), ("hours", 3600), ("days", 86400)]

    init(host: SettingsHost) {
        self.host = host
        let window = EscapeClosableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "Awake settings"
        window.isReleasedWhenClosed = false
        buildContent(in: window)
        buildAddPopover()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showSettingsWindow() {
        reload()
        if !hasCenteredWindow {
            window?.center()
            hasCenteredWindow = true
        }
        // Also after centering, which can move a tall window's top under
        // the menu bar, and for a screen that changed since the last time.
        fitWindowToContent()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Called on every status change, so it redraws only what changed: a
    /// rebuilt pop-up or list would lose what the user is doing with it.
    func reloadIfVisible() {
        if window?.isVisible == true {
            reload(onlyChanges: true)
        }
    }

    // MARK: Layout

    private func sectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    private func note(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 360
        // Otherwise it takes the keyboard focus before the first checkbox.
        label.isSelectable = false
        return label
    }

    /// A label and a control side by side.
    private func row(_ title: String, _ control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        let line = NSStackView(views: [label, control])
        line.orientation = .horizontal
        line.spacing = 8
        return line
    }

    /// The controls of one section, left-aligned with its header, as in the
    /// picker.
    private func group(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        // A hidden view, such as the heat note, then takes no space.
        stack.detachesHiddenViews = true
        return stack
    }

    private func buildContent(in window: NSWindow) {
        for (box, action) in [
            (launchAtLoginBox, #selector(launchAtLoginChanged(_:))),
            (passwordlessBox, #selector(passwordlessChanged(_:))),
            (customDialogBox, #selector(customDialogChanged(_:))),
            (soundBox, #selector(soundChanged(_:))),
            (thermalBox, #selector(thermalChanged(_:))),
            (batteryBox, #selector(batteryBoxChanged(_:))),
            (unplugBox, #selector(unplugChanged(_:))),
            (shortcutBox, #selector(shortcutBoxChanged(_:))),
            (indefiniteBox, #selector(indefiniteChanged(_:))),
        ] {
            box.target = self
            box.action = action
        }
        passwordlessBox.toolTip = "Lets Awake's helper change the sleep settings without asking for your password. Other apps running as you could then change them too."
        thermalBox.toolTip = "Ends a session when macOS reports that the Mac is overheating, so it can sleep and cool down. Applies to the next session."
        batteryBox.toolTip = "Ends a session when the Mac runs on battery power and the charge drops to the level next to it. Applies to the next session."
        batteryPopUp.target = self
        batteryPopUp.action = #selector(batteryChanged(_:))
        batteryPopUp.toolTip = "The battery charge at which a session ends on battery power."
        batteryPopUp.setAccessibilityLabel("Low battery level")
        unplugBox.toolTip = "Ends a session when the Mac switches from the power adapter to battery power, so a closed Mac that you carry off goes to sleep. A session started on battery power is affected only after the Mac has been plugged in. Applies to the next session."

        // The note lines up with the checkbox's title, as macOS sets text
        // that explains a checkbox, and wraps early by as much, so the right
        // margin stays.
        let indent = titleIndent(of: thermalBox)
        heatNote.preferredMaxLayoutWidth = 360 - indent
        heatNote.toolTip = "Shown after a session in which the Mac got hot: macOS reported its serious or critical thermal state, or Awake ended the session because of the heat. Only sessions that end while Awake.app is running are recorded."
        heatRow.orientation = .horizontal
        heatRow.edgeInsets = NSEdgeInsets(top: 0, left: indent, bottom: 0, right: 0)
        heatRow.addArrangedSubview(heatNote)
        heatRow.isHidden = true

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("length"))
        column.width = 340
        lengthsTable.addTableColumn(column)
        lengthsTable.headerView = nil
        lengthsTable.rowHeight = 22
        lengthsTable.dataSource = self
        lengthsTable.delegate = self
        lengthsTable.usesAlternatingRowBackgroundColors = true
        lengthsTable.setAccessibilityLabel("Session lengths")
        scrollView.documentView = lengthsTable
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.widthAnchor.constraint(equalToConstant: 360).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 176).isActive = true

        addButton.target = self
        addButton.action = #selector(showAddPopover(_:))
        addButton.setAccessibilityLabel("Add a length")
        addButton.toolTip = "Add a session length."
        removeButton.target = self
        removeButton.action = #selector(removeLength(_:))
        removeButton.setAccessibilityLabel("Remove the selected length")
        removeButton.toolTip = "Remove the selected session length."
        restoreButton.target = self
        restoreButton.action = #selector(restoreDefaults(_:))
        restoreButton.toolTip = "Go back to the built-in session lengths, default and time to add."
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let listButtons = NSStackView(views: [addButton, removeButton, spacer, restoreButton])
        listButtons.orientation = .horizontal
        listButtons.spacing = 6
        listButtons.translatesAutoresizingMaskIntoConstraints = false
        listButtons.widthAnchor.constraint(equalToConstant: 360).isActive = true

        defaultPopUp.target = self
        defaultPopUp.action = #selector(defaultChanged(_:))
        defaultPopUp.setAccessibilityLabel("Default session")
        addTimePopUp.target = self
        addTimePopUp.action = #selector(addTimeChanged(_:))
        addTimePopUp.setAccessibilityLabel("Time to add")
        addTimePopUp.toolTip = "What Add in the Ctrl-click menu adds to a running session."

        shortcutBox.toolTip = "Turns the keyboard shortcut on or off. It starts or stops Awake from any app while Awake.app is running."
        // Not just "Shortcut", which the button next to it would also be.
        shortcutBox.setAccessibilityLabel("Use keyboard shortcut")
        shortcutButton.target = self
        shortcutButton.action = #selector(shortcutButtonClicked(_:))
        shortcutButton.toolTip = "Click and press keys to record another shortcut."
        shortcutButton.setAccessibilityLabel("Keyboard shortcut")
        // Wide enough for "Type the shortcut…", so the row keeps its size.
        shortcutButton.translatesAutoresizingMaskIntoConstraints = false
        shortcutButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        for mode in StartShortcutMode.allCases {
            shortcutModePopUp.addItem(withTitle: mode.title)
            shortcutModePopUp.lastItem?.representedObject = mode.rawValue
        }
        shortcutModePopUp.target = self
        shortcutModePopUp.action = #selector(shortcutModeChanged(_:))
        shortcutModePopUp.toolTip = "The mode of a session started with the keyboard shortcut or with Start default session in the Ctrl-click menu. The picker keeps its own choice."
        shortcutModePopUp.setAccessibilityLabel("Keyboard shortcut mode")
        let shortcutLine = NSStackView(views: [shortcutBox, shortcutButton])
        shortcutLine.orientation = .horizontal
        shortcutLine.spacing = 8
        let modeLine = NSStackView(views: [shortcutModeLabel, shortcutModePopUp])
        modeLine.orientation = .horizontal
        modeLine.spacing = 8
        // Mode belongs to the box, so it lines up with the box's title, as
        // the heat note does.
        let shortcutIndent = titleIndent(of: shortcutBox)
        modeLine.edgeInsets = NSEdgeInsets(top: 0, left: shortcutIndent, bottom: 0, right: 0)

        let generalGroup = group([launchAtLoginBox, passwordlessBox, customDialogBox, soundBox])
        let shortcutGroup = group([shortcutLine, modeLine, shortcutNote])
        // The label is as much narrower than the box, so that the pop-up and
        // the button line up. Only now do the two rows share a superview,
        // which a constraint between them needs.
        shortcutModeLabel.widthAnchor.constraint(equalTo: shortcutBox.widthAnchor, constant: -shortcutIndent).isActive = true
        let batteryLine = NSStackView(views: [batteryBox, batteryPopUp])
        batteryLine.orientation = .horizontal
        batteryLine.spacing = 8
        let guardrailsGroup = group([
            thermalBox,
            heatRow,
            batteryLine,
            unplugBox,
            note("Apply to sessions started afterwards."),
        ])
        let defaultLine = row("Default session", defaultPopUp)
        let addTimeLine = row("Time to add", addTimePopUp)
        let lengthsGroup = group([
            scrollView,
            listButtons,
            indefiniteBox,
            defaultLine,
            addTimeLine,
            note("Shown in the picker. The default is also what Enter picks at the terminal prompt. Time to add is what Add in the Ctrl-click menu adds to a running session."),
        ])
        // The two pop-ups line up. The rows share a superview only now.
        if let defaultLabel = defaultLine.arrangedSubviews.first, let addTimeLabel = addTimeLine.arrangedSubviews.first {
            addTimeLabel.widthAnchor.constraint(equalTo: defaultLabel.widthAnchor).isActive = true
        }
        let content = NSStackView(views: [
            sectionHeader("General"),
            generalGroup,
            sectionHeader("Keyboard shortcut"),
            shortcutGroup,
            sectionHeader("Guardrails"),
            guardrailsGroup,
            sectionHeader("Session lengths"),
            lengthsGroup,
        ])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 10
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        for sectionGroup in [generalGroup, shortcutGroup, guardrailsGroup] {
            content.setCustomSpacing(18, after: sectionGroup)
        }
        // The content is the scroll view's document, top-aligned and as
        // wide as the scroll view, and as tall as the sections need.
        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: documentView.topAnchor),
            content.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
        ])
        contentScrollView.drawsBackground = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.autohidesScrollers = true
        contentScrollView.documentView = documentView
        let clipView = contentScrollView.contentView
        NSLayoutConstraint.activate([
            documentView.topAnchor.constraint(equalTo: clipView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            documentView.widthAnchor.constraint(equalTo: clipView.widthAnchor),
        ])
        window.contentView = contentScrollView
        contentStack = content
        // A window on a smaller screen, or scroll bars that the user now
        // wants always shown, may need another size.
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(screenOrScrollersChanged(_:)), name: NSWindow.didChangeScreenNotification, object: window)
        center.addObserver(self, selector: #selector(screenOrScrollersChanged(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(screenOrScrollersChanged(_:)), name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil)
        fitWindowToContent()
    }

    /// Sizes the window to its content, keeping its top edge in place. A
    /// hidden view gives its space back to the stack, but not to the window,
    /// so this runs again whenever the heat note appears, disappears, or
    /// changes. The fitting size leaves out the right inset, as the stack's
    /// views align to the left, so it is added here. The window is at most
    /// as tall as the screen's space below the menu bar and above the Dock,
    /// and stays within it; the rest of the content scrolls.
    private func fitWindowToContent() {
        guard let window = window, let content = contentStack else {
            return
        }
        let fitting = content.fittingSize
        var width = max(fitting.width, 360 + content.edgeInsets.left + content.edgeInsets.right).rounded(.up)
        // Rounded up, so that content that fits never shows a scroll bar.
        var height = fitting.height.rounded(.up)
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame
        if let visible = visible {
            // The title bar's height: the frame of an empty content area.
            let maxHeight = visible.height - window.frameRect(forContentRect: .zero).height
            if height > maxHeight {
                height = maxHeight
                // A scroll bar that is always shown takes its width from
                // the content; one that only appears while scrolling does not.
                if NSScroller.preferredScrollerStyle == .legacy {
                    width += NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
                }
            }
        }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: NSSize(width: width, height: height)))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        if let visible = visible {
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }
        if frame == window.frame {
            return
        }
        window.setFrame(frame, display: window.isVisible)
    }

    @objc private func screenOrScrollersChanged(_ notification: Notification) {
        fitWindowToContent()
    }

    /// How far a checkbox's title is from the checkbox's left edge, so that
    /// a note under it can line up with the title.
    private func titleIndent(of box: NSButton) -> CGFloat {
        box.sizeToFit()
        let indent: CGFloat = box.cell?.titleRect(forBounds: box.bounds).minX ?? 0
        // The usual distance, should the cell not report a believable one.
        return indent >= 8 && indent <= 40 ? indent : 20
    }

    private func buildAddPopover() {
        amountField.delegate = self
        amountField.formatter = DigitsFormatter()
        amountField.alignment = .right
        amountField.setAccessibilityLabel("Length")
        amountField.translatesAutoresizingMaskIntoConstraints = false
        amountField.widthAnchor.constraint(equalToConstant: 64).isActive = true
        amountStepper.minValue = 1
        amountStepper.increment = 1
        amountStepper.valueWraps = false
        amountStepper.target = self
        amountStepper.action = #selector(amountStepped(_:))
        amountStepper.setAccessibilityLabel("Length")
        for unit in units {
            unitPopUp.addItem(withTitle: unit.title)
        }
        unitPopUp.target = self
        unitPopUp.action = #selector(unitChanged(_:))
        unitPopUp.setAccessibilityLabel("Unit")
        addLengthButton.target = self
        addLengthButton.action = #selector(addLength(_:))
        addLengthButton.keyEquivalent = "\r"
        addErrorLabel.textColor = .systemRed
        addErrorLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)

        let fields = NSStackView(views: [amountField, amountStepper, unitPopUp, addLengthButton])
        fields.orientation = .horizontal
        fields.spacing = 6
        let stack = NSStackView(views: [fields, addErrorLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        let viewController = NSViewController()
        viewController.view = stack
        addPopover.contentViewController = viewController
        addPopover.behavior = .transient
        // The range first: a new stepper stops at 59.
        updateStepperRange()
        syncStepper()
    }

    // MARK: Showing the state

    /// Shows the stored state. With `onlyChanges`, the battery pop-up and
    /// the session lengths are rebuilt only when their stored value changed.
    private func reload(onlyChanges: Bool = false) {
        guard let host else {
            return
        }
        let passwordless = host.passwordlessSetting
        launchAtLoginBox.state = host.isLaunchAtLoginEnabled ? .on : .off
        passwordlessBox.state = passwordless == true ? .on : .off
        // Unknown until the first status arrives, and fixed while a command
        // runs.
        passwordlessBox.isEnabled = passwordless != nil && !host.isCommandPending
        customDialogBox.state = preferences.useCustomPasswordDialog ? .on : .off
        // No password is asked for then, so there is no dialog to choose.
        customDialogBox.isEnabled = passwordless != true
        customDialogBox.toolTip = passwordless == true ? "Not used while Start without password is on." : nil
        soundBox.state = preferences.soundEnabled ? .on : .off
        thermalBox.state = preferences.thermalGuardEnabled ? .on : .off
        unplugBox.state = preferences.unplugGuardEnabled ? .on : .off
        batteryBox.state = preferences.lowBatteryGuardEnabled ? .on : .off
        // The level belongs to the box.
        batteryPopUp.isEnabled = preferences.lowBatteryGuardEnabled
        if !onlyChanges || batteryPopUp.selectedItem?.tag != preferences.minBatteryPercent {
            reloadBatteryPopUp()
        }
        reloadHeatNote()
        let stored = PickerSettings.load()
        if !onlyChanges || stored != configuration {
            configuration = stored
            reloadLengths()
        } else if addTimePopUp.selectedItem?.tag != preferences.addTimeSeconds {
            reloadAddTimePopUp()
        }
        reloadShortcut()
    }

    /// Shows how hot the Mac got during the last session, or hides the note
    /// when there is nothing to report. The window is resized only when the
    /// note changed.
    private func reloadHeatNote() {
        let text = preferences.lastSessionHeat.flatMap { $0.noteText(timeZone: TimeZone.current) }
        if (text ?? "") == heatNote.stringValue && heatRow.isHidden == (text == nil) {
            return
        }
        heatNote.stringValue = text ?? ""
        heatRow.isHidden = text == nil
        fitWindowToContent()
    }

    private func reloadBatteryPopUp() {
        let current = preferences.minBatteryPercent
        var choices = PreferencesStore.minBatteryChoices
        // A level set with defaults write that the list does not offer.
        if !choices.contains(current) {
            choices.append(current)
            choices.sort()
        }
        batteryPopUp.removeAllItems()
        for percent in choices {
            batteryPopUp.addItem(withTitle: "\(percent)%")
            batteryPopUp.lastItem?.tag = percent
        }
        batteryPopUp.selectItem(withTag: current)
    }

    private func reloadLengths() {
        let selectedRow = lengthsTable.selectedRow
        lengthsTable.reloadData()
        if selectedRow >= 0 && selectedRow < configuration.lengths.count {
            lengthsTable.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
        }
        indefiniteBox.state = configuration.includesIndefinite ? .on : .off
        defaultPopUp.removeAllItems()
        for token in configuration.entries {
            defaultPopUp.addItem(withTitle: PickerSettings.label(for: token))
            defaultPopUp.lastItem?.representedObject = token
        }
        if let index = configuration.entries.firstIndex(of: configuration.defaultToken) {
            defaultPopUp.selectItem(at: index)
        }
        reloadAddTimePopUp()
        updateListButtons()
        // The shortcut's note names the default length.
        reloadShortcut()
    }

    /// The session lengths, with the time to add selected.
    private func reloadAddTimePopUp() {
        let current = preferences.addTimeSeconds
        addTimePopUp.removeAllItems()
        for seconds in PickerSettings.addChoices(lengths: configuration.lengths, current: current) {
            addTimePopUp.addItem(withTitle: PickerSettings.lengthLabel(seconds: seconds))
            addTimePopUp.lastItem?.tag = seconds
        }
        addTimePopUp.selectItem(withTag: current)
    }

    private func updateListButtons() {
        addButton.isEnabled = configuration.lengths.count < PickerSettings.maxLengths
        removeButton.isEnabled = configuration.lengths.count > 1 && lengthsTable.selectedRow >= 0
    }

    // MARK: General and Guardrails

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        do {
            try host?.setLaunchAtLogin(sender.state == .on)
        } catch {
            showError(error.localizedDescription)
        }
        reload()
    }

    @objc private func passwordlessChanged(_ sender: NSButton) {
        // The box shows the new state once the password was given.
        host?.setPasswordless(sender.state == .on)
        reload()
    }

    @objc private func customDialogChanged(_ sender: NSButton) {
        host?.setUseCustomPasswordDialog(sender.state == .on)
        reload()
    }

    @objc private func soundChanged(_ sender: NSButton) {
        preferences.soundEnabled = sender.state == .on
    }

    @objc private func thermalChanged(_ sender: NSButton) {
        preferences.thermalGuardEnabled = sender.state == .on
    }

    @objc private func unplugChanged(_ sender: NSButton) {
        preferences.unplugGuardEnabled = sender.state == .on
    }

    @objc private func batteryBoxChanged(_ sender: NSButton) {
        preferences.lowBatteryGuardEnabled = sender.state == .on
        reload()
    }

    @objc private func batteryChanged(_ sender: NSPopUpButton) {
        if let item = sender.selectedItem {
            preferences.minBatteryPercent = item.tag
        }
        reload()
    }

    private func showError(_ message: String) {
        guard let window else {
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Awake"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }

    // MARK: Keyboard shortcut

    private var isRecordingShortcut: Bool {
        recordingMonitor != nil
    }

    /// Shows whether the shortcut is on, the stored shortcut or else ⇧⌘A,
    /// its mode, and the note, or what keeps the shortcut from working. The
    /// button is dimmed while the shortcut is off; Mode is not, as Start
    /// default session in the menu uses it too. While a
    /// shortcut is being recorded, the button and the note show the
    /// recording instead.
    private func reloadShortcut() {
        guard !isRecordingShortcut else {
            return
        }
        let enabled = preferences.startShortcutEnabled
        let shortcut = preferences.startShortcut ?? StartShortcut.defaultShortcut()
        shortcutBox.state = enabled ? .on : .off
        shortcutButton.title = shortcut.displayText
        shortcutButton.setAccessibilityValue(shortcut.spokenText)
        shortcutButton.isEnabled = enabled
        let mode = preferences.startShortcutMode
        if let index = StartShortcutMode.allCases.firstIndex(of: mode) {
            shortcutModePopUp.selectItem(at: index)
        }
        if enabled, let problem = host?.startShortcutProblem {
            showShortcutNote(problem, isProblem: true)
        } else {
            showShortcutNote(StartShortcut.settingsNote(defaultToken: configuration.defaultToken, mode: mode), isProblem: false)
        }
    }

    /// The note may change its number of lines, so the window follows.
    private func showShortcutNote(_ text: String, isProblem: Bool) {
        let color: NSColor = isProblem ? .systemRed : .secondaryLabelColor
        if shortcutNote.stringValue == text && shortcutNote.textColor == color {
            return
        }
        shortcutNote.stringValue = text
        shortcutNote.textColor = color
        fitWindowToContent()
    }

    /// Shows why a shortcut cannot be used, and has VoiceOver read it.
    /// Recording goes on, so another one can be tried at once.
    private func showShortcutProblem(_ message: String) {
        shortcutButton.title = "Type the shortcut…"
        showShortcutNote(message, isProblem: true)
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    @objc private func shortcutBoxChanged(_ sender: NSButton) {
        // Read first: ending the recording redraws the box as stored.
        let enabled = sender.state == .on
        // Recording needs the shortcut on, so it ends first.
        stopRecordingShortcut()
        host?.setStartShortcutEnabled(enabled)
        reloadShortcut()
    }

    @objc private func shortcutButtonClicked(_ sender: NSButton) {
        if isRecordingShortcut {
            stopRecordingShortcut()
        } else {
            startRecordingShortcut()
        }
    }

    /// Records the next key pressed with modifiers in this window. The
    /// stored shortcut is off meanwhile, so pressing it records it again.
    private func startRecordingShortcut() {
        guard let window else {
            return
        }
        host?.pauseStartShortcut(true)
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, event.window === self.window else {
                return event
            }
            return self.handleRecordingEvent(event)
        }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowEndsRecording(_:)), name: NSWindow.didResignKeyNotification, object: window)
        center.addObserver(self, selector: #selector(windowEndsRecording(_:)), name: NSWindow.willCloseNotification, object: window)
        shortcutButton.title = "Type the shortcut…"
        shortcutButton.setAccessibilityValue("Recording")
        showShortcutNote(StartShortcut.recordingHint, isProblem: false)
    }

    /// Ends recording, keeping the stored shortcut as it is now, and turns
    /// it on again.
    private func stopRecordingShortcut() {
        guard let monitor = recordingMonitor else {
            return
        }
        NSEvent.removeMonitor(monitor)
        recordingMonitor = nil
        let center = NotificationCenter.default
        center.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        center.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
        host?.pauseStartShortcut(false)
        reloadShortcut()
    }

    @objc private func windowEndsRecording(_ notification: Notification) {
        stopRecordingShortcut()
    }

    /// Handles a key event while recording. It returns nil for every event,
    /// so that no Command combination reaches the menu: ⌘W would close the
    /// window.
    private func handleRecordingEvent(_ event: NSEvent) -> NSEvent? {
        let modifiers = StartShortcut.Modifiers(cocoaFlags: event.modifierFlags.rawValue)
        if event.type == .flagsChanged {
            shortcutButton.title = modifiers.isEmpty ? "Type the shortcut…" : modifiers.symbols + "…"
            return nil
        }
        if event.isARepeat {
            return nil
        }
        let keyCode = Int(event.keyCode)
        // Esc cancels recording only; the window's own Esc, which closes
        // it, never sees this one.
        if modifiers.isEmpty && keyCode == StartShortcut.escapeKeyCode {
            stopRecordingShortcut()
            return nil
        }
        let label = StartShortcut.label(forKeyCode: keyCode, characters: event.characters(byApplyingModifiers: []))
        let shortcut = StartShortcut(keyCode: keyCode, modifiers: modifiers, keyLabel: label)
        if let problem = shortcut.problem(macOSShortcuts: StartShortcutHotKey.macOSShortcuts()) {
            showShortcutProblem(shortcut.message(for: problem))
            return nil
        }
        if let failure = host?.setStartShortcut(shortcut) {
            showShortcutProblem(failure)
            return nil
        }
        stopRecordingShortcut()
        return nil
    }

    @objc private func shortcutModeChanged(_ sender: NSPopUpButton) {
        let stored = sender.selectedItem?.representedObject as? String
        preferences.startShortcutMode = StartShortcutMode(storedValue: stored)
        reloadShortcut()
    }

    // MARK: Session lengths

    private func store() {
        configuration = PickerSettings.save(configuration)
        reloadLengths()
    }

    @objc private func indefiniteChanged(_ sender: NSButton) {
        configuration.includesIndefinite = sender.state == .on
        store()
    }

    @objc private func defaultChanged(_ sender: NSPopUpButton) {
        if let token = sender.selectedItem?.representedObject as? String {
            configuration.defaultToken = token
            store()
        }
    }

    @objc private func removeLength(_ sender: Any?) {
        let row = lengthsTable.selectedRow
        guard configuration.lengths.count > 1, row >= 0, row < configuration.lengths.count else {
            return
        }
        configuration.lengths.remove(at: row)
        lengthsTable.deselectAll(nil)
        // A default that is gone follows the usual rule when stored.
        store()
    }

    @objc private func addTimeChanged(_ sender: NSPopUpButton) {
        if let item = sender.selectedItem {
            preferences.addTimeSeconds = item.tag
        }
        // A time the list no longer has leaves the choices once another is
        // chosen.
        reloadAddTimePopUp()
    }

    @objc private func restoreDefaults(_ sender: Any?) {
        PickerSettings.restoreDefaults()
        preferences.addTimeSeconds = PickerSettings.defaultAddSeconds
        configuration = PickerSettings.load()
        lengthsTable.deselectAll(nil)
        reloadLengths()
    }

    func numberOfRows(in _: NSTableView) -> Int {
        configuration.lengths.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("LengthCell")
        let cellView: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cellView = existing
        } else {
            cellView = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 240, height: 22))
            cellView.identifier = identifier
            let textField = NSTextField(labelWithString: "")
            textField.frame = NSRect(x: 6, y: 3, width: (tableColumn?.width ?? 240) - 12, height: 16)
            textField.lineBreakMode = .byTruncatingTail
            cellView.textField = textField
            cellView.addSubview(textField)
        }
        cellView.textField?.stringValue = PickerSettings.lengthLabel(seconds: configuration.lengths[row])
        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateListButtons()
    }

    // MARK: Adding a length

    @objc private func showAddPopover(_ sender: NSButton) {
        guard configuration.lengths.count < PickerSettings.maxLengths else {
            return
        }
        addErrorLabel.stringValue = ""
        syncStepper()
        addPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
        addPopover.contentViewController?.view.window?.makeFirstResponder(amountField)
    }

    private var selectedUnitSeconds: Int {
        units[max(unitPopUp.indexOfSelectedItem, 0)].seconds
    }

    private func updateStepperRange() {
        amountStepper.maxValue = Double(PickerSettings.maxSeconds / selectedUnitSeconds)
    }

    /// The stepper follows the typed number, as far as its range allows.
    private func syncStepper() {
        if let value = Int(amountField.stringValue) {
            amountStepper.integerValue = value
        }
    }

    /// Shows why the length cannot be added, and has VoiceOver read it.
    private func showAddError(_ message: String) {
        addErrorLabel.stringValue = message
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    // The field takes digits only (see DigitsFormatter).
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field === amountField else {
            return
        }
        syncStepper()
        addErrorLabel.stringValue = ""
    }

    @objc private func amountStepped(_ sender: NSStepper) {
        amountField.stringValue = String(sender.integerValue)
        addErrorLabel.stringValue = ""
    }

    @objc private func unitChanged(_ sender: NSPopUpButton) {
        updateStepperRange()
        syncStepper()
        addErrorLabel.stringValue = ""
    }

    @objc private func addLength(_ sender: Any?) {
        guard let amount = Int(amountField.stringValue), amount > 0 else {
            showAddError("Type a number.")
            return
        }
        let seconds = amount * selectedUnitSeconds
        guard seconds <= PickerSettings.maxSeconds else {
            showAddError("At most 365 days.")
            return
        }
        guard !configuration.lengths.contains(seconds) else {
            showAddError("\(PickerSettings.lengthLabel(seconds: seconds)) is already listed.")
            return
        }
        configuration.lengths.append(seconds)
        addPopover.performClose(nil)
        store()
        if let row = configuration.lengths.firstIndex(of: seconds) {
            lengthsTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            lengthsTable.scrollRowToVisible(row)
        }
        updateListButtons()
    }
}

/// Lets the length field take up to six digits and nothing else. Other
/// typing or pasting is refused as a whole, which keeps the caret and Undo
/// working, unlike text changed after the fact.
/// The Settings window's scrolled content, which starts at the top.
private final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}

private final class DigitsFormatter: Formatter {
    override func string(for obj: Any?) -> String? {
        switch obj {
        case let text as String:
            return text
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        obj?.pointee = string as NSString
        return true
    }

    override func isPartialStringValid(
        _ partialString: String,
        newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        partialString.count <= 6 && partialString.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
