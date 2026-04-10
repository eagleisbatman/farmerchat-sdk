import React, { useCallback } from 'react';
import {
  View,
  Text,
  Pressable,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { MarkdownContent } from './MarkdownContent';
import type { ChatMessage } from '../hooks/useChat';

// ── Colors ────────────────────────────────────────────────────────────────────
const PRIMARY_GREEN  = '#2E7D32';
const BUBBLE_AI_BG   = '#F1F8E9'; // mint green AI bubble
const AVATAR_BG      = '#C8E6C9'; // default avatar ring
const AVATAR_LEAF    = '#2E7D32'; // leaf color
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

  return (
    <View style={styles.container}>
      {/* Row: avatar + content */}
      <View style={styles.row}>
        {/* Avatar 32px */}
        <View style={styles.avatarContainer}>
          <View style={styles.avatar}>
            {/* Leaf shape */}
            <View style={styles.leaf} />
          </View>
        </View>

        {/* Content column */}
        <View style={styles.contentCol}>
          {/* AI bubble */}
          <View style={styles.bubble}>
            <MarkdownContent text={message.text} />
          </View>

          {/* ── Related questions (vertical list with Ask) ──────────────── */}
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

          {/* ── Listen button (TTS pill) ──────────────────────────────────── */}
          {!message.hideTtsSpeaker && (
            <ListenButton messageId={message.serverMessageId} text={message.text} />
          )}
        </View>
      </View>
    </View>
  );
});

// ── Listen button ─────────────────────────────────────────────────────────────

type ListenState = 'idle' | 'loading' | 'playing';

function ListenButton({ messageId, text }: { messageId?: string; text: string }) {
  const [state, setState] = React.useState<ListenState>('idle');

  const handlePress = useCallback(() => {
    if (state === 'idle') {
      setState('loading');
      // TTS call happens via ViewModel — placeholder for now
      setTimeout(() => setState('idle'), 2000);
    } else if (state === 'playing') {
      setState('idle');
    }
  }, [state]);

  return (
    <Pressable
      style={styles.listenBtn}
      onPress={handlePress}
      accessibilityRole="button"
      accessibilityLabel={state === 'playing' ? 'Stop audio' : 'Listen'}
    >
      {state === 'loading' ? (
        <ActivityIndicator size="small" color={PRIMARY_GREEN} style={{ width: 16, height: 16 }} />
      ) : (
        <>
          <Text style={styles.listenIcon}>{state === 'playing' ? '⏹' : '🔊'}</Text>
          <Text style={styles.listenText}>{state === 'playing' ? 'Stop' : 'Listen'}</Text>
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
  avatarContainer: {
    width: 32, height: 32,
    marginRight: 8, marginTop: 4,
  },
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
  // Related questions
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
  // Listen pill
  listenBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: PRIMARY_GREEN,
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 6,
    marginTop: 8,
    alignSelf: 'flex-start',
    gap: 6,
  },
  listenIcon: { fontSize: 14 },
  listenText: { fontSize: 13, color: PRIMARY_GREEN, fontWeight: '500' },
});
