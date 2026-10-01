//
//  CodeEditorView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI
import UIKit

// The code editor wraps UITextView so it can do what TextEditor can't:
// - turn off autocorrect and auto-capitals (so "launch()" doesn't become "Launch()")
// - color the code like Xcode does
// - auto-indent, and close a { for you when you press return
// - highlight the running line, the line with an error, and the line you tapped
// - show line numbers that stay lined up as you scroll, with loop counts and sensor results
//
// The text is the single source of truth: the editor only reports what was typed, and the
// code is parsed when Run is pressed.

struct CodeEditorView: UIViewRepresentable {
    @Binding var code: String
    let activeLine: Int?
    let errorLine: Int?
    let selectedLine: Int?
    let notes: [Int: GutterNote]
    let isEditable: Bool
    let bridge: EditorBridge
    let onEdit: () -> Void
    let onLineTapped: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> CodeEditorContainer {
        let container = CodeEditorContainer()
        container.textView.delegate = context.coordinator
        container.textView.text = code
        return container
    }

    func updateUIView(_ container: CodeEditorContainer, context: Context) {
        context.coordinator.parent = self
        bridge.textView = container.textView
        container.gutter.onLineTapped = onLineTapped

        if container.textView.text != code {
            container.textView.text = code
        }
        container.textView.isEditable = isEditable
        container.activeLine = activeLine
        container.errorLine = errorLine
        container.selectedLine = selectedLine
        container.notes = notes
        container.refresh()
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditorView

        init(parent: CodeEditorView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.code = textView.text
            (textView.superview as? CodeEditorContainer)?.refresh()
            parent.onEdit()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            (scrollView.superview as? CodeEditorContainer)?.gutter.setNeedsDisplay()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let content = textView.text as NSString
            let lineStart = content.lineRange(for: NSRange(location: range.location, length: 0)).location
            let beforeCursor = content.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
            let indent = String(beforeCursor.prefix { $0 == " " })

            switch text {
            case "\n":
                // Keep the current indent, and indent one more level after a {.
                guard beforeCursor.trimmingCharacters(in: .whitespaces).hasSuffix("{") else {
                    textView.insertText("\n" + indent)
                    return false
                }
                let inner = indent + "    "
                let afterCursor = content.substring(from: range.location + range.length)
                let restOfLine = afterCursor.prefix { $0 != "\n" }
                let opens = textView.text.filter { $0 == "{" }.count
                let closes = textView.text.filter { $0 == "}" }.count
                if restOfLine.trimmingCharacters(in: .whitespaces).hasPrefix("}") {
                    textView.insertText("\n" + inner + "\n" + indent)
                } else if opens > closes {
                    // This { has no partner yet, so add its } on the line below.
                    textView.insertText("\n" + inner + "\n" + indent + "}")
                } else {
                    textView.insertText("\n" + inner)
                    return false
                }
                textView.selectedRange = NSRange(location: range.location + 1 + (inner as NSString).length, length: 0)
                return false

            case "}" where beforeCursor.count >= 4 && beforeCursor.allSatisfy({ $0 == " " }):
                // Typing } on an indented blank line moves it back to line up with its {.
                textView.selectedRange = NSRange(location: lineStart, length: (beforeCursor as NSString).length + range.length)
                textView.insertText(String(beforeCursor.dropLast(4)) + "}")
                return false

            case "\t":
                textView.insertText("    ")
                return false

            default:
                return true
            }
        }
    }
}

/// Lets the block palette type into the editor at the cursor.
@MainActor
final class EditorBridge {
    weak var textView: UITextView?

    func insert(_ snippet: String) {
        guard let textView, textView.isEditable else { return }
        // Without a cursor (the keyboard isn't up), blocks go at the end.
        if !textView.isFirstResponder {
            textView.selectedRange = NSRange(location: (textView.text as NSString).length, length: 0)
        }

        let content = textView.text as NSString
        let cursor = textView.selectedRange.location
        let lineRange = content.lineRange(for: NSRange(location: cursor, length: 0))
        let lineText = content.substring(with: lineRange)
        let indent = String(lineText.prefix { $0 == " " })
        let lineIsBlank = lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        var text = snippet.replacingOccurrences(of: "\n", with: "\n" + indent)
        if !lineIsBlank {
            // Put the block on a new line below the current one.
            let lineEnd = lineRange.location + (lineText.hasSuffix("\n") ? lineRange.length - 1 : lineRange.length)
            textView.selectedRange = NSRange(location: lineEnd, length: 0)
            text = "\n" + indent + text
        }

        // "$0" marks where the cursor should land, such as inside a new repeat block.
        let insertAt = textView.selectedRange.location
        let marker = (text as NSString).range(of: "$0")
        let cleaned = text.replacingOccurrences(of: "$0", with: "")
        textView.insertText(cleaned)
        if marker.location != NSNotFound {
            textView.selectedRange = NSRange(location: insertAt + marker.location, length: 0)
        }
    }
}

final class CodeEditorContainer: UIView {
    let textView = UITextView()
    let gutter = GutterView()
    var activeLine: Int?
    var errorLine: Int?
    var selectedLine: Int?
    var notes: [Int: GutterNote] = [:]

    private let highlighter = SyntaxHighlighter()

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 1, alpha: 0.04)

        textView.backgroundColor = .clear
        textView.font = SyntaxHighlighter.font
        textView.textColor = .white
        textView.tintColor = SceneArt.trailColor
        textView.adjustsFontForContentSizeCategory = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.inlinePredictionType = .no
        textView.keyboardAppearance = .dark
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 8)
        textView.accessibilityLabel = "Code editor"
        textView.accessibilityHint = "Write commands for the rocket, one per line."

        gutter.textView = textView
        addSubview(gutter)
        addSubview(textView)

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (container: CodeEditorContainer, _) in
            container.textView.font = SyntaxHighlighter.font
            container.refresh()
            container.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let gutterWidth = UIFontMetrics(forTextStyle: .body).scaledValue(for: 44)
        gutter.frame = CGRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
        textView.frame = CGRect(x: gutterWidth, y: 0, width: bounds.width - gutterWidth, height: bounds.height)
        gutter.setNeedsDisplay()
    }

    func refresh() {
        highlighter.apply(to: textView, activeLine: activeLine, errorLine: errorLine, selectedLine: selectedLine)
        gutter.activeLine = activeLine
        gutter.errorLine = errorLine
        gutter.notes = notes
        gutter.setNeedsDisplay()
    }
}

/// Line numbers, drawn next to each line's position in the text view.
final class GutterView: UIView {
    weak var textView: UITextView?
    var activeLine: Int?
    var errorLine: Int?
    var notes: [Int: GutterNote] = [:]
    var onLineTapped: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 1, alpha: 0.03)
        contentMode = .redraw
        isAccessibilityElement = false
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Where each line starts on screen, found from the caret position at the start of the line.
    private func lineFrames() -> [(line: Int, rect: CGRect)] {
        guard let textView else { return [] }
        let content = textView.text as NSString
        var frames: [(Int, CGRect)] = []
        var lineStart = 0
        var line = 1
        while true {
            if let position = textView.position(from: textView.beginningOfDocument, offset: lineStart) {
                var rect = textView.caretRect(for: position)
                rect.origin.y -= textView.contentOffset.y
                frames.append((line, rect))
            }
            let newline = content.range(of: "\n", options: [], range: NSRange(location: lineStart, length: content.length - lineStart))
            if newline.location == NSNotFound { break }
            lineStart = newline.location + 1
            line += 1
        }
        return frames
    }

    override func draw(_ rect: CGRect) {
        let font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold))
        for (line, caret) in lineFrames() where caret.maxY >= 0 && caret.minY <= bounds.height {
            let note = notes[line]
            let text = (note?.text ?? "\(line)") as NSString
            let color: UIColor = switch note?.style {
            case .loop: SceneArt.guideGold
            case .yes: .systemOrange
            case .no: .systemTeal
            case nil: line == errorLine ? .systemRed : line == activeLine ? .white : UIColor(white: 1, alpha: 0.35)
            }
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let size = text.size(withAttributes: attributes)
            if line == activeLine {
                let pill = CGRect(x: 3, y: caret.midY - size.height / 2 - 2, width: bounds.width - 6, height: size.height + 4)
                SceneArt.trailColor.withAlphaComponent(0.35).setFill()
                UIBezierPath(roundedRect: pill, cornerRadius: 5).fill()
            }
            text.draw(at: CGPoint(x: bounds.width - size.width - 7, y: caret.midY - size.height / 2), withAttributes: attributes)
        }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let y = gesture.location(in: self).y
        if let hit = lineFrames().first(where: { $0.rect.minY - 4 <= y && y <= $0.rect.maxY + 4 }) {
            onLineTapped?(hit.line)
        }
    }
}

/// Colors the code by kind of word, Xcode-style.
@MainActor
struct SyntaxHighlighter {
    static var font: UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedSystemFont(ofSize: 16, weight: .regular))
    }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: UIColor.white]
    }

    private let rules: [(NSRegularExpression, UIColor)] = [
        ("\\b(repeat|if|else)\\b", UIColor(red: 1, green: 0.48, blue: 0.7, alpha: 1)),
        ("\\b(launch|move)\\b", UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 1)),
        ("\\b(up|down|left|right)\\b", UIColor(red: 1, green: 0.7, blue: 0.35, alpha: 1)),
        ("\\basteroidAhead\\b", UIColor(red: 0.95, green: 0.85, blue: 0.4, alpha: 1)),
        ("\\b\\d+\\b", UIColor(red: 0.75, green: 0.65, blue: 1, alpha: 1)),
        ("//.*", UIColor(red: 0.5, green: 0.56, blue: 0.62, alpha: 1))
    ].compactMap { pattern, color in
        (try? NSRegularExpression(pattern: pattern)).map { ($0, color) }
    }

    func apply(to textView: UITextView, activeLine: Int?, errorLine: Int?, selectedLine: Int?) {
        let storage = textView.textStorage
        let text = storage.string as NSString
        let everything = NSRange(location: 0, length: text.length)

        storage.beginEditing()
        storage.setAttributes(Self.baseAttributes, range: everything)
        for (expression, color) in rules {
            for match in expression.matches(in: storage.string, range: everything) {
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        let lineColors: [(Int?, UIColor)] = [
            (selectedLine, UIColor.systemYellow.withAlphaComponent(0.22)),
            (activeLine, SceneArt.trailColor.withAlphaComponent(0.3)),
            (errorLine, UIColor.systemRed.withAlphaComponent(0.3))
        ]
        for case let (line?, color) in lineColors {
            guard let range = Self.range(ofLine: line, in: text) else { continue }
            storage.addAttribute(.backgroundColor, value: color, range: range)
            if line == errorLine {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue, range: range)
                storage.addAttribute(.underlineColor, value: UIColor.systemRed, range: range)
            }
        }
        storage.endEditing()
        textView.typingAttributes = Self.baseAttributes
    }

    /// The characters of a line (counting from 1), without its newline.
    static func range(ofLine target: Int, in text: NSString) -> NSRange? {
        var line = 1
        var start = 0
        while line < target {
            let newline = text.range(of: "\n", options: [], range: NSRange(location: start, length: text.length - start))
            guard newline.location != NSNotFound else { return nil }
            start = newline.location + 1
            line += 1
        }
        let rest = NSRange(location: start, length: text.length - start)
        let end = text.range(of: "\n", options: [], range: rest)
        return NSRange(location: start, length: (end.location == NSNotFound ? text.length : end.location) - start)
    }
}
