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
}

/// The Settings window: General, Guardrails, and Session lengths. Changes
/// apply at once. The window shows each setting as it is stored, or for
/// Launch at login and Start without password as it really is, and redraws
/// whenever that changes.
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
    private let batteryPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let lengthsTable = NSTableView()
    private let addButton = NSButton(title: "+", target: nil, action: nil)
    private let removeButton = NSButton(title: "−", target: nil, action: nil)
    private let restoreButton = NSButton(title: "Restore Defaults", target: nil, action: nil)
    private let indefiniteBox = NSButton(checkboxWithTitle: "Include Indefinitely", target: nil, action: nil)
    private let defaultPopUp = NSPopUpButton(frame: .zero, pullsDown: false)

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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "Awake Settings"
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
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reloadIfVisible() {
        if window?.isVisible == true {
            reload()
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

    /// The controls of one section, indented under its header.
    private func group(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)
        return stack
    }

    private func buildContent(in window: NSWindow) {
        for (box, action) in [
            (launchAtLoginBox, #selector(launchAtLoginChanged(_:))),
            (passwordlessBox, #selector(passwordlessChanged(_:))),
            (customDialogBox, #selector(customDialogChanged(_:))),
            (soundBox, #selector(soundChanged(_:))),
            (thermalBox, #selector(thermalChanged(_:))),
            (indefiniteBox, #selector(indefiniteChanged(_:))),
        ] {
            box.target = self
            box.action = action
        }
        passwordlessBox.toolTip = "Lets Awake's helper change the sleep settings without asking for your password. Other apps running as you could then change them too."
        thermalBox.toolTip = "Ends a session when macOS reports that the Mac is overheating, so it can sleep and cool down. Applies to the next session."
        batteryPopUp.target = self
        batteryPopUp.action = #selector(batteryChanged(_:))
        batteryPopUp.toolTip = "Ends a session when the Mac runs on battery power and the charge drops to this level. Applies to the next session."
        batteryPopUp.setAccessibilityLabel("Stop at low battery")

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("length"))
        column.width = 240
        lengthsTable.addTableColumn(column)
        lengthsTable.headerView = nil
        lengthsTable.rowHeight = 22
        lengthsTable.dataSource = self
        lengthsTable.delegate = self
        lengthsTable.usesAlternatingRowBackgroundColors = true
        lengthsTable.setAccessibilityLabel("Session lengths")
        scrollView.documentView = lengthsTable
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.widthAnchor.constraint(equalToConstant: 260).isActive = true
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
        restoreButton.toolTip = "Go back to the built-in session lengths and default."
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let listButtons = NSStackView(views: [addButton, removeButton, spacer, restoreButton])
        listButtons.orientation = .horizontal
        listButtons.spacing = 6
        listButtons.translatesAutoresizingMaskIntoConstraints = false
        listButtons.widthAnchor.constraint(equalToConstant: 360).isActive = true

        defaultPopUp.target = self
        defaultPopUp.action = #selector(defaultChanged(_:))
        defaultPopUp.setAccessibilityLabel("Default selection")

        let content = NSStackView(views: [
            sectionHeader("General"),
            group([launchAtLoginBox, passwordlessBox, customDialogBox, soundBox]),
            sectionHeader("Guardrails"),
            group([
                thermalBox,
                row("Stop at low battery", batteryPopUp),
                note("Apply to sessions started afterwards."),
            ]),
            sectionHeader("Session lengths"),
            group([
                scrollView,
                listButtons,
                indefiniteBox,
                row("Default selection", defaultPopUp),
                note("Shown in the picker. The default is also what Enter picks at the terminal prompt."),
            ]),
        ])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 10
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        content.setCustomSpacing(18, after: content.views[1])
        content.setCustomSpacing(18, after: content.views[3])
        window.contentView = content
        window.setContentSize(content.fittingSize)
    }

    private func buildAddPopover() {
        amountField.delegate = self
        amountField.alignment = .right
        amountField.setAccessibilityLabel("Length")
        amountField.translatesAutoresizingMaskIntoConstraints = false
        amountField.widthAnchor.constraint(equalToConstant: 64).isActive = true
        amountStepper.minValue = 1
        amountStepper.increment = 1
        amountStepper.valueWraps = false
        amountStepper.integerValue = 90
        amountStepper.target = self
        amountStepper.action = #selector(amountStepped(_:))
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
        updateStepperRange()
    }

    // MARK: Showing the state

    private func reload() {
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
        reloadBatteryPopUp()
        configuration = PickerSettings.load()
        reloadLengths()
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
            batteryPopUp.addItem(withTitle: percent == 0 ? "Never" : "\(percent)%")
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
        updateListButtons()
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

    @objc private func restoreDefaults(_ sender: Any?) {
        PickerSettings.restoreDefaults()
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
        addPopover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
        addPopover.contentViewController?.view.window?.makeFirstResponder(amountField)
    }

    private var selectedUnitSeconds: Int {
        units[max(unitPopUp.indexOfSelectedItem, 0)].seconds
    }

    private func updateStepperRange() {
        amountStepper.maxValue = Double(PickerSettings.maxSeconds / selectedUnitSeconds)
    }

    // Digits only, kept in step with the stepper.
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field === amountField else {
            return
        }
        let digits = String(field.stringValue.filter { $0.isASCII && $0.isNumber }.prefix(6))
        if field.stringValue != digits {
            field.stringValue = digits
        }
        if let value = Int(digits) {
            amountStepper.integerValue = value
        }
        addErrorLabel.stringValue = ""
    }

    @objc private func amountStepped(_ sender: NSStepper) {
        amountField.stringValue = String(sender.integerValue)
        addErrorLabel.stringValue = ""
    }

    @objc private func unitChanged(_ sender: NSPopUpButton) {
        updateStepperRange()
        addErrorLabel.stringValue = ""
    }

    @objc private func addLength(_ sender: Any?) {
        guard let amount = Int(amountField.stringValue), amount > 0 else {
            addErrorLabel.stringValue = "Type a number."
            return
        }
        let seconds = amount * selectedUnitSeconds
        guard seconds <= PickerSettings.maxSeconds else {
            addErrorLabel.stringValue = "At most 365 days."
            return
        }
        guard !configuration.lengths.contains(seconds) else {
            addErrorLabel.stringValue = "\(PickerSettings.lengthLabel(seconds: seconds)) is already listed."
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
