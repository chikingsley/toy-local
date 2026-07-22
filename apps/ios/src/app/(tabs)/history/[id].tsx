import * as Clipboard from "expo-clipboard";
import { File } from "expo-file-system";
import { Stack, useLocalSearchParams, useRouter } from "expo-router";
import { SymbolView } from "expo-symbols";
import { useSQLiteContext } from "expo-sqlite";
import { useEffect, useMemo, useRef, useState } from "react";
import { Alert, Share, View } from "react-native";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { AppScreen } from "@/components/app/app-screen";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Text } from "@/components/ui/text";
import {
  deleteStoredDictation,
  loadStoredDictationDetail,
  type StoredArtifact,
  type StoredDictationDetail,
} from "@/features/dictation/dictation-repository";
import {
  dictationDisplayText,
  formatDate,
} from "@/features/history/history-format";
import { HistoryPlaybackControl } from "@/features/history/history-playback-control";
import { reprocessStoredDictation } from "@/features/history/history-reprocess";
import { useHistory } from "@/features/history/history-store";
import { configuredApiCredential } from "@/lib/api-credential";

type ArtifactKind = StoredArtifact["kind"];

export default function HistoryDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const database = useSQLiteContext();
  const history = useHistory();
  const router = useRouter();
  const [detail, setDetail] = useState<StoredDictationDetail | null>();
  const [reprocessing, setReprocessing] = useState(false);
  const [copied, setCopied] = useState(false);
  const copyResetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    let mounted = true;
    void loadStoredDictationDetail(database, id).then((stored) => {
      if (mounted) setDetail(stored);
    });
    return () => {
      mounted = false;
    };
  }, [database, id]);

  useEffect(
    () => () => {
      if (copyResetTimer.current) clearTimeout(copyResetTimer.current);
    },
    [],
  );

  const artifacts = useMemo(() => availableArtifacts(detail), [detail]);
  const [selected, setSelected] = useState<ArtifactKind>("raw");
  const visibleArtifact = artifacts.some((item) => item.kind === selected)
    ? selected
    : (artifacts[0]?.kind ?? "raw");

  if (detail === undefined) {
    return (
      <AppScreen contentClassName="items-center justify-center gap-3">
        <Text className="text-muted-foreground">Loading dictation…</Text>
      </AppScreen>
    );
  }

  if (detail === null) {
    return (
      <AppScreen contentClassName="items-center justify-center gap-4 px-8">
        <Text className="text-xl font-bold">Dictation not found</Text>
        <Button onPress={() => router.back()}>
          <Text>Back to History</Text>
        </Button>
      </AppScreen>
    );
  }

  const audioUri = existingAudioUri(detail.audioUri);
  const shareText =
    artifacts.find((item) => item.kind === visibleArtifact)?.text ??
    detail.text;
  const canReprocess =
    detail.mode.presetKind !== "voice" &&
    artifacts.some((artifact) => artifact.kind === "raw");

  const reprocess = async () => {
    setReprocessing(true);
    try {
      await reprocessStoredDictation(
        database,
        detail,
        configuredApiCredential(),
      );
      const updated = await loadStoredDictationDetail(database, detail.id);
      setDetail(updated);
      await history.reload();
      setSelected("processed");
    } catch (error) {
      Alert.alert(
        "Could not reprocess",
        error instanceof Error ? error.message : String(error),
      );
    } finally {
      setReprocessing(false);
    }
  };

  const deleteDetail = () => {
    Alert.alert(
      "Delete dictation?",
      "This permanently deletes its text and saved audio.",
      [
        { style: "cancel", text: "Cancel" },
        {
          onPress: () => {
            void deleteStoredDictation(database, detail.id).then(async () => {
              await history.reload();
              router.back();
            });
          },
          style: "destructive",
          text: "Delete",
        },
      ],
    );
  };

  const copyDetail = async () => {
    if (!shareText.trim()) return;
    await Clipboard.setStringAsync(shareText);
    setCopied(true);
    if (copyResetTimer.current) clearTimeout(copyResetTimer.current);
    copyResetTimer.current = setTimeout(() => setCopied(false), 2_000);
  };

  return (
    <>
      <Stack.Screen options={{ title: formatDate(detail.createdAt) }} />
      <Tabs
        className="flex-1 gap-0"
        onValueChange={(value) => setSelected(value as ArtifactKind)}
        value={visibleArtifact}
        testID="history-artifact-tabs"
      >
        <View className="flex-1">
          <AppScreen contentClassName="pb-8" scroll>
            {artifacts.length ? (
              artifacts.map((artifact) => (
                <TabsContent
                  className="pt-1"
                  key={artifact.id}
                  value={artifact.kind}
                >
                  <Text className="text-[20px] leading-8">{artifact.text}</Text>
                </TabsContent>
              ))
            ) : (
              <Text className="text-[20px] leading-8">
                {dictationDisplayText(detail)}
              </Text>
            )}
            {detail.error ? (
              <View className="bg-destructive/10 mt-3 rounded-2xl p-4">
                <Text className="text-destructive font-bold">
                  {detail.error.message}
                </Text>
              </View>
            ) : null}
          </AppScreen>

          <AppBottomActionBar className="gap-3">
            {audioUri ? (
              <HistoryPlaybackControl
                audioUri={audioUri}
                fallbackDurationMs={detail.durationMs}
              />
            ) : null}
            {artifacts.length > 1 ? (
              <TabsList accessibilityLabel="Dictation versions">
                {artifacts.map((artifact) => (
                  <TabsTrigger key={artifact.kind} value={artifact.kind}>
                    <Text>{artifactLabel(artifact.kind)}</Text>
                  </TabsTrigger>
                ))}
              </TabsList>
            ) : null}
            <View className="flex-row justify-end gap-2">
              {canReprocess ? (
                <Button
                  accessibilityLabel={
                    reprocessing
                      ? "Reprocessing dictation"
                      : "Reprocess dictation"
                  }
                  disabled={reprocessing}
                  onPress={() => void reprocess()}
                  size="icon"
                  testID="history-reprocess"
                  variant="ghost"
                >
                  <SymbolView
                    name="arrow.triangle.2.circlepath"
                    size={20}
                    tintColor="#91a8ff"
                  />
                </Button>
              ) : null}
              <Button
                accessibilityLabel={
                  copied ? "Dictation copied" : "Copy dictation"
                }
                disabled={!shareText.trim()}
                onPress={() => void copyDetail()}
                size="icon"
                testID="history-copy"
                variant="ghost"
              >
                <SymbolView
                  name={copied ? "checkmark.circle.fill" : "doc.on.doc"}
                  size={20}
                  tintColor={copied ? "#43d38a" : "#91a8ff"}
                />
              </Button>
              <Button
                accessibilityLabel="Dictation information"
                onPress={() =>
                  router.push({
                    pathname: "/history/info",
                    params: { id: detail.id },
                  })
                }
                size="icon"
                testID="history-info"
                variant="ghost"
              >
                <SymbolView name="info.circle" size={20} tintColor="#91a8ff" />
              </Button>
              <Button
                accessibilityLabel="Share dictation"
                disabled={!shareText.trim()}
                onPress={() => void Share.share({ message: shareText })}
                size="icon"
                testID="history-share"
                variant="ghost"
              >
                <SymbolView
                  name="square.and.arrow.up"
                  size={20}
                  tintColor="#91a8ff"
                />
              </Button>
              <Button
                accessibilityLabel="Delete dictation"
                onPress={deleteDetail}
                size="icon"
                testID="history-delete"
                variant="ghost"
              >
                <SymbolView name="trash" size={20} tintColor="#ff5a5f" />
              </Button>
            </View>
          </AppBottomActionBar>
        </View>
      </Tabs>
    </>
  );
}

function availableArtifacts(detail: StoredDictationDetail | null | undefined) {
  if (!detail) return [];
  return detail.artifacts.filter((artifact) => artifact.text.trim());
}

function artifactLabel(kind: ArtifactKind) {
  if (kind === "segmented") return "Segmented";
  if (kind === "processed") return "Processed";
  return "Raw";
}

function existingAudioUri(uri: string | null) {
  if (!uri) return null;
  try {
    return new File(uri).exists ? uri : null;
  } catch {
    return null;
  }
}
