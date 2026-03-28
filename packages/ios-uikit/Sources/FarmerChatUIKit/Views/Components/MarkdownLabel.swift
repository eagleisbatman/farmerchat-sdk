#if canImport(UIKit)
import UIKit

/// A UITextView subclass that renders markdown text as NSAttributedString.
///
/// Supports: **bold**, *italic*, ~~strikethrough~~, [links](url),
/// headings (# ## ###), bullet lists, ordered lists, task lists,
/// horizontal rules, and tables (monospace layout).
///
/// Does NOT support (treated as plain text): code blocks, LaTeX, block quotes.
internal final class MarkdownLabel: UITextView {

    // MARK: - Properties

    /// The raw markdown text. Setting this triggers a re-render.
    var markdownText: String = "" {
        didSet {
            renderMarkdown()
        }
    }

    // MARK: - Init

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        isEditable = false
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        self.textContainer.lineFragmentPadding = 0
        dataDetectorTypes = [.link]
        linkTextAttributes = [
            .foregroundColor: UIColor(hex: "#1B6B3A"),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
    }

    // MARK: - Rendering

    private func renderMarkdown() {
        let blocks = Self.parseBlocks(markdownText)
        let result = NSMutableAttributedString()

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(Self.renderBlock(block))
        }

        attributedText = result
    }

    // MARK: - Block Types

    private enum MarkdownBlock {
        case paragraph(String)
        case heading(level: Int, text: String)
        case bulletList(items: [String])
        case orderedList(start: Int, items: [String])
        case taskList(items: [(checked: Bool, text: String)])
        case table(header: [String], rows: [[String]])
        case horizontalRule
    }

    // MARK: - Block Parser

    private static func parseBlocks(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Horizontal rule
            let hrStripped = trimmed.replacingOccurrences(of: " ", with: "")
            if hrStripped.count >= 3,
               let firstChar = hrStripped.first,
               ["-", "*", "_"].contains(String(firstChar)),
               hrStripped.allSatisfy({ $0 == firstChar }) {
                if trimmed.range(of: #"^[-*_]\s+\S"#, options: .regularExpression) == nil {
                    blocks.append(.horizontalRule)
                    i += 1
                    continue
                }
            }

            // Heading
            if let match = trimmed.range(of: #"^(#{1,3})\s+(.+)$"#, options: .regularExpression) {
                let fullMatch = String(trimmed[match])
                let hashEnd = fullMatch.firstIndex(of: " ") ?? fullMatch.endIndex
                let level = fullMatch[fullMatch.startIndex..<hashEnd].count
                let headingText = String(fullMatch[fullMatch.index(after: hashEnd)...])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"#+$"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 3), text: headingText))
                i += 1
                continue
            }

            // Table
            if trimmed.hasPrefix("|"),
               i + 1 < lines.count,
               Self.isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
                let header = Self.parseTableRow(trimmed)
                var rows: [[String]] = []
                i += 2
                while i < lines.count {
                    let rowLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if rowLine.hasPrefix("|") {
                        rows.append(Self.parseTableRow(rowLine))
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }

            // Task list
            if trimmed.range(of: #"^[-*+]\s+\[[ xX]\]\s+"#, options: .regularExpression) != nil {
                var taskItems: [(checked: Bool, text: String)] = []
                while i < lines.count {
                    let tl = lines[i].trimmingCharacters(in: .whitespaces)
                    if tl.range(of: #"^[-*+]\s+\[([ xX])\]\s+(.*)"#, options: .regularExpression) != nil {
                        if let bracketOpen = tl.firstIndex(of: "["),
                           let bracketClose = tl.firstIndex(of: "]") {
                            let checkChar = tl[tl.index(after: bracketOpen)]
                            let checked = checkChar == "x" || checkChar == "X"
                            let afterBracket = tl.index(bracketClose, offsetBy: 1)
                            let itemText = afterBracket < tl.endIndex
                                ? String(tl[afterBracket...]).trimmingCharacters(in: .whitespaces)
                                : ""
                            taskItems.append((checked: checked, text: itemText))
                        }
                        i += 1
                    } else {
                        break
                    }
                }
                if !taskItems.isEmpty {
                    blocks.append(.taskList(items: taskItems))
                }
                continue
            }

            // Bullet list
            if trimmed.range(of: #"^[-*+]\s+."#, options: .regularExpression) != nil {
                var items: [String] = []
                while i < lines.count {
                    let bl = lines[i].trimmingCharacters(in: .whitespaces)
                    if bl.range(of: #"^[-*+]\s+(.*)"#, options: .regularExpression) != nil {
                        if let spaceIdx = bl.firstIndex(of: " ") {
                            items.append(String(bl[bl.index(after: spaceIdx)...])
                                .trimmingCharacters(in: .whitespaces))
                        }
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty {
                    blocks.append(.bulletList(items: items))
                }
                continue
            }

            // Ordered list
            if trimmed.range(of: #"^\d+\.\s+."#, options: .regularExpression) != nil {
                var items: [String] = []
                var startNumber = 1
                var isFirst = true
                while i < lines.count {
                    let ol = lines[i].trimmingCharacters(in: .whitespaces)
                    if ol.range(of: #"^(\d+)\.\s+(.*)"#, options: .regularExpression) != nil {
                        if let dotIdx = ol.firstIndex(of: ".") {
                            if isFirst {
                                startNumber = Int(String(ol[ol.startIndex..<dotIdx])) ?? 1
                                isFirst = false
                            }
                            let textStart = ol.index(dotIdx, offsetBy: 2)
                            if textStart < ol.endIndex {
                                items.append(String(ol[textStart...])
                                    .trimmingCharacters(in: .whitespaces))
                            }
                        }
                        i += 1
                    } else {
                        break
                    }
                }
                if !items.isEmpty {
                    blocks.append(.orderedList(start: startNumber, items: items))
                }
                continue
            }

            // Paragraph
            var paragraphLines: [String] = [trimmed]
            i += 1
            while i < lines.count {
                let next = lines[i].trimmingCharacters(in: .whitespaces)
                if next.isEmpty { break }
                if next.hasPrefix("#") { break }
                if next.range(of: #"^[-*+]\s+"#, options: .regularExpression) != nil { break }
                if next.hasPrefix("|") { break }
                if next.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil { break }
                let nextStripped = next.replacingOccurrences(of: " ", with: "")
                if nextStripped.count >= 3,
                   let fc = nextStripped.first,
                   ["-", "*", "_"].contains(String(fc)),
                   nextStripped.allSatisfy({ $0 == fc }) { break }
                paragraphLines.append(next)
                i += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
        }

        return blocks
    }

    // MARK: - Table Helpers

    private static func isTableSeparator(_ line: String) -> Bool {
        guard line.hasPrefix("|") else { return false }
        let stripped = line.trimmingCharacters(in: .whitespaces)
        let allowed = CharacterSet(charactersIn: "|-: ")
        return stripped.unicodeScalars.allSatisfy { allowed.contains($0) }
            && stripped.contains("-")
    }

    private static func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Block Renderer

    private static func renderBlock(_ block: MarkdownBlock) -> NSAttributedString {
        switch block {
        case .paragraph(let text):
            let result = NSMutableAttributedString()
            result.append(renderInlineText(text, baseFont: .preferredFont(forTextStyle: .body)))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 4
            result.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: result.length)
            )
            return result

        case .heading(let level, let text):
            let fontSize: CGFloat
            switch level {
            case 1: fontSize = 24
            case 2: fontSize = 20
            default: fontSize = 17
            }
            let font = UIFont.boldSystemFont(ofSize: fontSize)
            let result = NSMutableAttributedString()
            result.append(renderInlineText(text, baseFont: font))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacingBefore = 8
            paragraphStyle.paragraphSpacing = 4
            result.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: result.length)
            )
            return result

        case .bulletList(let items):
            let result = NSMutableAttributedString()
            for (index, item) in items.enumerated() {
                if index > 0 { result.append(NSAttributedString(string: "\n")) }
                let bullet = NSMutableAttributedString(string: "\u{2022}  ", attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .foregroundColor: UIColor.label,
                ])
                bullet.append(renderInlineText(item, baseFont: .preferredFont(forTextStyle: .body)))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.headIndent = 16
                paragraphStyle.firstLineHeadIndent = 8
                bullet.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: bullet.length)
                )
                result.append(bullet)
            }
            return result

        case .orderedList(let start, let items):
            let result = NSMutableAttributedString()
            for (index, item) in items.enumerated() {
                if index > 0 { result.append(NSAttributedString(string: "\n")) }
                let number = NSMutableAttributedString(string: "\(start + index). ", attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .foregroundColor: UIColor.label,
                ])
                number.append(renderInlineText(item, baseFont: .preferredFont(forTextStyle: .body)))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.headIndent = 24
                paragraphStyle.firstLineHeadIndent = 8
                number.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: number.length)
                )
                result.append(number)
            }
            return result

        case .taskList(let items):
            let result = NSMutableAttributedString()
            let greenColor = UIColor(hex: "#1B6B3A")
            for (index, item) in items.enumerated() {
                if index > 0 { result.append(NSAttributedString(string: "\n")) }
                let checkmark = item.checked ? "\u{2611}" : "\u{2610}"
                let prefix = NSMutableAttributedString(string: "\(checkmark) ", attributes: [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: item.checked ? greenColor : UIColor.secondaryLabel,
                ])
                prefix.append(renderInlineText(item.text, baseFont: .preferredFont(forTextStyle: .body)))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.headIndent = 24
                paragraphStyle.firstLineHeadIndent = 4
                prefix.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: prefix.length)
                )
                result.append(prefix)
            }
            return result

        case .table(let header, let rows):
            let result = NSMutableAttributedString()
            let monoFont = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let boldMonoFont = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)

            // Header
            let headerText = header.joined(separator: " | ")
            result.append(NSAttributedString(string: headerText + "\n", attributes: [
                .font: boldMonoFont,
                .foregroundColor: UIColor.label,
            ]))

            // Separator
            let separator = String(repeating: "-", count: headerText.count)
            result.append(NSAttributedString(string: separator + "\n", attributes: [
                .font: monoFont,
                .foregroundColor: UIColor.secondaryLabel,
            ]))

            // Rows
            for (index, row) in rows.enumerated() {
                let rowText = row.joined(separator: " | ")
                let isLast = index == rows.count - 1
                result.append(NSAttributedString(string: rowText + (isLast ? "" : "\n"), attributes: [
                    .font: monoFont,
                    .foregroundColor: UIColor.label,
                ]))
            }

            return result

        case .horizontalRule:
            let result = NSMutableAttributedString(string: "\n")
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 8
            paragraphStyle.paragraphSpacingBefore = 8
            result.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: result.length)
            )
            return result
        }
    }

    // MARK: - Inline Text Rendering

    /// Builds an NSAttributedString from markdown inline formatting.
    ///
    /// Handles: **bold**, *italic*, ~~strikethrough~~, [links](url).
    private static func renderInlineText(_ text: String, baseFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var i = text.startIndex

        while i < text.endIndex {
            // Link: [text](url)
            if text[i] == "[" {
                if let closeBracket = text[text.index(after: i)...].firstIndex(of: "]"),
                   text.index(after: closeBracket) < text.endIndex,
                   text[text.index(after: closeBracket)] == "(" {
                    let parenStart = text.index(after: closeBracket)
                    if let closeParen = text[text.index(after: parenStart)...].firstIndex(of: ")") {
                        let linkText = String(text[text.index(after: i)..<closeBracket])
                        let urlString = String(text[text.index(after: parenStart)..<closeParen])

                        var attrs: [NSAttributedString.Key: Any] = [
                            .font: baseFont,
                            .foregroundColor: UIColor(hex: "#1B6B3A"),
                            .underlineStyle: NSUnderlineStyle.single.rawValue,
                        ]
                        if let url = URL(string: urlString),
                           let scheme = url.scheme?.lowercased(),
                           scheme == "http" || scheme == "https" {
                            attrs[.link] = url
                        }
                        result.append(NSAttributedString(string: linkText, attributes: attrs))
                        i = text.index(after: closeParen)
                        continue
                    }
                }
                result.append(NSAttributedString(string: String(text[i]), attributes: [
                    .font: baseFont, .foregroundColor: UIColor.label,
                ]))
                i = text.index(after: i)
                continue
            }

            // Bold: **text** or __text__
            if i < text.endIndex,
               text.index(after: i) < text.endIndex {
                let twoChar = String(text[i...text.index(after: i)])
                if twoChar == "**" || twoChar == "__" {
                    let searchStart = text.index(i, offsetBy: 2)
                    if searchStart < text.endIndex,
                       let endRange = text.range(of: twoChar, range: searchStart..<text.endIndex) {
                        let innerText = String(text[searchStart..<endRange.lowerBound])
                        let boldFont: UIFont
                        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) {
                            boldFont = UIFont(descriptor: descriptor, size: baseFont.pointSize)
                        } else {
                            boldFont = UIFont.boldSystemFont(ofSize: baseFont.pointSize)
                        }
                        result.append(renderInlineText(innerText, baseFont: boldFont))
                        i = endRange.upperBound
                        continue
                    }
                }
            }

            // Strikethrough: ~~text~~
            if i < text.endIndex,
               text.index(after: i) < text.endIndex {
                let twoChar = String(text[i...text.index(after: i)])
                if twoChar == "~~" {
                    let searchStart = text.index(i, offsetBy: 2)
                    if searchStart < text.endIndex,
                       let endRange = text.range(of: "~~", range: searchStart..<text.endIndex) {
                        let innerText = String(text[searchStart..<endRange.lowerBound])
                        let inner = renderInlineText(innerText, baseFont: baseFont)
                        let mutable = NSMutableAttributedString(attributedString: inner)
                        mutable.addAttribute(
                            .strikethroughStyle,
                            value: NSUnderlineStyle.single.rawValue,
                            range: NSRange(location: 0, length: mutable.length)
                        )
                        result.append(mutable)
                        i = endRange.upperBound
                        continue
                    }
                }
            }

            // Italic: *text* or _text_
            if text[i] == "*" || text[i] == "_" {
                let delimiter = text[i]
                let nextIndex = text.index(after: i)
                if nextIndex < text.endIndex && text[nextIndex] == delimiter {
                    // Double delimiter handled above
                    result.append(NSAttributedString(string: String(text[i]), attributes: [
                        .font: baseFont, .foregroundColor: UIColor.label,
                    ]))
                    i = text.index(after: i)
                    continue
                }
                if nextIndex < text.endIndex,
                   let endIdx = text[nextIndex...].firstIndex(of: delimiter),
                   endIdx > nextIndex {
                    let innerText = String(text[nextIndex..<endIdx])
                    let italicFont: UIFont
                    if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                        italicFont = UIFont(descriptor: descriptor, size: baseFont.pointSize)
                    } else {
                        italicFont = UIFont.italicSystemFont(ofSize: baseFont.pointSize)
                    }
                    result.append(renderInlineText(innerText, baseFont: italicFont))
                    i = text.index(after: endIdx)
                    continue
                }
                result.append(NSAttributedString(string: String(text[i]), attributes: [
                    .font: baseFont, .foregroundColor: UIColor.label,
                ]))
                i = text.index(after: i)
                continue
            }

            // Plain character
            result.append(NSAttributedString(string: String(text[i]), attributes: [
                .font: baseFont, .foregroundColor: UIColor.label,
            ]))
            i = text.index(after: i)
        }

        return result
    }
}
#endif
