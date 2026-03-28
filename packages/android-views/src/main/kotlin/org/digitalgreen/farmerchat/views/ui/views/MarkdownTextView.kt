package org.digitalgreen.farmerchat.views.ui.views

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.method.LinkMovementMethod
import android.text.style.BulletSpan
import android.text.style.ClickableSpan
import android.text.style.ForegroundColorSpan
import android.text.style.LeadingMarginSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StrikethroughSpan
import android.text.style.StyleSpan
import android.text.style.TypefaceSpan
import android.text.style.UnderlineSpan
import android.util.AttributeSet
import android.util.Log
import android.view.View
import androidx.appcompat.widget.AppCompatTextView

/**
 * Custom TextView subclass that renders a subset of Markdown using [SpannableStringBuilder].
 *
 * Supported syntax:
 * - **Bold** (`**text**` or `__text__`)
 * - *Italic* (`*text*` or `_text_`)
 * - ~~Strikethrough~~ (`~~text~~`)
 * - [Links](url) (`[text](url)`)
 * - Headings (`# H1` through `### H3`)
 * - Bullet lists (`- item` or `* item`)
 * - Numbered lists (`1. item`)
 * - Task lists (`- [ ] unchecked` / `- [x] checked`)
 * - Inline code (`` `code` ``)
 * - Horizontal rules (`---` or `***`)
 *
 * Tables and images are handled as simplified fallbacks (monospace for tables,
 * placeholder text for images) to avoid heavyweight dependencies.
 *
 * All parsing is wrapped in try-catch — the SDK must never crash the host app.
 */
internal class MarkdownTextView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : AppCompatTextView(context, attrs, defStyleAttr) {

    private companion object {
        const val TAG = "FC.MarkdownTV"

        // Regex patterns
        val HEADING_PATTERN = Regex("^(#{1,3})\\s+(.*)")
        val BOLD_PATTERN = Regex("\\*\\*(.+?)\\*\\*|__(.+?)__")
        val ITALIC_PATTERN = Regex("(?<![*_])\\*(?![*])(.+?)(?<![*])\\*(?![*])|(?<![*_])_(?![_])(.+?)(?<![_])_(?![_])")
        val STRIKETHROUGH_PATTERN = Regex("~~(.+?)~~")
        val LINK_PATTERN = Regex("\\[(.+?)]\\((.+?)\\)")
        val INLINE_CODE_PATTERN = Regex("`(.+?)`")
        val BULLET_PATTERN = Regex("^\\s*[-*]\\s+(.*)")
        val NUMBERED_PATTERN = Regex("^\\s*(\\d+)\\.\\s+(.*)")
        val TASK_CHECKED_PATTERN = Regex("^\\s*-\\s+\\[x]\\s+(.*)", RegexOption.IGNORE_CASE)
        val TASK_UNCHECKED_PATTERN = Regex("^\\s*-\\s+\\[\\s]\\s+(.*)")
        val HR_PATTERN = Regex("^\\s*(---+|\\*\\*\\*+|___+)\\s*$")
        val IMAGE_PATTERN = Regex("!\\[(.+?)]\\((.+?)\\)")
        val TABLE_ROW_PATTERN = Regex("^\\|(.+)\\|\\s*$")
        val TABLE_SEPARATOR_PATTERN = Regex("^\\|[-:|\\s]+\\|\\s*$")
    }

    init {
        movementMethod = LinkMovementMethod.getInstance()
    }

    /**
     * Set markdown text content. Parses the input and applies spans.
     *
     * @param markdown Raw markdown string.
     */
    fun setMarkdownText(markdown: String) {
        try {
            val spannable = parseMarkdown(markdown)
            text = spannable
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse markdown, falling back to plain text", e)
            text = markdown
        }
    }

    private fun parseMarkdown(markdown: String): SpannableStringBuilder {
        val builder = SpannableStringBuilder()
        val lines = markdown.split("\n")
        var inTable = false
        val tableRows = mutableListOf<String>()

        for ((index, line) in lines.withIndex()) {
            // Flush table if we exit table mode
            if (inTable && !TABLE_ROW_PATTERN.matches(line) && !TABLE_SEPARATOR_PATTERN.matches(line)) {
                appendTable(builder, tableRows)
                tableRows.clear()
                inTable = false
            }

            when {
                // Horizontal rule
                HR_PATTERN.matches(line) -> {
                    appendHorizontalRule(builder)
                }

                // Table rows
                TABLE_ROW_PATTERN.matches(line) -> {
                    if (TABLE_SEPARATOR_PATTERN.matches(line)) {
                        // Skip separator row, but keep in table mode
                    } else {
                        tableRows.add(line)
                    }
                    inTable = true
                }

                // Headings
                HEADING_PATTERN.matches(line) -> {
                    val match = HEADING_PATTERN.find(line)!!
                    val level = match.groupValues[1].length
                    val headingText = match.groupValues[2]
                    appendHeading(builder, headingText, level)
                }

                // Task list (checked)
                TASK_CHECKED_PATTERN.matches(line) -> {
                    val match = TASK_CHECKED_PATTERN.find(line)!!
                    val taskText = match.groupValues[1]
                    appendTaskItem(builder, taskText, checked = true)
                }

                // Task list (unchecked)
                TASK_UNCHECKED_PATTERN.matches(line) -> {
                    val match = TASK_UNCHECKED_PATTERN.find(line)!!
                    val taskText = match.groupValues[1]
                    appendTaskItem(builder, taskText, checked = false)
                }

                // Bullet list
                BULLET_PATTERN.matches(line) -> {
                    val match = BULLET_PATTERN.find(line)!!
                    val itemText = match.groupValues[1]
                    appendBulletItem(builder, itemText)
                }

                // Numbered list
                NUMBERED_PATTERN.matches(line) -> {
                    val match = NUMBERED_PATTERN.find(line)!!
                    val number = match.groupValues[1]
                    val itemText = match.groupValues[2]
                    appendNumberedItem(builder, number, itemText)
                }

                // Regular paragraph
                else -> {
                    if (line.isNotEmpty()) {
                        val start = builder.length
                        appendInlineFormatted(builder, line)
                    }
                    if (index < lines.size - 1) {
                        builder.append("\n")
                    }
                }
            }
        }

        // Flush any remaining table
        if (inTable && tableRows.isNotEmpty()) {
            appendTable(builder, tableRows)
        }

        return builder
    }

    // ── Block-level elements ─────────────────────────────────────────

    private fun appendHeading(builder: SpannableStringBuilder, text: String, level: Int) {
        val start = builder.length
        appendInlineFormatted(builder, text)
        val end = builder.length

        val sizeMultiplier = when (level) {
            1 -> 1.6f
            2 -> 1.35f
            else -> 1.15f
        }

        builder.setSpan(
            RelativeSizeSpan(sizeMultiplier),
            start, end,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        builder.setSpan(
            StyleSpan(Typeface.BOLD),
            start, end,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        builder.append("\n\n")
    }

    private fun appendBulletItem(builder: SpannableStringBuilder, text: String) {
        val start = builder.length
        builder.append("  ") // Leading space for margin
        appendInlineFormatted(builder, text)
        builder.append("\n")
        val end = builder.length

        builder.setSpan(
            BulletSpan(16, Color.parseColor("#1B6B3A"), 4),
            start, end,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
    }

    private fun appendNumberedItem(builder: SpannableStringBuilder, number: String, text: String) {
        val start = builder.length
        val prefix = "$number. "
        builder.append(prefix)
        appendInlineFormatted(builder, text)
        builder.append("\n")
        val end = builder.length

        builder.setSpan(
            LeadingMarginSpan.Standard(32),
            start, end,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
    }

    private fun appendTaskItem(builder: SpannableStringBuilder, text: String, checked: Boolean) {
        val start = builder.length
        val checkbox = if (checked) "\u2611 " else "\u2610 " // ballot box with/without check
        builder.append(checkbox)
        appendInlineFormatted(builder, text)
        builder.append("\n")
        val end = builder.length

        builder.setSpan(
            LeadingMarginSpan.Standard(32),
            start, end,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
    }

    private fun appendHorizontalRule(builder: SpannableStringBuilder) {
        val start = builder.length
        builder.append("\n\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n\n")
        val end = builder.length
        builder.setSpan(
            ForegroundColorSpan(Color.parseColor("#CCCCCC")),
            start, end,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
    }

    private fun appendTable(builder: SpannableStringBuilder, rows: List<String>) {
        val start = builder.length
        for (row in rows) {
            // Strip leading/trailing pipes and split cells
            val cells = row.trim().removePrefix("|").removeSuffix("|")
                .split("|").map { it.trim() }
            builder.append(cells.joinToString("  |  "))
            builder.append("\n")
        }
        val end = builder.length

        builder.setSpan(
            TypefaceSpan("monospace"),
            start, end,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        builder.setSpan(
            RelativeSizeSpan(0.85f),
            start, end,
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        builder.append("\n")
    }

    // ── Inline formatting ────────────────────────────────────────────

    private fun appendInlineFormatted(builder: SpannableStringBuilder, text: String) {
        // Process inline elements by replacing patterns with placeholders,
        // then applying spans. Order matters to avoid conflicts.
        var processed = text

        // Handle images first (replace with alt text)
        processed = IMAGE_PATTERN.replace(processed) { match ->
            "[Image: ${match.groupValues[1]}]"
        }

        // Build the spannable from the processed text
        val segments = mutableListOf<InlineSegment>()
        parseInlineSegments(processed, segments)

        for (segment in segments) {
            val start = builder.length
            builder.append(segment.text)
            val end = builder.length

            for (span in segment.spans) {
                builder.setSpan(span, start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }
    }

    private data class InlineSegment(
        val text: String,
        val spans: List<Any>,
    )

    private fun parseInlineSegments(text: String, segments: MutableList<InlineSegment>) {
        // Find the first match of any inline pattern
        data class Match(val start: Int, val end: Int, val displayText: String, val spans: List<Any>)

        val matches = mutableListOf<Match>()

        // Bold
        for (m in BOLD_PATTERN.findAll(text)) {
            val displayText = m.groupValues[1].ifEmpty { m.groupValues[2] }
            matches.add(Match(m.range.first, m.range.last + 1, displayText, listOf(StyleSpan(Typeface.BOLD))))
        }

        // Italic
        for (m in ITALIC_PATTERN.findAll(text)) {
            val displayText = m.groupValues[1].ifEmpty { m.groupValues[2] }
            matches.add(Match(m.range.first, m.range.last + 1, displayText, listOf(StyleSpan(Typeface.ITALIC))))
        }

        // Strikethrough
        for (m in STRIKETHROUGH_PATTERN.findAll(text)) {
            matches.add(Match(m.range.first, m.range.last + 1, m.groupValues[1], listOf(StrikethroughSpan())))
        }

        // Links
        for (m in LINK_PATTERN.findAll(text)) {
            val linkText = m.groupValues[1]
            val url = m.groupValues[2]
            // Only allow http/https URLs to prevent intent injection and javascript: XSS
            if (!url.startsWith("http://", ignoreCase = true) && !url.startsWith("https://", ignoreCase = true)) continue
            val clickableSpan = object : ClickableSpan() {
                override fun onClick(widget: View) {
                    try {
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))
                        widget.context.startActivity(intent)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to open link", e)
                    }
                }

                override fun updateDrawState(ds: TextPaint) {
                    ds.color = Color.parseColor("#1B6B3A")
                    ds.isUnderlineText = true
                }
            }
            matches.add(Match(m.range.first, m.range.last + 1, linkText, listOf(clickableSpan)))
        }

        // Inline code
        for (m in INLINE_CODE_PATTERN.findAll(text)) {
            matches.add(
                Match(
                    m.range.first, m.range.last + 1, m.groupValues[1],
                    listOf(
                        TypefaceSpan("monospace"),
                        ForegroundColorSpan(Color.parseColor("#D32F2F")),
                    ),
                ),
            )
        }

        // Sort by position and resolve non-overlapping
        matches.sortBy { it.start }

        // Build segments from matches, filling gaps with plain text
        var cursor = 0
        for (match in matches) {
            if (match.start < cursor) continue // Skip overlapping matches
            if (match.start > cursor) {
                // Plain text segment before this match
                segments.add(InlineSegment(text.substring(cursor, match.start), emptyList()))
            }
            segments.add(InlineSegment(match.displayText, match.spans))
            cursor = match.end
        }

        // Remaining plain text
        if (cursor < text.length) {
            segments.add(InlineSegment(text.substring(cursor), emptyList()))
        }

        // If no matches, add the whole text as plain
        if (matches.isEmpty() && segments.isEmpty()) {
            segments.add(InlineSegment(text, emptyList()))
        }
    }
}
