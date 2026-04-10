import React, { useRef, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  Pressable,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Animated,
  Easing,
} from 'react-native';
import { useChat } from '../hooks/useChat';
import { useFarmerChatConfig } from '../FarmerChat';
import { useConnectivity } from '../hooks/useConnectivity';
import { InputBar } from '../components/InputBar';
import { ResponseCard } from '../components/ResponseCard';
import { ConnectivityBanner } from '../components/ConnectivityBanner';
import type { ChatMessage } from '../hooks/useChat';

// ── Colors ────────────────────────────────────────────────────────────────────
const PRIMARY_GREEN = '#2E7D32';
const LIGHT_GREEN   = '#4CAF50';
const WHITE         = '#FFFFFF';
const SURFACE_COLOR = '#F5F5F5';
const TEXT_PRIMARY  = '#212121';
const TEXT_SECONDARY = '#757575';

// ── ChatTopBar ────────────────────────────────────────────────────────────────

interface ChatTopBarProps {
  title: string;
  historyEnabled: boolean;
  onHistoryPress: () => void;
  primaryColor: string;
}

function ChatTopBar({ title, historyEnabled, onHistoryPress, primaryColor }: ChatTopBarProps) {
  return (
    <View style={[styles.topBar, { backgroundColor: WHITE }]}>
      {/* Logo circle 34px */}
      <View style={[styles.logoCircle, { backgroundColor: primaryColor }]}>
        <Text style={styles.logoEmoji}>🌱</Text>
      </View>

      {/* Title */}
      <Text style={styles.topBarTitle} numberOfLines={1}>{title}</Text>

      <View style={{ flex: 1 }} />

      {/* History icon */}
      {historyEnabled && (
        <Pressable
          style={styles.topBarButton}
          onPress={onHistoryPress}
          accessibilityLabel="Chat history"
          accessibilityRole="button"
        >
          <Text style={styles.topBarIcon}>🕐</Text>
        </Pressable>
      )}
    </View>
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

function EmptyState({ primaryColor }: { primaryColor: string }) {
  return (
    <View style={styles.emptyState}>
      <Text style={styles.emptyEmoji}>🌾</Text>
      <Text style={[styles.emptyTitle, { color: TEXT_PRIMARY }]}>
        Ask a question about farming to get started
      </Text>
    </View>
  );
}

// ── Loading bubble (3 animated dots) ─────────────────────────────────────────

function LoadingBubble() {
  const dots = [useRef(new Animated.Value(0.4)).current, useRef(new Animated.Value(0.4)).current, useRef(new Animated.Value(0.4)).current];

  useEffect(() => {
    dots.forEach((dot, i) => {
      Animated.loop(
        Animated.sequence([
          Animated.delay(i * 150),
          Animated.timing(dot, { toValue: 1, duration: 300, useNativeDriver: true, easing: Easing.inOut(Easing.ease) }),
          Animated.timing(dot, { toValue: 0.4, duration: 300, useNativeDriver: true, easing: Easing.inOut(Easing.ease) }),
        ]),
      ).start();
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <View style={styles.loadingRow}>
      {/* Avatar */}
      <View style={styles.avatar}>
        <Text style={{ fontSize: 16 }}>🌱</Text>
      </View>
      {/* Dots bubble */}
      <View style={styles.loadingBubble}>
        {dots.map((dot, i) => (
          <Animated.View
            key={i}
            style={[styles.dot, { transform: [{ scale: dot }] }]}
          />
        ))}
      </View>
    </View>
  );
}

// ── User bubble ───────────────────────────────────────────────────────────────

interface UserBubbleProps { message: ChatMessage }

const UserBubble = React.memo(function UserBubble({ message }: UserBubbleProps) {
  return (
    <View style={styles.userBubbleWrapper}>
      <View style={styles.userBubble}>
        <Text style={styles.userBubbleText}>{message.text}</Text>
      </View>
    </View>
  );
});

// ── Error banner ──────────────────────────────────────────────────────────────

function ErrorBanner({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <View style={styles.errorBanner}>
      <View style={styles.errorLeft}>
        <Text style={styles.errorEmoji}>⚠️</Text>
        <Text style={styles.errorText}>{message}</Text>
      </View>
      <Pressable style={styles.retryBtn} onPress={onRetry} accessibilityRole="button">
        <Text style={styles.retryBtnText}>Try again</Text>
      </Pressable>
    </View>
  );
}

// ── ChatScreen ────────────────────────────────────────────────────────────────

export function ChatScreen() {
  const config = useFarmerChatConfig();
  const {
    chatState, messages, isConnected, errorMessage,
    sendQuery, sendFollowUp, retryLastQuery, navigateTo, setIsConnected,
  } = useChat();
  const { isConnected: netConnected } = useConnectivity();
  const flatListRef = useRef<FlatList<ChatMessage>>(null);

  const primaryColor = config.theme?.primaryColor ?? PRIMARY_GREEN;

  useEffect(() => {
    try { setIsConnected(netConnected); } catch { /* no-op */ }
  }, [netConnected, setIsConnected]);

  useEffect(() => {
    if (messages.length > 0) {
      const t = setTimeout(() => {
        try { flatListRef.current?.scrollToEnd({ animated: true }); } catch { /* no-op */ }
      }, 100);
      return () => clearTimeout(t);
    }
  }, [messages.length, chatState]);

  const handleSend = useCallback(async (text: string, imageData?: string) => {
    try { await sendQuery(text, 'text', imageData); } catch { /* handled in hook */ }
  }, [sendQuery]);

  const lastIdRef = useRef<string | undefined>();
  lastIdRef.current = messages[messages.length - 1]?.id;

  const renderItem = useCallback(({ item }: { item: ChatMessage }) => {
    if (item.role === 'user') return <UserBubble message={item} />;
    return (
      <ResponseCard
        message={item}
        onFollowUp={(text, id) => { try { void sendFollowUp(text, id); } catch { /* no-op */ } }}
      />
    );
  }, [sendFollowUp]);

  const keyExtractor = useCallback((item: ChatMessage) => item.id, []);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ChatTopBar
        title={config.headerTitle ?? 'FarmerChat AI'}
        historyEnabled={config.historyEnabled !== false}
        onHistoryPress={() => navigateTo('history')}
        primaryColor={primaryColor}
      />

      {!isConnected && <ConnectivityBanner isConnected={isConnected} />}

      <View style={styles.chatBody}>
        {messages.length === 0 ? (
          <EmptyState primaryColor={primaryColor} />
        ) : (
          <FlatList<ChatMessage>
            ref={flatListRef}
            data={messages}
            renderItem={renderItem}
            keyExtractor={keyExtractor}
            contentContainerStyle={styles.messageList}
            showsVerticalScrollIndicator={false}
            initialNumToRender={15}
            maxToRenderPerBatch={10}
          />
        )}

        {chatState === 'sending' && <LoadingBubble />}

        {chatState === 'error' && errorMessage && (
          <ErrorBanner message={errorMessage} onRetry={retryLastQuery} />
        )}
      </View>

      <InputBar
        onSend={handleSend}
        isDisabled={!isConnected || chatState === 'sending'}
        voiceEnabled={config.voiceInputEnabled ?? false}
        imageEnabled={config.imageInputEnabled ?? false}
      />
    </KeyboardAvoidingView>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container:      { flex: 1, backgroundColor: SURFACE_COLOR },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: Platform.OS === 'ios' ? 52 : 12,
    paddingBottom: 12,
    backgroundColor: WHITE,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E0E0E0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 2,
    elevation: 2,
    gap: 10,
  },
  logoCircle:  { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
  logoEmoji:   { fontSize: 18 },
  topBarTitle: { fontSize: 18, fontWeight: '700', color: TEXT_PRIMARY, flexShrink: 1 },
  topBarButton: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  topBarIcon:   { fontSize: 20 },
  chatBody:    { flex: 1 },
  messageList: { paddingHorizontal: 12, paddingVertical: 8 },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 32,
    gap: 16,
  },
  emptyEmoji:  { fontSize: 48 },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: TEXT_SECONDARY,
    textAlign: 'center',
    lineHeight: 24,
  },
  // Loading
  loadingRow:  { flexDirection: 'row', paddingHorizontal: 12, paddingVertical: 4, alignItems: 'flex-start' },
  avatar: {
    width: 32, height: 32, borderRadius: 16,
    backgroundColor: '#C8E6C9',
    alignItems: 'center', justifyContent: 'center', marginRight: 8, marginTop: 4,
  },
  loadingBubble: {
    flexDirection: 'row', gap: 6, alignItems: 'center',
    backgroundColor: '#F1F8E9',
    borderRadius: 18, borderTopLeftRadius: 4,
    paddingHorizontal: 14, paddingVertical: 12,
    shadowColor: '#000', shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06, shadowRadius: 2, elevation: 1,
  },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: LIGHT_GREEN },
  // User bubble
  userBubbleWrapper: {
    alignSelf: 'flex-end', maxWidth: '80%',
    paddingHorizontal: 16, paddingVertical: 4, marginBottom: 4,
  },
  userBubble: {
    backgroundColor: PRIMARY_GREEN,
    borderRadius: 18, borderBottomRightRadius: 4,
    paddingHorizontal: 14, paddingVertical: 10,
    shadowColor: '#000', shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.12, shadowRadius: 3, elevation: 2,
  },
  userBubbleText: { color: WHITE, fontSize: 15, lineHeight: 22 },
  // Error
  errorBanner: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    backgroundColor: '#FFEBEE', borderLeftWidth: 3, borderLeftColor: '#D32F2F',
    borderRadius: 8, paddingHorizontal: 14, paddingVertical: 12,
    marginHorizontal: 12, marginVertical: 4,
  },
  errorLeft:   { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, marginRight: 12 },
  errorEmoji:  { fontSize: 14 },
  errorText:   { flex: 1, fontSize: 14, color: '#D32F2F', lineHeight: 20 },
  retryBtn: {
    paddingHorizontal: 12, paddingVertical: 6,
    borderRadius: 16, backgroundColor: PRIMARY_GREEN,
  },
  retryBtnText: { color: WHITE, fontSize: 13, fontWeight: '600' },
});
