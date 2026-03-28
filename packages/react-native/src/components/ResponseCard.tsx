import React, { useState, useCallback, useEffect, useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  Pressable,
  StyleSheet,
} from 'react-native';
import type {
  Message,
  MarkdownDocument,
} from '@digitalgreenorg/farmerchat-core';
import { MarkdownContent } from './MarkdownContent';

interface ResponseCardProps {
  message: Message;
  isStreaming?: boolean;
  streamingMarkdown?: MarkdownDocument | null;
  onFollowUp?: (text: string) => void;
  onFeedback?: (responseId: string, rating: 'positive' | 'negative') => Promise<void>;
}

export const ResponseCard = React.memo(function ResponseCard({
  message,
  isStreaming = false,
  streamingMarkdown,
  onFollowUp,
  onFeedback,
}: ResponseCardProps) {
  const [feedbackState, setFeedbackState] = useState<'positive' | 'negative' | null>(
    message.feedback?.rating ?? null,
  );
  const [feedbackLoading, setFeedbackLoading] = useState(false);
  const [cursorVisible, setCursorVisible] = useState(true);
  const cursorInterval = useRef<ReturnType<typeof setInterval> | null>(null);

  // Blink cursor during streaming
  useEffect(() => {
    if (isStreaming) {
      cursorInterval.current = setInterval(() => {
        setCursorVisible((v) => !v);
      }, 500);
    } else {
      setCursorVisible(false);
    }
    return () => {
      if (cursorInterval.current) {
        clearInterval(cursorInterval.current);
        cursorInterval.current = null;
      }
    };
  }, [isStreaming]);

  // Sync feedback from prop changes
  useEffect(() => {
    if (message.feedback?.rating) {
      setFeedbackState(message.feedback.rating);
    }
  }, [message.feedback?.rating]);

  const handleFeedback = useCallback(
    async (rating: 'positive' | 'negative') => {
      if (feedbackLoading || feedbackState != null) return;
      try {
        setFeedbackLoading(true);
        await onFeedback?.(message.id, rating);
        setFeedbackState(rating);
      } catch {
        // SDK must never crash the host app
      } finally {
        setFeedbackLoading(false);
      }
    },
    [feedbackLoading, feedbackState, message.id, onFeedback],
  );

  const handleFollowUp = useCallback(
    (text: string) => {
      try {
        onFollowUp?.(text);
      } catch {
        // SDK must never crash the host app
      }
    },
    [onFollowUp],
  );

  return (
    <View style={styles.container}>
      {/* Avatar + content row */}
      <View style={styles.row}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>FC</Text>
        </View>

        <View style={styles.content}>
          {/* Markdown body */}
          {isStreaming && streamingMarkdown ? (
            <MarkdownContent document={streamingMarkdown} />
          ) : (
            <MarkdownContent text={message.text} />
          )}

          {/* Streaming cursor */}
          {isStreaming && (
            <Text style={[styles.cursor, !cursorVisible && styles.cursorHidden]}>
              {'\u258B'}
            </Text>
          )}
        </View>
      </View>

      {/* Follow-up chips */}
      {!isStreaming &&
        message.followUps != null &&
        message.followUps.length > 0 && (
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            style={styles.followUpScroll}
            contentContainerStyle={styles.followUpContainer}
          >
            {message.followUps.map((fq, i) => (
              <Pressable
                key={i}
                onPress={() => handleFollowUp(fq.text)}
                style={({ pressed }) => [
                  styles.followUpChip,
                  pressed && styles.followUpChipPressed,
                ]}
                accessibilityRole="button"
                accessibilityLabel={`Follow-up: ${fq.text}`}
              >
                <Text style={styles.followUpText} numberOfLines={2}>
                  {fq.text}
                </Text>
              </Pressable>
            ))}
          </ScrollView>
        )}

      {/* Feedback bar */}
      {!isStreaming && (
        <View style={styles.feedbackBar}>
          <Pressable
            onPress={() => handleFeedback('positive')}
            disabled={feedbackLoading || feedbackState != null}
            style={({ pressed }) => [
              styles.feedbackButton,
              feedbackState === 'positive' && styles.feedbackSelected,
              pressed && styles.feedbackPressed,
            ]}
            accessibilityLabel="Thumbs up"
            accessibilityRole="button"
          >
            <Text
              style={[
                styles.feedbackIcon,
                feedbackState === 'positive' && styles.feedbackIconSelected,
                feedbackState != null && feedbackState !== 'positive' && styles.feedbackIconDimmed,
              ]}
            >
              {'👍'}
            </Text>
          </Pressable>

          <Pressable
            onPress={() => handleFeedback('negative')}
            disabled={feedbackLoading || feedbackState != null}
            style={({ pressed }) => [
              styles.feedbackButton,
              feedbackState === 'negative' && styles.feedbackSelected,
              pressed && styles.feedbackPressed,
            ]}
            accessibilityLabel="Thumbs down"
            accessibilityRole="button"
          >
            <Text
              style={[
                styles.feedbackIcon,
                feedbackState === 'negative' && styles.feedbackIconSelected,
                feedbackState != null && feedbackState !== 'negative' && styles.feedbackIconDimmed,
              ]}
            >
              {'👎'}
            </Text>
          </Pressable>
        </View>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  avatar: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#1B6B3A',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
    marginTop: 2,
  },
  avatarText: {
    color: '#FFFFFF',
    fontSize: 10,
    fontWeight: '700',
  },
  content: {
    flex: 1,
  },
  cursor: {
    fontSize: 16,
    color: '#1B6B3A',
    marginTop: 2,
  },
  cursorHidden: {
    opacity: 0,
  },
  followUpScroll: {
    marginTop: 12,
    marginLeft: 34,
  },
  followUpContainer: {
    gap: 8,
    paddingRight: 14,
  },
  followUpChip: {
    backgroundColor: '#F0F7F2',
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderWidth: 1,
    borderColor: '#D4E8DA',
    maxWidth: 220,
  },
  followUpChipPressed: {
    backgroundColor: '#D4E8DA',
  },
  followUpText: {
    fontSize: 13,
    color: '#1B6B3A',
    lineHeight: 18,
  },
  feedbackBar: {
    flexDirection: 'row',
    marginTop: 8,
    marginLeft: 34,
    gap: 4,
  },
  feedbackButton: {
    padding: 6,
    borderRadius: 8,
  },
  feedbackSelected: {
    backgroundColor: '#F0F7F2',
  },
  feedbackPressed: {
    opacity: 0.6,
  },
  feedbackIcon: {
    fontSize: 16,
  },
  feedbackIconSelected: {
    opacity: 1,
  },
  feedbackIconDimmed: {
    opacity: 0.3,
  },
});
