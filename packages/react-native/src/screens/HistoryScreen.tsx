import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  Pressable,
  SectionList,
  ActivityIndicator,
  StyleSheet,
  Platform,
} from 'react-native';
import { useChatContext as useChat } from '../ChatProvider';
import { useFarmerChatConfig } from '../FarmerChat';
import type { ConversationListItem } from '../models/responses';

// ── Colors ────────────────────────────────────────────────────────────────────
const PRIMARY_GREEN  = '#2E7D32';
const WHITE          = '#FFFFFF';
const SURFACE_COLOR  = '#F5F5F5';
const TEXT_PRIMARY   = '#212121';
const TEXT_SECONDARY = '#757575';
const DIVIDER_COLOR  = '#E0E0E0';
const ITEM_ICON_BG   = '#E8F5E9';

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

function TopBar({ onBack, primaryColor, onNewChat }: { onBack: () => void; primaryColor: string; onNewChat: () => void }) {
  return (
    <View style={styles.topBar}>
      <Pressable style={styles.backBtn} onPress={onBack} accessibilityLabel="Go back" accessibilityRole="button">
        <Text style={[styles.backArrow, { color: primaryColor }]}>←</Text>
      </Pressable>
      <View style={{ flex: 1 }}>
        <Text style={styles.topBarTitle}>Chat History</Text>
        <Text style={styles.topBarSub}>Your farming conversations</Text>
      </View>
      {/* + New conversation */}
      <Pressable
        style={[styles.addBtn, { backgroundColor: PRIMARY_GREEN }]}
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
  return (
    <Pressable style={styles.item} onPress={onPress} accessibilityRole="button">
      {/* Icon circle 40px */}
      <View style={styles.iconCircle}>
        <Text style={{ fontSize: 18 }}>{topicEmoji(item.conversation_title)}</Text>
      </View>
      {/* Content */}
      <View style={styles.itemContent}>
        <Text style={styles.itemTitle} numberOfLines={2}>{item.conversation_title ?? 'Conversation'}</Text>
        <Text style={styles.itemDate}>{item.created_on ?? ''}</Text>
      </View>
      <Text style={styles.chevron}>›</Text>
    </Pressable>
  );
}

// ── HistoryScreen ─────────────────────────────────────────────────────────────

interface Section { title: string; data: ConversationListItem[] }

export function HistoryScreen() {
  const config = useFarmerChatConfig();
  const { loadConversationList, loadConversation, navigateTo, startNewConversation, conversationList } = useChat();
  const conversations = conversationList as ConversationListItem[];

  const primaryColor = config.theme?.primaryColor ?? PRIMARY_GREEN;

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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

  // Group conversations by their grouping label or derive from date
  const sections: Section[] = useMemo(() => {
    const grouped: Record<string, ConversationListItem[]> = {};
    conversations.forEach(item => {
      const key = item.grouping ?? 'Older';
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(item);
    });
    return Object.entries(grouped).map(([title, data]) => ({ title, data }));
  }, [conversations]);

  // ── States ─────────────────────────────────────────────────────────────────

  let content: React.ReactNode;

  if (loading) {
    content = (
      <View style={styles.center}>
        <ActivityIndicator color={primaryColor} size="large" />
      </View>
    );
  } else if (error) {
    content = (
      <View style={styles.center}>
        <Text style={styles.emptyTitle}>⚠️</Text>
        <Text style={styles.errorText}>{error}</Text>
        <Pressable style={[styles.retryBtn, { backgroundColor: primaryColor }]} onPress={fetchHistory} accessibilityRole="button">
          <Text style={styles.retryBtnText}>Try Again</Text>
        </Pressable>
      </View>
    );
  } else if (conversations.length === 0) {
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
      />
    );
  }

  return (
    <View style={styles.container}>
      <TopBar onBack={handleBack} primaryColor={primaryColor} onNewChat={handleNewChat} />
      {content}
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: SURFACE_COLOR },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 16,
    paddingTop: Platform.OS === 'ios' ? 52 : 12,
    paddingBottom: 12,
    backgroundColor: WHITE,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: DIVIDER_COLOR,
  },
  backBtn:      { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  backArrow:    { fontSize: 22, fontWeight: '600' },
  topBarTitle:  { fontSize: 18, fontWeight: '600', color: TEXT_PRIMARY },
  topBarSub:    { fontSize: 12, color: TEXT_SECONDARY, marginTop: 1 },
  addBtn: {
    width: 36, height: 36, borderRadius: 18,
    alignItems: 'center', justifyContent: 'center',
  },
  addBtnText: { color: WHITE, fontSize: 22, lineHeight: 28 },
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
  retryBtn:   { paddingHorizontal: 24, paddingVertical: 10, borderRadius: 20 },
  retryBtnText: { color: WHITE, fontWeight: '600', fontSize: 14 },
  sectionHeader: {
    backgroundColor: SURFACE_COLOR,
    paddingHorizontal: 16, paddingVertical: 8,
  },
  sectionHeaderText: {
    fontSize: 12, fontWeight: '600', color: TEXT_SECONDARY,
    letterSpacing: 0.8,
  },
  item: {
    flexDirection: 'row', alignItems: 'center',
    paddingVertical: 14, paddingHorizontal: 16,
    backgroundColor: WHITE,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: DIVIDER_COLOR,
    gap: 12,
  },
  iconCircle: {
    width: 40, height: 40, borderRadius: 20,
    backgroundColor: ITEM_ICON_BG,
    alignItems: 'center', justifyContent: 'center',
  },
  itemContent: { flex: 1 },
  itemTitle:   { fontSize: 14, fontWeight: '500', color: TEXT_PRIMARY, lineHeight: 20 },
  itemDate:    { fontSize: 12, color: TEXT_SECONDARY, marginTop: 2 },
  chevron:     { fontSize: 22, color: TEXT_SECONDARY, marginLeft: 8 },
});
