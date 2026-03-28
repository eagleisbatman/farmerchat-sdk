import React, { useRef, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  Pressable,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useChat } from '../hooks/useChat';
import { useFarmerChatConfig } from '../FarmerChat';
import { useConnectivity } from '../hooks/useConnectivity';
import { InputBar } from '../components/InputBar';
import { ResponseCard } from '../components/ResponseCard';
import { ConnectivityBanner } from '../components/ConnectivityBanner';
import type { Message, StarterQuestion, MarkdownDocument } from '@digitalgreenorg/farmerchat-core';

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface ChatTopBarProps {
  title: string;
  historyEnabled: boolean;
  profileEnabled: boolean;
  onHistoryPress: () => void;
  onProfilePress: () => void;
  primaryColor: string;
}

function ChatTopBar({
  title,
  historyEnabled,
  profileEnabled,
  onHistoryPress,
  onProfilePress,
  primaryColor,
}: ChatTopBarProps) {
  return (
    <View style={[styles.topBar, { backgroundColor: primaryColor }]}>
      <Text style={styles.topBarTitle} numberOfLines={1}>
        {title}
      </Text>
      <View style={styles.topBarActions}>
        {historyEnabled && (
          <Pressable
            style={styles.topBarButton}
            onPress={onHistoryPress}
            accessibilityLabel="Chat history"
            accessibilityRole="button"
          >
            {/* Clock icon using unicode */}
            <Text style={styles.topBarIcon}>{'\u{1F551}'}</Text>
          </Pressable>
        )}
        {profileEnabled && (
          <Pressable
            style={styles.topBarButton}
            onPress={onProfilePress}
            accessibilityLabel="Profile"
            accessibilityRole="button"
          >
            {/* Person icon using unicode */}
            <Text style={styles.topBarIcon}>{'\u{1F464}'}</Text>
          </Pressable>
        )}
      </View>
    </View>
  );
}

interface StarterQuestionsAreaProps {
  questions: StarterQuestion[];
  onSelect: (text: string) => void;
  primaryColor: string;
  secondaryColor: string;
}

function StarterQuestionsArea({
  questions,
  onSelect,
  primaryColor,
  secondaryColor,
}: StarterQuestionsAreaProps) {
  return (
    <View style={styles.starterContainer}>
      <Text style={styles.starterHeading}>How can I help you today?</Text>
      <View style={styles.starterChips}>
        {questions.map((q, index) => (
          <Pressable
            key={`${q.text}-${index}`}
            style={[
              styles.starterChip,
              { backgroundColor: secondaryColor, borderColor: primaryColor },
            ]}
            onPress={() => onSelect(q.text)}
            accessibilityRole="button"
          >
            <Text style={[styles.starterChipText, { color: primaryColor }]}>
              {q.text}
            </Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

function StreamingIndicator() {
  return (
    <View style={styles.streamingRow}>
      <View style={styles.streamingDots}>
        <Text style={styles.streamingText}>...</Text>
      </View>
    </View>
  );
}

interface ErrorBannerProps {
  message: string;
  onRetry: () => void;
}

function ErrorBanner({ message, onRetry }: ErrorBannerProps) {
  return (
    <View style={styles.errorBanner}>
      <Text style={styles.errorText}>{message}</Text>
      <Pressable style={styles.retryButton} onPress={onRetry} accessibilityRole="button">
        <Text style={styles.retryButtonText}>Retry</Text>
      </Pressable>
    </View>
  );
}

interface UserBubbleProps {
  message: Message;
  primaryColor: string;
}

const UserBubble = React.memo(function UserBubble({ message, primaryColor }: UserBubbleProps) {
  return (
    <View style={styles.userBubbleRow}>
      <View style={[styles.userBubble, { backgroundColor: primaryColor }]}>
        <Text style={styles.userBubbleText}>{message.text}</Text>
      </View>
    </View>
  );
});

// ---------------------------------------------------------------------------
// ChatScreen
// ---------------------------------------------------------------------------

export function ChatScreen() {
  const config = useFarmerChatConfig();
  const {
    chatState,
    messages,
    starterQuestions,
    isConnected,
    errorMessage,
    streamingMarkdown,
    sendQuery,
    sendFollowUp,
    stopStream,
    retryLastQuery,
    submitFeedback,
    loadStarters,
    navigateTo,
    setIsConnected,
  } = useChat();

  const { isConnected: connectivityConnected } = useConnectivity();
  const flatListRef = useRef<FlatList<Message>>(null);

  const primaryColor = config.theme?.primaryColor ?? '#1B6B3A';
  const secondaryColor = config.theme?.secondaryColor ?? '#F0F7F2';
  const historyEnabled = config.historyEnabled !== false;
  const profileEnabled = config.profileEnabled !== false;
  const headerTitle = config.headerTitle ?? 'FarmerChat';

  // Sync connectivity state from the hook into the chat state machine
  useEffect(() => {
    try {
      setIsConnected(connectivityConnected);
    } catch {
      // SDK must never crash the host app
    }
  }, [connectivityConnected, setIsConnected]);

  // Load starter questions on mount
  useEffect(() => {
    try {
      loadStarters();
    } catch {
      // Silently ignore — starters are non-critical
    }
  }, [loadStarters]);

  // Auto-scroll to bottom when messages change
  useEffect(() => {
    if (messages.length > 0) {
      try {
        // Small delay to let layout settle after new message
        const timer = setTimeout(() => {
          flatListRef.current?.scrollToEnd({ animated: true });
        }, 100);
        return () => clearTimeout(timer);
      } catch {
        // Scroll failure is non-critical
      }
    }
  }, [messages.length, chatState]);

  const handleSendQuery = useCallback(
    async (text: string, imageData?: string) => {
      try {
        await sendQuery(text, imageData);
      } catch {
        // Error state is managed by the hook
      }
    },
    [sendQuery],
  );

  // Track last message ID in a ref to avoid closing over the messages array
  const lastMessageIdRef = useRef<string | undefined>(undefined);
  lastMessageIdRef.current = messages[messages.length - 1]?.id;

  const renderItem = useCallback(
    ({ item }: { item: Message }) => {
      try {
        if (item.role === 'user') {
          return <UserBubble message={item} primaryColor={primaryColor} />;
        }

        const isLastMessage = item.id === lastMessageIdRef.current;
        const isCurrentlyStreaming = chatState === 'streaming' && isLastMessage;

        return (
          <ResponseCard
            message={item}
            isStreaming={isCurrentlyStreaming}
            streamingMarkdown={isCurrentlyStreaming ? streamingMarkdown : null}
            onFollowUp={sendFollowUp}
            onFeedback={submitFeedback}
          />
        );
      } catch {
        // Render fallback if component errors
        return (
          <View style={styles.fallbackMessage}>
            <Text>{item.text}</Text>
          </View>
        );
      }
    },
    [primaryColor, chatState, streamingMarkdown, sendFollowUp, submitFeedback],
  );

  const keyExtractor = useCallback((item: Message) => item.id, []);

  const showStarters = messages.length === 0 && starterQuestions.length > 0;

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 0}
    >
      <ChatTopBar
        title={headerTitle}
        historyEnabled={historyEnabled}
        profileEnabled={profileEnabled}
        onHistoryPress={() => navigateTo('history')}
        onProfilePress={() => navigateTo('profile')}
        primaryColor={primaryColor}
      />

      {!isConnected && <ConnectivityBanner isConnected={isConnected} />}

      {chatState === 'error' && errorMessage && (
        <ErrorBanner message={errorMessage} onRetry={retryLastQuery} />
      )}

      <View style={styles.chatBody}>
        {showStarters ? (
          <StarterQuestionsArea
            questions={starterQuestions}
            onSelect={(text) => handleSendQuery(text)}
            primaryColor={primaryColor}
            secondaryColor={secondaryColor}
          />
        ) : (
          <FlatList<Message>
            ref={flatListRef}
            data={messages}
            renderItem={renderItem}
            keyExtractor={keyExtractor}
            extraData={chatState}
            contentContainerStyle={styles.messageList}
            showsVerticalScrollIndicator={false}
            initialNumToRender={15}
            maxToRenderPerBatch={10}
            windowSize={10}
          />
        )}

        {chatState === 'sending' && <StreamingIndicator />}
      </View>

      <InputBar
        onSend={handleSendQuery}
        isDisabled={!isConnected || chatState === 'streaming'}
      />
    </KeyboardAvoidingView>
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
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    paddingTop: Platform.OS === 'ios' ? 48 : 12,
  },
  topBarTitle: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
    flex: 1,
  },
  topBarActions: {
    flexDirection: 'row',
    gap: 8,
  },
  topBarButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  topBarIcon: {
    fontSize: 18,
  },
  chatBody: {
    flex: 1,
  },
  messageList: {
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  starterContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  starterHeading: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 24,
    textAlign: 'center',
  },
  starterChips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 10,
  },
  starterChip: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 12,
    borderWidth: 1,
  },
  starterChipText: {
    fontSize: 14,
    fontWeight: '500',
  },
  userBubbleRow: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginVertical: 4,
  },
  userBubble: {
    maxWidth: '78%',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
    borderBottomRightRadius: 4,
  },
  userBubbleText: {
    color: '#FFFFFF',
    fontSize: 15,
    lineHeight: 20,
  },
  streamingRow: {
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  streamingDots: {
    backgroundColor: '#F0F0F0',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 8,
    alignSelf: 'flex-start',
  },
  streamingText: {
    fontSize: 20,
    color: '#666666',
    letterSpacing: 4,
  },
  errorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#FEE2E2',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  errorText: {
    color: '#B91C1C',
    fontSize: 13,
    flex: 1,
    marginRight: 12,
  },
  retryButton: {
    backgroundColor: '#B91C1C',
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 12,
  },
  retryButtonText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '600',
  },
  fallbackMessage: {
    padding: 12,
    marginVertical: 4,
  },
});
