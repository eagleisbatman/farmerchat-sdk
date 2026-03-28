import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

interface ConnectivityBannerProps {
  isConnected: boolean;
}

export function ConnectivityBanner({ isConnected }: ConnectivityBannerProps) {
  if (isConnected) {
    return null;
  }

  return (
    <View style={styles.container} accessibilityRole="alert">
      <Text style={styles.icon}>{'⚠'}</Text>
      <Text style={styles.text}>You are offline. Check your connection.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FFF3CD',
    paddingVertical: 8,
    paddingHorizontal: 12,
  },
  icon: {
    fontSize: 14,
    marginRight: 6,
    color: '#856404',
  },
  text: {
    fontSize: 13,
    color: '#856404',
    fontWeight: '500',
  },
});
