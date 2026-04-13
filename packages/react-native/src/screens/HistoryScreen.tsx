import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  Pressable,
  SectionList,
  ActivityIndicator,
  StyleSheet,
  Platform,
  TextInput,
  StatusBar,
  NativeModules,
} from 'react-native';

const STATUS_BAR_HEIGHT: number = Platform.select({
  android: StatusBar.currentHeight ?? 0,
  ios: (NativeModules.StatusBarManager as { HEIGHT?: number } | undefined)?.HEIGHT ?? 44,
  default: 0,
});
import { useChatContext as useChat } from '../ChatProvider';
import { useFarmerChatConfig } from '../FarmerChat';
import type { ConversationListItem } from '../models/responses';

// ── Dark palette (mirrors Compose & iOS) ──────────────────────────────────────
const DARK_BG       = '#0F1A0D';
const DARK_TOOLBAR  = '#1A2318';
const DARK_CARD     = '#172213';
const DARK_SURFACE2 = '#243020';
const ACCENT_GREEN  = '#4CAF50';
const LABEL_COLOR   = '#4A5E48';
const TEXT_PRIMARY  = '#E8F5E9';
const TEXT_SECONDARY = '#8FA88C';
const TEXT_MUTED    = '#5A6B58';

// ── Date formatting ───────────────────────────────────────────────────────────

function formatRelativeDate(dateStr?: string | null): string {
  if (!dateStr) return '';
  // Normalize: T→space, strip timezone/sub-seconds
  const normalized = dateStr
    .replace('T', ' ')
    .split('Z')[0]
    .split('+')[0]
    .trim()
    .slice(0, 19);
  const date = new Date(normalized.replace(' ', 'T') + 'Z'); // parse as UTC
  if (isNaN(date.getTime())) return dateStr;
  const now = Date.now();
  const secs = (now - date.getTime()) / 1000;
  if (secs < 0)     return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  if (secs < 60)    return 'Just now';
  if (secs < 3600)  return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  if (secs < 172800) return 'Yesterday';
  if (secs < 604800) return `${Math.floor(secs / 86400)}d ago`;
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

// ── Topic emoji ────────────────────────────────────────────────────────────────

function topicEmoji(title?: string | null): string {
  const t = (title ?? '').toLowerCase();
  if (t.includes('tomato') || t.includes('vegetable')) return '🍅';
  if (t.includes('weather') || t.includes('rain'))     return '🌧️';
  if (t.includes('soil') || t.includes('npk'))         return '🌱';
  if (t.includes('irrigation') || t.includes('water')) return '💧';
  if (t.includes('fertilizer') || t.includes('nutrient')) return '🌻';
  if (t.includes('pest') || t.includes('insect'))      return '🐛';
  if (t.includes('wheat') || t.includes('rice') || t.includes('crop')) return '🌾';
  if (t.includes('disease'))                            return '⚠️';
  return '💬';
}

// ── TopBar ────────────────────────────────────────────────────────────────────

function TopBar({
  onBack,
  onNewChat,
}: {
  onBack: () => void;
  onNewChat: () => void;
}) {
  return (
    <View style={styles.topBar}>
      <Pressable style={styles.backBtn} onPress={onBack} accessibilityLabel="Go back" accessibilityRole="button">
        <Text style={styles.backArrow}>←</Text>
      </Pressable>
      <View style={{ flex: 1 }}>
        <Text style={styles.topBarTitle}>Chat History</Text>
        <Text style={styles.topBarSub}>Your farming conversations</Text>
      </View>
      <Pressable
        style={styles.addBtn}
        onPress={onNewChat}
        accessibilityLabel="New conversation"
        accessibilityRole="button"
      >
        <Text style={styles.addBtnText}>+</Text>
      </Pressable>
    </View>
  );
}

// ── Conversation item ─────────────────────────────────────────────────────────

function ConversationItem({ item, onPress }: { item: ConversationListItem; onPress: () => void }) {
  const title = item.conversation_title?.trim() || 'Conversation';
  return (
    <Pressable style={styles.item} onPress={onPress} accessibilityRole="button">
      <View style={styles.iconCircle}>
        <Text style={{ fontSize: 20 }}>{topicEmoji(item.conversation_title)}</Text>
      </View>
      <View style={styles.itemContent}>
        <Text style={styles.itemTitle} numberOfLines={1}>{title}</Text>
        <Text style={styles.itemDate}>{formatRelativeDate(item.created_on)}</Text>
      </View>
      <Text style={styles.chevron}>›</Text>
    </Pressable>
  );
}

// ── HistoryScreen ─────────────────────────────────────────────────────────────

interface Section { title: string; data: ConversationListItem[] }

export function HistoryScreen() {
  const { loadConversationList, loadConversation, navigateTo, startNewConversation, conversationList } = useChat();
  const conversations = conversationList as ConversationListItem[];

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');

  const fetchHistory = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      await loadConversationList();
    } catch {
      setError('Failed to load history. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [loadConversationList]);

  useEffect(() => { void fetchHistory(); }, [fetchHistory]);

  const handleBack = useCallback(() => {
    try { navigateTo('chat'); } catch { /* no-op */ }
  }, [navigateTo]);

  const handleNewChat = useCallback(() => {
    try { startNewConversation(); navigateTo('chat'); } catch { /* no-op */ }
  }, [startNewConversation, navigateTo]);

  const handleSelect = useCallback(async (item: ConversationListItem) => {
    try { await loadConversation(item); navigateTo('chat'); } catch { /* no-op */ }
  }, [loadConversation, navigateTo]);

  const filtered = useMemo(() =>
    searchQuery.trim()
      ? conversations.filter(c =>
          (c.conversation_title ?? '').toLowerCase().includes(searchQuery.toLowerCase())
        )
      : conversations,
    [conversations, searchQuery],
  );

  const sections: Section[] = useMemo(() => {
    const grouped: Record<string, ConversationListItem[]> = {};
    filtered.forEach(item => {
      const key = item.grouping ?? 'Older';
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(item);
    });
    return Object.entries(grouped).map(([title, data]) => ({ title, data }));
  }, [filtered]);

  let content: React.ReactNode;

  if (loading) {
    content = (
      <View style={styles.center}>
        <ActivityIndicator color={ACCENT_GREEN} size="large" />
      </View>
    );
  } else if (error) {
    content = (
      <View style={styles.center}>
        <Text style={styles.emptyTitle}>⚠️</Text>
        <Text style={styles.errorText}>{error}</Text>
        <Pressable style={styles.retryBtn} onPress={fetchHistory} accessibilityRole="button">
          <Text style={styles.retryBtnText}>Try Again</Text>
        </Pressable>
      </View>
    );
  } else if (filtered.length === 0) {
    content = (
      <View style={styles.center}>
        <View style={styles.emptyIconCircle}>
          <Text style={styles.emptyEmoji}>💬</Text>
        </View>
        <Text style={styles.emptyTitle}>No conversations yet</Text>
        <Text style={styles.emptySub}>Your past conversations will appear here</Text>
      </View>
    );
  } else {
    content = (
      <SectionList<ConversationListItem, Section>
        sections={sections}
        keyExtractor={item => item.conversation_id}
        renderSectionHeader={({ section }) => (
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionHeaderText}>{section.title.toUpperCase()}</Text>
          </View>
        )}
        renderItem={({ item }) => (
          <ConversationItem item={item} onPress={() => handleSelect(item)} />
        )}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 24 }}
      />
    );
  }

  return (
    <View style={styles.container}>
      <TopBar onBack={handleBack} onNewChat={handleNewChat} />
      {/* Search bar */}
      <View style={styles.searchContainer}>
        <Text style={styles.searchIcon}>🔍</Text>
        <TextInput
          style={styles.searchInput}
          placeholder="Search conversations..."
          placeholderTextColor={TEXT_MUTED}
          value={searchQuery}
          onChangeText={setSearchQuery}
          returnKeyType="search"
          clearButtonMode="while-editing"
        />
      </View>
      {content}
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: DARK_BG },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 12,
    paddingTop: STATUS_BAR_HEIGHT + 10,
    paddingBottom: 10,
    backgroundColor: DARK_TOOLBAR,
  },
  backBtn:      { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  backArrow:    { fontSize: 22, fontWeight: '600', color: TEXT_PRIMARY },
  topBarTitle:  { fontSize: 18, fontWeight: '700', color: TEXT_PRIMARY },
  topBarSub:    { fontSize: 12, color: TEXT_SECONDARY, marginTop: 1 },
  addBtn: {
    width: 38, height: 38, borderRadius: 19,
    backgroundColor: ACCENT_GREEN,
    alignItems: 'center', justifyContent: 'center',
  },
  addBtnText: { color: '#FFFFFF', fontSize: 24, lineHeight: 30, fontWeight: '400' },

  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: DARK_SURFACE2,
    marginHorizontal: 16,
    marginVertical: 8,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 8,
    gap: 8,
  },
  searchIcon:  { fontSize: 15, color: TEXT_MUTED },
  searchInput: { flex: 1, fontSize: 14, color: TEXT_PRIMARY, padding: 0 },

  center: { flex: 1, justifyContent: 'center', alignItems: 'center', paddingHorizontal: 32, gap: 16 },
  emptyIconCircle: {
    width: 90, height: 90, borderRadius: 45,
    backgroundColor: '#4CAF5019',
    alignItems: 'center', justifyContent: 'center',
  },
  emptyEmoji: { fontSize: 40 },
  emptyTitle: { fontSize: 18, fontWeight: '600', color: TEXT_PRIMARY, textAlign: 'center' },
  emptySub:   { fontSize: 14, color: TEXT_SECONDARY, textAlign: 'center', lineHeight: 20 },
  errorText:  { fontSize: 14, color: TEXT_SECONDARY, textAlign: 'center', lineHeight: 20 },
  retryBtn:   { paddingHorizontal: 24, paddingVertical: 10, borderRadius: 20, backgroundColor: ACCENT_GREEN },
  retryBtnText: { color: '#FFFFFF', fontWeight: '600', fontSize: 14 },

  sectionHeader: {
    backgroundColor: DARK_BG,
    paddingHorizontal: 20, paddingTop: 12, paddingBottom: 4,
  },
  sectionHeaderText: {
    fontSize: 10, fontWeight: '700', color: LABEL_COLOR,
    letterSpacing: 1.5,
  },

  item: {
    flexDirection: 'row', alignItems: 'center',
    paddingVertical: 14, paddingHorizontal: 14,
    marginHorizontal: 16, marginVertical: 4,
    backgroundColor: DARK_CARD,
    borderRadius: 14,
    gap: 12,
  },
  iconCircle: {
    width: 44, height: 44, borderRadius: 22,
    backgroundColor: '#4CAF5026',
    alignItems: 'center', justifyContent: 'center',
  },
  itemContent: { flex: 1 },
  itemTitle:   { fontSize: 14, fontWeight: '600', color: TEXT_PRIMARY, lineHeight: 20 },
  itemDate:    { fontSize: 11, color: TEXT_MUTED, marginTop: 3 },
  chevron:     { fontSize: 22, color: LABEL_COLOR, marginLeft: 8 },
});
