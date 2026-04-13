import React, { useCallback, useState } from 'react';
import {
  ActivityIndicator,
  Modal,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

const PRIMARY_GREEN = '#2E7D32';

interface ImageResult {
  uri: string;
  base64?: string | null;
}

interface Props {
  visible: boolean;
  onImageSelected: (result: ImageResult) => void;
  onCancel: () => void;
}

/**
 * Bottom-sheet modal for choosing between camera and gallery.
 * Uses expo-image-picker (declared as peer dependency).
 */
export function PhotoInputSheet({ visible, onImageSelected, onCancel }: Props) {
  const [isLoading, setIsLoading] = useState(false);

  const pickImage = useCallback(async (source: 'camera' | 'gallery') => {
    setIsLoading(true);
    try {
      const ImagePicker = await import('expo-image-picker');
      let result;
      if (source === 'camera') {
        const perm = await ImagePicker.requestCameraPermissionsAsync();
        if (!perm.granted) { onCancel(); return; }
        result = await ImagePicker.launchCameraAsync({
          mediaTypes: ImagePicker.MediaType ? [ImagePicker.MediaType.Images] : ['images'],
          quality: 0.8,
          base64: true,
        });
      } else {
        const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
        if (!perm.granted) { onCancel(); return; }
        result = await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ImagePicker.MediaType ? [ImagePicker.MediaType.Images] : ['images'],
          quality: 0.8,
          base64: true,
        });
      }
      if (!result.canceled && result.assets?.[0]) {
        const asset = result.assets[0];
        onImageSelected({ uri: asset.uri, base64: asset.base64 });
      } else {
        onCancel();
      }
    } catch {
      onCancel();
    } finally {
      setIsLoading(false);
    }
  }, [onCancel, onImageSelected]);

  if (!visible) return null;

  return (
    <Modal transparent animationType="slide" visible={visible} onRequestClose={onCancel}>
      <TouchableOpacity style={styles.scrim} activeOpacity={1} onPress={onCancel}>
        <View style={styles.sheet}>
          <View style={styles.handle} />
          <Text style={styles.title}>Add Image</Text>
          <Text style={styles.subtitle}>Photograph your crop for analysis</Text>

          {isLoading ? (
            <ActivityIndicator size="large" color={PRIMARY_GREEN} style={{ marginVertical: 24 }} />
          ) : (
            <View style={styles.optionsCard}>
              <TouchableOpacity style={styles.optionRow} onPress={() => pickImage('camera')}>
                <View style={styles.optionIcon}>
                  <Text style={styles.optionEmoji}>📷</Text>
                </View>
                <View style={styles.optionText}>
                  <Text style={styles.optionTitle}>Take Photo</Text>
                  <Text style={styles.optionDesc}>Use your camera to capture the crop</Text>
                </View>
              </TouchableOpacity>

              <View style={styles.divider} />

              <TouchableOpacity style={styles.optionRow} onPress={() => pickImage('gallery')}>
                <View style={styles.optionIcon}>
                  <Text style={styles.optionEmoji}>🖼️</Text>
                </View>
                <View style={styles.optionText}>
                  <Text style={styles.optionTitle}>Choose from Gallery</Text>
                  <Text style={styles.optionDesc}>Select an existing photo</Text>
                </View>
              </TouchableOpacity>
            </View>
          )}

          <TouchableOpacity style={styles.cancelBtn} onPress={onCancel}>
            <Text style={styles.cancelText}>Cancel</Text>
          </TouchableOpacity>
        </View>
      </TouchableOpacity>
    </Modal>
  );
}

const styles = StyleSheet.create({
  scrim: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: '#1A2318',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 32,
    alignItems: 'center',
  },
  handle: { width: 40, height: 4, backgroundColor: '#8FA88C', borderRadius: 2, marginBottom: 20 },
  title: { fontSize: 18, fontWeight: '700', color: '#E8F5E9', marginBottom: 4 },
  subtitle: { fontSize: 13, color: '#8FA88C', marginBottom: 20 },
  optionsCard: {
    width: '100%',
    backgroundColor: '#172213',
    borderRadius: 14,
    overflow: 'hidden',
    marginBottom: 12,
  },
  optionRow: { flexDirection: 'row', alignItems: 'center', padding: 16, gap: 14 },
  optionIcon: {
    width: 48, height: 48,
    backgroundColor: 'rgba(46,125,50,0.15)',
    borderRadius: 12,
    justifyContent: 'center', alignItems: 'center',
  },
  optionEmoji: { fontSize: 22 },
  optionText: { flex: 1 },
  optionTitle: { fontSize: 15, fontWeight: '600', color: '#E8F5E9' },
  optionDesc: { fontSize: 12, color: '#8FA88C' },
  divider: { height: 1, backgroundColor: 'rgba(143,168,140,0.15)', marginLeft: 72 },
  cancelBtn: {
    width: '100%',
    paddingVertical: 14,
    alignItems: 'center',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(143,168,140,0.2)',
  },
  cancelText: { fontSize: 15, color: '#8FA88C' },
});
