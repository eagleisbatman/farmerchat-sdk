import React from 'react';
import { Pressable, Text, StyleSheet } from 'react-native';

interface FarmerChatFABProps {
  onPress?: () => void;
}

/**
 * Floating Action Button for launching the FarmerChat widget.
 */
export function FarmerChatFAB({ onPress }: FarmerChatFABProps) {
  return (
    <Pressable style={styles.fab} onPress={onPress}>
      <Text style={styles.label}>FC</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  fab: {
    position: 'absolute',
    bottom: 24,
    right: 24,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#1B6B3A',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  label: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 16,
  },
});
