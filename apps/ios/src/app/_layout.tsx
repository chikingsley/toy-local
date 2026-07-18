import "@/global.css";

import { PortalHost } from "@rn-primitives/portal";
import { Stack, ThemeProvider } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useColorScheme } from "nativewind";

import { DictationSessionProvider } from "@/features/dictation/dictation-session";
import { LocalModelPackageProvider } from "@/features/dictation/local-model-package";
import { HistoryProvider } from "@/features/history/history-store";
import { ModeProvider } from "@/features/modes/mode-provider";
import { AppDatabaseProvider } from "@/lib/db/database";
import { NAV_THEME } from "@/lib/theme";

export { ErrorBoundary } from "expo-router";

export default function RootLayout() {
  const { colorScheme } = useColorScheme();
  return (
    <AppDatabaseProvider>
      <ModeProvider>
        <HistoryProvider>
          <LocalModelPackageProvider>
            <DictationSessionProvider>
              <ThemeProvider value={NAV_THEME[colorScheme ?? "light"]}>
                <StatusBar style={colorScheme === "dark" ? "light" : "dark"} />
                <Stack
                  screenOptions={{
                    headerBackButtonDisplayMode: "minimal",
                    headerTitleStyle: { fontWeight: "700" },
                  }}
                >
                  <Stack.Screen name="index" options={{ headerShown: false }} />
                  <Stack.Screen
                    name="(onboarding)"
                    options={{ animation: "none", headerShown: false }}
                  />
                  <Stack.Screen
                    name="(tabs)"
                    options={{ animation: "none", headerShown: false }}
                  />
                  <Stack.Screen
                    name="mode-picker"
                    options={{
                      presentation: "formSheet",
                      sheetAllowedDetents: [0.5, 0.85],
                      sheetGrabberVisible: true,
                      title: "Choose Mode",
                    }}
                  />
                </Stack>
                <PortalHost />
              </ThemeProvider>
            </DictationSessionProvider>
          </LocalModelPackageProvider>
        </HistoryProvider>
      </ModeProvider>
    </AppDatabaseProvider>
  );
}
