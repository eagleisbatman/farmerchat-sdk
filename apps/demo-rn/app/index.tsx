import { ScrollView, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { FarmerChatFAB } from "@digitalgreenorg/farmerchat-react-native";

const FEATURES = [
  { icon: "\u{1F4AC}", title: "AI Chat", description: "Get instant agricultural advice from an AI assistant" },
  { icon: "\u{1F3A4}", title: "Voice Input", description: "Ask questions using voice in your local language" },
  { icon: "\u{1F4F7}", title: "Image Analysis", description: "Take a photo of your crop for diagnosis" },
  { icon: "\u{1F30D}", title: "Multilingual", description: "Available in 20+ regional languages" },
  { icon: "\u{1F4CD}", title: "Location-Aware", description: "Region-specific weather and crop recommendations" },
  { icon: "\u{1F4DC}", title: "Chat History", description: "Access your previous conversations anytime" },
];

export default function HomeScreen() {
  const router = useRouter();

  return (
    <View style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
      >
        {/* Hero Section */}
        <View style={styles.hero}>
          <Text style={styles.heroIcon}>{"\u{1F331}"}</Text>
          <Text style={styles.heroTitle}>FarmerChat Demo</Text>
          <Text style={styles.heroSubtitle}>
            An embeddable AI-powered agricultural advisory chat widget for
            mobile and web applications.
          </Text>
        </View>

        {/* SDK Info Card */}
        <View style={styles.infoCard}>
          <Text style={styles.infoTitle}>About this SDK</Text>
          <Text style={styles.infoText}>
            FarmerChat SDK provides a complete, drop-in chat experience for
            agricultural advisory. It handles onboarding, real-time streaming
            responses, voice input, and image-based crop diagnosis -- all in
            under 3 MB.
          </Text>
        </View>

        {/* Features Grid */}
        <Text style={styles.sectionTitle}>SDK Features</Text>
        <View style={styles.featuresGrid}>
          {FEATURES.map((feature) => (
            <View key={feature.title} style={styles.featureCard}>
              <Text style={styles.featureIcon}>{feature.icon}</Text>
              <Text style={styles.featureTitle}>{feature.title}</Text>
              <Text style={styles.featureDescription}>
                {feature.description}
              </Text>
            </View>
          ))}
        </View>

        {/* Integration Example */}
        <View style={styles.integrationCard}>
          <Text style={styles.integrationTitle}>Quick Integration</Text>
          <View style={styles.codeBlock}>
            <Text style={styles.codeText}>
              {"<FarmerChat config={config}>\n"}
              {"  <YourApp />\n"}
              {"  <FarmerChatFAB />\n"}
              {"</FarmerChat>"}
            </Text>
          </View>
          <Text style={styles.integrationNote}>
            Wrap your app with the FarmerChat provider and add the FAB.
            That's it.
          </Text>
        </View>

        {/* Bottom spacer for FAB clearance */}
        <View style={styles.fabSpacer} />
      </ScrollView>

      {/* Floating Action Button */}
      <FarmerChatFAB onPress={() => router.push("/chat")} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#FFFFFF",
  },
  scrollContent: {
    paddingHorizontal: 20,
    paddingTop: 16,
    paddingBottom: 24,
  },

  // Hero
  hero: {
    alignItems: "center",
    paddingVertical: 32,
  },
  heroIcon: {
    fontSize: 56,
    marginBottom: 12,
  },
  heroTitle: {
    fontSize: 28,
    fontWeight: "800",
    color: "#1B6B3A",
    marginBottom: 8,
  },
  heroSubtitle: {
    fontSize: 15,
    color: "#666666",
    textAlign: "center",
    lineHeight: 22,
    maxWidth: 320,
  },

  // Info Card
  infoCard: {
    backgroundColor: "#F0F7F2",
    borderRadius: 12,
    padding: 20,
    marginBottom: 28,
    borderLeftWidth: 4,
    borderLeftColor: "#1B6B3A",
  },
  infoTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: "#1B6B3A",
    marginBottom: 8,
  },
  infoText: {
    fontSize: 14,
    color: "#444444",
    lineHeight: 21,
  },

  // Section Title
  sectionTitle: {
    fontSize: 18,
    fontWeight: "700",
    color: "#333333",
    marginBottom: 14,
  },

  // Features Grid
  featuresGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12,
    marginBottom: 28,
  },
  featureCard: {
    width: "47%",
    backgroundColor: "#FAFAFA",
    borderRadius: 10,
    padding: 14,
    borderWidth: 1,
    borderColor: "#EEEEEE",
  },
  featureIcon: {
    fontSize: 28,
    marginBottom: 8,
  },
  featureTitle: {
    fontSize: 14,
    fontWeight: "600",
    color: "#333333",
    marginBottom: 4,
  },
  featureDescription: {
    fontSize: 12,
    color: "#777777",
    lineHeight: 17,
  },

  // Integration Card
  integrationCard: {
    backgroundColor: "#F8F8F8",
    borderRadius: 12,
    padding: 20,
    borderWidth: 1,
    borderColor: "#E0E0E0",
  },
  integrationTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: "#333333",
    marginBottom: 12,
  },
  codeBlock: {
    backgroundColor: "#1E1E1E",
    borderRadius: 8,
    padding: 16,
    marginBottom: 12,
  },
  codeText: {
    fontFamily: "monospace",
    fontSize: 13,
    color: "#D4D4D4",
    lineHeight: 20,
  },
  integrationNote: {
    fontSize: 13,
    color: "#666666",
    lineHeight: 19,
  },

  // FAB spacer
  fabSpacer: {
    height: 80,
  },
});
