import { useCallback, useMemo, useState } from "react";
import { type LayoutChangeEvent, View } from "react-native";
import { Gesture, GestureDetector } from "react-native-gesture-handler";
import { runOnJS } from "react-native-reanimated";

import { Text } from "@/components/ui/text";
import { formatDuration } from "@/features/history/history-format";

function HistoryPlaybackScrubber({
  currentTime,
  duration,
  onSeek,
}: {
  currentTime: number;
  duration: number;
  onSeek: (time: number) => void;
}) {
  const [trackWidth, setTrackWidth] = useState(0);
  const progress =
    duration > 0 ? Math.min(1, Math.max(0, currentTime / duration)) : 0;

  const seekFromPosition = useCallback(
    (locationX: number) => {
      if (trackWidth <= 0 || duration <= 0) return;
      onSeek(
        Math.min(duration, Math.max(0, (locationX / trackWidth) * duration)),
      );
    },
    [duration, onSeek, trackWidth],
  );

  const gesture = useMemo(
    () =>
      Gesture.Pan()
        .minDistance(0)
        .onBegin((event) => runOnJS(seekFromPosition)(event.x))
        .onUpdate((event) => runOnJS(seekFromPosition)(event.x)),
    [seekFromPosition],
  );

  const accessibilityStep = (direction: -1 | 1) => {
    if (duration <= 0) return;
    onSeek(Math.min(duration, Math.max(0, currentTime + direction * 5)));
  };

  return (
    <View className="h-full flex-1 justify-center">
      <GestureDetector gesture={gesture}>
        <View
          accessibilityActions={[
            { label: "Move backward five seconds", name: "decrement" },
            { label: "Move forward five seconds", name: "increment" },
          ]}
          accessibilityLabel="Recording position"
          accessibilityRole="adjustable"
          accessibilityValue={{
            max: Math.round(duration),
            min: 0,
            now: Math.round(currentTime),
            text: `${formatDuration(currentTime * 1_000)} of ${formatDuration(duration * 1_000)}`,
          }}
          className="h-11 justify-center"
          onAccessibilityAction={(event) => {
            accessibilityStep(
              event.nativeEvent.actionName === "decrement" ? -1 : 1,
            );
          }}
          onLayout={(event: LayoutChangeEvent) =>
            setTrackWidth(event.nativeEvent.layout.width)
          }
          testID="history-playback-position"
        >
          <View className="bg-muted h-2 overflow-hidden rounded-full">
            <View
              className="bg-primary h-full rounded-full"
              style={{ width: `${progress * 100}%` }}
            />
          </View>
          <View
            className="border-background bg-primary absolute size-4 rounded-full border-2"
            pointerEvents="none"
            style={{
              left: Math.max(0, progress * Math.max(0, trackWidth - 16)),
            }}
          />
        </View>
      </GestureDetector>

      <View
        className="absolute right-0 bottom-1 left-0 flex-row justify-between"
        pointerEvents="none"
      >
        <Text className="text-muted-foreground text-[11px]">
          {formatDuration(currentTime * 1_000)}
        </Text>
        <Text className="text-muted-foreground text-[11px]">
          {formatDuration(duration * 1_000)}
        </Text>
      </View>
    </View>
  );
}

export { HistoryPlaybackScrubber };
