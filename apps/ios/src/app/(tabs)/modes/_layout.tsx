import { Stack } from "expo-router";

import { AppHeaderBackButton } from "@/components/app/app-header-back-button";
import { ModeEditorProvider } from "@/features/modes/mode-editor-state";

export default function ModesLayout() {
  return (
    <ModeEditorProvider>
      <Stack screenOptions={{ headerBackButtonDisplayMode: "minimal" }}>
        <Stack.Screen name="index" options={{ title: "Modes" }} />
        <Stack.Screen
          name="new"
          options={{
            headerLeft: () => <AppHeaderBackButton label="Back to Modes" />,
            title: "Mode",
          }}
        />
        <Stack.Screen
          name="[modeId]"
          options={{
            headerLeft: () => <AppHeaderBackButton label="Back to Modes" />,
            title: "Mode",
          }}
        />
        <Stack.Screen
          name="sheets/icon-picker"
          options={{
            headerLeft: () => <AppHeaderBackButton label="Back to Mode" />,
            presentation: "formSheet",
            sheetAllowedDetents: [0.46],
            sheetGrabberVisible: true,
            title: "Choose Icon",
          }}
        />
        <Stack.Screen
          name="sheets/preset-picker"
          options={{
            headerLeft: () => <AppHeaderBackButton label="Back to Mode" />,
            presentation: "formSheet",
            sheetAllowedDetents: [0.72],
            sheetGrabberVisible: true,
            title: "Choose Preset",
          }}
        />
        <Stack.Screen
          name="sheets/model-picker"
          options={{
            headerLeft: () => <AppHeaderBackButton label="Back to Mode" />,
            presentation: "formSheet",
            sheetAllowedDetents: [0.55],
            sheetGrabberVisible: true,
            title: "Transcription Model",
          }}
        />
        <Stack.Screen
          name="sheets/language-picker"
          options={{
            headerLeft: () => <AppHeaderBackButton label="Back to Mode" />,
            presentation: "formSheet",
            sheetAllowedDetents: [0.75, 0.95],
            sheetGrabberVisible: true,
            title: "Language",
          }}
        />
        <Stack.Screen
          name="sheets/language-model-picker"
          options={{
            headerLeft: () => <AppHeaderBackButton label="Back to Mode" />,
            presentation: "formSheet",
            sheetAllowedDetents: [0.8, 0.95],
            sheetGrabberVisible: true,
            title: "Language Model",
          }}
        />
      </Stack>
    </ModeEditorProvider>
  );
}
