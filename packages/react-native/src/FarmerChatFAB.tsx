import React, { useEffect, useRef } from 'react';
import { Animated, Pressable, Text, StyleSheet, Easing } from 'react-native';

interface FarmerChatFABProps {
  onPress?: () => void;
}

/**
 * Floating Action Button — light theme.
 *
 * Spec (from UI guide):
 *  - 56px circle, bg #2E7D32 (PRIMARY_GREEN)
 *  - 💬 emoji, fontSize 24
 *  - Spring entrance: scale 0.8 → 1.0
 *  - Elevation 8, shadow color #000 offset(0,4) opacity 0.3 radius 4
 */
export function FarmerChatFAB({ onPress }: FarmerChatFABProps) {
  const scaleAnim = useRef(new Animated.Value(0.8)).current;

  useEffect(() => {
    Animated.spring(scaleAnim, {
      toValue: 1,
      friction: 5,
      tension: 40,
      useNativeDriver: true,
    }).start();
  }, [scaleAnim]);

  return (
    <Animated.View style={[styles.fabWrapper, { transform: [{ scale: scaleAnim }] }]}>
      <Pressable
        style={({ pressed }) => [styles.fab, pressed && styles.fabPressed]}
        onPress={onPress}
        accessibilityLabel="Open FarmerChat"
        accessibilityRole="button"
      >
        <Text style={styles.fabEmoji}>💬</Text>
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  fabWrapper: {
    position: 'absolute',
    bottom: 24,
    right: 24,
  },
  fab: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#2E7D32',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  fabPressed: { backgroundColor: '#1B5E20' },
  fabEmoji: { fontSize: 24 },
});
