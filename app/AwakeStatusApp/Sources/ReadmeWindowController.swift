// Copyright (C) 2026 Antti Käenmäki

import AppKit
import Foundation
import WebKit

final class ReadmeWindowController: NSWindowController {
    private let webView = WKWebView(frame: .zero)
    private let textView = NSTextView(frame: .zero)
    private let scrollView = NSScrollView(frame: .zero)
    private var hasCenteredWindow = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        configureWindow()
        loadReadme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showReadmeWindow() {
        loadReadme()
        if !hasCenteredWindow {
            window?.center()
            hasCenteredWindow = true
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureWindow() {
        window?.title = "About Awake"
        window?.minSize = NSSize(width: 560, height: 420)
        window?.isReleasedWhenClosed = false

        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 22, height: 18)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        }

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        window?.contentView = webView
    }

    private func loadReadme() {
        guard let readmeURL = Bundle.main.url(forResource: "README", withExtension: "md") else {
            setPlainText("The bundled Awake guide could not be found.")
            return
        }

        do {
            let markdownData = try Data(contentsOf: readmeURL)
            let markdown = String(decoding: markdownData, as: UTF8.self)
            let html = renderHTMLDocument(for: markdown)
            webView.loadHTMLString(html, baseURL: readmeURL.deletingLastPathComponent())
            window?.contentView = webView
        } catch {
            setPlainText("Awake could not open its bundled guide.\n\n\(error.localizedDescription)")
        }
    }

    private func renderHTMLDocument(for markdown: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          font-size: 15px;
          line-height: 1.55;
          margin: 0;
          padding: 24px 28px 40px;
          max-width: 860px;
          color: #222;
          background: transparent;
        }
        h1, h2, h3 { line-height: 1.25; margin-top: 1.4em; margin-bottom: 0.55em; }
        h1 { font-size: 1.9em; }
        h2 { font-size: 1.45em; }
        h3 { font-size: 1.18em; }
        p { margin: 0.7em 0; }
        ul { margin: 0.55em 0 0.9em 1.4em; padding: 0; }
        li { margin: 0.25em 0; }
        code {
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          font-size: 0.92em;
          background: rgba(127,127,127,0.14);
          border-radius: 5px;
          padding: 0.08em 0.32em;
        }
        pre {
          background: rgba(127,127,127,0.12);
          border-radius: 10px;
          padding: 14px 16px;
          overflow-x: auto;
          margin: 0.9em 0 1.1em;
        }
        pre code {
          background: transparent;
          padding: 0;
          border-radius: 0;
        }
        </style>
        </head>
        <body>\(renderMarkdownBody(markdown))</body>
        </html>
        """
    }

    private func renderMarkdownBody(_ markdown: String) -> String {
        var html: [String] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var listDepth = 0
        var inCodeBlock = false

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            html.append("<p>\(renderInlineMarkdown(paragraphLines.joined(separator: " ")))</p>")
            paragraphLines.removeAll()
        }

        func closeLists(to depth: Int = 0) {
            while listDepth > depth {
                html.append("</ul>")
                listDepth -= 1
            }
        }

        func flushCodeBlock() {
            guard !codeLines.isEmpty else { return }
            html.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
            codeLines.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if rawLine.hasPrefix("```") {
                flushParagraph()
                closeLists()
                if inCodeBlock {
                    flushCodeBlock()
                }
                inCodeBlock.toggle()
                continue
            }

            if inCodeBlock {
                codeLines.append(rawLine)
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                closeLists()
                continue
            }

            if let heading = headingHTML(for: trimmed) {
                flushParagraph()
                closeLists()
                html.append(heading)
                continue
            }

            if let listItem = parseListItem(rawLine) {
                flushParagraph()
                while listDepth < listItem.depth {
                    html.append("<ul>")
                    listDepth += 1
                }
                closeLists(to: listItem.depth)
                html.append("<li>\(renderInlineMarkdown(listItem.content))</li>")
                continue
            }

            closeLists()
            paragraphLines.append(trimmed)
        }

        if inCodeBlock {
            flushCodeBlock()
        }
        flushParagraph()
        closeLists()
        return html.joined(separator: "\n")
    }

    private func headingHTML(for line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else {
            return nil
        }
        let text = line.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return nil
        }
        return "<h\(hashes.count)>\(renderInlineMarkdown(text))</h\(hashes.count)>"
    }

    private func parseListItem(_ line: String) -> (depth: Int, content: String)? {
        let indentCount = line.prefix { $0 == " " }.count
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") else {
            return nil
        }
        return (max(1, indentCount / 2 + 1), String(trimmed.dropFirst(2)))
    }

    private func renderInlineMarkdown(_ text: String) -> String {
        let escaped = escapeHTML(text)
        let parts = escaped.components(separatedBy: "`")
        guard parts.count > 1 else {
            return escaped
        }
        return parts.enumerated().map { index, part in
            index.isMultiple(of: 2) ? part : "<code>\(part)</code>"
        }.joined()
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func setPlainText(_ text: String) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attributes))
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        window?.contentView = scrollView
    }
}
