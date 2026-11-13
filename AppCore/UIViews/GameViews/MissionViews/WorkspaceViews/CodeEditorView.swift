//
//  CodeEditorView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SwiftUI
import UIKit

// The code editor wraps UITextView so it can do what TextEditor can't:
// - turn off autocorrect and auto-capitals (so "launch" doesn't become "Launch")
// - color the code like Xcode does
// - auto-indent: press return after a line ending in : and the next line is indented
// - highlight the running line, the line with an error, the line you tapped, and the line you're on
// - show line numbers that stay lined up as you scroll, with loop counts and sensor results
// - feel alive: a glowing cursor, and a little sparkle whenever a block lands
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
    let onFocusChange: (Bool) -> Void

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
        bridge.container = container
        container.gutter.onLineTapped = { line in
            Feedback.select()
            onLineTapped(line)
        }

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

        private func container(of view: UIView) -> CodeEditorContainer? {
            view.superview as? CodeEditorContainer
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.code = textView.text
            container(of: textView)?.refresh()
            parent.onEdit()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            container(of: textView)?.cursorMoved()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            container(of: textView)?.focusChanged(true)
            parent.onFocusChange(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            container(of: textView)?.focusChanged(false)
            parent.onFocusChange(false)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            container(of: scrollView)?.scrolled()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let content = textView.text as NSString
            let lineStart = content.lineRange(for: NSRange(location: range.location, length: 0)).location
            let beforeCursor = content.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
            let indent = String(beforeCursor.prefix { $0 == " " })

            switch text {
            case "\n":
                // Keep the current indent, and indent one more level after a line ending in a colon.
                let opensBlock = beforeCursor.trimmingCharacters(in: .whitespaces).hasSuffix(":")
                textView.insertText("\n" + indent + (opensBlock ? "    " : ""))
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
    weak var container: CodeEditorContainer?

    func insert(_ snippet: String) {
        guard let container, container.textView.isEditable else { return }
        let textView = container.textView
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

        // Work out which lines are new, so they can sparkle.
        let before = (textView.text as NSString).substring(to: insertAt)
        var firstLine = before.filter { $0 == "\n" }.count + 1
        if cleaned.hasPrefix("\n") { firstLine += 1 }
        let lineCount = cleaned.trimmingCharacters(in: .newlines).split(separator: "\n", omittingEmptySubsequences: false).count
        container.celebrateInsertion(lines: firstLine..<(firstLine + max(lineCount, 1)))
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
    private let placeholder = UILabel()
    private let caretGlow = UIView()
    private var isEditing = false

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled || UserDefaults.standard.bool(forKey: "isReducedMotion")
    }

    init() {
        super.init(frame: .zero)
        backgroundColor = Palette.deepSpace

        textView.backgroundColor = .clear
        textView.font = SyntaxHighlighter.font
        textView.textColor = Palette.starlight
        textView.tintColor = Palette.nebulaPurple
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
        textView.textContainerInset = UIEdgeInsets(top: Space.m, left: Space.xs, bottom: Space.m, right: Space.s)
        textView.accessibilityLabel = "Code editor"
        textView.accessibilityHint = "Write commands for the rocket, one per line."

        placeholder.text = GuideVoice.editorPlaceholder
        placeholder.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedSystemFont(ofSize: 16, weight: .regular))
        placeholder.adjustsFontForContentSizeCategory = true
        placeholder.textColor = Palette.starlight.withAlphaComponent(0.35)
        placeholder.numberOfLines = 0
        placeholder.isAccessibilityElement = false

        // A soft lime glow that follows the cursor and breathes while you type.
        let glowLayer = CAGradientLayer()
        glowLayer.type = .radial
        glowLayer.colors = [Palette.goldTrim.withAlphaComponent(0.55).cgColor, Palette.goldTrim.withAlphaComponent(0).cgColor]
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 1)
        glowLayer.frame = CGRect(x: 0, y: 0, width: Space.xl, height: Space.xl)
        caretGlow.layer.addSublayer(glowLayer)
        caretGlow.frame = glowLayer.frame
        caretGlow.isUserInteractionEnabled = false
        caretGlow.alpha = 0

        gutter.textView = textView
        addSubview(gutter)
        addSubview(textView)
        addSubview(placeholder)
        addSubview(caretGlow)

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
        let inset = textView.textContainerInset
        let placeholderWidth = textView.bounds.width - inset.left - inset.right - Space.s
        let placeholderSize = placeholder.sizeThatFits(CGSize(width: placeholderWidth, height: .greatestFiniteMagnitude))
        placeholder.frame = CGRect(x: gutterWidth + inset.left + Space.xs, y: inset.top, width: placeholderWidth, height: placeholderSize.height)
        gutter.setNeedsDisplay()
        cursorMoved()
    }

    func refresh() {
        let cursorLine = isEditing ? currentLine() : nil
        highlighter.apply(to: textView, activeLine: activeLine, errorLine: errorLine, selectedLine: selectedLine, cursorLine: cursorLine)
        placeholder.isHidden = !textView.text.isEmpty
        gutter.activeLine = activeLine
        gutter.errorLine = errorLine
        gutter.notes = notes
        gutter.setNeedsDisplay()
    }

    // MARK: Focus and cursor

    func focusChanged(_ focused: Bool) {
        isEditing = focused
        refresh()
        UIView.animate(withDuration: 0.25) { self.caretGlow.alpha = focused ? 1 : 0 }
        if focused && !reduceMotion {
            let breathe = CABasicAnimation(keyPath: "opacity")
            breathe.fromValue = 1
            breathe.toValue = 0.35
            breathe.duration = 1.1
            breathe.autoreverses = true
            breathe.repeatCount = .infinity
            breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            caretGlow.layer.add(breathe, forKey: "breathe")
        } else {
            caretGlow.layer.removeAnimation(forKey: "breathe")
        }
    }

    func cursorMoved() {
        if isEditing { refresh() }
        guard let range = textView.selectedTextRange else { return }
        let caret = textView.caretRect(for: range.end)
        let point = textView.convert(CGPoint(x: caret.midX, y: caret.midY), to: self)
        caretGlow.center = point
    }

    func scrolled() {
        gutter.setNeedsDisplay()
        cursorMoved()
    }

    private func currentLine() -> Int {
        let location = min(textView.selectedRange.location, (textView.text as NSString).length)
        return (textView.text as NSString).substring(to: location).filter { $0 == "\n" }.count + 1
    }

    // MARK: Delight

    /// When a block lands: the new lines glow and wiggle, and a few sparkles pop out at the cursor.
    func celebrateInsertion(lines: Range<Int>) {
        layoutIfNeeded()
        for line in lines {
            guard let rect = rect(forLine: line) else { continue }
            let bar = UIView(frame: CGRect(x: gutter.frame.maxX + Space.xs, y: rect.minY - 1, width: textView.bounds.width - Space.s, height: rect.height + 2))
            bar.backgroundColor = Palette.goldTrim.withAlphaComponent(0.22)
            bar.layer.cornerRadius = Radius.small / 2
            bar.isUserInteractionEnabled = false
            insertSubview(bar, belowSubview: placeholder)
            if !reduceMotion {
                let wiggle = CAKeyframeAnimation(keyPath: "transform.translation.x")
                wiggle.values = [0, -5, 4, -2, 1, 0]
                wiggle.duration = 0.4
                bar.layer.add(wiggle, forKey: "wiggle")
            }
            UIView.animate(withDuration: 0.7, delay: 0.35, options: [.curveEaseOut]) {
                bar.alpha = 0
            } completion: { _ in
                bar.removeFromSuperview()
            }
        }
        guard !reduceMotion else { return }
        sparkle(at: caretGlow.center)
    }

    private func rect(forLine line: Int) -> CGRect? {
        guard let range = SyntaxHighlighter.range(ofLine: line, in: textView.text as NSString),
              let start = textView.position(from: textView.beginningOfDocument, offset: range.location) else { return nil }
        return textView.convert(textView.caretRect(for: start), to: self)
    }

    private static let sparkleImage: CGImage? = {
        let size = CGSize(width: 24, height: 24)
        return UIGraphicsImageRenderer(size: size).image { _ in
            Palette.starlight.setFill()
            UIBezierPath(cgPath: SparkleShape().path(in: CGRect(origin: .zero, size: size)).cgPath).fill()
        }.cgImage
    }()

    private func sparkle(at point: CGPoint) {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        let cell = CAEmitterCell()
        cell.contents = Self.sparkleImage
        cell.birthRate = 140
        cell.lifetime = 0.7
        cell.velocity = 70
        cell.velocityRange = 40
        cell.emissionRange = .pi * 2
        cell.scale = 0.45
        cell.scaleRange = 0.2
        cell.scaleSpeed = -0.5
        cell.spin = 2
        cell.spinRange = 3
        cell.alphaSpeed = -1.4
        cell.color = Palette.goldTrim.cgColor
        emitter.emitterCells = [cell]
        layer.addSublayer(emitter)
        // A short puff, then the sparkles fade on their own.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            emitter.birthRate = 0
            try? await Task.sleep(for: .seconds(1))
            emitter.removeFromSuperlayer()
        }
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
        backgroundColor = .clear
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
        // No line numbers: they're clutter for beginners. The margin only speaks up when it has
        // something to say: a loop's count, an if's answer, or a dot beside the running line.
        for (line, caret) in lineFrames() where caret.maxY >= 0 && caret.minY <= bounds.height {
            guard let note = notes[line] else {
                if line == activeLine || line == errorLine {
                    let dot = CGRect(x: bounds.width - Space.l, y: caret.midY - Space.xs, width: Space.s, height: Space.s)
                    (line == errorLine ? Palette.goldTrim : Palette.softTeal).setFill()
                    UIBezierPath(ovalIn: dot).fill()
                }
                continue
            }
            let color: UIColor = switch note.style {
            case .loop: Palette.goldTrim
            case .yes: Palette.softTeal
            case .no: Palette.nebulaPurple
            }
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let text = note.text as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: bounds.width - size.width - Space.s, y: caret.midY - size.height / 2), withAttributes: attributes)
        }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let y = gesture.location(in: self).y
        if let hit = lineFrames().first(where: { $0.rect.minY - 4 <= y && y <= $0.rect.maxY + 4 }) {
            onLineTapped?(hit.line)
        }
    }
}

/// Colors the code by kind of word, using only the palette.
@MainActor
struct SyntaxHighlighter {
    static var font: UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedSystemFont(ofSize: 16, weight: .regular))
    }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: Palette.starlight]
    }

    private let rules: [(NSRegularExpression, UIColor)] = [
        ("\\b(repeat|times|if|else|not)\\b", Palette.goldTrim),
        ("\\bcreate\\b", Palette.nebulaPurple),
        ("\\b(launch|orbit|explore|land|move)\\b", Palette.goldTrim.mixed(with: Palette.starlight, 0.15)),
        ("\\b(up|down|left|right)\\b", Palette.goldTrim),
        ("\\b(launchpad|rocket|star|planet|moon|satellite|asteroid|comet|rover|base)\\b", Palette.goldTrim.mixed(with: Palette.starlight, 0.4)),
        ("\\b(suitUp|stargaze|hello|hi)\\b", Palette.goldTrim.mixed(with: Palette.goldTrim, 0.4)),
        ("\\b\\d+\\b", Palette.nebulaPurple.mixed(with: Palette.starlight, 0.4)),
        ("//.*", Palette.starlight.withAlphaComponent(0.4))
    ].compactMap { pattern, color in
        (try? NSRegularExpression(pattern: pattern)).map { ($0, color) }
    }

    func apply(to textView: UITextView, activeLine: Int?, errorLine: Int?, selectedLine: Int?, cursorLine: Int?) {
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

        // Later entries win: the running line and errors matter more than where the cursor is.
        let lineColors: [(Int?, UIColor)] = [
            (cursorLine, Palette.starlight.withAlphaComponent(0.06)),
            (selectedLine, Palette.goldTrim.withAlphaComponent(0.2)),
            (activeLine, Palette.goldTrim.withAlphaComponent(0.28)),
            (errorLine, Palette.softTeal.withAlphaComponent(0.3))
        ]
        for case let (line?, color) in lineColors {
            guard let range = Self.range(ofLine: line, in: text) else { continue }
            storage.addAttribute(.backgroundColor, value: color, range: range)
            if line == errorLine {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue, range: range)
                storage.addAttribute(.underlineColor, value: Palette.goldTrim, range: range)
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
