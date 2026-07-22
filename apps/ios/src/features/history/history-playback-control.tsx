import { useAudioPlayer, useAudioPlayerStatus } from "expo-audio";
import { SymbolView } from "expo-symbols";
import { useCallback, useState } from "react";
import { View } from "react-native";

import { Button } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import { configurePlaybackAudioSession } from "@/features/audio/audio-session";
import { useDictationSession } from "@/features/dictation/dictation-session";
import { HistoryPlaybackScrubber } from "@/features/history/history-playback-scrubber";

function HistoryPlaybackControl({
  audioUri,
  fallbackDurationMs,
}: {
  audioUri: string;
  fallbackDurationMs: number;
}) {
  const player = useAudioPlayer(audioUri, { updateInterval: 100 });
  const status = useAudioPlayerStatus(player);
  const session = useDictationSession();
  const [playbackError, setPlaybackError] = useState<string | null>(null);
  const duration = status.duration || fallbackDurationMs / 1_000;
  const seekTo = useCallback(
    (time: number) => {
      void player.seekTo(time);
    },
    [player],
  );

  const togglePlayback = async () => {
    if (status.playing) {
      player.pause();
      return;
    }
    setPlaybackError(null);
    try {
      if (session.sessionActive) await session.endSession();
      await configurePlaybackAudioSession();
      if (duration > 0 && status.currentTime >= duration - 0.05) {
        await player.seekTo(0);
      }
      player.play();
    } catch (error) {
      setPlaybackError(
        error instanceof Error ? error.message : "Audio playback failed.",
      );
    }
  };

  return (
    <View className="gap-2">
      <View className="bg-card h-[72px] flex-row items-center gap-3 rounded-[18px] px-3">
        <Button
          accessibilityLabel={
            status.playing ? "Pause recording" : "Play recording"
          }
          className="rounded-full"
          onPress={() => void togglePlayback()}
          size="icon"
          testID="history-playback-toggle"
        >
          <SymbolView
            name={status.playing ? "pause.fill" : "play.fill"}
            size={15}
            tintColor="#ffffff"
          />
        </Button>
        <HistoryPlaybackScrubber
          currentTime={status.currentTime}
          duration={duration}
          onSeek={seekTo}
        />
      </View>
      {status.error || playbackError ? (
        <Text
          className="text-destructive px-2 text-xs"
          testID="history-playback-error"
        >
          {status.error || playbackError}
        </Text>
      ) : null}
    </View>
  );
}

export { HistoryPlaybackControl };
