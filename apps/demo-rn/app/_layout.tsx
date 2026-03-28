import { Stack } from "expo-router";
import { FarmerChat } from "@digitalgreenorg/farmerchat-react-native";

// API key from environment (EXPO_PUBLIC_ prefix exposes it to the client bundle)
const API_KEY = process.env.EXPO_PUBLIC_FC_API_KEY ?? "demo-key";

export default function RootLayout() {
  return (
    <FarmerChat
      config={{
        apiKey: API_KEY,
        theme: { primaryColor: "#1B6B3A", secondaryColor: "#F0F7F2" },
        headerTitle: "FarmerChat Demo",
      }}
    >
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: "#1B6B3A" },
          headerTintColor: "#FFFFFF",
          headerTitleStyle: { fontWeight: "600" },
          contentStyle: { backgroundColor: "#FFFFFF" },
        }}
      >
        <Stack.Screen
          name="index"
          options={{ title: "FarmerChat Demo" }}
        />
        <Stack.Screen
          name="chat"
          options={{ title: "Chat", headerShown: false }}
        />
        <Stack.Screen
          name="onboarding"
          options={{ title: "Get Started", headerShown: false }}
        />
      </Stack>
    </FarmerChat>
  );
}
