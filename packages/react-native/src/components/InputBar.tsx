import React, { useState, useCallback } from 'react';
import {
  View,
  TextInput,
  Pressable,
  Text,
  StyleSheet,
  Platform,
  Image,
} from 'react-native';

// ── Colors ────────────────────────────────────────────────────────────────────
const PRIMARY_GREEN  = '#2E7D32';
const SURFACE_COLOR  = '#F5F5F5';
const WHITE          = '#FFFFFF';
const TEXT_SECONDARY = '#757575';
const DIVIDER_COLOR  = '#E0E0E0';

interface InputBarProps {
  onSend: (text: string) => void;
  onVoicePress?: () => void;
  onCameraPress?: () => void;
  voiceEnabled?: boolean;
  imageEnabled?: boolean;
  isDisabled?: boolean;
  placeholder?: string;
  selectedImageUri?: string;
  onClearImage?: () => void;
}

/**
 * Chat input bar — light flat theme.
 *
 * Layout: [Camera 36px circle] [TextInput flex:1 20px radius] [Mic | Send 40px circle]
 * Padding: h 12, top 8, bottom 4(iOS)/8(Android).
 * Send button bg: #2E7D32. Mic/Camera bg: #F5F5F5.
 */
export const InputBar = React.memo(function InputBar({
  onSend,
  onVoicePress,
  onCameraPress,
  voiceEnabled = false,
  imageEnabled = false,
  isDisabled = false,
  placeholder = 'Ask about your crops…',
  selectedImageUri,
  onClearImage,
}: InputBarProps) {
  const [text, setText] = useState('');

  const hasText = text.trim().length > 0;
  const hasImage = !!selectedImageUri;
  const canSend = (hasText || hasImage) && !isDisabled;

  const handleSend = useCallback(() => {
    try {
      const trimmed = text.trim();
      if (!trimmed && !hasImage) return;
      onSend(trimmed);
      setText('');
    } catch { /* no-op */ }
  }, [text, hasImage, onSend]);

  const handleVoice = useCallback(() => {
    try { onVoicePress?.(); } catch { /* no-op */ }
  }, [onVoicePress]);

  const handleCamera = useCallback(() => {
    try { onCameraPress?.(); } catch { /* no-op */ }
  }, [onCameraPress]);

  return (
    <View style={styles.container}>
      {/* Image preview */}
      {selectedImageUri && (
        <View style={styles.imagePreviewRow}>
          <View style={styles.imagePreviewContainer}>
            <Image source={{ uri: selectedImageUri }} style={styles.imagePreview} />
            <Pressable style={styles.imageRemoveBtn} onPress={onClearImage}>
              <Text style={styles.imageRemoveText}>✕</Text>
            </Pressable>
          </View>
        </View>
      )}

      <View style={styles.inputRow}>
        {/* Camera icon button */}
        {imageEnabled && (
          <Pressable
            onPress={handleCamera}
            disabled={isDisabled}
            style={[styles.iconBtn, isDisabled && styles.disabled]}
            accessibilityLabel="Take photo"
            accessibilityRole="button"
          >
            <Text style={styles.iconText}>📷</Text>
          </Pressable>
        )}

        {/* Text input — flex:1, #F5F5F5 bg, 20px radius pill */}
        <TextInput
          style={[styles.input, isDisabled && styles.inputDisabled]}
          value={text}
          onChangeText={setText}
          placeholder={placeholder}
          placeholderTextColor={TEXT_SECONDARY}
          multiline
          maxLength={2000}
          editable={!isDisabled}
          returnKeyType={Platform.OS === 'ios' ? 'default' : 'send'}
          blurOnSubmit={false}
          accessibilityLabel="Message input"
        />

        {/* Send or Mic */}
        {canSend ? (
          <Pressable
            onPress={handleSend}
            disabled={!canSend}
            style={({ pressed }) => [
              styles.sendBtn,
              pressed && styles.sendBtnPressed,
              !canSend && styles.disabled,
            ]}
            accessibilityLabel="Send message"
            accessibilityRole="button"
          >
            <Text style={styles.sendBtnText}>↑</Text>
          </Pressable>
        ) : voiceEnabled ? (
          <Pressable
            onPress={handleVoice}
            disabled={isDisabled}
            style={[styles.iconBtn, isDisabled && styles.disabled]}
            accessibilityLabel="Voice input"
            accessibilityRole="button"
          >
            <Text style={styles.iconText}>🎤</Text>
          </Pressable>
        ) : null}
      </View>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    backgroundColor: WHITE,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: DIVIDER_COLOR,
    paddingBottom: Platform.OS === 'ios' ? 4 : 8,
  },
  imagePreviewRow: { paddingHorizontal: 12, paddingTop: 8 },
  imagePreviewContainer: { position: 'relative', alignSelf: 'flex-start' },
  imagePreview: {
    width: 80, height: 60, borderRadius: 8,
  },
  imageRemoveBtn: {
    position: 'absolute', top: -8, right: -8,
    width: 20, height: 20, borderRadius: 10,
    backgroundColor: '#757575',
    alignItems: 'center', justifyContent: 'center',
  },
  imageRemoveText: { color: WHITE, fontSize: 10, fontWeight: '700' },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 8,
    paddingHorizontal: 12,
    paddingTop: 8,
    minHeight: 44,
  },
  input: {
    flex: 1,
    minHeight: 40,
    maxHeight: 120,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 20,
    backgroundColor: SURFACE_COLOR,
    fontSize: 15,
    color: '#1A1A1A',
  },
  inputDisabled: { opacity: 0.5 },
  iconBtn: {
    width: 36, height: 36, borderRadius: 18,
    backgroundColor: SURFACE_COLOR,
    alignItems: 'center', justifyContent: 'center',
  },
  iconText: { fontSize: 18 },
  sendBtn: {
    width: 40, height: 40, borderRadius: 20,
    backgroundColor: PRIMARY_GREEN,
    alignItems: 'center', justifyContent: 'center',
  },
  sendBtnPressed: { backgroundColor: '#1B5E20' },
  sendBtnText: { color: WHITE, fontSize: 20, fontWeight: '700', lineHeight: 24 },
  disabled: { opacity: 0.4 },
});
