import { Stack } from "expo-router";

export default function HistoryLayout() {
  return (
    <Stack screenOptions={{ headerBackButtonDisplayMode: "minimal" }}>
      <Stack.Screen name="index" options={{ title: "History" }} />
      <Stack.Screen name="[id]" options={{ title: "Dictation" }} />
      <Stack.Screen
        name="info"
        options={{
          presentation: "formSheet",
          sheetAllowedDetents: [0.55, 0.85],
          sheetGrabberVisible: true,
          title: "Dictation Info",
        }}
      />
    </Stack>
  );
}
