import SwiftUI

// MARK: - Platform Color Helpers

/// Primary text color, adapting to platform.
private var labelColor: Color {
    #if os(iOS)
    return Color(.label)
    #else
    return Color(nsColor: .labelColor)
    #endif
}

/// Placeholder/loading background, adapting to platform.
private var placeholderBackgroundColor: Color {
    #if os(iOS)
    return Color(.systemGray6)
    #else
    return Color.gray.opacity(0.1)
    #endif
}

// MARK: - MarkdownContent

/// Native SwiftUI markdown renderer for FarmerChat's agricultural content.
///
/// Supports: bold, italic, strikethrough, headings, bullet/ordered/task lists,
/// tables (GFM), links, images, horizontal rules.
///
/// Does NOT support (treated as plain text): code blocks, LaTeX, block quotes.
///
/// Uses a line-by-line block parser that produces SwiftUI views, matching the
/// approach in the Android Compose `MarkdownContent.kt`.
struct MarkdownContent: View {

    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let blocks = parseBlocks(text)
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }
}

// MARK: - Block Types

/// Parsed markdown block types.
private enum MarkdownBlock {
    case paragraph(String)
    case heading(level: Int, text: String)
    case bulletList(items: [String])
    case orderedList(start: Int, items: [String])
    case taskList(items: [(checked: Bool, text: String)])
    case table(header: [String], alignments: [HorizontalAlignment], rows: [[String]])
    case horizontalRule
    case image(alt: String, url: String)
}

// MARK: - Block Parser

/// Parses raw markdown text into an array of `MarkdownBlock` values.
///
/// Processes lines sequentially, grouping consecutive lines of the same type
/// into a single block (e.g., consecutive bullet items become one `bulletList`).
private func parseBlocks(_ text: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    let lines = text.components(separatedBy: "\n")
    var i = 0

    while i < lines.count {
        let line = lines[i]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Empty line -- skip
        if trimmed.isEmpty {
            i += 1
            continue
        }

        // Horizontal rule: --- or *** or ___ (3 or more, possibly with spaces)
        let hrStripped = trimmed.replacingOccurrences(of: " ", with: "")
        if hrStripped.count >= 3,
           let firstChar = hrStripped.first,
           ["-", "*", "_"].contains(String(firstChar)),
           hrStripped.allSatisfy({ $0 == firstChar }) {
            // Distinguish from bullet list: "- text" would have non-marker characters
            if trimmed.range(of: #"^[-*_]\s+\S"#, options: .regularExpression) == nil {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }
        }

        // Heading: # ## ###
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

        // Image (standalone line): ![alt](url)
        if let imgMatch = trimmed.range(of: #"^!\[([^\]]*)\]\(([^)]+)\)$"#, options: .regularExpression) {
            let imgStr = String(trimmed[imgMatch])
            if let altRange = imgStr.range(of: #"\[([^\]]*)\]"#, options: .regularExpression),
               let urlRange = imgStr.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
                let alt = String(imgStr[altRange]).dropFirst().dropLast()
                let url = String(imgStr[urlRange]).dropFirst().dropLast()
                blocks.append(.image(alt: String(alt), url: String(url)))
            }
            i += 1
            continue
        }

        // Table: line starts with | and next line is separator row
        if trimmed.hasPrefix("|"),
           i + 1 < lines.count,
           isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
            let header = parseTableRow(trimmed)
            let separatorLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
            let alignments = parseTableAlignments(separatorLine)
            var rows: [[String]] = []
            i += 2
            while i < lines.count {
                let rowLine = lines[i].trimmingCharacters(in: .whitespaces)
                if rowLine.hasPrefix("|") {
                    rows.append(parseTableRow(rowLine))
                    i += 1
                } else {
                    break
                }
            }
            blocks.append(.table(header: header, alignments: alignments, rows: rows))
            continue
        }

        // Task list item: - [ ] or - [x]
        if trimmed.range(of: #"^[-*+]\s+\[[ xX]\]\s+"#, options: .regularExpression) != nil {
            var taskItems: [(checked: Bool, text: String)] = []
            while i < lines.count {
                let tl = lines[i].trimmingCharacters(in: .whitespaces)
                if tl.range(of: #"^[-*+]\s+\[([ xX])\]\s+(.*)"#, options: .regularExpression) != nil {
                    // Extract the check character and text
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

        // Bullet list item: - or * or +
        if trimmed.range(of: #"^[-*+]\s+."#, options: .regularExpression) != nil {
            var items: [String] = []
            while i < lines.count {
                let bl = lines[i].trimmingCharacters(in: .whitespaces)
                if bl.range(of: #"^[-*+]\s+(.*)"#, options: .regularExpression) != nil {
                    // Skip the marker and space
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

        // Ordered list item: 1. 2. etc.
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

        // Paragraph (default): collect consecutive non-special lines
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
            if next.range(of: #"^!\[.*\]\(.*\)$"#, options: .regularExpression) != nil { break }
            paragraphLines.append(next)
            i += 1
        }
        blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
    }

    return blocks
}

// MARK: - Table Helpers

/// Checks if a line is a GFM table separator (e.g., `| --- | :---: | ---: |`).
private func isTableSeparator(_ line: String) -> Bool {
    guard line.hasPrefix("|") else { return false }
    let stripped = line.trimmingCharacters(in: .whitespaces)
    // Must contain only |, -, :, and spaces
    let allowed = CharacterSet(charactersIn: "|-: ")
    return stripped.unicodeScalars.allSatisfy { allowed.contains($0) }
        && stripped.contains("-")
}

/// Splits a pipe-delimited table row into cell strings.
private func parseTableRow(_ line: String) -> [String] {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    // Remove leading and trailing pipes
    if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
    if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
    return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
}

/// Parses column alignments from a GFM table separator row.
private func parseTableAlignments(_ line: String) -> [HorizontalAlignment] {
    let cells = parseTableRow(line)
    return cells.map { cell in
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(":") && trimmed.hasSuffix(":") {
            return .center
        } else if trimmed.hasSuffix(":") {
            return .trailing
        } else {
            return .leading
        }
    }
}

// MARK: - Block Renderer

/// Renders a single `MarkdownBlock` as a SwiftUI view.
@ViewBuilder
private func renderBlock(_ block: MarkdownBlock) -> some View {
    switch block {
    case .paragraph(let text):
        ParagraphView(text: text)

    case .heading(let level, let text):
        HeadingView(level: level, text: text)

    case .bulletList(let items):
        BulletListView(items: items)

    case .orderedList(let start, let items):
        OrderedListView(start: start, items: items)

    case .taskList(let items):
        TaskListView(items: items)

    case .table(let header, let alignments, let rows):
        TableView(header: header, alignments: alignments, rows: rows)

    case .horizontalRule:
        Divider()
            .padding(.vertical, 8)

    case .image(let alt, let url):
        MarkdownImageView(alt: alt, urlString: url)
    }
}

// MARK: - Inline Text Rendering

/// Builds an `AttributedString` from markdown inline formatting.
///
/// Handles: **bold**, *italic*, ~~strikethrough~~, [links](url).
/// Processes delimiters in priority order: links, bold, strikethrough, italic.
private func renderInlineText(_ text: String) -> AttributedString {
    var result = AttributedString()
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

                    var linkAttr = AttributedString(linkText)
                    if let url = URL(string: urlString),
                       let scheme = url.scheme?.lowercased(),
                       scheme == "http" || scheme == "https" {
                        linkAttr.link = url
                        linkAttr.foregroundColor = Color(red: 0.106, green: 0.420, blue: 0.227)
                        linkAttr.underlineStyle = .single
                    }
                    result += linkAttr
                    i = text.index(after: closeParen)
                    continue
                }
            }
            // Not a valid link, emit the bracket
            result += AttributedString(String(text[i]))
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
                    var boldAttr = renderInlineText(innerText)
                    for run in boldAttr.runs {
                        var container = AttributeContainer()
                        container.inlinePresentationIntent = (run.inlinePresentationIntent ?? []).union(.stronglyEmphasized)
                        boldAttr[run.range].mergeAttributes(container)
                    }
                    result += boldAttr
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
                    var strikeAttr = renderInlineText(innerText)
                    for run in strikeAttr.runs {
                        var container = AttributeContainer()
                        container.strikethroughStyle = .single
                        strikeAttr[run.range].mergeAttributes(container)
                    }
                    result += strikeAttr
                    i = endRange.upperBound
                    continue
                }
            }
        }

        // Italic: *text* or _text_ (single delimiter)
        if text[i] == "*" || text[i] == "_" {
            let delimiter = text[i]
            let nextIndex = text.index(after: i)
            // Make sure it's not the start of ** or __
            if nextIndex < text.endIndex && text[nextIndex] == delimiter {
                // This is a double delimiter (handled above if matched), emit single char
                result += AttributedString(String(text[i]))
                i = text.index(after: i)
                continue
            }
            // Find closing single delimiter
            if nextIndex < text.endIndex,
               let endIdx = text[nextIndex...].firstIndex(of: delimiter),
               endIdx > nextIndex {
                let innerText = String(text[nextIndex..<endIdx])
                var italicAttr = renderInlineText(innerText)
                for run in italicAttr.runs {
                    var container = AttributeContainer()
                    container.inlinePresentationIntent = (run.inlinePresentationIntent ?? []).union(.emphasized)
                    italicAttr[run.range].mergeAttributes(container)
                }
                result += italicAttr
                i = text.index(after: endIdx)
                continue
            }
            // No closing delimiter, emit the character
            result += AttributedString(String(text[i]))
            i = text.index(after: i)
            continue
        }

        // Plain character
        result += AttributedString(String(text[i]))
        i = text.index(after: i)
    }

    return result
}

// MARK: - Paragraph View

private struct ParagraphView: View {
    let text: String

    var body: some View {
        Text(renderInlineText(text))
            .font(.body)
            .foregroundStyle(labelColor)
            .padding(.vertical, 2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Heading View

private struct HeadingView: View {
    let level: Int
    let text: String

    var body: some View {
        Text(renderInlineText(text))
            .font(headingFont)
            .fontWeight(.bold)
            .foregroundStyle(labelColor)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var headingFont: Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        default: return .title3
        }
    }
}

// MARK: - Bullet List View

private struct BulletListView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 0) {
                    Text("\u{2022}")
                        .font(.body)
                        .foregroundStyle(labelColor)
                        .frame(width: 16)

                    Text(renderInlineText(item))
                        .font(.body)
                        .foregroundStyle(labelColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ordered List View

private struct OrderedListView: View {
    let start: Int
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 0) {
                    Text("\(start + index).")
                        .font(.body)
                        .foregroundStyle(labelColor)
                        .frame(width: 24, alignment: .trailing)
                        .padding(.trailing, 4)

                    Text(renderInlineText(item))
                        .font(.body)
                        .foregroundStyle(labelColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Task List View

private struct TaskListView: View {
    let items: [(checked: Bool, text: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            item.checked
                                ? Color(red: 0.106, green: 0.420, blue: 0.227)
                                : Color.secondary
                        )
                        .frame(width: 20, height: 20)

                    Text(renderInlineText(item.text))
                        .font(.body)
                        .foregroundStyle(labelColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Table View

private struct TableView: View {

    let header: [String]
    let alignments: [HorizontalAlignment]
    let rows: [[String]]

    /// Consistent colors for header and alternating rows.
    private let headerBackground = Color(red: 0.941, green: 0.969, blue: 0.949) // #F0F7F2
    private let altRowBackground = Color(red: 0.980, green: 0.980, blue: 0.980) // #FAFAFA
    private let minColumnWidth: CGFloat = 80

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(Array(header.enumerated()), id: \.offset) { colIndex, cell in
                        cellView(text: cell, isBold: true, colIndex: colIndex)
                            .frame(minWidth: minColumnWidth, alignment: cellFrameAlignment(at: colIndex))
                            .background(headerBackground)
                    }
                }

                Divider()

                // Data rows
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                            cellView(text: cell, isBold: false, colIndex: colIndex)
                                .frame(minWidth: minColumnWidth, alignment: cellFrameAlignment(at: colIndex))
                                .background(rowIndex % 2 == 1 ? altRowBackground : Color.clear)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func cellView(text: String, isBold: Bool, colIndex: Int) -> some View {
        Text(renderInlineText(text))
            .font(isBold ? .subheadline.bold() : .subheadline)
            .foregroundStyle(labelColor)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: cellFrameAlignment(at: colIndex))
    }

    private func columnAlignment(at index: Int) -> HorizontalAlignment {
        guard index < alignments.count else { return .leading }
        return alignments[index]
    }

    private func cellFrameAlignment(at index: Int) -> Alignment {
        switch columnAlignment(at: index) {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}

// MARK: - Image View

private struct MarkdownImageView: View {

    let alt: String
    let urlString: String

    var body: some View {
        if let url = URL(string: urlString),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    // Loading placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(placeholderBackgroundColor)
                        .frame(height: 100)
                        .overlay {
                            Text("Loading image\u{2026}")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(alt.isEmpty ? "Image" : alt)

                case .failure:
                    // Error state
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.secondary)
                        Text("[Image: \(alt)]")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.vertical, 2)

                @unknown default:
                    EmptyView()
                }
            }
            .padding(.vertical, 4)
        } else {
            // Invalid URL
            HStack(spacing: 4) {
                Image(systemName: "photo")
                    .foregroundStyle(Color.secondary)
                Text("[Image: \(alt)]")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}
