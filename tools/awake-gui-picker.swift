#!/usr/bin/swift

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
        if let image = NSImage(contentsOf: candidateURL) {
            return image
        }
    }
    return nil
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
            textField.frame = NSRect(x: 12, y: 4, width: tableColumn?.width ?? 320 - 24, height: 20)
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

let defaultKeepLidClosed = CommandLine.arguments.dropFirst().first == "true"
let defaultSelectionIndex = 1
let checkboxLabel = "Keep laptop awake with lid closed"

let dataSource = DurationPickerDataSource(options: durationOptions, selectedIndex: defaultSelectionIndex)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

let alert = NSAlert()
alert.messageText = "Awake"
if let icon = pickerIcon() {
    alert.icon = icon
}
alert.informativeText = """
WARNING: Keeping the lid closed while awake can increase heat and battery drain and may shut down the Mac if the battery runs low. Use only on a hard, flat, well-ventilated surface, at your own risk.

Choose the duration.
"""
alert.alertStyle = .warning
alert.addButton(withTitle: "Start")
alert.addButton(withTitle: "Cancel")

let containerWidth: CGFloat = 340
let checkboxHeight: CGFloat = 24
let checkboxBottomPadding: CGFloat = 8
let checkboxTopGap: CGFloat = 10
let listHeight: CGFloat = 292
let containerHeight = listHeight + checkboxTopGap + checkboxHeight + checkboxBottomPadding

let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: containerHeight))

let scrollView = NSScrollView(frame: NSRect(x: 0, y: checkboxHeight + checkboxTopGap + checkboxBottomPadding, width: containerWidth, height: listHeight))
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
checkbox.frame = NSRect(x: 0, y: checkboxBottomPadding, width: containerWidth, height: checkboxHeight)
checkbox.state = defaultKeepLidClosed ? .on : .off

container.addSubview(scrollView)
container.addSubview(checkbox)
alert.accessoryView = container

let result = alert.runModal()
if result != .alertFirstButtonReturn {
    print("CANCELLED")
    exit(0)
}

let backend = checkbox.state == .on ? "awake" : "caffeinate"
print("\(dataSource.selectedDurationLabel)|\(backend)")
