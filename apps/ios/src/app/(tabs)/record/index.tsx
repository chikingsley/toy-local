import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { Pressable, ScrollView, View } from "react-native";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { AppScreen } from "@/components/app/app-screen";
import { RecordingControl } from "@/components/app/recording-control";
import { Button } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import { useDictationSession } from "@/features/dictation/dictation-session";
import { useModes } from "@/features/modes/mode-provider";

export default function RecordScreen() {
  const router = useRouter();
  const session = useDictationSession();
  const { activeMode } = useModes();
  const text = session.partialTranscript;
  const chooseMode = session.errorCode === "unsupported_model";

  return (
    <View className="bg-background flex-1">
      <AppScreen className="px-5" edges={["top", "left", "right"]}>
        <Pressable
          accessibilityLabel="Choose active mode"
          className="bg-card border-border mt-[18px] h-[50px] flex-row items-center gap-2.5 self-center rounded-full border px-[18px]"
          onPress={() => router.push("/mode-picker")}
        >
          <SymbolView
            name={(activeMode?.iconKey ?? "person.wave.2.fill") as never}
            size={24}
            tintColor="#ffffff"
          />
          <Text className="text-xl font-semibold">
            {activeMode?.name ?? "Voice to Text"}
          </Text>
          <SymbolView name="chevron.right" size={14} tintColor="#707785" />
        </Pressable>

        {session.stage === "error" ? (
          <View className="flex-1 items-center justify-center gap-4 px-3.5">
            <Text className="text-destructive text-sm font-bold">
              Needs attention
            </Text>
            <View className="max-w-[320px] items-center gap-3">
              <Text className="text-muted-foreground text-center text-sm leading-5">
                {session.error}
              </Text>
              <Button
                onPress={
                  chooseMode
                    ? () => router.push("/mode-picker")
                    : () => void session.recover()
                }
                size="sm"
                variant="outline"
              >
                <Text>
                  {chooseMode
                    ? "Choose Mode"
                    : (session.recoveryLabel ?? "Retry")}
                </Text>
              </Button>
            </View>
          </View>
        ) : (
          <ScrollView
            className="flex-1"
            contentContainerClassName="px-3.5 pt-10 pb-10"
          >
            {text ? (
              <Text className="text-left text-[22px] leading-[31px]">
                {text}
              </Text>
            ) : null}
          </ScrollView>
        )}
      </AppScreen>

      <AppBottomActionBar>
        <RecordingControl
          disabled={
            session.errorCode === "persistence_failure" ||
            session.errorCode === "delivery_failure"
          }
          onPress={
            session.stage === "connecting" || session.stage === "listening"
              ? session.stopDictation
              : session.startDictation
          }
          stage={session.stage}
        />
      </AppBottomActionBar>
    </View>
  );
}
