// Copyright (C) 2026 Antti Käenmäki

import AppKit

/// A window that Esc closes, as Command-W and the close button do: the
/// Settings window and the About / Instructions window. AppKit turns Esc
/// and Command-period into `cancelOperation(_:)`, sent to the focused view
/// and on up the responder chain, which ends at the window. A view that
/// cancels something of its own, such as the find bar's search field,
/// takes it first, and so does a key monitor, such as the Settings
/// window's while it records a shortcut.
final class EscapeClosableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }
}
