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

let lidClosedCaption = "Lid closed (Awake): the Mac stays awake even with the lid closed. This changes the sleep settings and may ask for your password. It can get hot and drain the battery: use it only on a hard, flat, well-ventilated surface, never in a bag. Awake stops early if the battery runs low or the Mac overheats."
let lidOpenCaption = "Lid open (Caffeine): no password needed. Closing the lid still puts the Mac to sleep."
let displayOnCaption = "The display stays on, for presentations, video calls, or watching a long task."
let displayOffCaption = "The display can dim and turn off as usual; apps keep running and the Mac stays awake."
let displayUnusedCaption = "Only for lid-open sessions. With the lid closed, the display is off."

let dataSource = DurationPickerDataSource(options: durationOptions, selectedIndex: defaultSelectionIndex)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

let alert = NSAlert()
alert.messageText = "Awake"
if let icon = pickerIcon() {
    alert.icon = icon
}
alert.informativeText = "Choose how long to keep the Mac awake, and how."
alert.alertStyle = .informational
alert.addButton(withTitle: "Start")
alert.addButton(withTitle: "Cancel")

let containerWidth: CGFloat = 340
let checkboxHeight: CGFloat = 22
let displayCaptionHeight: CGFloat = 32
let lidCaptionHeight: CGFloat = 74
let smallGap: CGFloat = 2
let sectionGap: CGFloat = 10
let listHeight: CGFloat = 292

let displayCaptionY: CGFloat = 0
let displayCheckboxY = displayCaptionY + displayCaptionHeight + smallGap
let lidCaptionY = displayCheckboxY + checkboxHeight + sectionGap
let lidCheckboxY = lidCaptionY + lidCaptionHeight + smallGap
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

func captionLabel(frame: NSRect) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: "")
    label.frame = frame
    label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = .secondaryLabelColor
    return label
}

let checkbox = NSButton(checkboxWithTitle: checkboxLabel, target: nil, action: nil)
checkbox.frame = NSRect(x: 0, y: lidCheckboxY, width: containerWidth, height: checkboxHeight)
checkbox.state = defaultKeepLidClosed ? .on : .off
let lidCaption = captionLabel(frame: NSRect(x: 20, y: lidCaptionY, width: containerWidth - 20, height: lidCaptionHeight))

let displayCheckbox = NSButton(checkboxWithTitle: displayCheckboxLabel, target: nil, action: nil)
displayCheckbox.frame = NSRect(x: 0, y: displayCheckboxY, width: containerWidth, height: checkboxHeight)
displayCheckbox.state = defaultKeepDisplayOn ? .on : .off
let displayCaption = captionLabel(frame: NSRect(x: 20, y: displayCaptionY, width: containerWidth - 20, height: displayCaptionHeight))

// Keeps the captions in step with the checkboxes, so each choice says what
// it does before the user starts the session.
final class ChoiceExplainer: NSObject {
    private let lidCheckbox: NSButton
    private let lidCaption: NSTextField
    private let displayCheckbox: NSButton
    private let displayCaption: NSTextField

    init(lidCheckbox: NSButton, lidCaption: NSTextField, displayCheckbox: NSButton, displayCaption: NSTextField) {
        self.lidCheckbox = lidCheckbox
        self.lidCaption = lidCaption
        self.displayCheckbox = displayCheckbox
        self.displayCaption = displayCaption
        super.init()
        lidCheckbox.target = self
        lidCheckbox.action = #selector(update(_:))
        displayCheckbox.target = self
        displayCheckbox.action = #selector(update(_:))
        update(nil)
    }

    @objc func update(_ sender: Any?) {
        let lidClosed = lidCheckbox.state == .on
        lidCaption.stringValue = lidClosed ? lidClosedCaption : lidOpenCaption
        lidCaption.textColor = lidClosed ? .labelColor : .secondaryLabelColor
        displayCheckbox.isEnabled = !lidClosed
        if lidClosed {
            displayCaption.stringValue = displayUnusedCaption
        } else {
            displayCaption.stringValue = displayCheckbox.state == .on ? displayOnCaption : displayOffCaption
        }
    }
}

let explainer = ChoiceExplainer(
    lidCheckbox: checkbox,
    lidCaption: lidCaption,
    displayCheckbox: displayCheckbox,
    displayCaption: displayCaption
)

container.addSubview(scrollView)
container.addSubview(checkbox)
container.addSubview(lidCaption)
container.addSubview(displayCheckbox)
container.addSubview(displayCaption)
alert.accessoryView = container

let result = alert.runModal()
if result != .alertFirstButtonReturn {
    print("CANCELLED")
    exit(0)
}

let backend = checkbox.state == .on ? "awake" : "caffeinate"
let keepDisplay = displayCheckbox.state == .on ? "on" : "off"
print("\(dataSource.selectedDurationLabel)|\(backend)|\(keepDisplay)")
