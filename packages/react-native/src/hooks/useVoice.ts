import { useState, useCallback } from 'react';

interface UseVoiceReturn {
  /** Whether the microphone is actively recording */
  isListening: boolean;
  /** Accumulated transcript from the current or last recording session */
  transcript: string;
  /** Error message if STT is unavailable or failed */
  error: string | null;
  /** Begin speech-to-text recording */
  startListening: () => Promise<void>;
  /** Stop recording */
  stopListening: () => void;
  /** Clear the transcript and any errors */
  resetTranscript: () => void;
}

/**
 * Voice input (speech-to-text) hook.
 *
 * This is a well-typed stub. Actual STT requires a native module
 * (expo-speech-recognition, react-native-voice, or a custom Expo module).
 * Host apps should wire their STT provider into the FarmerChat SDK via
 * the onVoiceInput callback. See the integration docs for details.
 */
export function useVoice(): UseVoiceReturn {
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);

  const startListening = useCallback(async () => {
    // STT requires a native module integration (expo-speech-recognition or similar).
    // This stub provides the typed interface for host apps to implement.
    setError('Speech-to-text requires a native module. See docs for integration guide.');
  }, []);

  const stopListening = useCallback(() => {
    setIsListening(false);
  }, []);

  const resetTranscript = useCallback(() => {
    setTranscript('');
    setError(null);
  }, []);

  return {
    isListening,
    transcript,
    error,
    startListening,
    stopListening,
    resetTranscript,
  };
}
