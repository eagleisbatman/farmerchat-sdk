import React, { useCallback, useRef } from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  ActivityIndicator,
  Share,
  Clipboard,
  Platform,
} from 'react-native';
import { Audio } from 'expo-av';
import { MarkdownContent } from './MarkdownContent';
import type { ChatMessage } from '../hooks/useChat';
import { useChatContext } from '../ChatProvider';

// ── Colors ────────────────────────────────────────────────────────────────────
const PRIMARY_GREEN  = '#2E7D32';
const BUBBLE_AI_BG   = '#F1F8E9';
const AVATAR_BG      = '#C8E6C9';
const AVATAR_LEAF    = '#2E7D32';
const TEXT_PRIMARY   = '#212121';
const TEXT_SECONDARY = '#757575';

// ── ResponseCard ──────────────────────────────────────────────────────────────

interface ResponseCardProps {
  message: ChatMessage;
  onFollowUp?: (text: string, id?: string) => void;
}

export const ResponseCard = React.memo(function ResponseCard({
  message,
  onFollowUp,
}: ResponseCardProps) {

  const handleFollowUp = useCallback(
    (text: string, id?: string) => {
      try { onFollowUp?.(text, id); } catch { /* no-op */ }
    },
    [onFollowUp],
  );

  const handleShare = useCallback(async () => {
    try {
      await Share.share({ message: message.text, title: 'FarmerChat Response' });
    } catch { /* user cancelled */ }
  }, [message.text]);

  const handleCopy = useCallback(() => {
    try { Clipboard.setString(message.text); } catch { /* no-op */ }
  }, [message.text]);

  return (
    <View style={styles.container}>
      <View style={styles.row}>
        {/* Avatar */}
        <View style={styles.avatarContainer}>
          <View style={styles.avatar}>
            <View style={styles.leaf} />
          </View>
        </View>

        {/* Content column */}
        <View style={styles.contentCol}>
          {/* AI bubble */}
          <View style={styles.bubble}>
            <MarkdownContent text={message.text} />
          </View>

          {/* Related questions */}
          {message.followUps && message.followUps.length > 0 && (
            <View style={styles.relatedContainer}>
              <Text style={styles.relatedLabel}>Related questions</Text>
              {message.followUps.map((fu, i) => (
                <View key={fu.follow_up_question_id ?? i} style={[styles.relatedItem, i > 0 && styles.relatedItemBorder]}>
                  <Text style={styles.relatedText} numberOfLines={3}>{fu.question}</Text>
                  <Pressable
                    style={styles.askBtn}
                    onPress={() => handleFollowUp(fu.question, fu.follow_up_question_id)}
                    accessibilityRole="button"
                    accessibilityLabel={`Ask: ${fu.question}`}
                  >
                    <Text style={styles.askBtnText}>Ask</Text>
                  </Pressable>
                </View>
              ))}
            </View>
          )}

          {/* Actions row: Listen + Copy + Share */}
          <View style={styles.actionsRow}>
            {!message.hideTtsSpeaker && message.serverMessageId ? (
              <ListenButton
                messageId={message.serverMessageId}
                text={message.text}
              />
            ) : null}

            {/* Copy */}
            <Pressable
              style={styles.iconBtn}
              onPress={handleCopy}
              accessibilityRole="button"
              accessibilityLabel="Copy response"
            >
              <Text style={styles.iconBtnText}>⎘</Text>
            </Pressable>

            {/* Share */}
            <Pressable
              style={styles.iconBtn}
              onPress={handleShare}
              accessibilityRole="button"
              accessibilityLabel="Share response"
            >
              <Text style={styles.iconBtnText}>↗</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </View>
  );
});

// ── Listen button ─────────────────────────────────────────────────────────────

type ListenState = 'idle' | 'loading' | 'playing';

function ListenButton({ messageId, text }: { messageId: string; text: string }) {
  const { synthesiseAudio } = useChatContext();
  const [state, setState] = React.useState<ListenState>('idle');
  const soundRef = useRef<Audio.Sound | null>(null);

  const stopAudio = useCallback(async () => {
    try {
      if (soundRef.current) {
        await soundRef.current.stopAsync();
        await soundRef.current.unloadAsync();
        soundRef.current = null;
      }
    } catch { /* no-op */ }
    setState('idle');
  }, []);

  const handlePress = useCallback(async () => {
    if (state === 'playing') {
      await stopAudio();
      return;
    }
    if (state === 'loading') return;

    setState('loading');
    try {
      const url = await synthesiseAudio(messageId, text);
      if (!url) { setState('idle'); return; }

      await Audio.setAudioModeAsync({ playsInSilentModeIOS: true });
      const { sound } = await Audio.Sound.createAsync(
        { uri: url },
        { shouldPlay: true },
        (status) => {
          if (status.isLoaded && status.didJustFinish) {
            void stopAudio();
          }
        }
      );
      soundRef.current = sound;
      setState('playing');
    } catch {
      setState('idle');
    }
  }, [state, messageId, text, synthesiseAudio, stopAudio]);

  return (
    <Pressable
      style={[styles.listenBtn, state === 'loading' && styles.listenBtnDisabled]}
      onPress={handlePress}
      disabled={state === 'loading'}
      accessibilityRole="button"
      accessibilityLabel={state === 'playing' ? 'Stop audio' : 'Listen'}
    >
      {state === 'loading' ? (
        <ActivityIndicator size="small" color={PRIMARY_GREEN} style={{ width: 16, height: 16 }} />
      ) : (
        <>
          <Text style={styles.listenIcon}>
            {state === 'playing' ? '⏹' : '🔊'}
          </Text>
          <Text style={styles.listenText}>
            {state === 'playing' ? 'Stop' : 'Listen'}
          </Text>
        </>
      )}
    </Pressable>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    alignSelf: 'flex-start',
    maxWidth: '92%',
    paddingHorizontal: 12,
    paddingVertical: 4,
    marginBottom: 4,
  },
  row: { flexDirection: 'row', alignItems: 'flex-start' },
  avatarContainer: { width: 32, height: 32, marginRight: 8, marginTop: 4 },
  avatar: {
    width: 32, height: 32, borderRadius: 16,
    backgroundColor: AVATAR_BG,
    alignItems: 'center', justifyContent: 'center',
  },
  leaf: {
    width: 16, height: 20,
    backgroundColor: AVATAR_LEAF,
    borderRadius: 8,
    transform: [{ rotate: '30deg' }],
  },
  contentCol: { flex: 1 },
  bubble: {
    backgroundColor: BUBBLE_AI_BG,
    borderRadius: 18, borderTopLeftRadius: 4,
    paddingHorizontal: 14, paddingVertical: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 2,
    elevation: 1,
  },
  relatedContainer: {
    marginTop: 8,
    backgroundColor: '#FFFFFF',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#E0E0E0',
  },
  relatedLabel: {
    fontSize: 13, fontWeight: '600', color: TEXT_PRIMARY,
    paddingHorizontal: 16, paddingTop: 12, paddingBottom: 6,
  },
  relatedItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  relatedItemBorder: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#E0E0E0',
  },
  relatedText: { flex: 1, fontSize: 14, color: TEXT_PRIMARY, marginRight: 12, lineHeight: 20 },
  askBtn: {
    backgroundColor: PRIMARY_GREEN,
    borderRadius: 16,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  askBtnText: { color: '#FFFFFF', fontSize: 13, fontWeight: '600' },
  // Actions row
  actionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
    gap: 8,
  },
  listenBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: PRIMARY_GREEN,
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 6,
    gap: 6,
  },
  listenBtnDisabled: { opacity: 0.5 },
  listenIcon: { fontSize: 14 },
  listenText: { fontSize: 13, color: PRIMARY_GREEN, fontWeight: '500' },
  // Icon buttons (Copy / Share)
  iconBtn: {
    width: 30, height: 30, borderRadius: 15,
    backgroundColor: '#EEEEEE',
    alignItems: 'center', justifyContent: 'center',
  },
  iconBtnText: { fontSize: 14, color: TEXT_SECONDARY },
});
