import { Stack } from "expo-router";

import { AppHeaderBackButton } from "@/components/app/app-header-back-button";

export default function SettingsLayout() {
  return (
    <Stack screenOptions={{ headerBackButtonDisplayMode: "minimal" }}>
      <Stack.Screen name="index" options={{ title: "Settings" }} />
      <Stack.Screen
        name="personal-vocabulary"
        options={{
          headerLeft: () => <AppHeaderBackButton label="Back to Settings" />,
          title: "Personal Vocabulary",
        }}
      />
      <Stack.Screen
        name="personal-vocabulary-add"
        options={{
          headerLeft: () => (
            <AppHeaderBackButton label="Back to Personal Vocabulary" />
          ),
          presentation: "formSheet",
          sheetAllowedDetents: [0.46],
          sheetGrabberVisible: true,
          title: "Add Vocabulary",
        }}
      />
    </Stack>
  );
}
