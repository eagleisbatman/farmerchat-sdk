package org.digitalgreen.farmerchat.compose.components

import android.graphics.BitmapFactory
import android.util.Log
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.ClickableText
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.URL

/**
 * Renders markdown text as native Compose UI.
 *
 * Supports: bold, italic, strikethrough, headings (h1-h3), bullet lists,
 * ordered lists, task lists, tables (horizontal scroll), images, links,
 * and horizontal rules.
 *
 * Does NOT support: code blocks, LaTeX, block quotes.
 *
 * Uses a simple line-by-line parser matching the core markdown parser logic.
 * No external dependencies -- images are loaded via [BitmapFactory].
 */
@Composable
internal fun MarkdownContent(
    text: String,
    modifier: Modifier = Modifier,
) {
    val blocks = remember(text) {
        try {
            parseMarkdownBlocks(text)
        } catch (e: Exception) {
            Log.w("FC.Markdown", "Parse failed, falling back to plain text", e)
            listOf(MarkdownBlock.Paragraph(text))
        }
    }

    Column(modifier = modifier) {
        blocks.forEach { block ->
            try {
                RenderBlock(block)
            } catch (e: Exception) {
                Log.w("FC.Markdown", "Render block failed", e)
                Text(
                    text = block.rawText(),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

// ── Block types ─────────────────────────────────────────────────────────

private sealed interface MarkdownBlock {
    fun rawText(): String

    data class Heading(val level: Int, val text: String) : MarkdownBlock {
        override fun rawText() = text
    }

    data class Paragraph(val text: String) : MarkdownBlock {
        override fun rawText() = text
    }

    data class BulletList(val items: List<String>) : MarkdownBlock {
        override fun rawText() = items.joinToString("\n") { "- $it" }
    }

    data class OrderedList(val items: List<String>) : MarkdownBlock {
        override fun rawText() = items.mapIndexed { i, t -> "${i + 1}. $t" }.joinToString("\n")
    }

    data class TaskList(val items: List<Pair<Boolean, String>>) : MarkdownBlock {
        override fun rawText() = items.joinToString("\n") { (checked, t) ->
            if (checked) "- [x] $t" else "- [ ] $t"
        }
    }

    data class Table(
        val header: List<String>,
        val alignments: List<String>,
        val rows: List<List<String>>,
    ) : MarkdownBlock {
        override fun rawText() = header.joinToString(" | ")
    }

    data class MarkdownImage(val alt: String, val url: String) : MarkdownBlock {
        override fun rawText() = alt
    }

    data object HorizontalRule : MarkdownBlock {
        override fun rawText() = "---"
    }
}

// ── Parser ──────────────────────────────────────────────────────────────

private fun parseMarkdownBlocks(text: String): List<MarkdownBlock> {
    val blocks = mutableListOf<MarkdownBlock>()
    val lines = text.lines()
    var i = 0

    while (i < lines.size) {
        val line = lines[i]
        val trimmed = line.trim()

        when {
            // Empty line -- skip
            trimmed.isEmpty() -> {
                i++
            }

            // Horizontal rule
            trimmed.matches(Regex("^[-*_]{3,}$")) -> {
                blocks.add(MarkdownBlock.HorizontalRule)
                i++
            }

            // Heading
            trimmed.startsWith("#") -> {
                val match = Regex("^(#{1,6})\\s+(.+)$").find(trimmed)
                if (match != null) {
                    val level = match.groupValues[1].length
                    val headingText = match.groupValues[2].trimEnd('#').trim()
                    blocks.add(MarkdownBlock.Heading(level.coerceAtMost(3), headingText))
                } else {
                    blocks.add(MarkdownBlock.Paragraph(trimmed))
                }
                i++
            }

            // Image (standalone line)
            trimmed.matches(Regex("^!\\[.*]\\(.*\\)$")) -> {
                val match = Regex("^!\\[(.*)\\]\\((.*)\\)$").find(trimmed)
                if (match != null) {
                    blocks.add(MarkdownBlock.MarkdownImage(match.groupValues[1], match.groupValues[2]))
                }
                i++
            }

            // Task list item
            trimmed.matches(Regex("^[-*]\\s+\\[[ xX]\\]\\s+.*")) -> {
                val taskItems = mutableListOf<Pair<Boolean, String>>()
                while (i < lines.size) {
                    val tl = lines[i].trim()
                    val taskMatch = Regex("^[-*]\\s+\\[([ xX])\\]\\s+(.*)").find(tl)
                    if (taskMatch != null) {
                        val checked = taskMatch.groupValues[1].lowercase() == "x"
                        taskItems.add(checked to taskMatch.groupValues[2])
                        i++
                    } else {
                        break
                    }
                }
                blocks.add(MarkdownBlock.TaskList(taskItems))
            }

            // Bullet list item
            trimmed.matches(Regex("^[-*+]\\s+.*")) -> {
                val items = mutableListOf<String>()
                while (i < lines.size) {
                    val bl = lines[i].trim()
                    val bulletMatch = Regex("^[-*+]\\s+(.*)").find(bl)
                    if (bulletMatch != null) {
                        items.add(bulletMatch.groupValues[1])
                        i++
                    } else {
                        break
                    }
                }
                blocks.add(MarkdownBlock.BulletList(items))
            }

            // Ordered list item
            trimmed.matches(Regex("^\\d+\\.\\s+.*")) -> {
                val items = mutableListOf<String>()
                while (i < lines.size) {
                    val ol = lines[i].trim()
                    val orderedMatch = Regex("^\\d+\\.\\s+(.*)").find(ol)
                    if (orderedMatch != null) {
                        items.add(orderedMatch.groupValues[1])
                        i++
                    } else {
                        break
                    }
                }
                blocks.add(MarkdownBlock.OrderedList(items))
            }

            // Table (starts with |)
            trimmed.startsWith("|") && i + 1 < lines.size &&
                lines[i + 1].trim().matches(Regex("^\\|[-:|\\s]+\\|$")) -> {
                val headerLine = trimmed
                val separatorLine = lines[i + 1].trim()

                val header = parseTableRow(headerLine)
                val alignments = parseTableAlignments(separatorLine)

                val rows = mutableListOf<List<String>>()
                i += 2
                while (i < lines.size && lines[i].trim().startsWith("|")) {
                    rows.add(parseTableRow(lines[i].trim()))
                    i++
                }
                blocks.add(MarkdownBlock.Table(header, alignments, rows))
            }

            // Paragraph (default)
            else -> {
                val paragraphLines = mutableListOf(trimmed)
                i++
                while (i < lines.size) {
                    val next = lines[i].trim()
                    if (next.isEmpty() || next.startsWith("#") || next.startsWith("-") ||
                        next.startsWith("*") || next.startsWith("|") ||
                        next.matches(Regex("^\\d+\\.\\s+.*")) ||
                        next.matches(Regex("^[-*_]{3,}$"))
                    ) {
                        break
                    }
                    paragraphLines.add(next)
                    i++
                }
                blocks.add(MarkdownBlock.Paragraph(paragraphLines.joinToString(" ")))
            }
        }
    }

    return blocks
}

private fun parseTableRow(line: String): List<String> {
    return line.trim('|').split("|").map { it.trim() }
}

private fun parseTableAlignments(line: String): List<String> {
    return line.trim('|').split("|").map { cell ->
        val trimmed = cell.trim()
        when {
            trimmed.startsWith(":") && trimmed.endsWith(":") -> "center"
            trimmed.endsWith(":") -> "right"
            else -> "left"
        }
    }
}

// ── Block renderers ────────────────────────────────────────────────────

@Composable
private fun RenderBlock(block: MarkdownBlock) {
    when (block) {
        is MarkdownBlock.Heading -> HeadingBlock(block)
        is MarkdownBlock.Paragraph -> ParagraphBlock(block)
        is MarkdownBlock.BulletList -> BulletListBlock(block)
        is MarkdownBlock.OrderedList -> OrderedListBlock(block)
        is MarkdownBlock.TaskList -> TaskListBlock(block)
        is MarkdownBlock.Table -> MarkdownTable(block.header, block.rows, block.alignments)
        is MarkdownBlock.MarkdownImage -> MarkdownImageBlock(block)
        is MarkdownBlock.HorizontalRule -> {
            HorizontalDivider(
                modifier = Modifier.padding(vertical = 8.dp),
                color = MaterialTheme.colorScheme.outlineVariant,
            )
        }
    }
}

@Composable
private fun HeadingBlock(heading: MarkdownBlock.Heading) {
    val style = when (heading.level) {
        1 -> MaterialTheme.typography.headlineMedium
        2 -> MaterialTheme.typography.titleLarge
        else -> MaterialTheme.typography.titleMedium
    }
    Text(
        text = heading.text,
        style = style,
        color = MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.padding(top = 8.dp, bottom = 4.dp),
    )
}

@Composable
private fun ParagraphBlock(paragraph: MarkdownBlock.Paragraph) {
    val linkColor = MaterialTheme.colorScheme.primary
    val annotatedString = parseInlineFormatting(paragraph.text, linkColor)
    val uriHandler = LocalUriHandler.current

    ClickableText(
        text = annotatedString,
        style = MaterialTheme.typography.bodyMedium.copy(
            color = MaterialTheme.colorScheme.onSurface,
        ),
        modifier = Modifier.padding(vertical = 2.dp),
        onClick = { offset ->
            try {
                annotatedString.getStringAnnotations("URL", offset, offset)
                    .firstOrNull()?.let { annotation ->
                        val url = annotation.item
                        if (url.startsWith("http://", ignoreCase = true) ||
                            url.startsWith("https://", ignoreCase = true)
                        ) {
                            uriHandler.openUri(url)
                        }
                    }
            } catch (e: Exception) {
                Log.w("FC.Markdown", "Link click failed", e)
            }
        },
    )
}

@Composable
private fun BulletListBlock(list: MarkdownBlock.BulletList) {
    Column(modifier = Modifier.padding(vertical = 4.dp)) {
        list.items.forEach { item ->
            Row(modifier = Modifier.padding(start = 8.dp, bottom = 2.dp)) {
                Text(
                    text = "\u2022",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.width(16.dp),
                )
                InlineFormattedText(
                    text = item,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun OrderedListBlock(list: MarkdownBlock.OrderedList) {
    Column(modifier = Modifier.padding(vertical = 4.dp)) {
        list.items.forEachIndexed { index, item ->
            Row(modifier = Modifier.padding(start = 8.dp, bottom = 2.dp)) {
                Text(
                    text = "${index + 1}.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.width(24.dp),
                )
                InlineFormattedText(
                    text = item,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun TaskListBlock(list: MarkdownBlock.TaskList) {
    Column(modifier = Modifier.padding(vertical = 4.dp)) {
        list.items.forEach { (checked, text) ->
            Row(
                modifier = Modifier.padding(start = 4.dp, bottom = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Checkbox(
                    checked = checked,
                    onCheckedChange = null, // Read-only
                    modifier = Modifier.size(20.dp),
                )
                Spacer(Modifier.width(8.dp))
                InlineFormattedText(
                    text = text,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun MarkdownTable(
    header: List<String>,
    rows: List<List<String>>,
    alignments: List<String>,
) {
    val scrollState = rememberScrollState()
    val headerBg = MaterialTheme.colorScheme.surfaceVariant
    val altRowBg = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)

    Row(
        modifier = Modifier
            .padding(vertical = 4.dp)
            .horizontalScroll(scrollState),
    ) {
        Column(modifier = Modifier.width(IntrinsicSize.Max)) {
            // Header row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(headerBg),
            ) {
                header.forEach { cell ->
                    Box(
                        modifier = Modifier
                            .width(120.dp)
                            .padding(8.dp),
                    ) {
                        Text(
                            text = cell,
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            // Divider
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

            // Data rows
            rows.forEachIndexed { rowIndex, row ->
                val rowBg = if (rowIndex % 2 == 1) altRowBg else Color.Transparent
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(rowBg),
                ) {
                    row.forEach { cell ->
                        Box(
                            modifier = Modifier
                                .width(120.dp)
                                .padding(8.dp),
                        ) {
                            Text(
                                text = cell,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MarkdownImageBlock(image: MarkdownBlock.MarkdownImage) {
    var bitmap by remember(image.url) { mutableStateOf<android.graphics.Bitmap?>(null) }
    var loadFailed by remember(image.url) { mutableStateOf(false) }

    LaunchedEffect(image.url) {
        try {
            // Only allow https (or http for dev) images to prevent SSRF
            if (!image.url.startsWith("http://", ignoreCase = true) &&
                !image.url.startsWith("https://", ignoreCase = true)
            ) {
                loadFailed = true
                return@LaunchedEffect
            }
            val loadedBitmap = withContext(Dispatchers.IO) {
                val connection = URL(image.url).openConnection()
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                val contentLength = connection.contentLength
                // Reject images larger than 5 MB to prevent OOM
                if (contentLength > 5 * 1024 * 1024) {
                    throw IOException("Image too large: $contentLength bytes")
                }
                connection.getInputStream().use { stream ->
                    // Subsample large images to fit within 1024px
                    val bytes = stream.readBytes().also { data ->
                        if (data.size > 5 * 1024 * 1024) throw IOException("Image too large")
                    }
                    val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
                    val scale = maxOf(1, maxOf(opts.outWidth, opts.outHeight) / 1024)
                    val decodeOpts = BitmapFactory.Options().apply { inSampleSize = scale }
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, decodeOpts)
                }
            }
            bitmap = loadedBitmap
        } catch (e: Exception) {
            Log.w("FC.Markdown", "Image load failed: ${image.url}", e)
            loadFailed = true
        }
    }

    when {
        bitmap != null -> {
            Image(
                bitmap = bitmap!!.asImageBitmap(),
                contentDescription = image.alt,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
            )
        }
        loadFailed -> {
            Text(
                text = "[Image: ${image.alt}]",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 2.dp),
            )
        }
        else -> {
            // Loading placeholder
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(100.dp)
                    .padding(vertical = 4.dp)
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        shape = MaterialTheme.shapes.small,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Loading image\u2026",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

// ── Inline formatting ───────────────────────────────────────────────────

/**
 * Helper composable that renders a single line of text with inline formatting.
 */
@Composable
private fun InlineFormattedText(
    text: String,
    modifier: Modifier = Modifier,
) {
    val linkColor = MaterialTheme.colorScheme.primary
    val annotatedString = parseInlineFormatting(text, linkColor)
    val uriHandler = LocalUriHandler.current

    ClickableText(
        text = annotatedString,
        style = MaterialTheme.typography.bodyMedium.copy(
            color = MaterialTheme.colorScheme.onSurface,
        ),
        modifier = modifier,
        onClick = { offset ->
            try {
                annotatedString.getStringAnnotations("URL", offset, offset)
                    .firstOrNull()?.let { annotation ->
                        val url = annotation.item
                        if (url.startsWith("http://", ignoreCase = true) ||
                            url.startsWith("https://", ignoreCase = true)
                        ) {
                            uriHandler.openUri(url)
                        }
                    }
            } catch (e: Exception) {
                Log.w("FC.Markdown", "Link click failed", e)
            }
        },
    )
}

/**
 * Parses inline markdown formatting into an [AnnotatedString].
 *
 * Supports:
 * - **bold** / __bold__
 * - *italic* / _italic_
 * - ~~strikethrough~~
 * - [link text](url)
 */
private fun parseInlineFormatting(text: String, linkColor: Color): AnnotatedString {
    return buildAnnotatedString {
        var i = 0
        val len = text.length

        while (i < len) {
            when {
                // Link: [text](url)
                text[i] == '[' -> {
                    val closeBracket = text.indexOf(']', i + 1)
                    if (closeBracket != -1 && closeBracket + 1 < len && text[closeBracket + 1] == '(') {
                        val closeParen = text.indexOf(')', closeBracket + 2)
                        if (closeParen != -1) {
                            val linkText = text.substring(i + 1, closeBracket)
                            val url = text.substring(closeBracket + 2, closeParen)
                            pushStringAnnotation("URL", url)
                            withStyle(
                                SpanStyle(
                                    color = linkColor,
                                    textDecoration = TextDecoration.Underline,
                                ),
                            ) {
                                append(linkText)
                            }
                            pop()
                            i = closeParen + 1
                            continue
                        }
                    }
                    append(text[i])
                    i++
                }

                // Bold: **text** or __text__
                i + 1 < len && (text.substring(i, i + 2) == "**" || text.substring(i, i + 2) == "__") -> {
                    val delimiter = text.substring(i, i + 2)
                    val end = text.indexOf(delimiter, i + 2)
                    if (end != -1) {
                        withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
                            append(text.substring(i + 2, end))
                        }
                        i = end + 2
                    } else {
                        append(text[i])
                        i++
                    }
                }

                // Strikethrough: ~~text~~
                i + 1 < len && text.substring(i, i + 2) == "~~" -> {
                    val end = text.indexOf("~~", i + 2)
                    if (end != -1) {
                        withStyle(SpanStyle(textDecoration = TextDecoration.LineThrough)) {
                            append(text.substring(i + 2, end))
                        }
                        i = end + 2
                    } else {
                        append(text[i])
                        i++
                    }
                }

                // Italic: *text* or _text_ (single delimiter, not at word boundary for _)
                (text[i] == '*' || text[i] == '_') -> {
                    val delimiter = text[i].toString()
                    val end = text.indexOf(delimiter, i + 1)
                    if (end != -1 && end > i + 1) {
                        withStyle(SpanStyle(fontStyle = FontStyle.Italic)) {
                            append(text.substring(i + 1, end))
                        }
                        i = end + 1
                    } else {
                        append(text[i])
                        i++
                    }
                }

                else -> {
                    append(text[i])
                    i++
                }
            }
        }
    }
}
