import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  Pressable,
  FlatList,
  ActivityIndicator,
  StyleSheet,
  Platform,
} from 'react-native';
import { useChat } from '../hooks/useChat';
import { useFarmerChatConfig } from '../FarmerChat';
import type { Conversation } from '@digitalgreenorg/farmerchat-core';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatDate(timestamp: number): string {
  try {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;

    // Fallback to short date
    return date.toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined,
    });
  } catch {
    return '';
  }
}

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface TopBarProps {
  onBack: () => void;
  primaryColor: string;
}

function TopBar({ onBack, primaryColor }: TopBarProps) {
  return (
    <View style={[styles.topBar, { backgroundColor: primaryColor }]}>
      <Pressable
        style={styles.backButton}
        onPress={onBack}
        accessibilityLabel="Go back"
        accessibilityRole="button"
      >
        <Text style={styles.backArrow}>{'\u2190'}</Text>
      </Pressable>
      <Text style={styles.topBarTitle}>History</Text>
      <View style={styles.topBarSpacer} />
    </View>
  );
}

interface ConversationCardProps {
  conversation: Conversation;
  primaryColor: string;
}

function ConversationCard({ conversation, primaryColor }: ConversationCardProps) {
  return (
    <Pressable
      style={styles.conversationCard}
      accessibilityRole="button"
      // Tapping is a no-op for now (future: load that conversation)
    >
      <View style={[styles.conversationIndicator, { backgroundColor: primaryColor }]} />
      <View style={styles.conversationContent}>
        <Text style={styles.conversationTitle} numberOfLines={2}>
          {conversation.title}
        </Text>
        <Text style={styles.conversationDate}>
          {formatDate(conversation.updatedAt)}
        </Text>
      </View>
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// HistoryScreen
// ---------------------------------------------------------------------------

export function HistoryScreen() {
  const config = useFarmerChatConfig();
  const { loadHistory, navigateTo } = useChat();

  const primaryColor = config.theme?.primaryColor ?? '#1B6B3A';

  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchHistory = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const result = await loadHistory();
      setConversations(result);
    } catch {
      setError('Failed to load history. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [loadHistory]);

  useEffect(() => {
    fetchHistory();
  }, [fetchHistory]);

  const handleBack = useCallback(() => {
    try {
      navigateTo('chat');
    } catch {
      // Navigation failure is non-critical
    }
  }, [navigateTo]);

  const renderItem = useCallback(
    ({ item }: { item: Conversation }) => (
      <ConversationCard conversation={item} primaryColor={primaryColor} />
    ),
    [primaryColor],
  );

  const keyExtractor = useCallback((item: Conversation) => item.id, []);

  // ---------------------------------------------------------------------------
  // Content states
  // ---------------------------------------------------------------------------

  let content: React.ReactNode;

  if (loading) {
    content = (
      <View style={styles.centerContainer}>
        <ActivityIndicator color={primaryColor} size="large" />
      </View>
    );
  } else if (error) {
    content = (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>{error}</Text>
        <Pressable
          style={[styles.retryButton, { backgroundColor: primaryColor }]}
          onPress={fetchHistory}
          accessibilityRole="button"
        >
          <Text style={styles.retryButtonText}>Retry</Text>
        </Pressable>
      </View>
    );
  } else if (conversations.length === 0) {
    content = (
      <View style={styles.centerContainer}>
        <Text style={styles.emptyIcon}>{'\u{1F4AC}'}</Text>
        <Text style={styles.emptyText}>No conversations yet</Text>
        <Text style={styles.emptySubtext}>
          Start chatting to see your history here
        </Text>
      </View>
    );
  } else {
    content = (
      <FlatList<Conversation>
        data={conversations}
        renderItem={renderItem}
        keyExtractor={keyExtractor}
        contentContainerStyle={styles.listContent}
        showsVerticalScrollIndicator={false}
      />
    );
  }

  return (
    <View style={styles.container}>
      <TopBar onBack={handleBack} primaryColor={primaryColor} />
      {content}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    paddingTop: Platform.OS === 'ios' ? 48 : 12,
  },
  backButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  backArrow: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '600',
  },
  topBarTitle: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
  },
  topBarSpacer: {
    width: 36,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 32,
  },
  errorText: {
    fontSize: 14,
    color: '#B91C1C',
    textAlign: 'center',
    marginBottom: 16,
  },
  retryButton: {
    paddingHorizontal: 24,
    paddingVertical: 10,
    borderRadius: 12,
  },
  retryButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  emptyIcon: {
    fontSize: 48,
    marginBottom: 16,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 8,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#666666',
    textAlign: 'center',
  },
  listContent: {
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  conversationCard: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E5E5E5',
  },
  conversationIndicator: {
    width: 4,
    height: 36,
    borderRadius: 2,
    marginRight: 12,
  },
  conversationContent: {
    flex: 1,
  },
  conversationTitle: {
    fontSize: 15,
    fontWeight: '500',
    color: '#333333',
    marginBottom: 4,
  },
  conversationDate: {
    fontSize: 12,
    color: '#999999',
  },
});
