import React from 'react';
import { View, Text, Image, ScrollView, Linking, StyleSheet } from 'react-native';
import type {
  MarkdownDocument,
  BlockNode,
  InlineNode,
  BulletListNode,
  OrderedListNode,
  ListItemNode,
  TableNode,
  TableAlignment,
} from '@digitalgreenorg/farmerchat-core';
import { parseMarkdown } from '@digitalgreenorg/farmerchat-core';

interface MarkdownContentProps {
  text?: string;
  document?: MarkdownDocument;
}

export function MarkdownContent({ text, document }: MarkdownContentProps) {
  let ast: MarkdownDocument;

  try {
    if (document) {
      ast = document;
    } else if (text) {
      ast = parseMarkdown(text);
    } else {
      return null;
    }
  } catch {
    // Fallback: render raw text if parsing fails
    return <Text style={styles.paragraph}>{text ?? ''}</Text>;
  }

  try {
    return (
      <View style={styles.container}>
        {ast.map((node, index) => (
          <BlockNodeRenderer key={index} node={node} />
        ))}
      </View>
    );
  } catch {
    return <Text style={styles.paragraph}>{text ?? ''}</Text>;
  }
}

// -- Block-level rendering --

function BlockNodeRenderer({ node }: { node: BlockNode }) {
  try {
    switch (node.type) {
      case 'paragraph':
        return (
          <Text style={styles.paragraph}>
            <InlineChildren nodes={node.children} />
          </Text>
        );

      case 'heading':
        return (
          <Text
            style={[
              styles.heading,
              node.level === 1 && styles.h1,
              node.level === 2 && styles.h2,
              node.level === 3 && styles.h3,
            ]}
          >
            <InlineChildren nodes={node.children} />
          </Text>
        );

      case 'bulletList':
        return <BulletList node={node} />;

      case 'orderedList':
        return <OrderedList node={node} />;

      case 'taskList':
        return (
          <View style={styles.list}>
            {node.items.map((item, i) => (
              <View key={i} style={styles.listItemRow}>
                <Text style={styles.listMarker}>
                  {item.checked ? '\u2611 ' : '\u2610 '}
                </Text>
                <Text style={styles.listItemText}>
                  <InlineChildren nodes={item.children} />
                </Text>
              </View>
            ))}
          </View>
        );

      case 'table':
        return <TableRenderer node={node} />;

      case 'image': {
        const isSafeImageUrl = /^https:\/\//i.test(node.url);
        if (!isSafeImageUrl) return null;
        return (
          <Image
            source={{ uri: node.url }}
            style={styles.image}
            accessibilityLabel={node.alt}
            resizeMode="contain"
          />
        );
      }

      case 'horizontalRule':
        return <View style={styles.horizontalRule} />;

      default:
        return null;
    }
  } catch {
    return null;
  }
}

// -- List renderers --

function BulletList({ node }: { node: BulletListNode }) {
  return (
    <View style={styles.list}>
      {node.items.map((item, i) => (
        <ListItemRenderer key={i} item={item} marker={'\u2022 '} />
      ))}
    </View>
  );
}

function OrderedList({ node }: { node: OrderedListNode }) {
  return (
    <View style={styles.list}>
      {node.items.map((item, i) => (
        <ListItemRenderer key={i} item={item} marker={`${node.start + i}. `} />
      ))}
    </View>
  );
}

function ListItemRenderer({
  item,
  marker,
}: {
  item: ListItemNode;
  marker: string;
}) {
  return (
    <View>
      <View style={styles.listItemRow}>
        <Text style={styles.listMarker}>{marker}</Text>
        <Text style={styles.listItemText}>
          <InlineChildren nodes={item.children} />
        </Text>
      </View>
      {item.subList && (
        <View style={styles.nestedList}>
          {item.subList.type === 'bulletList' ? (
            <BulletList node={item.subList} />
          ) : (
            <OrderedList node={item.subList} />
          )}
        </View>
      )}
    </View>
  );
}

// -- Table renderer --

function TableRenderer({ node }: { node: TableNode }) {
  const columnCount = node.alignments.length;

  return (
    <ScrollView horizontal style={styles.tableScroll} showsHorizontalScrollIndicator={false}>
      <View style={styles.table}>
        {/* Header row */}
        <View style={[styles.tableRow, styles.tableHeaderRow]}>
          {node.header.cells.map((cell, ci) => (
            <View
              key={ci}
              style={[
                styles.tableCell,
                { minWidth: 100 },
                ci < columnCount - 1 && styles.tableCellBorder,
              ]}
            >
              <Text
                style={[
                  styles.tableHeaderText,
                  alignmentStyle(node.alignments[ci]),
                ]}
              >
                <InlineChildren nodes={cell.children} />
              </Text>
            </View>
          ))}
        </View>

        {/* Body rows */}
        {node.rows.map((row, ri) => (
          <View
            key={ri}
            style={[
              styles.tableRow,
              ri % 2 === 1 && styles.tableRowAlt,
            ]}
          >
            {row.cells.map((cell, ci) => (
              <View
                key={ci}
                style={[
                  styles.tableCell,
                  { minWidth: 100 },
                  ci < columnCount - 1 && styles.tableCellBorder,
                ]}
              >
                <Text style={[styles.tableCellText, alignmentStyle(node.alignments[ci])]}>
                  <InlineChildren nodes={cell.children} />
                </Text>
              </View>
            ))}
          </View>
        ))}
      </View>
    </ScrollView>
  );
}

function alignmentStyle(alignment: TableAlignment) {
  switch (alignment) {
    case 'center':
      return styles.textCenter;
    case 'right':
      return styles.textRight;
    default:
      return styles.textLeft;
  }
}

// -- Inline rendering --

function InlineChildren({ nodes }: { nodes: InlineNode[] }) {
  return (
    <>
      {nodes.map((node, i) => (
        <InlineNodeRenderer key={i} node={node} />
      ))}
    </>
  );
}

function InlineNodeRenderer({ node }: { node: InlineNode }) {
  try {
    switch (node.type) {
      case 'text':
        return <Text>{node.content}</Text>;

      case 'bold':
        return (
          <Text style={styles.bold}>
            <InlineChildren nodes={node.children} />
          </Text>
        );

      case 'italic':
        return (
          <Text style={styles.italic}>
            <InlineChildren nodes={node.children} />
          </Text>
        );

      case 'strikethrough':
        return (
          <Text style={styles.strikethrough}>
            <InlineChildren nodes={node.children} />
          </Text>
        );

      case 'link': {
        const isSafeUrl = /^https?:\/\//i.test(node.url);
        return (
          <Text
            style={isSafeUrl ? styles.link : styles.paragraph}
            onPress={isSafeUrl ? () => {
              try {
                Linking.openURL(node.url);
              } catch {
                // Silently fail
              }
            } : undefined}
            accessibilityRole={isSafeUrl ? 'link' : undefined}
          >
            <InlineChildren nodes={node.children} />
          </Text>
        );
      }

      case 'lineBreak':
        return <Text>{'\n'}</Text>;

      default:
        return null;
    }
  } catch {
    return null;
  }
}

// -- Styles --

const styles = StyleSheet.create({
  container: {
    gap: 8,
  },
  paragraph: {
    fontSize: 15,
    lineHeight: 22,
    color: '#1A1A1A',
  },
  heading: {
    fontWeight: 'bold',
    color: '#1A1A1A',
  },
  h1: {
    fontSize: 22,
    lineHeight: 30,
    marginTop: 4,
  },
  h2: {
    fontSize: 18,
    lineHeight: 26,
    marginTop: 2,
  },
  h3: {
    fontSize: 16,
    lineHeight: 24,
  },
  bold: {
    fontWeight: 'bold',
  },
  italic: {
    fontStyle: 'italic',
  },
  strikethrough: {
    textDecorationLine: 'line-through',
  },
  link: {
    color: '#1B6B3A',
    textDecorationLine: 'underline',
  },
  list: {
    gap: 4,
  },
  listItemRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  listMarker: {
    fontSize: 15,
    lineHeight: 22,
    color: '#1A1A1A',
    width: 24,
  },
  listItemText: {
    flex: 1,
    fontSize: 15,
    lineHeight: 22,
    color: '#1A1A1A',
  },
  nestedList: {
    marginLeft: 24,
  },
  tableScroll: {
    marginVertical: 4,
  },
  table: {
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 4,
    overflow: 'hidden',
  },
  tableRow: {
    flexDirection: 'row',
  },
  tableHeaderRow: {
    backgroundColor: '#F0F7F2',
  },
  tableRowAlt: {
    backgroundColor: '#FAFAFA',
  },
  tableCell: {
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  tableCellBorder: {
    borderRightWidth: 1,
    borderRightColor: '#DDD',
  },
  tableHeaderText: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#1A1A1A',
  },
  tableCellText: {
    fontSize: 14,
    color: '#1A1A1A',
  },
  textLeft: {
    textAlign: 'left',
  },
  textCenter: {
    textAlign: 'center',
  },
  textRight: {
    textAlign: 'right',
  },
  image: {
    width: '100%' as unknown as number,
    height: 200,
    borderRadius: 8,
    marginVertical: 4,
  },
  horizontalRule: {
    height: 1,
    backgroundColor: '#DDD',
    marginVertical: 8,
  },
});
