import React, { useEffect, useCallback } from 'react';
import {
  View,
  Text,
  Pressable,
  ScrollView,
  ActivityIndicator,
  StyleSheet,
  Platform,
} from 'react-native';
import { useChatContext as useChat } from '../ChatProvider';
import { useFarmerChatConfig } from '../FarmerChat';

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface TopBarProps {
  onBack: () => void;
  primaryColor: string;
}

function TopBar({ onBack, primaryColor }: TopBarProps) {
  return (
    <View style={[styles.topBar, { backgroundColor: primaryColor }]}>
      <Pressable
        style={styles.backButton}
        onPress={onBack}
        accessibilityLabel="Go back"
        accessibilityRole="button"
      >
        <Text style={styles.backArrow}>{'\u2190'}</Text>
      </Pressable>
      <Text style={styles.topBarTitle}>Profile</Text>
      <View style={styles.topBarSpacer} />
    </View>
  );
}

interface LanguageOptionProps {
  code: string;
  name: string;
  nativeName: string;
  isSelected: boolean;
  primaryColor: string;
  secondaryColor: string;
  onSelect: () => void;
}

function LanguageOption({
  code,
  name,
  nativeName,
  isSelected,
  primaryColor,
  secondaryColor,
  onSelect,
}: LanguageOptionProps) {
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
      <View style={styles.languageInfo}>
        <Text
          style={[styles.languageNative, isSelected && { color: primaryColor }]}
        >
          {nativeName}
        </Text>
        <Text style={styles.languageName}>{name}</Text>
      </View>
      <Text style={styles.languageCode}>{code.toUpperCase()}</Text>
      {isSelected && (
        <View style={[styles.checkmark, { backgroundColor: primaryColor }]}>
          <Text style={styles.checkmarkText}>{'\u2713'}</Text>
        </View>
      )}
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// ProfileScreen
// ---------------------------------------------------------------------------

export function ProfileScreen() {
  const config = useFarmerChatConfig();
  const {
    selectedLanguage,
    availableLanguages,
    loadLanguages,
    setLanguage,
    navigateTo,
  } = useChat();

  const primaryColor = config.theme?.primaryColor ?? '#1B6B3A';
  const secondaryColor = config.theme?.secondaryColor ?? '#F0F7F2';
  const showPoweredBy = config.showPoweredBy !== false;

  const [languagesLoading, setLanguagesLoading] = React.useState(false);

  useEffect(() => {
    const fetchLanguages = async () => {
      try {
        setLanguagesLoading(true);
        await loadLanguages();
      } catch {
        // Fall back to bundled list
      } finally {
        setLanguagesLoading(false);
      }
    };
    fetchLanguages();
  }, [loadLanguages]);

  const handleBack = useCallback(() => {
    try {
      navigateTo('chat');
    } catch {
      // Navigation failure is non-critical
    }
  }, [navigateTo]);

  const handleLanguageSelect = useCallback(
    (code: string) => {
      try {
        setLanguage(code);
        navigateTo('chat');
      } catch {
        // Language change failure is non-critical
      }
    },
    [setLanguage, navigateTo],
  );

  return (
    <View style={styles.container}>
      <TopBar onBack={handleBack} primaryColor={primaryColor} />

      <ScrollView
        style={styles.body}
        contentContainerStyle={styles.bodyContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Language section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Language</Text>
          <Text style={styles.sectionSubtitle}>
            Choose the language for your conversations
          </Text>

          {languagesLoading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator color={primaryColor} size="small" />
            </View>
          ) : (
            <View style={styles.languageList}>
              {availableLanguages.map((lang) => (
                <LanguageOption
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
            </View>
          )}
        </View>
      </ScrollView>

      {/* Footer */}
      <View style={styles.footer}>
        {showPoweredBy && (
          <Text style={styles.poweredBy}>Powered by FarmerChat</Text>
        )}
        <Text style={styles.version}>v0.0.0</Text>
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
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    paddingTop: Platform.OS === 'ios' ? 48 : 12,
  },
  backButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  backArrow: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '600',
  },
  topBarTitle: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
  },
  topBarSpacer: {
    width: 36,
  },
  body: {
    flex: 1,
  },
  bodyContent: {
    paddingBottom: 24,
  },
  section: {
    paddingHorizontal: 16,
    paddingTop: 24,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333333',
    marginBottom: 4,
  },
  sectionSubtitle: {
    fontSize: 13,
    color: '#666666',
    marginBottom: 16,
  },
  loadingContainer: {
    paddingVertical: 24,
    alignItems: 'center',
  },
  languageList: {
    gap: 10,
  },
  languageCard: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 2,
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  languageInfo: {
    flex: 1,
  },
  languageNative: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333333',
  },
  languageName: {
    fontSize: 13,
    color: '#666666',
    marginTop: 2,
  },
  languageCode: {
    fontSize: 12,
    fontWeight: '600',
    color: '#999999',
    marginRight: 8,
  },
  checkmark: {
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkmarkText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '700',
  },
  footer: {
    alignItems: 'center',
    paddingVertical: 16,
    paddingBottom: Platform.OS === 'ios' ? 32 : 16,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#E5E5E5',
  },
  poweredBy: {
    fontSize: 12,
    color: '#999999',
    marginBottom: 4,
  },
  version: {
    fontSize: 11,
    color: '#CCCCCC',
  },
});
