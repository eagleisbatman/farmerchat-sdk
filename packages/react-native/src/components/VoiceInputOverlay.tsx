import React, {
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react';
import {
  ActivityIndicator,
  Animated,
  Modal,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

const PRIMARY_GREEN = '#2E7D32';
const RED = '#D32F2F';

type RecordingState = 'idle' | 'recording' | 'processing';

interface Props {
  visible: boolean;
  onConfirm: (audioUri: string, base64: string) => void;
  onCancel: () => void;
}

/**
 * Full-screen voice recording overlay.
 * Uses expo-av for audio recording; gracefully degrades if not available.
 */
export function VoiceInputOverlay({ visible, onConfirm, onCancel }: Props) {
  const [recordingState, setRecordingState] = useState<RecordingState>('idle');
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const recordingRef = useRef<unknown>(null); // expo-av Recording instance
  const fadeAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (visible) {
      Animated.timing(fadeAnim, { toValue: 1, duration: 200, useNativeDriver: true }).start();
      startRecording();
    } else {
      fadeAnim.setValue(0);
      setRecordingState('idle');
      setElapsedSeconds(0);
    }
  }, [visible]);

  const clearTimer = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const startRecording = useCallback(async () => {
    try {
      const { Audio } = await import('expo-av');
      await Audio.requestPermissionsAsync();
      await Audio.setAudioModeAsync({ allowsRecordingIOS: true, playsInSilentModeIOS: true });
      const { recording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY,
      );
      recordingRef.current = recording;
      setRecordingState('recording');
      timerRef.current = setInterval(() => setElapsedSeconds((s) => s + 1), 1000);
    } catch {
      setRecordingState('idle');
    }
  }, []);

  const handleConfirm = useCallback(async () => {
    clearTimer();
    setRecordingState('processing');
    try {
      const { Audio, FileSystem } = await Promise.all([
        import('expo-av'),
        import('expo-file-system'),
      ]).then(([av, fs]) => ({ Audio: av.Audio, FileSystem: fs.default }));

      const recording = recordingRef.current as InstanceType<typeof Audio.Recording>;
      await recording.stopAndUnloadAsync();
      await Audio.setAudioModeAsync({ allowsRecordingIOS: false });
      const uri = recording.getURI();
      if (!uri) { onCancel(); return; }
      const base64 = await FileSystem.readAsStringAsync(uri, { encoding: 'base64' });
      recordingRef.current = null;
      setRecordingState('idle');
      onConfirm(uri, base64);
    } catch {
      setRecordingState('idle');
      onCancel();
    }
  }, [clearTimer, onCancel, onConfirm]);

  const handleCancel = useCallback(async () => {
    clearTimer();
    try {
      if (recordingRef.current) {
        const { Audio } = await import('expo-av');
        const rec = recordingRef.current as InstanceType<typeof Audio.Recording>;
        await rec.stopAndUnloadAsync();
        await Audio.setAudioModeAsync({ allowsRecordingIOS: false });
        recordingRef.current = null;
      }
    } catch {}
    setRecordingState('idle');
    onCancel();
  }, [clearTimer, onCancel]);

  const formatTime = (s: number) => {
    const m = Math.floor(s / 60).toString().padStart(2, '0');
    const sec = (s % 60).toString().padStart(2, '0');
    return `${m}:${sec}`;
  };

  if (!visible) return null;

  return (
    <Modal transparent animationType="fade" visible={visible} onRequestClose={handleCancel}>
      <Animated.View style={[styles.backdrop, { opacity: fadeAnim }]}>
        <View style={styles.container}>
          <Text style={styles.title}>Voice Input</Text>
          <Text style={styles.subtitle}>Speak your question clearly</Text>

          <View style={styles.waveformRow}>
            {Array.from({ length: 9 }).map((_, i) => (
              <View key={i} style={[styles.bar, recordingState === 'recording' && styles.barActive]} />
            ))}
          </View>

          {recordingState === 'recording' && (
            <Text style={styles.timer}>{formatTime(elapsedSeconds)}</Text>
          )}

          {recordingState === 'processing' ? (
            <ActivityIndicator size="large" color={PRIMARY_GREEN} style={{ marginTop: 16 }} />
          ) : (
            <View style={styles.buttonRow}>
              <TouchableOpacity style={[styles.circleBtn, styles.cancelBtn]} onPress={handleCancel}>
                <Text style={styles.btnIcon}>✕</Text>
              </TouchableOpacity>
              <TouchableOpacity style={[styles.circleBtn, styles.confirmBtn]} onPress={handleConfirm}
                disabled={recordingState !== 'recording'}>
                <Text style={styles.btnIcon}>✓</Text>
              </TouchableOpacity>
            </View>
          )}
        </View>
      </Animated.View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.85)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  container: {
    width: '85%',
    backgroundColor: '#1A2318',
    borderRadius: 20,
    padding: 32,
    alignItems: 'center',
    gap: 16,
  },
  title: { fontSize: 20, fontWeight: '700', color: '#E8F5E9' },
  subtitle: { fontSize: 14, color: '#8FA88C', textAlign: 'center' },
  waveformRow: { flexDirection: 'row', alignItems: 'center', gap: 4, height: 48 },
  bar: { width: 5, height: 12, backgroundColor: '#4CAF50', borderRadius: 3, opacity: 0.4 },
  barActive: { height: 36, opacity: 1 },
  timer: { fontSize: 32, fontWeight: '600', color: '#E8F5E9', fontVariant: ['tabular-nums'] },
  buttonRow: { flexDirection: 'row', gap: 32, marginTop: 8 },
  circleBtn: {
    width: 64,
    height: 64,
    borderRadius: 32,
    justifyContent: 'center',
    alignItems: 'center',
  },
  cancelBtn: { backgroundColor: RED },
  confirmBtn: { backgroundColor: PRIMARY_GREEN },
  btnIcon: { fontSize: 24, color: '#FFFFFF', fontWeight: '700' },
});
