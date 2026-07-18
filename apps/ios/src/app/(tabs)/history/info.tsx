import { Stack, useLocalSearchParams } from "expo-router";
import { useSQLiteContext } from "expo-sqlite";
import { useEffect, useState } from "react";
import { View } from "react-native";

import { AppScreen } from "@/components/app/app-screen";
import { AppSection } from "@/components/app/app-section";
import { Separator } from "@/components/ui/separator";
import { Text } from "@/components/ui/text";
import {
  loadStoredDictationDetail,
  type StoredDictationDetail,
} from "@/features/dictation/dictation-repository";
import {
  formatBytes,
  formatDate,
  formatDuration,
} from "@/features/history/history-format";

export default function HistoryInfoScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const database = useSQLiteContext();
  const [detail, setDetail] = useState<StoredDictationDetail | null>();

  useEffect(() => {
    void loadStoredDictationDetail(database, id).then(setDetail);
  }, [database, id]);

  return (
    <>
      <Stack.Screen options={{ title: "Dictation Info" }} />
      <AppScreen contentClassName="pb-6" scroll>
        {detail ? (
          <AppSection>
            <InfoRow label="Date" value={formatDate(detail.createdAt)} />
            <Separator />
            <InfoRow label="Mode" value={detail.mode.name} />
            <Separator />
            <InfoRow label="Model" value={detail.modelId} />
            <Separator />
            <InfoRow label="Language" value={detail.language ?? "Automatic"} />
            <Separator />
            <InfoRow
              label="Duration"
              value={formatDuration(detail.durationMs)}
            />
            <Separator />
            <InfoRow label="Words" value={detail.wordCount.toLocaleString()} />
            <Separator />
            <InfoRow
              label="Started from"
              value={entryPointLabel(detail.entryPoint)}
            />
            <Separator />
            <InfoRow label="Audio" value={formatBytes(detail.audioSizeBytes)} />
          </AppSection>
        ) : (
          <Text className="text-muted-foreground text-center">
            {detail === null ? "Dictation not found." : "Loading…"}
          </Text>
        )}
      </AppScreen>
    </>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View className="min-h-[56px] flex-row items-center justify-between gap-5">
      <Text className="text-muted-foreground">{label}</Text>
      <Text className="flex-1 text-right font-semibold">{value}</Text>
    </View>
  );
}

function entryPointLabel(entryPoint: StoredDictationDetail["entryPoint"]) {
  if (entryPoint === "keyboard") return "Keyboard";
  if (entryPoint === "shortcut") return "Shortcut";
  return "TimberVox";
}
