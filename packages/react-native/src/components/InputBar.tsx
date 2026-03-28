import React, { useState, useCallback } from 'react';
import { View, TextInput, Pressable, Text, StyleSheet, Platform } from 'react-native';

interface InputBarProps {
  onSend: (text: string) => void;
  onVoicePress?: () => void;
  onCameraPress?: () => void;
  voiceEnabled?: boolean;
  imageEnabled?: boolean;
  isDisabled?: boolean;
  placeholder?: string;
}

export const InputBar = React.memo(function InputBar({
  onSend,
  onVoicePress,
  onCameraPress,
  voiceEnabled = false,
  imageEnabled = false,
  isDisabled = false,
  placeholder = 'Ask about your crops...',
}: InputBarProps) {
  const [text, setText] = useState('');

  const handleSend = useCallback(() => {
    try {
      const trimmed = text.trim();
      if (trimmed.length === 0) return;
      onSend(trimmed);
      setText('');
    } catch {
      // SDK must never crash the host app
    }
  }, [text, onSend]);

  const handleVoicePress = useCallback(() => {
    try {
      onVoicePress?.();
    } catch {
      // SDK must never crash the host app
    }
  }, [onVoicePress]);

  const handleCameraPress = useCallback(() => {
    try {
      onCameraPress?.();
    } catch {
      // SDK must never crash the host app
    }
  }, [onCameraPress]);

  const hasText = text.trim().length > 0;

  return (
    <View style={styles.container}>
      {imageEnabled && (
        <Pressable
          onPress={handleCameraPress}
          disabled={isDisabled}
          style={({ pressed }) => [
            styles.iconButton,
            pressed && styles.buttonPressed,
            isDisabled && styles.buttonDisabled,
          ]}
          accessibilityLabel="Take photo"
          accessibilityRole="button"
        >
          <Text style={styles.iconText}>{'📷'}</Text>
        </Pressable>
      )}

      <TextInput
        style={[styles.input, isDisabled && styles.inputDisabled]}
        value={text}
        onChangeText={setText}
        placeholder={placeholder}
        placeholderTextColor="#999"
        multiline
        maxLength={2000}
        editable={!isDisabled}
        returnKeyType={Platform.OS === 'ios' ? 'default' : 'send'}
        blurOnSubmit={false}
        accessibilityLabel="Message input"
      />

      {hasText ? (
        <Pressable
          onPress={handleSend}
          disabled={isDisabled}
          style={({ pressed }) => [
            styles.sendButton,
            pressed && styles.sendButtonPressed,
            isDisabled && styles.buttonDisabled,
          ]}
          accessibilityLabel="Send message"
          accessibilityRole="button"
        >
          <Text style={styles.sendButtonText}>{'↑'}</Text>
        </Pressable>
      ) : voiceEnabled ? (
        <Pressable
          onPress={handleVoicePress}
          disabled={isDisabled}
          style={({ pressed }) => [
            styles.iconButton,
            pressed && styles.buttonPressed,
            isDisabled && styles.buttonDisabled,
          ]}
          accessibilityLabel="Voice input"
          accessibilityRole="button"
        >
          <Text style={styles.iconText}>{'🎤'}</Text>
        </Pressable>
      ) : null}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: 8,
    paddingVertical: 6,
    borderTopWidth: 1,
    borderTopColor: '#E5E5E5',
    backgroundColor: '#FFFFFF',
  },
  input: {
    flex: 1,
    minHeight: 40,
    maxHeight: 120,
    paddingHorizontal: 12,
    paddingVertical: 8,
    marginHorizontal: 6,
    borderRadius: 20,
    backgroundColor: '#F5F5F5',
    fontSize: 16,
    color: '#1A1A1A',
  },
  inputDisabled: {
    opacity: 0.5,
  },
  iconButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconText: {
    fontSize: 20,
  },
  sendButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#1B6B3A',
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendButtonText: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '700',
  },
  sendButtonPressed: {
    backgroundColor: '#155A2F',
  },
  buttonPressed: {
    opacity: 0.6,
  },
  buttonDisabled: {
    opacity: 0.4,
  },
});
