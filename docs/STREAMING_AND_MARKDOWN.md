# FarmerChat SDK — Streaming & Markdown Architecture

**Date:** March 27, 2026
**Status:** Decided — pending implementation

---

## Context

The FarmerChat SDK receives AI advisory responses from the server. These responses may arrive as:
1. **SSE streaming** — token-by-token via `text/event-stream` (primary mode)
2. **Non-streaming** — complete JSON response via `application/json` (fallback/canned answers)

Responses contain **Markdown-formatted text** tailored for agricultural users (farmers, extension workers, agri-input dealers). The SDK must parse and render this markdown natively on each platform — no WebView.

---

## New Tasks

### Task 1: Dual-mode API Client (Core)

**Package:** `packages/core/src/api/client.ts`

The current `sendQuery()` only handles SSE streams. It must also handle non-streaming JSON responses.

**Work:**
- Inspect `Content-Type` response header
- If `text/event-stream` → use SSE parser (existing path)
- If `application/json` → parse as complete `Response` object, yield as single event
- The async generator interface stays the same — consumers don't care which mode was used
- Add a `done` event at the end of both paths for consistent lifecycle

**Why:** Server may return canned answers, error messages, or disable streaming for certain query types. SDK must handle both transparently.

---

### Task 2: Markdown Node Types (Core)

**Package:** `packages/core/src/markdown/types.ts`

Define the typed AST node system that the parser outputs and all platform renderers consume.

**Work:**
- Define `MarkdownNode` union type with discriminated `type` field
- Node types needed:
  - `paragraph` — plain text block
  - `heading` — level 1-3, with inline children
  - `bold` — inline emphasis
  - `italic` — inline emphasis
  - `strikethrough` — inline ~~deleted~~ text
  - `text` — plain text leaf node
  - `link` — url + display text
  - `image` — url + alt text
  - `bulletList` — container for `listItem` nodes
  - `orderedList` — container for `listItem` nodes, with start index
  - `taskList` — container for `taskItem` nodes
  - `taskItem` — checked/unchecked + inline children
  - `listItem` — inline children (may contain nested lists)
  - `table` — headers + rows of cells
  - `tableRow` — array of cells
  - `tableCell` — inline children + alignment (left/center/right)
  - `horizontalRule` — thematic break
  - `lineBreak` — hard line break
- All inline nodes can nest (e.g., bold inside a link, italic inside bold)
- Export types for codegen to Kotlin/Swift

**Why:** Single source of truth for all 6 platform renderers. Codegen produces matching Kotlin data classes and Swift structs.

---

### Task 3: Streaming-Aware Markdown Parser (Core)

**Package:** `packages/core/src/markdown/parser.ts`

A lightweight markdown tokenizer that handles both complete text and partial/streaming chunks.

**Work:**
- Two modes:
  - `parse(fullText: string): MarkdownNode[]` — parse complete markdown
  - `StreamingMarkdownParser` class with `append(chunk: string): MarkdownNode[]` — incremental parsing during SSE
- Must handle **incomplete syntax gracefully**:
  - `**bol` arriving without closing `**` → render as plain text until closed
  - Half-built table row `| Crop | Dosage` without trailing `|` → buffer until complete
  - Unclosed link `[text](ur` → buffer until closed
- Supported elements (and nothing else):
  - Bold (`**text**` or `__text__`)
  - Italic (`*text*` or `_text_`)
  - Strikethrough (`~~text~~`)
  - Headings (`#`, `##`, `###`)
  - Bullet lists (`-`, `*`, `+`)
  - Numbered lists (`1.`, `2.`)
  - Task lists (`- [ ]`, `- [x]`)
  - Tables (GFM pipe syntax)
  - Links (`[text](url)`)
  - Images (`![alt](url)`)
  - Horizontal rules (`---`, `***`, `___`)
  - Line breaks / paragraphs
- **Not supported** (treated as plain text if encountered):
  - Code blocks / fenced code / inline code
  - LaTeX math
  - Block quotes
  - HTML tags
- Target: < 5 KB minified (keep binary impact minimal)
- Add comprehensive Vitest tests for:
  - Complete markdown parsing
  - Streaming with partial chunks
  - Edge cases (nested bold/italic, tables mid-stream, unclosed syntax)

**Why:** Agricultural advisory content doesn't need code/LaTeX. A scoped parser is smaller, faster, and easier to make streaming-safe than a full CommonMark implementation.

---

### Task 4: Platform Markdown Renderers

Each platform SDK needs a native component that consumes `MarkdownNode[]` and renders styled native UI.

#### Task 4a: Android Compose Renderer

**Package:** `packages/android-compose/src/.../components/MarkdownContent.kt`

- `@Composable fun MarkdownContent(nodes: List<MarkdownNode>)`
- Inline elements (bold, italic, strikethrough, links) → `AnnotatedString` spans within `Text`
- Block elements (headings, lists, tables, images, rules) → individual composables in a `Column`
- **Tables** → `Row`/`Column` grid wrapped in `horizontalScroll` modifier. Alternating row backgrounds. Proper cell padding.
- **Images** → `BitmapFactory` loading (per PRD constraint — no Coil/Glide). Show placeholder while loading.
- **Task lists** → Checkbox + text row (read-only, non-interactive)
- **Links** → Tappable via `ClickableText` + `UriHandler`

#### Task 4b: Android Views Renderer

**Package:** `packages/android-views/src/.../views/MarkdownTextView.kt`

- Custom `View` that renders `MarkdownNode[]`
- Inline elements → `SpannableStringBuilder` with `StyleSpan`, `StrikethroughSpan`, `URLSpan`
- Block elements → Programmatic `LinearLayout` children
- **Tables** → `HorizontalScrollView` wrapping a `TableLayout`
- **Images** → `BitmapFactory` + `ImageView`
- **Task lists** → `CheckBox` (disabled) + `TextView`

#### Task 4c: iOS SwiftUI Renderer

**Package:** `packages/ios-swiftui/Sources/.../Components/MarkdownContent.swift`

- `struct MarkdownContent: View` that takes `[MarkdownNode]`
- Inline elements → `AttributedString` with bold/italic/strikethrough attributes + `Text(attributedString)`
- Block elements → `ForEach` over nodes, each producing a SwiftUI view
- **Tables** → `ScrollView(.horizontal)` wrapping a `Grid` (iOS 16+). Alternating row colors via `background` modifier.
- **Images** → `AsyncImage(url:)` (built-in SwiftUI, no third-party lib)
- **Task lists** → `Image(systemName: "checkmark.square")` / `Image(systemName: "square")` + `Text`
- **Links** → `Link` view or `Text` with `AttributedString` link attribute

#### Task 4d: iOS UIKit Renderer

**Package:** `packages/ios-uikit/Sources/.../Views/MarkdownContentView.swift`

- `UIView` subclass that renders `[MarkdownNode]`
- Inline elements → `NSAttributedString` with `UIFont` traits
- Block elements → Stacked `UIView` subviews via Auto Layout
- **Tables** → `UIScrollView` (horizontal) containing a `UIStackView` grid
- **Images** → `URLSession` data task + `UIImageView`
- **Task lists** → Custom cell with `UIImageView` (SF Symbol) + `UILabel`

#### Task 4e: React Native Renderer

**Package:** `packages/react-native/src/components/MarkdownContent.tsx`

- `<MarkdownContent nodes={nodes} />` React component
- Inline elements → Nested `<Text>` with style props (`fontWeight`, `textDecorationLine`)
- Block elements → `FlatList` or `ScrollView` rendering each block node
- **Tables** → `<ScrollView horizontal>` wrapping rows. `<View>` grid with flex.
- **Images** → `<Image source={{ uri }}>`  with `resizeMode="contain"`
- **Task lists** → Custom row with checkbox icon + `<Text>`
- **Links** → `<Text onPress={() => Linking.openURL(url)}>`

#### Task 4f: Web Renderer

**Package:** `packages/web/src/markdown/MarkdownRenderer.ts`

- Converts `MarkdownNode[]` → sanitized HTML string
- Injected into Shadow DOM with scoped CSS
- **Tables** → `<div style="overflow-x: auto"><table>...</table></div>`
- **Images** → `<img>` with `max-width: 100%` and `loading="lazy"`
- **Task lists** → `<input type="checkbox" disabled>` + `<span>`
- **Links** → `<a target="_blank" rel="noopener">`
- All HTML is sanitized (no script injection from server markdown)

---

### Task 5: Streaming UI State Machine Updates

Each platform's chat ViewModel/state manager needs updates to handle both streaming and non-streaming flows.

**Work per platform:**
- Define states: `IDLE` → `SENDING` → `STREAMING` → `COMPLETE` (for SSE) or `IDLE` → `SENDING` → `COMPLETE` (for non-streaming)
- During `STREAMING`:
  - Accumulate text from token events
  - Re-parse markdown on each token (or use `StreamingMarkdownParser.append()`)
  - Update UI incrementally
  - Show blinking cursor + "Generating response..." + Stop button
- On `COMPLETE`:
  - Hide cursor/generating indicator
  - Show follow-up chips + action bar (thumbs up/down, share, TTS)
- On error during stream:
  - Show "Tap to retry" on the partial response
  - Retain accumulated text (don't discard partial answer)

---

### Task 6: Table UX Design

**Cross-platform, defined in core as guidelines:**

- Minimum column width: 80dp/pt (prevents unreadable cramped columns)
- Maximum table width before horizontal scroll: viewport width - 28dp padding
- Scroll indicator visible when table overflows
- Header row: bold text, subtle background color (e.g., `#F0F7F2` in FarmerChat green theme)
- Alternating row backgrounds for readability: white / `#FAFAFA`
- Cell padding: 8dp vertical, 12dp horizontal
- Text alignment: left by default, right for numeric columns (respect GFM alignment syntax `:---`, `:---:`, `---:`)
- Consider: on very small screens (< 5"), tables with 4+ columns should show a "scroll for more" hint

---

## Task Dependency Order

```
Task 2 (Node types)
  ↓
Task 3 (Parser)  ←── Task 1 (Dual-mode client) can be parallel
  ↓
Task 4a-4f (Platform renderers) — can be done in parallel per platform
  ↓
Task 5 (Streaming UI state machine) — depends on renderer + client
  ↓
Task 6 (Table UX polish) — final refinement
```

Tasks 1, 2, 3 are all in `packages/core/` and part of **Phase 2**.
Tasks 4a-4f are part of **Phases 3-7** (one per platform SDK).
Tasks 5-6 span all platforms.

---

## Impact on Existing Scaffold

| File | Change |
|------|--------|
| `packages/core/src/api/client.ts` | Add Content-Type detection for non-streaming |
| `packages/core/src/markdown/` | **New directory** — types.ts, parser.ts |
| `packages/core/src/index.ts` | Export markdown types + parser |
| `packages/core/codegen/kotlin-gen.ts` | Add MarkdownNode codegen |
| `packages/core/codegen/swift-gen.ts` | Add MarkdownNode codegen |
| Each platform's `components/ResponseCard.*` | Integrate markdown renderer |
| Each platform's ViewModel/state | Add streaming state machine |
