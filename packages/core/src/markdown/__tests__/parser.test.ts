import { describe, it, expect } from 'vitest';
import { parse, parseInline, StreamingMarkdownParser } from '../parser';
import type {
  ParagraphNode,
  HeadingNode,
  BulletListNode,
  OrderedListNode,
  TaskListNode,
  HorizontalRuleNode,
  ImageNode,
  TableNode,
  TextNode,
  BoldNode,
  ItalicNode,
  StrikethroughNode,
  LinkNode,
  LineBreakNode,
  InlineNode,
} from '../types';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function textContent(nodes: InlineNode[]): string {
  return nodes
    .map((n) => {
      if (n.type === 'text') return (n as TextNode).content;
      if (n.type === 'lineBreak') return '\n';
      if ('children' in n) return textContent(n.children as InlineNode[]);
      return '';
    })
    .join('');
}

// ===========================================================================
// Block-level parsing
// ===========================================================================

describe('parse — block-level', () => {
  // -----------------------------------------------------------------------
  // Headings
  // -----------------------------------------------------------------------

  describe('headings', () => {
    it('parses H1', () => {
      const doc = parse('# Hello');
      expect(doc).toHaveLength(1);
      const h = doc[0] as HeadingNode;
      expect(h.type).toBe('heading');
      expect(h.level).toBe(1);
      expect(textContent(h.children)).toBe('Hello');
    });

    it('parses H2', () => {
      const doc = parse('## Sub-heading');
      expect(doc).toHaveLength(1);
      const h = doc[0] as HeadingNode;
      expect(h.type).toBe('heading');
      expect(h.level).toBe(2);
      expect(textContent(h.children)).toBe('Sub-heading');
    });

    it('parses H3', () => {
      const doc = parse('### Third level');
      expect(doc).toHaveLength(1);
      const h = doc[0] as HeadingNode;
      expect(h.type).toBe('heading');
      expect(h.level).toBe(3);
    });
  });

  // -----------------------------------------------------------------------
  // Paragraphs
  // -----------------------------------------------------------------------

  describe('paragraphs', () => {
    it('parses a single paragraph', () => {
      const doc = parse('This is a paragraph.');
      expect(doc).toHaveLength(1);
      expect(doc[0].type).toBe('paragraph');
      expect(textContent((doc[0] as ParagraphNode).children)).toBe('This is a paragraph.');
    });

    it('parses multiple paragraphs separated by blank lines', () => {
      const doc = parse('First paragraph.\n\nSecond paragraph.');
      expect(doc).toHaveLength(2);
      expect(doc[0].type).toBe('paragraph');
      expect(doc[1].type).toBe('paragraph');
      expect(textContent((doc[0] as ParagraphNode).children)).toBe('First paragraph.');
      expect(textContent((doc[1] as ParagraphNode).children)).toBe('Second paragraph.');
    });
  });

  // -----------------------------------------------------------------------
  // Bullet lists
  // -----------------------------------------------------------------------

  describe('bullet lists', () => {
    it('parses dash-style bullet list', () => {
      const doc = parse('- Item one\n- Item two\n- Item three');
      expect(doc).toHaveLength(1);
      const list = doc[0] as BulletListNode;
      expect(list.type).toBe('bulletList');
      expect(list.items).toHaveLength(3);
      expect(textContent(list.items[0].children)).toBe('Item one');
      expect(textContent(list.items[2].children)).toBe('Item three');
    });

    it('parses asterisk-style bullet list', () => {
      const doc = parse('* Alpha\n* Beta');
      expect(doc).toHaveLength(1);
      const list = doc[0] as BulletListNode;
      expect(list.type).toBe('bulletList');
      expect(list.items).toHaveLength(2);
    });

    it('parses plus-style bullet list', () => {
      const doc = parse('+ First\n+ Second');
      expect(doc).toHaveLength(1);
      const list = doc[0] as BulletListNode;
      expect(list.type).toBe('bulletList');
      expect(list.items).toHaveLength(2);
    });
  });

  // -----------------------------------------------------------------------
  // Ordered lists
  // -----------------------------------------------------------------------

  describe('ordered lists', () => {
    it('parses numbered list', () => {
      const doc = parse('1. First\n2. Second\n3. Third');
      expect(doc).toHaveLength(1);
      const list = doc[0] as OrderedListNode;
      expect(list.type).toBe('orderedList');
      expect(list.start).toBe(1);
      expect(list.items).toHaveLength(3);
      expect(textContent(list.items[0].children)).toBe('First');
    });

    it('preserves starting number', () => {
      const doc = parse('5. Fifth item\n6. Sixth item');
      const list = doc[0] as OrderedListNode;
      expect(list.start).toBe(5);
      expect(list.items).toHaveLength(2);
    });
  });

  // -----------------------------------------------------------------------
  // Task lists
  // -----------------------------------------------------------------------

  describe('task lists', () => {
    it('parses unchecked and checked items', () => {
      const doc = parse('- [ ] Unchecked\n- [x] Checked\n- [ ] Another');
      expect(doc).toHaveLength(1);
      const list = doc[0] as TaskListNode;
      expect(list.type).toBe('taskList');
      expect(list.items).toHaveLength(3);
      expect(list.items[0].checked).toBe(false);
      expect(list.items[1].checked).toBe(true);
      expect(list.items[2].checked).toBe(false);
      expect(textContent(list.items[0].children)).toBe('Unchecked');
    });

    it('handles uppercase X as checked', () => {
      const doc = parse('- [X] Done');
      const list = doc[0] as TaskListNode;
      expect(list.items[0].checked).toBe(true);
    });
  });

  // -----------------------------------------------------------------------
  // Horizontal rules
  // -----------------------------------------------------------------------

  describe('horizontal rules', () => {
    it('parses --- as horizontal rule', () => {
      const doc = parse('---');
      expect(doc).toHaveLength(1);
      expect(doc[0].type).toBe('horizontalRule');
    });

    it('parses *** as horizontal rule', () => {
      const doc = parse('***');
      expect(doc).toHaveLength(1);
      expect(doc[0].type).toBe('horizontalRule');
    });

    it('parses ___ as horizontal rule', () => {
      const doc = parse('___');
      expect(doc).toHaveLength(1);
      expect(doc[0].type).toBe('horizontalRule');
    });

    it('parses extended dashes as horizontal rule', () => {
      const doc = parse('----------');
      expect(doc).toHaveLength(1);
      expect(doc[0].type).toBe('horizontalRule');
    });
  });

  // -----------------------------------------------------------------------
  // Images (block-level)
  // -----------------------------------------------------------------------

  describe('images', () => {
    it('parses standalone image on its own line', () => {
      const doc = parse('![Pest on leaf](https://example.com/pest.jpg)');
      expect(doc).toHaveLength(1);
      const img = doc[0] as ImageNode;
      expect(img.type).toBe('image');
      expect(img.alt).toBe('Pest on leaf');
      expect(img.url).toBe('https://example.com/pest.jpg');
    });

    it('parses image with empty alt text', () => {
      const doc = parse('![](https://example.com/photo.png)');
      const img = doc[0] as ImageNode;
      expect(img.alt).toBe('');
      expect(img.url).toBe('https://example.com/photo.png');
    });
  });

  // -----------------------------------------------------------------------
  // Tables
  // -----------------------------------------------------------------------

  describe('tables', () => {
    it('parses a simple table with header and rows', () => {
      const input = [
        '| Crop    | Season  |',
        '| ------- | ------- |',
        '| Rice    | Kharif  |',
        '| Wheat   | Rabi    |',
      ].join('\n');
      const doc = parse(input);
      expect(doc).toHaveLength(1);
      const table = doc[0] as TableNode;
      expect(table.type).toBe('table');
      expect(table.header.cells).toHaveLength(2);
      expect(textContent(table.header.cells[0].children)).toBe('Crop');
      expect(textContent(table.header.cells[1].children)).toBe('Season');
      expect(table.rows).toHaveLength(2);
      expect(textContent(table.rows[0].cells[0].children)).toBe('Rice');
      expect(textContent(table.rows[1].cells[1].children)).toBe('Rabi');
    });

    it('parses column alignment', () => {
      const input = [
        '| Left | Center | Right |',
        '| :--- | :----: | ----: |',
        '| a    | b      | c     |',
      ].join('\n');
      const doc = parse(input);
      const table = doc[0] as TableNode;
      expect(table.alignments).toEqual(['left', 'center', 'right']);
    });

    it('defaults to left alignment when no colons', () => {
      const input = [
        '| A | B |',
        '| --- | --- |',
        '| 1 | 2 |',
      ].join('\n');
      const doc = parse(input);
      const table = doc[0] as TableNode;
      expect(table.alignments).toEqual(['left', 'left']);
    });
  });

  // -----------------------------------------------------------------------
  // Mixed block types
  // -----------------------------------------------------------------------

  describe('mixed block types', () => {
    it('parses heading followed by paragraph and list', () => {
      const input = '# Title\n\nSome text.\n\n- Item A\n- Item B';
      const doc = parse(input);
      expect(doc).toHaveLength(3);
      expect(doc[0].type).toBe('heading');
      expect(doc[1].type).toBe('paragraph');
      expect(doc[2].type).toBe('bulletList');
    });

    it('parses horizontal rule between paragraphs', () => {
      const input = 'Above\n\n---\n\nBelow';
      const doc = parse(input);
      expect(doc).toHaveLength(3);
      expect(doc[0].type).toBe('paragraph');
      expect(doc[1].type).toBe('horizontalRule');
      expect(doc[2].type).toBe('paragraph');
    });
  });
});

// ===========================================================================
// Inline parsing
// ===========================================================================

describe('parseInline', () => {
  // -----------------------------------------------------------------------
  // Bold
  // -----------------------------------------------------------------------

  describe('bold', () => {
    it('parses **bold** text', () => {
      const nodes = parseInline('Hello **world**');
      expect(nodes).toHaveLength(2);
      expect(nodes[0]).toEqual({ type: 'text', content: 'Hello ' });
      const bold = nodes[1] as BoldNode;
      expect(bold.type).toBe('bold');
      expect(textContent(bold.children)).toBe('world');
    });

    it('parses __bold__ text', () => {
      const nodes = parseInline('__important__ info');
      expect(nodes).toHaveLength(2);
      const bold = nodes[0] as BoldNode;
      expect(bold.type).toBe('bold');
      expect(textContent(bold.children)).toBe('important');
    });
  });

  // -----------------------------------------------------------------------
  // Italic
  // -----------------------------------------------------------------------

  describe('italic', () => {
    it('parses *italic* text', () => {
      const nodes = parseInline('Some *emphasis* here');
      expect(nodes).toHaveLength(3);
      const italic = nodes[1] as ItalicNode;
      expect(italic.type).toBe('italic');
      expect(textContent(italic.children)).toBe('emphasis');
    });

    it('parses _italic_ text', () => {
      const nodes = parseInline('_subtle_ style');
      expect(nodes).toHaveLength(2);
      const italic = nodes[0] as ItalicNode;
      expect(italic.type).toBe('italic');
      expect(textContent(italic.children)).toBe('subtle');
    });
  });

  // -----------------------------------------------------------------------
  // Strikethrough
  // -----------------------------------------------------------------------

  describe('strikethrough', () => {
    it('parses ~~strikethrough~~ text', () => {
      const nodes = parseInline('~~outdated~~ info');
      expect(nodes).toHaveLength(2);
      const strike = nodes[0] as StrikethroughNode;
      expect(strike.type).toBe('strikethrough');
      expect(textContent(strike.children)).toBe('outdated');
    });
  });

  // -----------------------------------------------------------------------
  // Links
  // -----------------------------------------------------------------------

  describe('links', () => {
    it('parses [text](url) links', () => {
      const nodes = parseInline('Click [here](https://example.com) now');
      expect(nodes).toHaveLength(3);
      const link = nodes[1] as LinkNode;
      expect(link.type).toBe('link');
      expect(link.url).toBe('https://example.com');
      expect(textContent(link.children)).toBe('here');
    });
  });

  // -----------------------------------------------------------------------
  // Nested inline
  // -----------------------------------------------------------------------

  describe('nested inline', () => {
    it('parses bold inside italic: *some **bold** inside*', () => {
      const nodes = parseInline('*some **bold** inside*');
      expect(nodes).toHaveLength(1);
      const italic = nodes[0] as ItalicNode;
      expect(italic.type).toBe('italic');
      // The italic contains: text "some ", bold "bold", text " inside"
      expect(italic.children).toHaveLength(3);
      expect(italic.children[0]).toEqual({ type: 'text', content: 'some ' });
      expect(italic.children[1].type).toBe('bold');
      expect(italic.children[2]).toEqual({ type: 'text', content: ' inside' });
    });

    it('parses link with bold text: [**bold link**](url)', () => {
      const nodes = parseInline('[**bold link**](https://example.com)');
      expect(nodes).toHaveLength(1);
      const link = nodes[0] as LinkNode;
      expect(link.type).toBe('link');
      expect(link.url).toBe('https://example.com');
      expect(link.children).toHaveLength(1);
      expect(link.children[0].type).toBe('bold');
    });
  });

  // -----------------------------------------------------------------------
  // Plain text
  // -----------------------------------------------------------------------

  describe('plain text', () => {
    it('returns plain text with no markup', () => {
      const nodes = parseInline('Just plain text');
      expect(nodes).toHaveLength(1);
      expect(nodes[0]).toEqual({ type: 'text', content: 'Just plain text' });
    });
  });

  // -----------------------------------------------------------------------
  // Line breaks
  // -----------------------------------------------------------------------

  describe('line breaks', () => {
    it('treats newline in inline text as line break', () => {
      const nodes = parseInline('Line one\nLine two');
      expect(nodes).toHaveLength(3);
      expect(nodes[0]).toEqual({ type: 'text', content: 'Line one' });
      expect(nodes[1]).toEqual({ type: 'lineBreak' });
      expect(nodes[2]).toEqual({ type: 'text', content: 'Line two' });
    });
  });
});

// ===========================================================================
// StreamingMarkdownParser
// ===========================================================================

describe('StreamingMarkdownParser', () => {
  it('builds document incrementally via append()', () => {
    const parser = new StreamingMarkdownParser();

    const doc1 = parser.append('# Heading');
    expect(doc1).toHaveLength(1);
    expect(doc1[0].type).toBe('heading');

    const doc2 = parser.append('\n\nSome text');
    expect(doc2).toHaveLength(2);
    expect(doc2[0].type).toBe('heading');
    expect(doc2[1].type).toBe('paragraph');
  });

  it('resolves partial bold markers across appends', () => {
    const parser = new StreamingMarkdownParser();

    // First chunk: incomplete bold marker — should be treated as plain text
    const doc1 = parser.append('Hello **bol');
    expect(doc1).toHaveLength(1);
    const p1 = doc1[0] as ParagraphNode;
    // The text "**bol" has an unclosed bold marker so it falls through as text
    // (the ** is consumed as an attempt but since there's no close, it remains plain)
    const fullText1 = textContent(p1.children);
    expect(fullText1).toContain('bol');

    // Second chunk completes the bold
    const doc2 = parser.append('d**');
    expect(doc2).toHaveLength(1);
    const p2 = doc2[0] as ParagraphNode;
    // Now it should have a bold node with "bold"
    const hasBold = p2.children.some((n) => n.type === 'bold');
    expect(hasBold).toBe(true);
  });

  it('buffers partial table rows until complete', () => {
    const parser = new StreamingMarkdownParser();

    // Start with a table header
    parser.append('| Crop | Season |\n');
    // Add separator — now the table header + separator are present but no body rows yet
    const doc1 = parser.append('| --- | --- |\n');
    const hasTable = doc1.some((n) => n.type === 'table');
    expect(hasTable).toBe(true);

    // Add a body row
    const doc2 = parser.append('| Rice | Kharif |');
    const table = doc2.find((n) => n.type === 'table') as TableNode;
    expect(table.rows).toHaveLength(1);
  });

  it('reset() clears all state', () => {
    const parser = new StreamingMarkdownParser();
    parser.append('# Heading');
    parser.reset();
    expect(parser.getText()).toBe('');

    const doc = parser.append('New text');
    expect(doc).toHaveLength(1);
    expect(doc[0].type).toBe('paragraph');
  });

  it('getText() returns accumulated text', () => {
    const parser = new StreamingMarkdownParser();
    parser.append('Hello ');
    parser.append('World');
    expect(parser.getText()).toBe('Hello World');
  });
});

// ===========================================================================
// Edge cases
// ===========================================================================

describe('parse — edge cases', () => {
  it('empty string returns empty array', () => {
    const doc = parse('');
    expect(doc).toEqual([]);
  });

  it('whitespace-only string returns empty array', () => {
    const doc = parse('   \n\n   ');
    expect(doc).toEqual([]);
  });

  it('unclosed bold marker is treated as plain text', () => {
    const nodes = parseInline('Hello **unclosed');
    // Since ** never closes, the parser should fall through
    // The ** is not consumed as bold, so it becomes part of plain text
    const text = textContent(nodes);
    expect(text).toContain('**unclosed');
  });

  it('unclosed link is treated as plain text', () => {
    const nodes = parseInline('Click [here for more');
    const text = textContent(nodes);
    expect(text).toContain('[here for more');
  });

  it('unclosed link with bracket but no url parens', () => {
    const nodes = parseInline('[text] no parens');
    const text = textContent(nodes);
    expect(text).toContain('[text] no parens');
  });

  it('unclosed strikethrough is treated as plain text', () => {
    const nodes = parseInline('Hello ~~unclosed');
    const text = textContent(nodes);
    expect(text).toContain('~~unclosed');
  });

  it('handles consecutive different block types gracefully', () => {
    const input = [
      '# Heading',
      '',
      '- Bullet one',
      '- Bullet two',
      '',
      '1. First',
      '2. Second',
      '',
      '---',
      '',
      'A paragraph.',
    ].join('\n');

    const doc = parse(input);
    expect(doc).toHaveLength(5);
    expect(doc[0].type).toBe('heading');
    expect(doc[1].type).toBe('bulletList');
    expect(doc[2].type).toBe('orderedList');
    expect(doc[3].type).toBe('horizontalRule');
    expect(doc[4].type).toBe('paragraph');
  });
});
