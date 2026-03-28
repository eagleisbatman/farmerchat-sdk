import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  Pressable,
  ScrollView,
  ActivityIndicator,
  StyleSheet,
  Platform,
} from 'react-native';
import { useChat } from '../hooks/useChat';
import { useFarmerChatConfig } from '../FarmerChat';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface LocationData {
  lat: number;
  lng: number;
}

type OnboardingStep = 'location' | 'language';

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface LanguageCardProps {
  code: string;
  name: string;
  nativeName: string;
  isSelected: boolean;
  primaryColor: string;
  secondaryColor: string;
  onSelect: () => void;
}

function LanguageCard({
  code,
  name,
  nativeName,
  isSelected,
  primaryColor,
  secondaryColor,
  onSelect,
}: LanguageCardProps) {
  return (
    <Pressable
      style={[
        styles.languageCard,
        {
          borderColor: isSelected ? primaryColor : '#E0E0E0',
          backgroundColor: isSelected ? secondaryColor : '#FFFFFF',
        },
      ]}
      onPress={onSelect}
      accessibilityRole="button"
      accessibilityState={{ selected: isSelected }}
    >
      <Text style={[styles.languageNative, isSelected && { color: primaryColor }]}>
        {nativeName}
      </Text>
      <Text style={styles.languageName}>{name}</Text>
      <Text style={styles.languageCode}>{code.toUpperCase()}</Text>
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// OnboardingScreen
// ---------------------------------------------------------------------------

export function OnboardingScreen() {
  const config = useFarmerChatConfig();
  const {
    selectedLanguage,
    availableLanguages,
    loadLanguages,
    setLanguage,
    completeOnboarding,
  } = useChat();

  const primaryColor = config.theme?.primaryColor ?? '#1B6B3A';
  const secondaryColor = config.theme?.secondaryColor ?? '#F0F7F2';

  const [step, setStep] = useState<OnboardingStep>('location');
  const [location, setLocation] = useState<LocationData | null>(null);
  const [locationLoading, setLocationLoading] = useState(false);
  const [locationError, setLocationError] = useState<string | null>(null);
  const [languagesLoading, setLanguagesLoading] = useState(false);

  // Fetch available languages when entering the language step
  useEffect(() => {
    if (step === 'language') {
      const fetchLanguages = async () => {
        try {
          setLanguagesLoading(true);
          await loadLanguages();
        } catch {
          // Languages will fall back to bundled list
        } finally {
          setLanguagesLoading(false);
        }
      };
      fetchLanguages();
    }
  }, [step, loadLanguages]);

  const handleShareLocation = useCallback(async () => {
    try {
      setLocationLoading(true);
      setLocationError(null);

      // Attempt geolocation via the global navigator (polyfilled in React Native).
      // We use a dynamic check since types may not include navigator.geolocation.
      const geo = (globalThis as Record<string, unknown>).navigator as
        | { geolocation?: { getCurrentPosition: (s: (p: { coords: { latitude: number; longitude: number } }) => void, e: (err: unknown) => void, o: object) => void } }
        | undefined;

      if (!geo?.geolocation) {
        setLocationError('Location services are not available. You can skip this step.');
        return;
      }

      const position = await new Promise<{ coords: { latitude: number; longitude: number } }>(
        (resolve, reject) => {
          geo.geolocation!.getCurrentPosition(resolve, reject, {
            enableHighAccuracy: false,
            timeout: 10000,
            maximumAge: 300000,
          });
        },
      );

      setLocation({
        lat: position.coords.latitude,
        lng: position.coords.longitude,
      });
      setStep('language');
    } catch {
      setLocationError('Could not get your location. You can skip this step.');
    } finally {
      setLocationLoading(false);
    }
  }, []);

  const handleSkipLocation = useCallback(() => {
    try {
      setLocation({ lat: 0, lng: 0 });
      setStep('language');
    } catch {
      // Navigation is non-critical
    }
  }, []);

  const handleLanguageSelect = useCallback(
    (code: string) => {
      try {
        setLanguage(code);
      } catch {
        // Language selection failure is non-critical
      }
    },
    [setLanguage],
  );

  const handleComplete = useCallback(async () => {
    try {
      const loc = location ?? { lat: 0, lng: 0 };
      await completeOnboarding(loc, selectedLanguage);
    } catch {
      // Error is managed by the hook
    }
  }, [location, selectedLanguage, completeOnboarding]);

  // ---------------------------------------------------------------------------
  // Location step
  // ---------------------------------------------------------------------------

  if (step === 'location') {
    return (
      <View style={styles.container}>
        <View style={[styles.header, { backgroundColor: primaryColor }]}>
          <Text style={styles.headerTitle}>Welcome to FarmerChat</Text>
        </View>

        <View style={styles.stepContent}>
          <Text style={styles.stepIcon}>{'\u{1F4CD}'}</Text>
          <Text style={styles.stepTitle}>Share Your Location</Text>
          <Text style={styles.stepDescription}>
            Your location helps us provide region-specific agricultural advice,
            including local weather and crop recommendations.
          </Text>

          {locationError && (
            <Text style={styles.locationError}>{locationError}</Text>
          )}

          <Pressable
            style={[styles.primaryButton, { backgroundColor: primaryColor }]}
            onPress={handleShareLocation}
            disabled={locationLoading}
            accessibilityRole="button"
          >
            {locationLoading ? (
              <ActivityIndicator color="#FFFFFF" size="small" />
            ) : (
              <Text style={styles.primaryButtonText}>Share Location</Text>
            )}
          </Pressable>

          <Pressable
            style={styles.secondaryButton}
            onPress={handleSkipLocation}
            accessibilityRole="button"
          >
            <Text style={[styles.secondaryButtonText, { color: primaryColor }]}>
              Skip for now
            </Text>
          </Pressable>
        </View>
      </View>
    );
  }

  // ---------------------------------------------------------------------------
  // Language step
  // ---------------------------------------------------------------------------

  return (
    <View style={styles.container}>
      <View style={[styles.header, { backgroundColor: primaryColor }]}>
        <Text style={styles.headerTitle}>Choose Your Language</Text>
      </View>

      <View style={styles.languageBody}>
        {languagesLoading ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator color={primaryColor} size="large" />
            <Text style={styles.loadingText}>Loading languages...</Text>
          </View>
        ) : (
          <ScrollView
            contentContainerStyle={styles.languageList}
            showsVerticalScrollIndicator={false}
          >
            {availableLanguages.map((lang) => (
              <LanguageCard
                key={lang.code}
                code={lang.code}
                name={lang.name}
                nativeName={lang.nativeName}
                isSelected={selectedLanguage === lang.code}
                primaryColor={primaryColor}
                secondaryColor={secondaryColor}
                onSelect={() => handleLanguageSelect(lang.code)}
              />
            ))}
          </ScrollView>
        )}
      </View>

      <View style={styles.footer}>
        <Pressable
          style={[
            styles.primaryButton,
            { backgroundColor: primaryColor },
            !selectedLanguage && styles.disabledButton,
          ]}
          onPress={handleComplete}
          disabled={!selectedLanguage}
          accessibilityRole="button"
        >
          <Text style={styles.primaryButtonText}>Get Started</Text>
        </Pressable>
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  header: {
    paddingHorizontal: 24,
    paddingVertical: 20,
    paddingTop: Platform.OS === 'ios' ? 56 : 20,
    alignItems: 'center',
  },
  headerTitle: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: '700',
  },
  stepContent: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 32,
  },
  stepIcon: {
    fontSize: 48,
    marginBottom: 16,
  },
  stepTitle: {
    fontSize: 22,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 12,
    textAlign: 'center',
  },
  stepDescription: {
    fontSize: 15,
    color: '#666666',
    lineHeight: 22,
    textAlign: 'center',
    marginBottom: 32,
  },
  locationError: {
    fontSize: 13,
    color: '#B91C1C',
    textAlign: 'center',
    marginBottom: 16,
  },
  primaryButton: {
    width: '100%',
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 48,
  },
  primaryButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  secondaryButton: {
    marginTop: 16,
    paddingVertical: 10,
  },
  secondaryButtonText: {
    fontSize: 15,
    fontWeight: '500',
  },
  disabledButton: {
    opacity: 0.5,
  },
  languageBody: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 14,
    color: '#666666',
    marginTop: 12,
  },
  languageList: {
    paddingHorizontal: 16,
    paddingVertical: 16,
    gap: 10,
  },
  languageCard: {
    borderWidth: 2,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  languageNative: {
    fontSize: 17,
    fontWeight: '600',
    color: '#333333',
    flex: 1,
  },
  languageName: {
    fontSize: 14,
    color: '#666666',
    marginHorizontal: 8,
  },
  languageCode: {
    fontSize: 12,
    fontWeight: '600',
    color: '#999999',
    width: 32,
    textAlign: 'right',
  },
  footer: {
    paddingHorizontal: 24,
    paddingVertical: 16,
    paddingBottom: Platform.OS === 'ios' ? 32 : 16,
  },
});
