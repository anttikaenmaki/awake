#!/usr/bin/swift
// Copyright (C) 2026 Antti Käenmäki

// The GUI picker that `awake --gui` shows. It asks how long to keep the Mac
// awake and how, and prints the answer as key=value lines for the CLI:
//
//   awake-gui-picker LID DISPLAY [--entry TOKEN LABEL]... [--default-index N]
//                    [--custom-seconds N] [--custom-until HH:MM]
//
// LID is true or false (keep the Mac awake with the lid closed), DISPLAY on
// or off. Each --entry is a row of the list: TOKEN is a length in seconds or
// indefinite, and LABEL is its text, which the CLI formats. The --custom-*
// values are what Custom… opens with.
//
// Output, one key=value per line: result (start or cancelled), backend
// (awake or caffeinate), display (on or off), end_mode (duration, until,
// none, or process) with duration_seconds, until_epoch, or watch_pid, and
// custom_seconds or custom_until after a Custom… choice. The CLI checks
// every value.

import AppKit
import Foundation

func pickerIcon() -> NSImage? {
    let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0], isDirectory: false)
        .resolvingSymlinksInPath()
        .deletingLastPathComponent()
    let sourceDirectory = URL(fileURLWithPath: #filePath, isDirectory: false)
        .deletingLastPathComponent()
    let candidateURLs = [
        executableDirectory.appendingPathComponent("awake-off.png", isDirectory: false),
        sourceDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("app/AwakeStatusApp/Assets/awake-off.png", isDirectory: false),
    ]

    for candidateURL in candidateURLs {
        if let glyph = NSImage(contentsOf: candidateURL) {
            return appearanceTintedImage(glyph)
        }
    }
    return nil
}

// The logo artwork is a white glyph on a transparent background, which
// disappears on a light alert. Redraw it in the label color at draw time so
// it stays visible in both light and dark mode.
func appearanceTintedImage(_ glyph: NSImage) -> NSImage {
    NSImage(size: glyph.size, flipped: false) { rect in
        glyph.draw(in: rect)
        NSColor.labelColor.set()
        rect.fill(using: .sourceAtop)
        return true
    }
}

// MARK: - Arguments

/// A row of the list: a length in seconds, or indefinite.
struct PickerEntry {
    let token: String
    let label: String

    var seconds: Int? { Int(token) }
}

/// A clock time, hours 0-23 and minutes 0-59.
struct ClockTime {
    let hour: Int
    let minute: Int

    init?(_ text: String) {
        let parts = text.split(separator: ":")
        guard parts.count == 2, parts[1].count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }
        self.hour = hour
        self.minute = minute
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    var text: String { String(format: "%02d:%02d", hour, minute) }
}

let maxSeconds = 365 * 24 * 3600

let builtinEntries: [PickerEntry] = [
    PickerEntry(token: "600", label: "10 minutes"),
    PickerEntry(token: "1200", label: "20 minutes"),
    PickerEntry(token: "1800", label: "30 minutes"),
    PickerEntry(token: "2400", label: "40 minutes"),
    PickerEntry(token: "3000", label: "50 minutes"),
    PickerEntry(token: "3600", label: "1 hour"),
    PickerEntry(token: "7200", label: "2 hours"),
    PickerEntry(token: "10800", label: "3 hours"),
    PickerEntry(token: "14400", label: "4 hours"),
    PickerEntry(token: "21600", label: "6 hours"),
    PickerEntry(token: "28800", label: "8 hours"),
    PickerEntry(token: "indefinite", label: "Indefinitely"),
]

struct PickerArguments {
    var keepLidClosed = false
    var keepDisplayOn = true
    var entries: [PickerEntry] = []
    var defaultIndex = 1
    var customSeconds: Int?
    var customUntil: ClockTime?
}

func isValidToken(_ token: String) -> Bool {
    if token == "indefinite" {
        return true
    }
    guard let seconds = Int(token) else {
        return false
    }
    return seconds > 0 && seconds <= maxSeconds
}

func parseArguments(_ arguments: [String]) -> PickerArguments {
    var result = PickerArguments()
    var positional: [String] = []
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        if argument == "--entry" && index + 2 < arguments.count {
            let token = arguments[index + 1]
            if isValidToken(token) {
                result.entries.append(PickerEntry(token: token, label: arguments[index + 2]))
            }
            index += 3
        } else if argument == "--default-index" && index + 1 < arguments.count {
            result.defaultIndex = Int(arguments[index + 1]) ?? result.defaultIndex
            index += 2
        } else if argument == "--custom-seconds" && index + 1 < arguments.count {
            if let seconds = Int(arguments[index + 1]), seconds > 0, seconds <= maxSeconds {
                result.customSeconds = seconds
            }
            index += 2
        } else if argument == "--custom-until" && index + 1 < arguments.count {
            result.customUntil = ClockTime(arguments[index + 1])
            index += 2
        } else {
            positional.append(argument)
            index += 1
        }
    }
    result.keepLidClosed = positional.first == "true"
    // Caffeine sessions keep the display on unless the user chose otherwise.
    result.keepDisplayOn = positional.count < 2 || positional[1] != "off"
    if result.entries.isEmpty {
        result.entries = builtinEntries
    }
    if result.defaultIndex < 0 || result.defaultIndex >= result.entries.count {
        result.defaultIndex = 0
    }
    return result
}

// MARK: - Shared state

let checkboxLabel = "Keep laptop awake with lid closed"
let displayCheckboxLabel = "Keep the display on"
let lidToolTip = "Checked: the Mac stays awake even with the lid closed; this changes the sleep settings and may ask for your password. Unchecked: no password needed, but closing the lid still puts the Mac to sleep."
let displayToolTip = "Lid-open sessions only. Checked: the display stays on. Unchecked: it can dim and sleep while the Mac stays awake."

/// The lid and display choices, shared by both steps.
final class LidAndDisplay: NSObject {
    var keepLidClosed: Bool
    var keepDisplayOn: Bool
    private var lidCheckbox: NSButton?
    private var displayCheckbox: NSButton?

    init(keepLidClosed: Bool, keepDisplayOn: Bool) {
        self.keepLidClosed = keepLidClosed
        self.keepDisplayOn = keepDisplayOn
        super.init()
    }

    /// Adds the two checkboxes to `view`, the lid one at `y` and the display
    /// one below it.
    func addCheckboxes(to view: NSView, width: CGFloat, y: CGFloat) {
        let lid = NSButton(checkboxWithTitle: checkboxLabel, target: self, action: #selector(lidChanged(_:)))
        lid.frame = NSRect(x: 0, y: y, width: width, height: 22)
        lid.state = keepLidClosed ? .on : .off
        lid.toolTip = lidToolTip
        let display = NSButton(checkboxWithTitle: displayCheckboxLabel, target: self, action: #selector(displayChanged(_:)))
        display.frame = NSRect(x: 0, y: y - 28, width: width, height: 22)
        display.toolTip = displayToolTip
        view.addSubview(lid)
        view.addSubview(display)
        lidCheckbox = lid
        displayCheckbox = display
        showDisplayChoice()
    }

    // The display choice only applies to lid-open sessions. While the lid
    // box is checked, the display box shows unchecked and cannot be changed;
    // unchecking the lid box brings back the choice the user had made.
    private func showDisplayChoice() {
        guard let displayCheckbox else {
            return
        }
        if keepLidClosed {
            displayCheckbox.state = .off
            displayCheckbox.isEnabled = false
        } else {
            displayCheckbox.state = keepDisplayOn ? .on : .off
            displayCheckbox.isEnabled = true
        }
    }

    @objc func lidChanged(_ sender: NSButton) {
        keepLidClosed = sender.state == .on
        showDisplayChoice()
    }

    @objc func displayChanged(_ sender: NSButton) {
        keepDisplayOn = sender.state == .on
    }
}

func makeAlert(informativeText: String) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = "Awake"
    if let icon = pickerIcon() {
        alert.icon = icon
    }
    alert.informativeText = informativeText
    alert.alertStyle = .informational
    return alert
}

// MARK: - Step 1: the list

enum StepOneResult {
    case start(Int)
    case custom
    case cancel
}

final class StepOne: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let entries: [PickerEntry]
    private let choices: LidAndDisplay
    private(set) var selectedIndex: Int
    private var alert: NSAlert?

    init(entries: [PickerEntry], selectedIndex: Int, choices: LidAndDisplay) {
        self.entries = entries
        self.selectedIndex = selectedIndex
        self.choices = choices
        super.init()
    }

    func run() -> StepOneResult {
        let alert = makeAlert(informativeText: "Choose how long to keep the Mac awake, and how.")
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Custom…")
        self.alert = alert

        let width: CGFloat = 340
        let rowHeight: CGFloat = 30
        // Up to 12 rows show at once, fewer when the screen is small; a
        // scroller appears only when not all rows fit.
        let visibleFrameHeight = NSScreen.main?.visibleFrame.height ?? 800
        let maxListHeight = max(rowHeight * 3, visibleFrameHeight - 320)
        let fullHeight = rowHeight * CGFloat(entries.count)
        let listHeight = min(rowHeight * CGFloat(min(entries.count, 12)), maxListHeight)
        let checkboxesHeight: CGFloat = 50
        let gap: CGFloat = 10
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: listHeight + gap + checkboxesHeight))

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: checkboxesHeight + gap, width: width, height: listHeight))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = fullHeight > listHeight
        scrollView.autohidesScrollers = true

        let tableView = NSTableView(frame: scrollView.bounds)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        column.width = width - (scrollView.hasVerticalScroller ? 18 : 2)
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.selectionHighlightStyle = .regular
        tableView.focusRingType = .none
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked(_:))
        tableView.setAccessibilityLabel("Session length")
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        scrollView.documentView = tableView
        tableView.scrollRowToVisible(selectedIndex)

        container.addSubview(scrollView)
        choices.addCheckboxes(to: container, width: width, y: 28)
        alert.accessoryView = container
        alert.layout()
        alert.window.initialFirstResponder = tableView

        let response = alert.runModal()
        self.alert = nil
        switch response {
        case .alertFirstButtonReturn:
            return .start(selectedIndex)
        case .alertThirdButtonReturn:
            return .custom
        default:
            return .cancel
        }
    }

    func numberOfRows(in _: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("DurationCell")
        let cellView: NSTableCellView
        let textField: NSTextField

        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView,
           let existingTextField = existing.textField {
            cellView = existing
            textField = existingTextField
        } else {
            cellView = NSTableCellView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 320, height: 28))
            cellView.identifier = identifier
            textField = NSTextField(labelWithString: "")
            textField.frame = NSRect(x: 12, y: 4, width: (tableColumn?.width ?? 320) - 24, height: 20)
            textField.lineBreakMode = .byTruncatingTail
            cellView.textField = textField
            cellView.addSubview(textField)
        }

        textField.stringValue = entries[row].label
        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView,
              tableView.selectedRow >= 0,
              tableView.selectedRow < entries.count else {
            return
        }
        selectedIndex = tableView.selectedRow
    }

    // A double-click on a row is the same as Start.
    @objc func rowDoubleClicked(_ sender: NSTableView) {
        guard sender.clickedRow >= 0, let alert else {
            return
        }
        alert.buttons[0].performClick(nil)
    }
}

// MARK: - Step 2: Custom…

/// A process the session can wait for.
struct WatchCandidate {
    let pid: pid_t
    let title: String
    let name: String
    let icon: NSImage?
}

/// Running apps with a Dock icon, apart from Awake itself.
func runningAppCandidates() -> [WatchCandidate] {
    let ownPid = ProcessInfo.processInfo.processIdentifier
    return NSWorkspace.shared.runningApplications
        .filter { app in
            app.activationPolicy == .regular && app.processIdentifier != ownPid &&
                app.bundleIdentifier != "net.kaenmaki.awake.statusbar"
        }
        .map { app in
            let name = app.bundleURL?.deletingPathExtension().lastPathComponent ?? app.localizedName ?? "App"
            let icon = app.icon
            icon?.size = NSSize(width: 16, height: 16)
            return WatchCandidate(pid: app.processIdentifier, title: name, name: name, icon: icon)
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
}

/// Commands running in the user's terminals: the user's own processes with
/// a terminal, apart from shells, this picker and the processes that
/// started it.
func terminalCommandCandidates() -> [WatchCandidate] {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-ax", "-o", "pid=,ppid=,uid=,tty=,comm="]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
    } catch {
        return []
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard let output = String(data: data, encoding: .utf8) else {
        return []
    }

    struct Row {
        let pid: pid_t
        let ppid: pid_t
        let uid: uid_t
        let tty: String
        let command: String
    }
    var rows: [Row] = []
    for line in output.split(separator: "\n") {
        let fields = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
        guard fields.count == 5,
              let pid = pid_t(fields[0]), let ppid = pid_t(fields[1]), let uid = uid_t(fields[2]) else {
            continue
        }
        rows.append(Row(
            pid: pid,
            ppid: ppid,
            uid: uid,
            tty: String(fields[3]),
            command: String(fields[4]).trimmingCharacters(in: .whitespaces)
        ))
    }

    var parentOf: [pid_t: pid_t] = [:]
    for row in rows {
        parentOf[row.pid] = row.ppid
    }
    var excluded: Set<pid_t> = []
    var current = ProcessInfo.processInfo.processIdentifier
    while current > 1, !excluded.contains(current) {
        excluded.insert(current)
        current = parentOf[current] ?? 0
    }

    let shells: Set<String> = ["bash", "zsh", "sh", "fish", "tcsh", "csh", "ksh", "dash", "login", "ps"]
    let ownUid = getuid()
    return rows.compactMap { row in
        guard row.uid == ownUid, row.tty != "??", !excluded.contains(row.pid) else {
            return nil
        }
        var name = URL(fileURLWithPath: row.command).lastPathComponent
        if name.hasPrefix("-") {
            name.removeFirst()
        }
        guard !name.isEmpty, !shells.contains(name) else {
            return nil
        }
        return WatchCandidate(pid: row.pid, title: "\(name) (PID \(row.pid))", name: name, icon: nil)
    }
}

enum StepTwoResult {
    case duration(Int)
    case until(Int, ClockTime)
    case process(pid_t)
    case back
    case cancel
}

final class StepTwo: NSObject, NSTextFieldDelegate, NSMenuDelegate {
    private enum Mode {
        case forLength
        case untilTime
        case whileRunning
    }

    private let choices: LidAndDisplay
    private var mode: Mode = .forLength
    private var alert: NSAlert?

    private var hours: Int
    private var minutes: Int
    private var untilTime: ClockTime
    private var chosenPid: pid_t?
    private var chosenName = ""
    /// Whether the hint last said today; checked again at Start.
    private var hintSaidToday = true
    private var result: StepTwoResult = .cancel

    private let forRadio = NSButton(radioButtonWithTitle: "For", target: nil, action: nil)
    private let untilRadio = NSButton(radioButtonWithTitle: "Until", target: nil, action: nil)
    private let whileRadio = NSButton(radioButtonWithTitle: "While", target: nil, action: nil)
    private let hoursField = NSTextField(string: "")
    private let minutesField = NSTextField(string: "")
    private let hoursStepper = NSStepper()
    private let minutesStepper = NSStepper()
    private let datePicker = NSDatePicker()
    private let hintLabel = NSTextField(labelWithString: "")
    private let processPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    init(customSeconds: Int?, customUntil: ClockTime?, choices: LidAndDisplay) {
        self.choices = choices
        let seconds = customSeconds ?? 3600
        hours = min(seconds / 3600, 8760)
        minutes = hours == 8760 ? 0 : (seconds % 3600) / 60
        if let customUntil {
            untilTime = customUntil
        } else {
            // The next full hour.
            let nextHour = (Calendar.current.component(.hour, from: Date()) + 1) % 24
            untilTime = ClockTime(hour: nextHour, minute: 0)
        }
        super.init()
    }

    func run() -> StepTwoResult {
        let alert = makeAlert(informativeText: "Keep the Mac awake:")
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Back")
        self.alert = alert
        // Start checks the input first and keeps the dialog open when
        // something is wrong.
        let startButton = alert.buttons[0]
        startButton.target = self
        startButton.action = #selector(startPressed(_:))

        alert.accessoryView = makeAccessoryView()
        selectMode(mode)
        updateHint()
        alert.layout()
        alert.window.initialFirstResponder = firstResponderForMode()

        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.updateHint()
        }
        RunLoop.main.add(timer, forMode: .modalPanel)
        result = .cancel
        let response = alert.runModal()
        timer.invalidate()
        self.alert = nil
        switch response {
        case .alertFirstButtonReturn:
            return result
        case .alertThirdButtonReturn:
            return .back
        default:
            return .cancel
        }
    }

    private func makeAccessoryView() -> NSView {
        let width: CGFloat = 380
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 204))
        let forY: CGFloat = 176
        let untilY: CGFloat = 142
        let whileY: CGFloat = 108

        for (radio, y) in [(forRadio, forY), (untilRadio, untilY), (whileRadio, whileY)] {
            radio.target = self
            radio.action = #selector(radioChanged(_:))
            radio.frame = NSRect(x: 0, y: y, width: 70, height: 24)
            container.addSubview(radio)
        }

        configureNumberField(hoursField, value: hours, label: "Hours")
        hoursField.frame = NSRect(x: 74, y: forY, width: 64, height: 24)
        configureStepper(hoursStepper, value: hours, maximum: 8760)
        hoursStepper.frame = NSRect(x: 140, y: forY, width: 19, height: 24)
        let hoursUnit = NSTextField(labelWithString: "h")
        hoursUnit.frame = NSRect(x: 163, y: forY + 3, width: 20, height: 18)
        configureNumberField(minutesField, value: minutes, label: "Minutes")
        minutesField.frame = NSRect(x: 190, y: forY, width: 44, height: 24)
        configureStepper(minutesStepper, value: minutes, maximum: 59)
        minutesStepper.frame = NSRect(x: 236, y: forY, width: 19, height: 24)
        let minutesUnit = NSTextField(labelWithString: "min")
        minutesUnit.frame = NSRect(x: 259, y: forY + 3, width: 40, height: 18)
        let lengthViews: [NSView] = [hoursField, hoursStepper, hoursUnit, minutesField, minutesStepper, minutesUnit]
        for view in lengthViews {
            container.addSubview(view)
        }

        // The picker follows the system's 12- or 24-hour setting.
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = .hourMinute
        datePicker.datePickerMode = .single
        datePicker.dateValue = dateToday(at: untilTime)
        datePicker.target = self
        datePicker.action = #selector(untilChanged(_:))
        datePicker.setAccessibilityLabel("Until time")
        datePicker.sizeToFit()
        datePicker.frame = NSRect(x: 74, y: untilY, width: max(datePicker.frame.width, 90), height: 24)
        hintLabel.frame = NSRect(x: datePicker.frame.maxX + 10, y: untilY + 3, width: width - datePicker.frame.maxX - 10, height: 18)
        hintLabel.textColor = .secondaryLabelColor
        container.addSubview(datePicker)
        container.addSubview(hintLabel)

        processPopUp.autoenablesItems = false
        processPopUp.menu?.delegate = self
        processPopUp.target = self
        processPopUp.action = #selector(processChosen(_:))
        processPopUp.setAccessibilityLabel("Process to wait for")
        processPopUp.frame = NSRect(x: 74, y: whileY - 2, width: width - 74, height: 28)
        rebuildProcessMenu()
        container.addSubview(processPopUp)

        errorLabel.frame = NSRect(x: 0, y: 64, width: width, height: 36)
        errorLabel.textColor = .systemRed
        errorLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        container.addSubview(errorLabel)

        choices.addCheckboxes(to: container, width: width, y: 30)
        return container
    }

    private func configureNumberField(_ field: NSTextField, value: Int, label: String) {
        field.stringValue = String(value)
        field.alignment = .right
        field.delegate = self
        field.setAccessibilityLabel(label)
    }

    private func configureStepper(_ stepper: NSStepper, value: Int, maximum: Int) {
        stepper.minValue = 0
        stepper.maxValue = Double(maximum)
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.integerValue = value
        stepper.target = self
        stepper.action = #selector(stepperChanged(_:))
    }

    private func firstResponderForMode() -> NSView {
        switch mode {
        case .forLength:
            return hoursField
        case .untilTime:
            return datePicker
        case .whileRunning:
            return processPopUp
        }
    }

    // MARK: Editing

    private func selectMode(_ newMode: Mode) {
        mode = newMode
        forRadio.state = mode == .forLength ? .on : .off
        untilRadio.state = mode == .untilTime ? .on : .off
        whileRadio.state = mode == .whileRunning ? .on : .off
        errorLabel.stringValue = ""
        updateStartButton()
    }

    @objc func radioChanged(_ sender: NSButton) {
        if sender === untilRadio {
            selectMode(.untilTime)
        } else if sender === whileRadio {
            selectMode(.whileRunning)
        } else {
            selectMode(.forLength)
        }
    }

    // Fields take digits only, up to 8760 hours and 59 minutes. At 8760
    // hours the minutes are 0, since a session lasts at most 365 days.
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else {
            return
        }
        let maximum = field === hoursField ? 8760 : 59
        let digits = String(field.stringValue.filter { $0.isASCII && $0.isNumber }.prefix(4))
        let value = min(Int(digits) ?? 0, maximum)
        if digits.isEmpty {
            field.stringValue = ""
        } else if field.stringValue != String(value) {
            field.stringValue = String(value)
        }
        if field === hoursField {
            hours = value
            hoursStepper.integerValue = value
        } else {
            minutes = value
            minutesStepper.integerValue = value
        }
        limitMinutesAtMaximum()
        selectMode(.forLength)
    }

    @objc func stepperChanged(_ sender: NSStepper) {
        if sender === hoursStepper {
            hours = sender.integerValue
            hoursField.stringValue = String(hours)
        } else {
            minutes = sender.integerValue
            minutesField.stringValue = String(minutes)
        }
        limitMinutesAtMaximum()
        selectMode(.forLength)
    }

    private func limitMinutesAtMaximum() {
        if hours >= 8760 && minutes > 0 {
            minutes = 0
            minutesField.stringValue = "0"
            minutesStepper.integerValue = 0
        }
    }

    @objc func untilChanged(_ sender: NSDatePicker) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: sender.dateValue)
        untilTime = ClockTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
        selectMode(.untilTime)
        updateHint()
    }

    @objc func processChosen(_ sender: NSPopUpButton) {
        if let pid = sender.selectedItem?.representedObject as? Int {
            chosenPid = pid_t(pid)
            chosenName = sender.selectedItem?.toolTip ?? sender.selectedItem?.title ?? ""
        } else {
            chosenPid = nil
        }
        selectMode(.whileRunning)
    }

    private func updateStartButton() {
        guard let startButton = alert?.buttons.first else {
            return
        }
        switch mode {
        case .forLength:
            startButton.isEnabled = hours * 3600 + minutes * 60 > 0
        case .untilTime:
            startButton.isEnabled = true
        case .whileRunning:
            startButton.isEnabled = chosenPid != nil
        }
    }

    // MARK: Until

    private func dateToday(at time: ClockTime) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
    }

    /// The next time the clock shows `time`: today if still ahead, otherwise
    /// tomorrow. A time skipped by DST moves on, and a repeated one gives its
    /// first occurrence, as in the CLI.
    private func nextOccurrence(of time: ClockTime, after now: Date) -> Date? {
        Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: time.hour, minute: time.minute, second: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func updateHint() {
        let now = Date()
        guard let next = nextOccurrence(of: untilTime, after: now) else {
            hintLabel.stringValue = ""
            return
        }
        hintSaidToday = Calendar.current.isDateInToday(next)
        let totalMinutes = max(Int((next.timeIntervalSince(now) / 60).rounded(.up)), 1)
        let hoursLeft = totalMinutes / 60
        let minutesLeft = totalMinutes % 60
        let interval = hoursLeft > 0 ? "\(hoursLeft) h \(minutesLeft) min" : "\(minutesLeft) min"
        hintLabel.stringValue = "\(hintSaidToday ? "today" : "tomorrow"), in \(interval)"
    }

    // MARK: While

    private func addHeader(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    /// Rebuilt each time the pop-up opens, so it lists what runs now.
    private func rebuildProcessMenu() {
        guard let menu = processPopUp.menu else {
            return
        }
        menu.removeAllItems()
        let placeholder = NSMenuItem(title: "Choose an app or command…", action: nil, keyEquivalent: "")
        placeholder.isEnabled = false
        menu.addItem(placeholder)
        var selected: NSMenuItem = placeholder

        let groups = [("Apps", runningAppCandidates()), ("Terminal commands", terminalCommandCandidates())]
        for (header, candidates) in groups where !candidates.isEmpty {
            addHeader(header, to: menu)
            for candidate in candidates {
                let item = NSMenuItem(title: candidate.title, action: nil, keyEquivalent: "")
                item.representedObject = Int(candidate.pid)
                item.toolTip = candidate.name
                item.image = candidate.icon
                item.indentationLevel = 1
                menu.addItem(item)
                if candidate.pid == chosenPid {
                    selected = item
                }
            }
        }
        processPopUp.select(selected)
        if selected === placeholder {
            chosenPid = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildProcessMenu()
    }

    // MARK: Start

    private func showError(_ message: String) {
        errorLabel.stringValue = message
    }

    @objc func startPressed(_ sender: Any?) {
        switch mode {
        case .forLength:
            let seconds = hours * 3600 + minutes * 60
            guard seconds > 0 else {
                return
            }
            guard seconds <= maxSeconds else {
                showError("At most 365 days")
                return
            }
            result = .duration(seconds)
        case .untilTime:
            let now = Date()
            guard let next = nextOccurrence(of: untilTime, after: now) else {
                showError("Awake could not work out that time.")
                return
            }
            // The day moved on since the hint was shown: say so first.
            if Calendar.current.isDateInToday(next) != hintSaidToday {
                updateHint()
                showError("\(untilTime.text) has just passed. Press Start again to stay awake until tomorrow \(untilTime.text).")
                return
            }
            result = .until(Int(next.timeIntervalSince1970), untilTime)
        case .whileRunning:
            guard let pid = chosenPid else {
                return
            }
            guard kill(pid, 0) == 0 else {
                showError("\(chosenName) has exited.")
                rebuildProcessMenu()
                updateStartButton()
                return
            }
            result = .process(pid)
        }
        NSApp.stopModal(withCode: .alertFirstButtonReturn)
    }
}

// MARK: - Main

func printResult(_ lines: [String]) -> Never {
    print(lines.joined(separator: "\n"))
    exit(0)
}

let arguments = parseArguments(Array(CommandLine.arguments.dropFirst()))
let choices = LidAndDisplay(keepLidClosed: arguments.keepLidClosed, keepDisplayOn: arguments.keepDisplayOn)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

let stepOne = StepOne(entries: arguments.entries, selectedIndex: arguments.defaultIndex, choices: choices)
let stepTwo = StepTwo(customSeconds: arguments.customSeconds, customUntil: arguments.customUntil, choices: choices)

func commonLines() -> [String] {
    [
        "result=start",
        "backend=\(choices.keepLidClosed ? "awake" : "caffeinate")",
        // For a lid-closed session this is the choice kept for next time.
        "display=\(choices.keepDisplayOn ? "on" : "off")",
    ]
}

while true {
    switch stepOne.run() {
    case .cancel:
        printResult(["result=cancelled"])
    case let .start(index):
        let entry = arguments.entries[index]
        if let seconds = entry.seconds {
            printResult(commonLines() + ["end_mode=duration", "duration_seconds=\(seconds)"])
        }
        printResult(commonLines() + ["end_mode=none"])
    case .custom:
        switch stepTwo.run() {
        case .back:
            continue
        case .cancel:
            printResult(["result=cancelled"])
        case let .duration(seconds):
            printResult(commonLines() + ["end_mode=duration", "duration_seconds=\(seconds)", "custom_seconds=\(seconds)"])
        case let .until(epoch, time):
            printResult(commonLines() + ["end_mode=until", "until_epoch=\(epoch)", "custom_until=\(time.text)"])
        case let .process(pid):
            printResult(commonLines() + ["end_mode=process", "watch_pid=\(pid)"])
        }
    }
}
