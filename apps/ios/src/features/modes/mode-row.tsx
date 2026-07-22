import { SymbolView } from "expo-symbols";
import { Pressable, View } from "react-native";

import { Text } from "@/components/ui/text";
import { ModeIcon } from "@/features/modes/mode-icon";
import type { Mode } from "@/features/modes/mode-types";

function ModeRow({
  accessibilityLabel,
  mode,
  onPress,
}: {
  accessibilityLabel?: string;
  mode: Mode;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel ?? `Edit ${mode.name}`}
      className="border-border bg-card active:bg-accent min-h-[88px] flex-row items-center gap-3 rounded-[22px] border px-4 py-3"
      onPress={onPress}
      testID={`mode-row-${mode.id}`}
    >
      <ModeIcon iconKey={mode.iconKey} />
      <View className="min-w-0 flex-1 gap-1">
        <View className="flex-row items-center gap-2">
          <Text className="shrink text-[17px] font-bold" numberOfLines={1}>
            {mode.name}
          </Text>
          {mode.isActive ? (
            <View className="bg-success/15 rounded-full px-2 py-0.5">
              <Text className="text-success text-[10px] font-bold uppercase tracking-wide">
                Active
              </Text>
            </View>
          ) : null}
        </View>
        <Text
          className="text-muted-foreground text-[13px] leading-[18px]"
          numberOfLines={2}
        >
          {mode.description}
        </Text>
      </View>
      <SymbolView name="chevron.right" size={14} tintColor="#737b89" />
    </Pressable>
  );
}

export { ModeRow };
