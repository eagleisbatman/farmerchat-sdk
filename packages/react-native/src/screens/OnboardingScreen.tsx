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
import { useChatContext } from '../ChatProvider';
import { useFarmerChatConfig } from '../FarmerChat';
import type { SupportedLanguage } from '../models/responses';

// ---------------------------------------------------------------------------
// LanguageCard
// ---------------------------------------------------------------------------

interface LanguageCardProps {
  language: SupportedLanguage;
  isSelected: boolean;
  primaryColor: string;
  onSelect: () => void;
}

function LanguageCard({ language, isSelected, primaryColor, onSelect }: LanguageCardProps) {
  const displayName = language.display_name || language.name;
  const subName = language.name !== displayName ? language.name : null;

  return (
    <Pressable
      style={[
        styles.langCard,
        {
          borderColor:     isSelected ? primaryColor : '#E0E0E0',
          backgroundColor: isSelected ? primaryColor + '18' : '#FFFFFF',
        },
      ]}
      onPress={onSelect}
      accessibilityRole="button"
      accessibilityState={{ selected: isSelected }}
    >
      {/* Speaker icon placeholder */}
      <Text style={[styles.langIcon, { color: isSelected ? primaryColor : '#BDBDBD' }]}>🔊</Text>

      <View style={styles.langTextGroup}>
        <Text
          style={[styles.langPrimary, isSelected && { color: primaryColor }]}
          numberOfLines={1}
        >
          {displayName}
        </Text>
        {subName ? (
          <Text style={styles.langSub} numberOfLines={1}>{subName}</Text>
        ) : null}
      </View>

      {isSelected ? (
        <View style={[styles.checkCircle, { backgroundColor: primaryColor }]}>
          <Text style={styles.checkMark}>✓</Text>
        </View>
      ) : (
        <View style={styles.checkCirclePlaceholder} />
      )}
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// OnboardingScreen
// ---------------------------------------------------------------------------

export function OnboardingScreen() {
  const config = useFarmerChatConfig();
  const { selectedLanguage, setLanguage, navigateTo, availableLanguageGroups, loadLanguages } =
    useChatContext();

  const primaryColor = config.theme?.primaryColor ?? '#2E7D32';

  const [step, setStep] = useState<'location' | 'language'>('location');
  const [locationLoading, setLocationLoading] = useState(false);
  const [locationError, setLocationError] = useState<string | null>(null);
  const [languagesLoading, setLanguagesLoading] = useState(false);
  const [langLoadError, setLangLoadError] = useState(false);
  const [hasPickedLanguage, setHasPickedLanguage] = useState(false);

  const languages: SupportedLanguage[] = availableLanguageGroups.flatMap(g => g.languages);

  const fetchLanguages = useCallback(async () => {
    if (languages.length > 0) return;
    setLanguagesLoading(true);
    setLangLoadError(false);
    try {
      await loadLanguages();
    } catch {
      setLangLoadError(true);
    } finally {
      setLanguagesLoading(false);
    }
  }, [languages.length, loadLanguages]);

  // Pre-fetch languages immediately on mount so they are ready for step 2
  useEffect(() => {
    void fetchLanguages();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Retry if still empty when entering step 2
  useEffect(() => {
    if (step === 'language' && languages.length === 0) {
      void fetchLanguages();
    }
  }, [step, fetchLanguages, languages.length]);

  const handleShareLocation = useCallback(async () => {
    try {
      setLocationLoading(true);
      setLocationError(null);

      const geo = (globalThis as Record<string, unknown>).navigator as
        | { geolocation?: { getCurrentPosition: (s: (p: { coords: { latitude: number; longitude: number } }) => void, e: (err: unknown) => void, o: object) => void } }
        | undefined;

      if (!geo?.geolocation) {
        setLocationError('Location services unavailable. You can skip this step.');
        return;
      }

      await new Promise<void>((resolve, reject) => {
        geo.geolocation!.getCurrentPosition(
          () => resolve(),
          (err) => reject(err),
          { enableHighAccuracy: false, timeout: 10_000, maximumAge: 300_000 },
        );
      });

      setStep('language');
    } catch {
      setLocationError('Could not get your location. You can skip this step.');
    } finally {
      setLocationLoading(false);
    }
  }, []);

  const handleSkipLocation = useCallback(() => {
    setStep('language');
  }, []);

  const handleGetStarted = useCallback(() => {
    navigateTo('chat');
  }, [navigateTo]);

  // ---------------------------------------------------------------------------
  // Location step
  // ---------------------------------------------------------------------------

  if (step === 'location') {
    return (
      <View style={styles.container}>
        {/* Header */}
        <View style={[styles.header, { backgroundColor: primaryColor }]}>
          <Text style={styles.logoEmoji}>🌱</Text>
          <Text style={styles.headerTitle}>FarmChat AI</Text>
          <Text style={styles.headerSub}>Smart Farming Assistant</Text>
        </View>

        {/* Step dots */}
        <View style={styles.stepDots}>
          <View style={[styles.dot, styles.dotActive, { backgroundColor: primaryColor }]} />
          <View style={[styles.dot, styles.dotInactive]} />
        </View>

        {/* Content */}
        <View style={styles.stepContent}>
          <Text style={styles.stepIcon}>📍</Text>
          <Text style={styles.stepTitle}>Share Your Location</Text>
          <Text style={styles.stepDesc}>
            Your location helps us provide region-specific agricultural advice,
            including local weather and crop recommendations.
          </Text>

          {locationError ? (
            <Text style={styles.errorText}>{locationError}</Text>
          ) : null}

          <Pressable
            style={[styles.outlineBtn, { borderColor: primaryColor }]}
            onPress={handleShareLocation}
            disabled={locationLoading}
            accessibilityRole="button"
          >
            {locationLoading ? (
              <ActivityIndicator color={primaryColor} size="small" />
            ) : (
              <Text style={[styles.outlineBtnText, { color: primaryColor }]}>Share Location</Text>
            )}
          </Pressable>

          <Pressable style={styles.skipBtn} onPress={handleSkipLocation}>
            <Text style={styles.skipBtnText}>Skip for now</Text>
          </Pressable>
        </View>

        {/* Continue */}
        <View style={styles.footer}>
          <Pressable
            style={[styles.primaryBtn, { backgroundColor: primaryColor }]}
            onPress={handleSkipLocation}
          >
            <Text style={styles.primaryBtnText}>Continue</Text>
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
      {/* Header */}
      <View style={[styles.header, { backgroundColor: primaryColor }]}>
        <Text style={styles.logoEmoji}>🌱</Text>
        <Text style={styles.headerTitle}>FarmChat AI</Text>
        <Text style={styles.headerSub}>Smart Farming Assistant</Text>
      </View>

      {/* Step dots */}
      <View style={styles.stepDots}>
        <View style={[styles.dot, styles.dotInactive]} />
        <View style={[styles.dot, styles.dotActive, { backgroundColor: primaryColor }]} />
      </View>

      {/* Language label */}
      <Text style={[styles.langLabel, { color: primaryColor }]}>SELECT YOUR LANGUAGE</Text>

      {/* Language grid */}
      {langLoadError && languages.length === 0 ? (
        <View style={styles.loadingBox}>
          <Text style={styles.errorText}>Could not load languages.</Text>
          <Pressable
            onPress={() => void fetchLanguages()}
            style={[styles.retryBtn, { borderColor: primaryColor }]}
          >
            <Text style={[styles.retryBtnText, { color: primaryColor }]}>Retry</Text>
          </Pressable>
        </View>
      ) : languagesLoading || languages.length === 0 ? (
        <View style={styles.loadingBox}>
          <ActivityIndicator color={primaryColor} size="large" />
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={styles.langList}
          showsVerticalScrollIndicator={false}
        >
          {languages.map(lang => (
            <LanguageCard
              key={String(lang.id)}
              language={lang}
              isSelected={selectedLanguage === lang.code}
              primaryColor={primaryColor}
              onSelect={() => { setLanguage(lang.code); setHasPickedLanguage(true); }}
            />
          ))}
        </ScrollView>
      )}

      {/* Get Started */}
      <View style={styles.footer}>
        <Pressable
          style={[
            styles.primaryBtn,
            { backgroundColor: primaryColor },
            !hasPickedLanguage && styles.primaryBtnDisabled,
          ]}
          onPress={handleGetStarted}
          disabled={!hasPickedLanguage}
          accessibilityRole="button"
        >
          <Text style={styles.primaryBtnText}>Get Started</Text>
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

  // Header
  header: {
    alignItems: 'center',
    paddingTop: Platform.OS === 'ios' ? 56 : 24,
    paddingBottom: 24,
    gap: 4,
  },
  logoEmoji:   { fontSize: 40 },
  headerTitle: { color: '#FFFFFF', fontSize: 22, fontWeight: '700' },
  headerSub:   { color: 'rgba(255,255,255,0.7)', fontSize: 13 },

  // Step dots
  stepDots: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 6,
    paddingTop: 14,
    paddingBottom: 4,
  },
  dot: {
    height: 6,
    borderRadius: 3,
  },
  dotActive:   { width: 24 },
  dotInactive: { width: 16, backgroundColor: '#E0E0E0' },

  // Location step
  stepContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
    gap: 12,
  },
  stepIcon:  { fontSize: 48 },
  stepTitle: { fontSize: 20, fontWeight: '600', color: '#212121', textAlign: 'center' },
  stepDesc:  { fontSize: 14, color: '#757575', lineHeight: 21, textAlign: 'center' },
  errorText: { fontSize: 13, color: '#B91C1C', textAlign: 'center' },

  outlineBtn: {
    marginTop: 4,
    borderWidth: 1.5,
    borderRadius: 24,
    paddingVertical: 12,
    paddingHorizontal: 28,
    alignItems: 'center',
    minWidth: 180,
  },
  outlineBtnText: { fontSize: 15, fontWeight: '600' },

  skipBtn:     { paddingVertical: 8 },
  skipBtnText: { fontSize: 13, color: '#9E9E9E' },

  // Language step
  langLabel: {
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 1.8,
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 4,
  },
  loadingBox: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 12,
  },
  retryBtn: {
    borderWidth: 1.5,
    borderRadius: 20,
    paddingVertical: 8,
    paddingHorizontal: 24,
  },
  retryBtnText: { fontSize: 14, fontWeight: '600' },
  langList: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    gap: 8,
  },

  // Language card (row layout)
  langCard: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1.5,
    borderRadius: 14,
    paddingHorizontal: 14,
    paddingVertical: 12,
    gap: 10,
    marginBottom: 2,
  },
  langIcon: { fontSize: 16 },
  langTextGroup: { flex: 1 },
  langPrimary:   { fontSize: 14, fontWeight: '600', color: '#212121' },
  langSub:       { fontSize: 11, color: '#9E9E9E', marginTop: 1 },
  checkCircle: {
    width: 20, height: 20, borderRadius: 10,
    alignItems: 'center', justifyContent: 'center',
  },
  checkMark:          { color: '#FFFFFF', fontSize: 11, fontWeight: '700' },
  checkCirclePlaceholder: { width: 20, height: 20 },

  // Shared footer
  footer: {
    paddingHorizontal: 24,
    paddingVertical: 16,
    paddingBottom: Platform.OS === 'ios' ? 32 : 16,
  },
  primaryBtn: {
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
  },
  primaryBtnText:     { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  primaryBtnDisabled: { opacity: 0.35 },
});
