#!/usr/bin/swift
// Copyright (C) 2026 Antti Käenmäki

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

final class DurationPickerDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let options: [String]
    private(set) var selectedIndex: Int

    init(options: [String], selectedIndex: Int) {
        self.options = options
        self.selectedIndex = selectedIndex
        super.init()
    }

    func numberOfRows(in _: NSTableView) -> Int {
        options.count
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

        textField.stringValue = options[row]
        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView,
              tableView.selectedRow >= 0,
              tableView.selectedRow < options.count else {
            return
        }

        selectedIndex = tableView.selectedRow
    }

    var selectedDurationLabel: String {
        options[selectedIndex]
    }
}

let durationOptions = [
    "10 minutes",
    "20 minutes",
    "30 minutes",
    "40 minutes",
    "50 minutes",
    "1 hour",
    "2 hours",
    "3 hours",
    "4 hours",
    "6 hours",
    "8 hours",
]

let pickerArguments = Array(CommandLine.arguments.dropFirst())
let defaultKeepLidClosed = pickerArguments.first == "true"
// Caffeine sessions keep the display on unless the user chose otherwise.
let defaultKeepDisplayOn = pickerArguments.count < 2 || pickerArguments[1] != "off"
let defaultSelectionIndex = 1
let checkboxLabel = "Keep laptop awake with lid closed"
let displayCheckboxLabel = "Keep the display on"

let lidToolTip = "Checked: the Mac stays awake even with the lid closed; this changes the sleep settings and may ask for your password. Unchecked: no password needed, but closing the lid still puts the Mac to sleep."
let displayToolTip = "Lid-open sessions only. Checked: the display stays on. Unchecked: it can dim and sleep while the Mac stays awake."

let dataSource = DurationPickerDataSource(options: durationOptions, selectedIndex: defaultSelectionIndex)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

let alert = NSAlert()
alert.messageText = "Awake"
if let icon = pickerIcon() {
    alert.icon = icon
}
alert.informativeText = "Choose the duration."
alert.alertStyle = .informational
alert.addButton(withTitle: "Start")
alert.addButton(withTitle: "Cancel")

let containerWidth: CGFloat = 340
let checkboxHeight: CGFloat = 22
let checkboxGap: CGFloat = 6
let sectionGap: CGFloat = 10
let listHeight: CGFloat = 292

let displayCheckboxY: CGFloat = 0
let lidCheckboxY = displayCheckboxY + checkboxHeight + checkboxGap
let listY = lidCheckboxY + checkboxHeight + sectionGap
let containerHeight = listY + listHeight

let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))

let scrollView = NSScrollView(frame: NSRect(x: 0, y: listY, width: containerWidth, height: listHeight))
scrollView.borderType = .bezelBorder
scrollView.hasVerticalScroller = false
scrollView.autohidesScrollers = true

let tableView = NSTableView(frame: scrollView.bounds)
let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
column.width = containerWidth - 2
tableView.addTableColumn(column)
tableView.headerView = nil
tableView.dataSource = dataSource
tableView.delegate = dataSource
tableView.rowHeight = 30
tableView.intercellSpacing = NSSize(width: 0, height: 0)
tableView.selectionHighlightStyle = .regular
tableView.focusRingType = .none
tableView.usesAlternatingRowBackgroundColors = false
tableView.reloadData()
tableView.selectRowIndexes(IndexSet(integer: defaultSelectionIndex), byExtendingSelection: false)
scrollView.documentView = tableView

let checkbox = NSButton(checkboxWithTitle: checkboxLabel, target: nil, action: nil)
checkbox.frame = NSRect(x: 0, y: lidCheckboxY, width: containerWidth, height: checkboxHeight)
checkbox.state = defaultKeepLidClosed ? .on : .off
checkbox.toolTip = lidToolTip

let displayCheckbox = NSButton(checkboxWithTitle: displayCheckboxLabel, target: nil, action: nil)
displayCheckbox.frame = NSRect(x: 0, y: displayCheckboxY, width: containerWidth, height: checkboxHeight)
displayCheckbox.toolTip = displayToolTip

// The display choice only applies to lid-open sessions. While the lid box is
// checked, the display box shows unchecked and cannot be changed; unchecking
// the lid box brings back the choice the user had made.
final class DisplayChoice: NSObject {
    private let lidCheckbox: NSButton
    private let displayCheckbox: NSButton
    private(set) var keepDisplayOn: Bool

    init(lidCheckbox: NSButton, displayCheckbox: NSButton, keepDisplayOn: Bool) {
        self.lidCheckbox = lidCheckbox
        self.displayCheckbox = displayCheckbox
        self.keepDisplayOn = keepDisplayOn
        super.init()
        lidCheckbox.target = self
        lidCheckbox.action = #selector(lidChanged(_:))
        displayCheckbox.target = self
        displayCheckbox.action = #selector(displayChanged(_:))
        lidChanged(nil)
    }

    @objc func lidChanged(_ sender: Any?) {
        if lidCheckbox.state == .on {
            displayCheckbox.state = .off
            displayCheckbox.isEnabled = false
        } else {
            displayCheckbox.state = keepDisplayOn ? .on : .off
            displayCheckbox.isEnabled = true
        }
    }

    @objc func displayChanged(_ sender: Any?) {
        keepDisplayOn = displayCheckbox.state == .on
    }
}

let displayChoice = DisplayChoice(lidCheckbox: checkbox, displayCheckbox: displayCheckbox, keepDisplayOn: defaultKeepDisplayOn)

container.addSubview(scrollView)
container.addSubview(checkbox)
container.addSubview(displayCheckbox)
alert.accessoryView = container

let result = alert.runModal()
if result != .alertFirstButtonReturn {
    print("CANCELLED")
    exit(0)
}

let backend = checkbox.state == .on ? "awake" : "caffeinate"
// For a lid-closed session this is the choice kept for next time.
let keepDisplay = displayChoice.keepDisplayOn ? "on" : "off"
print("\(dataSource.selectedDurationLabel)|\(backend)|\(keepDisplay)")
