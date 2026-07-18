import Constants from "expo-constants";
import { SymbolView } from "expo-symbols";
import { useSQLiteContext } from "expo-sqlite";
import { useRouter } from "expo-router";
import { useCallback, useEffect, useState } from "react";
import { Alert, Pressable, View } from "react-native";

import { AppScreen } from "@/components/app/app-screen";
import { AppSection } from "@/components/app/app-section";
import { Separator } from "@/components/ui/separator";
import { Switch } from "@/components/ui/switch";
import { Text } from "@/components/ui/text";
import { useDictationSession } from "@/features/dictation/dictation-session";
import {
  clearStoredAudio,
  clearStoredHistory,
  loadAudioRetention,
  loadStorageSummary,
  setAudioRetention,
  type AudioRetentionDays,
  type StorageSummary,
} from "@/features/history/history-storage";
import { formatBytes } from "@/features/history/history-format";
import { useHistory } from "@/features/history/history-store";
import { useKeyboardPreferences } from "@/features/keyboard/keyboard-preferences";
import {
  modelDisplayName,
  selectedTranscriptionModel,
} from "@/features/modes/model-catalog";
import { useModes } from "@/features/modes/mode-provider";
import { useSetupState } from "@/features/setup/setup-state";
import { ShortcutsButton } from "@/features/setup/shortcuts-button";
import { cn } from "@/lib/utils";

const EMPTY_STORAGE: StorageSummary = {
  audioBytes: 0,
  audioCount: 0,
  historyCount: 0,
};

export default function SettingsScreen() {
  const database = useSQLiteContext();
  const router = useRouter();
  const history = useHistory();
  const session = useDictationSession();
  const modes = useModes();
  const setup = useSetupState();
  const keyboard = useKeyboardPreferences();
  const [storage, setStorage] = useState(EMPTY_STORAGE);
  const [retention, setRetention] = useState<AudioRetentionDays>(null);
  const activeModel =
    modes.activeMode && modes.catalog
      ? selectedTranscriptionModel(modes.catalog, modes.activeMode.asrModelId)
      : undefined;

  const refreshStorage = useCallback(async () => {
    const [nextStorage, nextRetention] = await Promise.all([
      loadStorageSummary(database),
      loadAudioRetention(database),
    ]);
    setStorage(nextStorage);
    setRetention(nextRetention);
  }, [database]);

  useEffect(() => {
    let mounted = true;
    void Promise.all([
      loadStorageSummary(database),
      loadAudioRetention(database),
    ]).then(([nextStorage, nextRetention]) => {
      if (!mounted) return;
      setStorage(nextStorage);
      setRetention(nextRetention);
    });
    return () => {
      mounted = false;
    };
  }, [database]);

  const restartSetup = () => {
    setup.restart();
    router.dismissAll();
    router.replace("/");
  };

  const chooseRetention = () => {
    const options: { label: string; value: AudioRetentionDays }[] = [
      { label: "Forever", value: null },
      { label: "1 day", value: 1 },
      { label: "7 days", value: 7 },
      { label: "30 days", value: 30 },
      { label: "90 days", value: 90 },
    ];
    Alert.alert(
      "Keep audio",
      "Transcripts remain in History after their audio is removed.",
      [
        ...options.map((option) => ({
          onPress: () => {
            void setAudioRetention(database, option.value).then(async () => {
              setRetention(option.value);
              await history.reload();
              await refreshStorage();
            });
          },
          text: option.label,
        })),
        { style: "cancel", text: "Cancel" },
      ],
    );
  };

  const confirmClearAudio = () => {
    Alert.alert(
      "Clear saved audio?",
      "Your transcripts and processed text will remain in History.",
      [
        { style: "cancel", text: "Cancel" },
        {
          onPress: () =>
            void clearStoredAudio(database).then(async () => {
              await history.reload();
              await refreshStorage();
            }),
          style: "destructive",
          text: "Clear Audio",
        },
      ],
    );
  };

  const confirmClearHistory = () => {
    Alert.alert(
      "Clear all history?",
      "This permanently deletes every transcript, artifact, and saved recording.",
      [
        { style: "cancel", text: "Cancel" },
        {
          onPress: () =>
            void clearStoredHistory(database).then(async () => {
              await history.reload();
              await refreshStorage();
            }),
          style: "destructive",
          text: "Clear History",
        },
      ],
    );
  };

  return (
    <AppScreen scroll>
      <AppSection title="Keyboard">
        <SwitchRow
          checked={keyboard.preferences.predictions}
          label="Predictive text"
          onChange={(value) => keyboard.update("predictions", value)}
        />
        <Separator />
        <SwitchRow
          checked={keyboard.preferences.autocorrect}
          label="Auto-correction"
          onChange={(value) => keyboard.update("autocorrect", value)}
        />
        <Separator />
        <SwitchRow
          checked={keyboard.preferences.swipe}
          label="Swipe typing"
          onChange={(value) => keyboard.update("swipe", value)}
        />
        <Separator />
        <SwitchRow
          checked={keyboard.preferences.haptics}
          label="Haptic feedback"
          onChange={(value) => keyboard.update("haptics", value)}
        />
        <Separator />
        <SwitchRow
          checked={keyboard.preferences.sound}
          label="Key sounds"
          onChange={(value) => keyboard.update("sound", value)}
        />
      </AppSection>

      <AppSection className="mt-1" title="Dictation">
        <ValueRow
          label="Mode"
          value={modes.activeMode?.name ?? "Voice to Text"}
        />
        <Separator />
        <ValueRow
          label="Model"
          value={activeModel ? modelDisplayName(activeModel) : "Unavailable"}
        />
        <Separator />
        <ValueRow
          label="Background session"
          value={session.sessionActive ? "Ready" : "Off"}
        />
        {session.sessionActive ? (
          <ActionRow
            destructive
            label="End background session"
            onPress={session.endSession}
          />
        ) : null}
      </AppSection>

      <AppSection className="mt-1" title="Shortcut">
        <ValueRow
          label="Toggle TimberVox Dictation"
          value="Apple-signed"
        />
        <Separator />
        <View className="gap-3 py-4">
          <Text className="text-muted-foreground text-sm leading-5">
            Add or reinstall the signed shortcut, then connect it to Back Tap,
            the Action Button, Siri, or an automation.
          </Text>
          <ShortcutsButton className="h-12 w-full" />
        </View>
      </AppSection>

      <AppSection className="mt-1" title="Storage & Privacy">
        <ValueRow
          label="Stored audio"
          value={`${formatBytes(storage.audioBytes)} · ${storage.audioCount}`}
        />
        <Separator />
        <ActionRow
          label="Keep audio"
          onPress={chooseRetention}
          systemName="chevron.right"
          value={retentionLabel(retention)}
        />
        <Separator />
        <ActionRow
          destructive
          disabled={storage.audioCount === 0}
          label="Clear saved audio"
          onPress={confirmClearAudio}
        />
        <Separator />
        <ActionRow
          destructive
          disabled={storage.historyCount === 0}
          label="Clear recording history"
          onPress={confirmClearHistory}
        />
      </AppSection>

      <AppSection className="mt-1" title="Access Status">
        <StatusRow label="Microphone" verified={setup.microphoneGranted} />
        <Separator />
        <StatusRow label="Keyboard" verified={setup.keyboardEnabled} />
        <Separator />
        <StatusRow label="Full Access" verified={setup.fullAccessVerified} />
        <Separator />
        <ActionRow
          label="Open iPhone Settings"
          onPress={setup.openKeyboardSettings}
          systemName="arrow.up.right"
        />
      </AppSection>

      <AppSection className="mt-1" title="Setup">
        <ActionRow
          label="Run setup again"
          onPress={restartSetup}
          systemName="chevron.right"
        />
      </AppSection>

      <Text className="text-muted-foreground mt-3 text-center text-xs">
        TimberVox {Constants.expoConfig?.version ?? "1.0.0"} (
        {Constants.expoConfig?.ios?.buildNumber ?? "—"})
      </Text>
    </AppScreen>
  );
}

function SwitchRow({
  checked,
  label,
  onChange,
}: {
  checked: boolean;
  label: string;
  onChange: (value: boolean) => void;
}) {
  return (
    <View className="min-h-[58px] flex-row items-center justify-between gap-3">
      <Text className="font-semibold">{label}</Text>
      <Switch checked={checked} onCheckedChange={onChange} />
    </View>
  );
}

function StatusRow({ label, verified }: { label: string; verified: boolean }) {
  return (
    <View className="min-h-[58px] flex-row items-center justify-between gap-3">
      <Text className="font-semibold">{label}</Text>
      <View className="flex-row items-center gap-2">
        <View
          className={cn(
            "bg-muted-foreground size-2 rounded-full",
            verified && "bg-success",
          )}
        />
        <Text
          className={cn(
            "text-muted-foreground text-sm",
            verified && "text-success",
          )}
        >
          {verified ? "Verified" : "Not verified"}
        </Text>
      </View>
    </View>
  );
}

function ValueRow({ label, value }: { label: string; value: string }) {
  return (
    <View className="min-h-[58px] flex-row items-center justify-between gap-3">
      <Text className="font-semibold">{label}</Text>
      <Text className="text-muted-foreground flex-1 text-right text-sm">
        {value}
      </Text>
    </View>
  );
}

function ActionRow({
  destructive = false,
  disabled = false,
  label,
  onPress,
  systemName,
  value,
}: {
  destructive?: boolean;
  disabled?: boolean;
  label: string;
  onPress: () => void | Promise<void>;
  systemName?: string;
  value?: string;
}) {
  return (
    <Pressable
      className={cn(
        "min-h-[56px] flex-row items-center justify-between gap-3",
        disabled && "opacity-40",
      )}
      disabled={disabled}
      onPress={onPress}
    >
      <Text
        className={cn(
          "text-primary text-[15px] font-bold",
          destructive && "text-destructive",
        )}
      >
        {label}
      </Text>
      <View className="flex-row items-center gap-2">
        {value ? (
          <Text className="text-muted-foreground text-sm">{value}</Text>
        ) : null}
        {systemName ? (
          <SymbolView
            name={systemName as never}
            size={14}
            tintColor="#7f8796"
          />
        ) : null}
      </View>
    </Pressable>
  );
}

function retentionLabel(retention: AudioRetentionDays) {
  if (retention === null) return "Forever";
  return `${retention} ${retention === 1 ? "day" : "days"}`;
}
