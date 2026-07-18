import { useAudioPlayer, useAudioPlayerStatus } from "expo-audio";
import { SymbolView } from "expo-symbols";
import { useState } from "react";
import { type LayoutChangeEvent, Pressable, View } from "react-native";

import { Button } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import { formatDuration } from "@/features/history/history-format";

function HistoryPlaybackControl({
  audioUri,
  fallbackDurationMs,
}: {
  audioUri: string;
  fallbackDurationMs: number;
}) {
  const player = useAudioPlayer(audioUri, { updateInterval: 100 });
  const status = useAudioPlayerStatus(player);
  const [trackWidth, setTrackWidth] = useState(0);
  const duration = status.duration || fallbackDurationMs / 1_000;
  const progress = duration > 0 ? status.currentTime / duration : 0;

  const togglePlayback = () => {
    if (status.playing) {
      player.pause();
      return;
    }
    if (duration > 0 && status.currentTime >= duration - 0.05) {
      void player.seekTo(0).then(() => player.play());
      return;
    }
    player.play();
  };

  const seek = (locationX: number) => {
    if (trackWidth <= 0 || duration <= 0) return;
    void player.seekTo(
      Math.min(duration, Math.max(0, (locationX / trackWidth) * duration)),
    );
  };

  return (
    <View className="bg-card flex-row items-center gap-3 rounded-[18px] px-3 py-3">
      <Button
        accessibilityLabel={
          status.playing ? "Pause recording" : "Play recording"
        }
        className="rounded-full"
        onPress={togglePlayback}
        size="icon"
      >
        <SymbolView
          name={status.playing ? "pause.fill" : "play.fill"}
          size={15}
          tintColor="#ffffff"
        />
      </Button>
      <View className="flex-1 gap-1.5">
        <Pressable
          accessibilityLabel="Recording position"
          className="bg-muted h-2 overflow-hidden rounded-full"
          onLayout={(event: LayoutChangeEvent) =>
            setTrackWidth(event.nativeEvent.layout.width)
          }
          onPress={(event) => seek(event.nativeEvent.locationX)}
        >
          <View
            className="bg-primary h-full rounded-full"
            style={{ width: `${Math.min(100, Math.max(0, progress * 100))}%` }}
          />
        </Pressable>
        <View className="flex-row justify-between">
          <Text className="text-muted-foreground text-[11px]">
            {formatDuration(status.currentTime * 1_000)}
          </Text>
          <Text className="text-muted-foreground text-[11px]">
            {formatDuration(duration * 1_000)}
          </Text>
        </View>
      </View>
    </View>
  );
}

export { HistoryPlaybackControl };
