/**
 * @module markdown/types
 *
 * Typed AST for the FarmerChat markdown subset.
 *
 * FarmerChat targets agricultural users (farmers, extension workers) so the
 * supported markdown is intentionally limited: no code blocks, no LaTeX, no
 * block quotes. These types are the single source of truth consumed by the
 * parser and code-generated into Kotlin data classes and Swift structs for
 * all 6 platform renderers.
 */

// ---------------------------------------------------------------------------
// Document & union types
// ---------------------------------------------------------------------------

/**
 * A markdown document is an array of block-level nodes.
 */
export type MarkdownDocument = BlockNode[];

/**
 * Block-level markdown nodes (rendered as distinct visual blocks).
 */
export type BlockNode =
  | ParagraphNode
  | HeadingNode
  | BulletListNode
  | OrderedListNode
  | TaskListNode
  | TableNode
  | HorizontalRuleNode
  | ImageNode;

/**
 * Inline-level markdown nodes (rendered within a text flow).
 */
export type InlineNode =
  | TextNode
  | BoldNode
  | ItalicNode
  | StrikethroughNode
  | LinkNode
  | LineBreakNode;

/** Any markdown node. */
export type MarkdownNode = BlockNode | InlineNode;

// ---------------------------------------------------------------------------
// Inline nodes
// ---------------------------------------------------------------------------

/** Plain text leaf node. */
export interface TextNode {
  readonly type: 'text';
  /** The text content. */
  readonly content: string;
}

/** Bold emphasis — contains inline children. */
export interface BoldNode {
  readonly type: 'bold';
  readonly children: InlineNode[];
}

/** Italic emphasis — contains inline children. */
export interface ItalicNode {
  readonly type: 'italic';
  readonly children: InlineNode[];
}

/** Strikethrough text — contains inline children. */
export interface StrikethroughNode {
  readonly type: 'strikethrough';
  readonly children: InlineNode[];
}

/** Hyperlink — contains inline children for display text. */
export interface LinkNode {
  readonly type: 'link';
  /** URL target. */
  readonly url: string;
  readonly children: InlineNode[];
}

/** Hard line break. */
export interface LineBreakNode {
  readonly type: 'lineBreak';
}

// ---------------------------------------------------------------------------
// Block nodes
// ---------------------------------------------------------------------------

/** A paragraph — contains inline children. */
export interface ParagraphNode {
  readonly type: 'paragraph';
  readonly children: InlineNode[];
}

/** Heading (H1-H3) — contains inline children. */
export interface HeadingNode {
  readonly type: 'heading';
  /** Heading level: 1, 2, or 3. */
  readonly level: 1 | 2 | 3;
  readonly children: InlineNode[];
}

/** Unordered (bullet) list. */
export interface BulletListNode {
  readonly type: 'bulletList';
  readonly items: ListItemNode[];
}

/** Ordered (numbered) list. */
export interface OrderedListNode {
  readonly type: 'orderedList';
  /** Starting number (usually 1). */
  readonly start: number;
  readonly items: ListItemNode[];
}

/** A single list item — can contain inline content and nested lists. */
export interface ListItemNode {
  readonly type: 'listItem';
  readonly children: InlineNode[];
  /** Nested sub-list (if any). */
  readonly subList?: BulletListNode | OrderedListNode;
}

/** Task list (checkbox list). */
export interface TaskListNode {
  readonly type: 'taskList';
  readonly items: TaskItemNode[];
}

/** A single task item with checked/unchecked state. */
export interface TaskItemNode {
  readonly type: 'taskItem';
  /** Whether the task is checked. */
  readonly checked: boolean;
  readonly children: InlineNode[];
}

// ---------------------------------------------------------------------------
// Table nodes
// ---------------------------------------------------------------------------

/** GFM pipe table. */
export interface TableNode {
  readonly type: 'table';
  /** Column alignments. */
  readonly alignments: TableAlignment[];
  /** Header row. */
  readonly header: TableRowNode;
  /** Body rows. */
  readonly rows: TableRowNode[];
}

/** Table column alignment. */
export type TableAlignment = 'left' | 'center' | 'right';

/** A table row. */
export interface TableRowNode {
  readonly type: 'tableRow';
  readonly cells: TableCellNode[];
}

/** A table cell — contains inline children. */
export interface TableCellNode {
  readonly type: 'tableCell';
  readonly children: InlineNode[];
}

// ---------------------------------------------------------------------------
// Standalone block nodes
// ---------------------------------------------------------------------------

/** Image (block-level). */
export interface ImageNode {
  readonly type: 'image';
  /** Image URL. */
  readonly url: string;
  /** Alt text for accessibility. */
  readonly alt: string;
}

/** Horizontal rule / thematic break. */
export interface HorizontalRuleNode {
  readonly type: 'horizontalRule';
}
