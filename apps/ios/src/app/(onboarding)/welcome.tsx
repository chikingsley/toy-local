import { requestRecordingPermissionsAsync } from "expo-audio";
import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { useEffect, useRef, useState } from "react";
import {
  AppState,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  TextInput,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { AppSection } from "@/components/app/app-section";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { Text } from "@/components/ui/text";
import { useSetupState } from "@/features/setup/setup-state";

export default function WelcomeScreen() {
  const router = useRouter();
  const setup = useSetupState();
  const verificationInput = useRef<TextInput>(null);
  const [awaitingKeyboardVerification, setAwaitingKeyboardVerification] =
    useState(false);

  const requestMicrophone = async () => {
    await requestRecordingPermissionsAsync();
    await setup.refresh();
  };

  const openKeyboardSettings = async () => {
    setAwaitingKeyboardVerification(true);
    await setup.openKeyboardSettings();
  };

  useEffect(() => {
    const subscription = AppState.addEventListener("change", (nextState) => {
      if (nextState !== "active" || !awaitingKeyboardVerification) return;
      setAwaitingKeyboardVerification(false);
      setTimeout(() => verificationInput.current?.focus(), 250);
    });
    return () => subscription.remove();
  }, [awaitingKeyboardVerification]);

  return (
    <SafeAreaView
      className="bg-background flex-1"
      edges={["top", "left", "right"]}
    >
      <KeyboardAvoidingView
        behavior={Platform.OS === "ios" ? "padding" : undefined}
        className="flex-1"
      >
        <ScrollView
          className="flex-1"
          contentContainerClassName="gap-4 px-[18px] pt-5 pb-4"
          keyboardShouldPersistTaps="handled"
        >
          <View className="gap-3">
            <View className="bg-primary h-14 w-14 items-center justify-center rounded-2xl">
              <SymbolView name="waveform" size={27} tintColor="#ffffff" />
            </View>
            <View className="gap-2">
              <Text className="text-[32px] font-extrabold">Allow access</Text>
              <Text className="text-muted-foreground text-base leading-6">
                TimberVox needs the microphone to record and Full Access so its
                keyboard can reach the transcription service.
              </Text>
            </View>
          </View>

          <AppSection>
            <SetupRow
              action={requestMicrophone}
              actionLabel="Allow"
              complete={setup.microphoneGranted}
              label="Microphone"
            />
            <Separator />
            <SetupRow
              action={openKeyboardSettings}
              actionLabel="Open Settings"
              complete={setup.keyboardEnabled}
              label="TimberVox keyboard"
            />
            <Separator />
            <SetupRow
              action={openKeyboardSettings}
              actionLabel="Open Settings"
              complete={setup.fullAccessVerified}
              label="Full Access"
            />
            <Text className="text-muted-foreground pb-3 text-sm leading-5">
              In Settings, open Apps → TimberVox → Keyboards. Turn on TimberVox
              and Full Access, then return here and choose TimberVox below to
              verify both.
            </Text>
          </AppSection>
        </ScrollView>

        <AppBottomActionBar className="gap-3">
          <View className="gap-1.5">
            <Text className="text-sm font-semibold">Verify keyboard</Text>
            <Input
              ref={verificationInput}
              accessibilityLabel="Keyboard verification field"
              autoCapitalize="sentences"
              className="h-12 rounded-xl px-4"
              placeholder="Tap, then choose TimberVox"
              testID="keyboard-verification-field"
            />
          </View>
          <Button
            className="h-14 rounded-2xl"
            disabled={!setup.microphoneGranted || !setup.keyboardVerified}
            onPress={() => router.push("/shortcut")}
          >
            <Text className="text-base font-bold">Continue</Text>
          </Button>
        </AppBottomActionBar>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function SetupRow({
  action,
  actionLabel,
  complete,
  label,
}: {
  action: () => void | Promise<void>;
  actionLabel: string;
  complete: boolean;
  label: string;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      className="min-h-14 flex-row items-center justify-between gap-3"
      onPress={action}
    >
      <View className="min-w-0 flex-1 flex-row items-center gap-3">
        <View
          className={
            complete
              ? "bg-success size-7 items-center justify-center rounded-full"
              : "bg-muted size-7 items-center justify-center rounded-full"
          }
        >
          <SymbolView
            name={complete ? "checkmark" : "circle"}
            size={13}
            tintColor={complete ? "#ffffff" : "#7f8796"}
          />
        </View>
        <Text className="font-semibold">{label}</Text>
      </View>
      <Text
        className={complete ? "text-success text-sm" : "text-primary text-sm"}
      >
        {complete ? "Verified" : actionLabel}
      </Text>
    </Pressable>
  );
}
