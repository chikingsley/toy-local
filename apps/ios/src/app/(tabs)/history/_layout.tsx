import { Stack } from "expo-router";

import { AppHeaderBackButton } from "@/components/app/app-header-back-button";

export default function HistoryLayout() {
  return (
    <Stack screenOptions={{ headerBackButtonDisplayMode: "minimal" }}>
      <Stack.Screen name="index" options={{ title: "History" }} />
      <Stack.Screen
        name="[id]"
        options={{
          headerLeft: () => <AppHeaderBackButton label="Back to History" />,
          title: "Dictation",
        }}
      />
      <Stack.Screen
        name="info"
        options={{
          headerLeft: () => <AppHeaderBackButton label="Back to Dictation" />,
          presentation: "formSheet",
          sheetAllowedDetents: [0.55, 0.85],
          sheetGrabberVisible: true,
          title: "Dictation Info",
        }}
      />
    </Stack>
  );
}
