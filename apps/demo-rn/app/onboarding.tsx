import { StyleSheet, View } from "react-native";
import { OnboardingScreen } from "@digitalgreenorg/farmerchat-react-native";

export default function OnboardingRoute() {
  return (
    <View style={styles.container}>
      <OnboardingScreen />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#FFFFFF",
  },
});
