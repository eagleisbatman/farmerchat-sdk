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
import { useChatContext as useChat } from '../ChatProvider';
import { useFarmerChatConfig } from '../FarmerChat';
import { useConnectivity } from '../hooks/useConnectivity';
import { InputBar } from '../components/InputBar';
import { ResponseCard } from '../components/ResponseCard';
import { ConnectivityBanner } from '../components/ConnectivityBanner';
import type { ChatMessage } from '../hooks/useChat';

// ── Dark palette (matches Compose + Views dark theme) ─────────────────────────
const PRIMARY_GREEN    = '#2E7D32';
const LIGHT_GREEN      = '#4CAF50';
const WHITE            = '#FFFFFF';
const DARK_BG          = '#0F1A0D';
const DARK_TOOLBAR     = '#1A2318';
const DARK_SURFACE     = '#1A2318';
const DARK_SURFACE2    = '#243020';
const TEXT_PRIMARY     = '#E8F5E9';
const TEXT_SECONDARY   = '#8FA88C';
const TEXT_MUTED       = '#5A6B58';
const ONLINE_DOT       = '#69F0AE';
const USER_BUBBLE      = '#4CAF50';

// ── ChatTopBar ────────────────────────────────────────────────────────────────

interface ChatTopBarProps {
  title: string;
  historyEnabled: boolean;
  onHistoryPress: () => void;
  onLanguagePress: () => void;
  primaryColor: string;
}

function ChatTopBar({ title, historyEnabled, onHistoryPress, onLanguagePress, primaryColor }: ChatTopBarProps) {
  return (
    <View style={styles.topBar}>
      {/* Avatar — 40px green circle */}
      <View style={[styles.logoCircle, { backgroundColor: LIGHT_GREEN }]}>
        <Text style={styles.logoEmoji}>🌱</Text>
      </View>

      {/* Title column — title + online dot + subtitle */}
      <View style={styles.topBarTitleCol}>
        <View style={styles.topBarTitleRow}>
          <Text style={styles.topBarTitle} numberOfLines={1}>{title}</Text>
          <View style={styles.onlineDot} />
        </View>
        <Text style={styles.topBarSubtitle}>Smart Farming Assistant</Text>
      </View>

      {/* Language/translate icon */}
      {historyEnabled && (
        <Pressable
          style={styles.topBarButton}
          onPress={onLanguagePress}
          accessibilityLabel="Language"
          accessibilityRole="button"
        >
          <Text style={styles.topBarIcon}>🌐</Text>
        </Pressable>
      )}

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

function EmptyState() {
  return (
    <View style={styles.emptyState}>
      <Text style={styles.emptyEmoji}>🌾</Text>
      <Text style={styles.emptyTitle}>
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
      {/* Avatar — 36px green circle */}
      <View style={styles.avatar}>
        <Text style={{ fontSize: 18 }}>🌱</Text>
      </View>
      {/* Dots bubble — dark surface bg */}
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
        onLanguagePress={() => navigateTo('profile')}
        primaryColor={primaryColor}
      />

      {!isConnected && <ConnectivityBanner isConnected={isConnected} />}

      <View style={styles.chatBody}>
        {messages.length === 0 ? (
          <EmptyState />
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
  container: { flex: 1, backgroundColor: DARK_BG },
  // Top bar
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingTop: Platform.OS === 'ios' ? 52 : 10,
    paddingBottom: 10,
    backgroundColor: DARK_TOOLBAR,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 4,
    gap: 10,
  },
  logoCircle:  { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  logoEmoji:   { fontSize: 20 },
  topBarTitleCol: { flex: 1 },
  topBarTitleRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  topBarTitle: { fontSize: 15, fontWeight: '700', color: WHITE, flexShrink: 1 },
  topBarSubtitle: { fontSize: 11, color: TEXT_SECONDARY, marginTop: 1 },
  onlineDot: { width: 7, height: 7, borderRadius: 3.5, backgroundColor: ONLINE_DOT },
  topBarButton: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center' },
  topBarIcon:   { fontSize: 20 },
  // Chat body
  chatBody:    { flex: 1 },
  messageList: { paddingHorizontal: 12, paddingVertical: 8 },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 32,
    gap: 16,
  },
  emptyEmoji:  { fontSize: 56 },
  emptyTitle: {
    fontSize: 16,
    color: TEXT_SECONDARY,
    textAlign: 'center',
    lineHeight: 24,
  },
  // Loading bubble
  loadingRow:  { flexDirection: 'row', paddingHorizontal: 12, paddingVertical: 4, alignItems: 'flex-start' },
  avatar: {
    width: 36, height: 36, borderRadius: 18,
    backgroundColor: LIGHT_GREEN,
    alignItems: 'center', justifyContent: 'center', marginRight: 8, marginTop: 4,
  },
  loadingBubble: {
    flexDirection: 'row', gap: 6, alignItems: 'center',
    backgroundColor: DARK_SURFACE,
    borderRadius: 18, borderTopLeftRadius: 4,
    paddingHorizontal: 14, paddingVertical: 12,
    shadowColor: '#000', shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.2, shadowRadius: 2, elevation: 2,
  },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: LIGHT_GREEN },
  // User bubble
  userBubbleWrapper: {
    alignSelf: 'flex-end', maxWidth: '80%',
    paddingHorizontal: 12, paddingVertical: 4, marginBottom: 4,
  },
  userBubble: {
    backgroundColor: USER_BUBBLE,
    borderRadius: 18, borderBottomRightRadius: 4,
    paddingHorizontal: 14, paddingVertical: 10,
    shadowColor: '#000', shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.18, shadowRadius: 3, elevation: 2,
  },
  userBubbleText: { color: WHITE, fontSize: 15, lineHeight: 22 },
  // Error banner
  errorBanner: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between',
    backgroundColor: '#3D1C22', borderLeftWidth: 3, borderLeftColor: '#CF6679',
    borderRadius: 8, paddingHorizontal: 14, paddingVertical: 12,
    marginHorizontal: 12, marginVertical: 4,
  },
  errorLeft:   { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, marginRight: 12 },
  errorEmoji:  { fontSize: 14 },
  errorText:   { flex: 1, fontSize: 14, color: '#CF6679', lineHeight: 20 },
  retryBtn: {
    paddingHorizontal: 12, paddingVertical: 6,
    borderRadius: 16, backgroundColor: LIGHT_GREEN,
  },
  retryBtnText: { color: WHITE, fontSize: 13, fontWeight: '600' },
});
