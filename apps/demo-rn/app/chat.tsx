import { StyleSheet, View } from "react-native";
import { ChatScreen } from "@digitalgreenorg/farmerchat-react-native";

export default function ChatRoute() {
  return (
    <View style={styles.container}>
      <ChatScreen />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#FFFFFF",
  },
});
