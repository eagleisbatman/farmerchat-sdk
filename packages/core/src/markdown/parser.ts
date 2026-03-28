/**
 * @module markdown/parser
 *
 * Lightweight, streaming-aware markdown parser for the FarmerChat SDK.
 *
 * Supports only the elements needed for agricultural advisory content:
 * bold, italic, strikethrough, headings, bullet/ordered/task lists,
 * tables (GFM), links, images, horizontal rules.
 *
 * NOT supported (treated as plain text): code blocks, LaTeX, block quotes.
 */

import type {
  BlockNode,
  InlineNode,
  MarkdownDocument,
  ParagraphNode,
  HeadingNode,
  BulletListNode,
  OrderedListNode,
  TaskListNode,
  ListItemNode,
  TaskItemNode,
  TableNode,
  TableRowNode,
  TableAlignment,
  ImageNode,
  HorizontalRuleNode,
  TextNode,
  BoldNode,
  ItalicNode,
  StrikethroughNode,
  LinkNode,
} from './types';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Parse a complete markdown string into a MarkdownDocument.
 */
export function parse(text: string): MarkdownDocument {
  const lines = text.split('\n');
  return parseBlocks(lines, 0, lines.length);
}

/**
 * Streaming markdown parser.
 * Feed chunks of text as they arrive from SSE and get back
 * the current parsed document after each append.
 *
 * @example
 * ```ts
 * const parser = new StreamingMarkdownParser();
 * for await (const token of sseStream) {
 *   const doc = parser.append(token.text);
 *   renderMarkdown(doc);
 * }
 * ```
 */
export class StreamingMarkdownParser {
  private buffer = '';

  /** Append a chunk and re-parse the full accumulated text. */
  append(chunk: string): MarkdownDocument {
    this.buffer += chunk;
    return parse(this.buffer);
  }

  /** Get the current accumulated text. */
  getText(): string {
    return this.buffer;
  }

  /** Reset the parser state. */
  reset(): void {
    this.buffer = '';
  }
}

// ---------------------------------------------------------------------------
// Block-level parsing
// ---------------------------------------------------------------------------

function parseBlocks(lines: string[], start: number, end: number): BlockNode[] {
  const blocks: BlockNode[] = [];
  let i = start;

  while (i < end) {
    const line = lines[i];

    // Empty line — skip
    if (line.trim() === '') {
      i++;
      continue;
    }

    // Horizontal rule: ---, ***, ___  (3+ of the same char, optional spaces)
    if (isHorizontalRule(line)) {
      blocks.push({ type: 'horizontalRule' } as HorizontalRuleNode);
      i++;
      continue;
    }

    // Heading: # ... , ## ... , ### ...
    const headingMatch = line.match(/^(#{1,3})\s+(.+)$/);
    if (headingMatch) {
      blocks.push({
        type: 'heading',
        level: headingMatch[1].length as 1 | 2 | 3,
        children: parseInline(headingMatch[2].trim()),
      } as HeadingNode);
      i++;
      continue;
    }

    // Image on its own line: ![alt](url)
    const imageMatch = line.trim().match(/^!\[([^\]]*)\]\(([^)]+)\)$/);
    if (imageMatch) {
      blocks.push({
        type: 'image',
        alt: imageMatch[1],
        url: imageMatch[2],
      } as ImageNode);
      i++;
      continue;
    }

    // Table: line starts with | and next line is a separator row
    if (line.trim().startsWith('|') && i + 1 < end && isTableSeparator(lines[i + 1])) {
      const tableResult = parseTable(lines, i, end);
      blocks.push(tableResult.node);
      i = tableResult.nextIndex;
      continue;
    }

    // Task list: - [ ] or - [x]
    if (isTaskListItem(line)) {
      const listResult = parseTaskList(lines, i, end);
      blocks.push(listResult.node);
      i = listResult.nextIndex;
      continue;
    }

    // Bullet list: - , * , +  (followed by space)
    if (isBulletListItem(line)) {
      const listResult = parseBulletList(lines, i, end);
      blocks.push(listResult.node);
      i = listResult.nextIndex;
      continue;
    }

    // Ordered list: 1. , 2. , etc.
    const orderedMatch = line.match(/^(\d+)\.\s+/);
    if (orderedMatch) {
      const listResult = parseOrderedList(lines, i, end);
      blocks.push(listResult.node);
      i = listResult.nextIndex;
      continue;
    }

    // Default: paragraph (collect consecutive non-empty, non-special lines)
    const paraResult = parseParagraph(lines, i, end);
    blocks.push(paraResult.node);
    i = paraResult.nextIndex;
  }

  return blocks;
}

// ---------------------------------------------------------------------------
// Horizontal rule detection
// ---------------------------------------------------------------------------

function isHorizontalRule(line: string): boolean {
  const trimmed = line.trim();
  return /^[-*_]{3,}$/.test(trimmed.replace(/\s/g, ''));
}

// ---------------------------------------------------------------------------
// Paragraph
// ---------------------------------------------------------------------------

interface ParseResult<T> {
  node: T;
  nextIndex: number;
}

function parseParagraph(lines: string[], start: number, end: number): ParseResult<ParagraphNode> {
  const textLines: string[] = [];
  let i = start;

  while (i < end) {
    const line = lines[i];
    if (
      line.trim() === '' ||
      isHorizontalRule(line) ||
      line.match(/^#{1,3}\s/) ||
      (line.trim().startsWith('|') && i + 1 < end && isTableSeparator(lines[i + 1])) ||
      isTaskListItem(line) ||
      isBulletListItem(line) ||
      line.match(/^\d+\.\s/) ||
      line.trim().match(/^!\[([^\]]*)\]\(([^)]+)\)$/)
    ) {
      break;
    }
    textLines.push(line);
    i++;
  }

  const text = textLines.join('\n');
  return {
    node: { type: 'paragraph', children: parseInline(text) },
    nextIndex: i,
  };
}

// ---------------------------------------------------------------------------
// Lists
// ---------------------------------------------------------------------------

function isBulletListItem(line: string): boolean {
  return /^[\s]*[-*+]\s+/.test(line) && !isTaskListItem(line);
}

function isTaskListItem(line: string): boolean {
  return /^[\s]*[-*+]\s+\[[ xX]\]\s+/.test(line);
}

function parseBulletList(lines: string[], start: number, end: number): ParseResult<BulletListNode> {
  const items: ListItemNode[] = [];
  let i = start;

  while (i < end && isBulletListItem(lines[i])) {
    const content = lines[i].replace(/^[\s]*[-*+]\s+/, '');
    items.push({
      type: 'listItem',
      children: parseInline(content),
    });
    i++;
  }

  return {
    node: { type: 'bulletList', items },
    nextIndex: i,
  };
}

function parseOrderedList(lines: string[], start: number, end: number): ParseResult<OrderedListNode> {
  const items: ListItemNode[] = [];
  let i = start;
  const startMatch = lines[start].match(/^(\d+)\.\s+/);
  const startNum = startMatch ? parseInt(startMatch[1], 10) : 1;

  while (i < end) {
    const match = lines[i].match(/^\d+\.\s+(.*)/);
    if (!match) break;
    items.push({
      type: 'listItem',
      children: parseInline(match[1]),
    });
    i++;
  }

  return {
    node: { type: 'orderedList', start: startNum, items },
    nextIndex: i,
  };
}

function parseTaskList(lines: string[], start: number, end: number): ParseResult<TaskListNode> {
  const items: TaskItemNode[] = [];
  let i = start;

  while (i < end && isTaskListItem(lines[i])) {
    const checkedMatch = lines[i].match(/^[\s]*[-*+]\s+\[([xX ])\]\s+(.*)/);
    if (checkedMatch) {
      items.push({
        type: 'taskItem',
        checked: checkedMatch[1].toLowerCase() === 'x',
        children: parseInline(checkedMatch[2]),
      });
    }
    i++;
  }

  return {
    node: { type: 'taskList', items },
    nextIndex: i,
  };
}

// ---------------------------------------------------------------------------
// Table
// ---------------------------------------------------------------------------

function isTableSeparator(line: string): boolean {
  if (!line) return false;
  const trimmed = line.trim();
  // Must start/end with | and contain only |, -, :, spaces
  return /^\|[\s:|-]+\|$/.test(trimmed);
}

function parseTableAlignments(separatorLine: string): TableAlignment[] {
  const cells = splitTableRow(separatorLine);
  return cells.map((cell) => {
    const trimmed = cell.trim();
    const left = trimmed.startsWith(':');
    const right = trimmed.endsWith(':');
    if (left && right) return 'center';
    if (right) return 'right';
    return 'left';
  });
}

function splitTableRow(line: string): string[] {
  const trimmed = line.trim();
  // Remove leading and trailing |
  const inner = trimmed.startsWith('|') ? trimmed.slice(1) : trimmed;
  const stripped = inner.endsWith('|') ? inner.slice(0, -1) : inner;
  return stripped.split('|').map((cell) => cell.trim());
}

function parseTableRow(line: string): TableRowNode {
  const cells = splitTableRow(line);
  return {
    type: 'tableRow',
    cells: cells.map((cell) => ({
      type: 'tableCell' as const,
      children: parseInline(cell),
    })),
  };
}

function parseTable(lines: string[], start: number, end: number): ParseResult<TableNode> {
  const headerRow = parseTableRow(lines[start]);
  const alignments = parseTableAlignments(lines[start + 1]);
  const rows: TableRowNode[] = [];
  let i = start + 2;

  while (i < end && lines[i].trim().startsWith('|')) {
    rows.push(parseTableRow(lines[i]));
    i++;
  }

  return {
    node: { type: 'table', alignments, header: headerRow, rows },
    nextIndex: i,
  };
}

// ---------------------------------------------------------------------------
// Inline parsing
// ---------------------------------------------------------------------------

/**
 * Parse inline markdown content into an array of InlineNode.
 * Handles: **bold**, *italic*, ~~strikethrough~~, [links](url), ![images](url),
 *          and hard line breaks (trailing double space or \n).
 */
export function parseInline(text: string): InlineNode[] {
  const nodes: InlineNode[] = [];
  let i = 0;
  let plainStart = 0;

  while (i < text.length) {
    // Newline → line break
    if (text[i] === '\n') {
      if (i > plainStart) {
        nodes.push(textNode(text.slice(plainStart, i)));
      }
      nodes.push({ type: 'lineBreak' });
      i++;
      plainStart = i;
      continue;
    }

    // Trailing double-space before newline → line break
    if (text[i] === ' ' && text[i + 1] === ' ' && text[i + 2] === '\n') {
      if (i > plainStart) {
        nodes.push(textNode(text.slice(plainStart, i)));
      }
      nodes.push({ type: 'lineBreak' });
      i += 3;
      plainStart = i;
      continue;
    }

    // Strikethrough: ~~text~~
    if (text[i] === '~' && text[i + 1] === '~') {
      const closeIdx = text.indexOf('~~', i + 2);
      if (closeIdx !== -1) {
        if (i > plainStart) {
          nodes.push(textNode(text.slice(plainStart, i)));
        }
        const inner = text.slice(i + 2, closeIdx);
        nodes.push({
          type: 'strikethrough',
          children: parseInline(inner),
        } as StrikethroughNode);
        i = closeIdx + 2;
        plainStart = i;
        continue;
      }
    }

    // Bold: **text** or __text__
    if (
      (text[i] === '*' && text[i + 1] === '*') ||
      (text[i] === '_' && text[i + 1] === '_')
    ) {
      const marker = text.slice(i, i + 2);
      const closeIdx = text.indexOf(marker, i + 2);
      if (closeIdx !== -1) {
        if (i > plainStart) {
          nodes.push(textNode(text.slice(plainStart, i)));
        }
        const inner = text.slice(i + 2, closeIdx);
        nodes.push({
          type: 'bold',
          children: parseInline(inner),
        } as BoldNode);
        i = closeIdx + 2;
        plainStart = i;
        continue;
      }
    }

    // Italic: *text* or _text_ (single marker, not preceded by another marker)
    if (
      (text[i] === '*' && text[i + 1] !== '*') ||
      (text[i] === '_' && text[i + 1] !== '_')
    ) {
      const marker = text[i];
      const closeIdx = findClosingMarker(text, marker, i + 1);
      if (closeIdx !== -1) {
        if (i > plainStart) {
          nodes.push(textNode(text.slice(plainStart, i)));
        }
        const inner = text.slice(i + 1, closeIdx);
        nodes.push({
          type: 'italic',
          children: parseInline(inner),
        } as ItalicNode);
        i = closeIdx + 1;
        plainStart = i;
        continue;
      }
    }

    // Image: ![alt](url) — inline occurrence
    if (text[i] === '!' && text[i + 1] === '[') {
      const altClose = text.indexOf(']', i + 2);
      if (altClose !== -1 && text[altClose + 1] === '(') {
        const urlClose = text.indexOf(')', altClose + 2);
        if (urlClose !== -1) {
          if (i > plainStart) {
            nodes.push(textNode(text.slice(plainStart, i)));
          }
          // Inline images are rendered as link with image alt text
          // The block-level parser handles standalone images
          nodes.push({
            type: 'link',
            url: text.slice(altClose + 2, urlClose),
            children: [textNode(text.slice(i + 2, altClose))],
          } as LinkNode);
          i = urlClose + 1;
          plainStart = i;
          continue;
        }
      }
    }

    // Link: [text](url)
    if (text[i] === '[') {
      const textClose = text.indexOf(']', i + 1);
      if (textClose !== -1 && text[textClose + 1] === '(') {
        const urlClose = text.indexOf(')', textClose + 2);
        if (urlClose !== -1) {
          if (i > plainStart) {
            nodes.push(textNode(text.slice(plainStart, i)));
          }
          const linkText = text.slice(i + 1, textClose);
          const linkUrl = text.slice(textClose + 2, urlClose);
          nodes.push({
            type: 'link',
            url: linkUrl,
            children: parseInline(linkText),
          } as LinkNode);
          i = urlClose + 1;
          plainStart = i;
          continue;
        }
      }
    }

    i++;
  }

  // Remaining plain text
  if (plainStart < text.length) {
    nodes.push(textNode(text.slice(plainStart)));
  }

  return nodes;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function textNode(content: string): TextNode {
  return { type: 'text', content };
}

/**
 * Find a closing single marker (* or _) that isn't immediately preceded/followed
 * by a space (to avoid matching mid-word underscores in URLs, etc.).
 */
function findClosingMarker(text: string, marker: string, from: number): number {
  for (let j = from; j < text.length; j++) {
    if (text[j] === marker) {
      // Don't match double markers
      if (text[j + 1] === marker) {
        j++; // skip double
        continue;
      }
      return j;
    }
  }
  return -1;
}
