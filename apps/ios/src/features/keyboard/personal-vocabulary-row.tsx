import { SymbolView } from "expo-symbols";
import { useMemo } from "react";
import { Dimensions, Pressable, View } from "react-native";
import {
  Gesture,
  GestureDetector,
} from "react-native-gesture-handler";
import Animated, {
  runOnJS,
  type SharedValue,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from "react-native-reanimated";

import { Card, CardContent } from "@/components/ui/card";
import { Text } from "@/components/ui/text";
import {
  personalValueKey,
  type PersonalVocabularyEntry,
} from "@/features/keyboard/personal-vocabulary-contract";
import { cn } from "@/lib/utils";

const VOCABULARY_ROW_HEIGHT = 76;
const DRAG_TOP_EDGE = 138;
const DRAG_BOTTOM_EDGE = 168;

function PersonalVocabularyRow({
  canDrag,
  entry,
  index,
  itemCount,
  onAutoScroll,
  onMove,
  onShowMenu,
  scrollOffset,
}: {
  canDrag: boolean;
  entry: PersonalVocabularyEntry;
  index: number;
  itemCount: number;
  onAutoScroll: (direction: -1 | 1) => void;
  onMove: (destinationIndex: number) => void;
  onShowMenu: () => void;
  scrollOffset: SharedValue<number>;
}) {
  const startScrollOffset = useSharedValue(0);
  const translationY = useSharedValue(0);
  const dragging = useSharedValue(false);
  const screenHeight = Dimensions.get("window").height;

  const dragGesture = useMemo(
    () =>
      Gesture.Pan()
        .enabled(canDrag)
        .activateAfterLongPress(100)
        .minDistance(2)
        .onStart(() => {
          dragging.set(true);
          startScrollOffset.set(scrollOffset.get());
        })
        .onUpdate((event) => {
          translationY.set(event.translationY);
          if (event.absoluteY < DRAG_TOP_EDGE) {
            runOnJS(onAutoScroll)(-1);
          } else if (event.absoluteY > screenHeight - DRAG_BOTTOM_EDGE) {
            runOnJS(onAutoScroll)(1);
          }
        })
        .onEnd((event) => {
          const scrollDelta = scrollOffset.get() - startScrollOffset.get();
          const rowDelta = Math.round(
            (event.translationY + scrollDelta) / VOCABULARY_ROW_HEIGHT,
          );
          const destination = Math.max(
            0,
            Math.min(itemCount - 1, index + rowDelta),
          );
          if (destination !== index) runOnJS(onMove)(destination);
        })
        .onFinalize(() => {
          dragging.set(false);
          translationY.set(withSpring(0, { damping: 22, stiffness: 260 }));
        }),
    [
      canDrag,
      dragging,
      index,
      itemCount,
      onAutoScroll,
      onMove,
      screenHeight,
      scrollOffset,
      startScrollOffset,
      translationY,
    ],
  );

  const animatedStyle = useAnimatedStyle(() => ({
    elevation: dragging.get() ? 10 : 0,
    opacity: dragging.get() ? 0.96 : 1,
    shadowOpacity: dragging.get() ? 0.25 : 0,
    transform: [{ translateY: translationY.get() }],
    zIndex: dragging.get() ? 10 : 0,
  }));

  const usageLabel = `Used ${entry.usageCount} ${entry.usageCount === 1 ? "time" : "times"}`;
  const rankingLabel =
    entry.pinnedSlot === null
      ? `Automatic · ${usageLabel}`
      : `Pinned #${entry.pinnedSlot + 1} · ${usageLabel}`;

  return (
    <Animated.View style={animatedStyle}>
      <Card className="h-[68px] gap-0 rounded-[18px] border-0 py-0 shadow-none">
        <CardContent className="h-full flex-row items-center gap-3 px-4">
          <GestureDetector gesture={dragGesture}>
            <Pressable
              accessibilityActions={[
                { label: "Move earlier", name: "decrement" },
                { label: "Move later", name: "increment" },
              ]}
              accessibilityHint={
                canDrag
                  ? "Drag to pin this entry at a list position."
                  : "Clear the search to drag this entry."
              }
              accessibilityLabel={`Reorder ${entry.value}`}
              accessibilityRole="adjustable"
              className={cn(
                "size-9 items-center justify-center rounded-full",
                canDrag ? "bg-muted" : "opacity-35",
              )}
              onAccessibilityAction={(event) => {
                if (!canDrag) return;
                const destination =
                  event.nativeEvent.actionName === "decrement"
                    ? index - 1
                    : index + 1;
                onMove(Math.max(0, Math.min(itemCount - 1, destination)));
              }}
              testID={`personal-vocabulary-drag-${personalValueKey(entry.value)}`}
            >
              <SymbolView name="line.3.horizontal" size={16} tintColor="#7f8796" />
            </Pressable>
          </GestureDetector>

          <View className="min-w-0 flex-1 gap-0.5">
            <Text className="font-semibold" numberOfLines={1}>
              {entry.value}
            </Text>
            <Text className="text-muted-foreground text-xs" numberOfLines={1}>
              {rankingLabel}
            </Text>
          </View>

          <Pressable
            accessibilityLabel={`More options for ${entry.value}`}
            accessibilityRole="button"
            className="size-10 items-center justify-center rounded-full"
            hitSlop={5}
            onPress={onShowMenu}
            testID={`personal-vocabulary-menu-${personalValueKey(entry.value)}`}
          >
            <SymbolView name="ellipsis" size={18} tintColor="#7f8796" />
          </Pressable>
        </CardContent>
      </Card>
    </Animated.View>
  );
}

export { PersonalVocabularyRow, VOCABULARY_ROW_HEIGHT };
