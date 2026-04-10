import { StyleSheet, View } from "react-native";
import { FarmerChatView } from "@digitalgreenorg/farmerchat-react-native";

/**
 * Chat route — renders the full FarmerChat UI.
 *
 * [FarmerChatView] internally manages:
 *   - First-time language-selection (Onboarding screen)
 *   - Chat screen (main conversation)
 *   - History screen (past conversations)
 *   - Profile screen (settings / language change)
 *
 * Navigation between screens is handled automatically via the shared
 * [ChatProvider] context — no expo-router push/pop needed inside the SDK.
 */
export default function ChatRoute() {
  return (
    <View style={styles.container}>
      <FarmerChatView />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#FFFFFF",
  },
});
