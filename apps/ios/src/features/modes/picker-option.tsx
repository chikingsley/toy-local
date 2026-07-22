import { SymbolView } from "expo-symbols";
import type { ReactNode } from "react";
import { Pressable, View } from "react-native";

import { Text } from "@/components/ui/text";
import { cn } from "@/lib/utils";

function PickerOption({
  detail,
  disabled = false,
  grouped = false,
  iconKey,
  label,
  leading,
  live = false,
  onPress,
  selected,
  testID,
}: {
  detail?: string;
  disabled?: boolean;
  grouped?: boolean;
  iconKey?: string;
  label: string;
  leading?: ReactNode;
  live?: boolean;
  onPress?: () => void;
  selected: boolean;
  testID?: string;
}) {
  return (
    <Pressable
      className={cn(
        "active:bg-accent min-h-[64px] flex-row items-center gap-3 px-4 py-3",
        grouped
          ? "bg-transparent"
          : "border-border bg-card rounded-[18px] border",
      )}
      disabled={disabled}
      onPress={onPress}
      style={{ opacity: disabled ? 0.45 : 1 }}
      testID={testID}
    >
      {leading ??
        (iconKey ? (
          <SymbolView name={iconKey as never} size={21} tintColor="#8bb2ff" />
        ) : null)}
      <View className="min-w-0 flex-1 gap-1">
        <Text className="font-bold">{label}</Text>
        {detail ? (
          <View className="flex-row items-center gap-1.5">
            {live ? (
              <View className="size-1.5 rounded-full bg-green-500" />
            ) : null}
            <Text
              className="text-muted-foreground min-w-0 flex-shrink text-[12px] leading-4"
              numberOfLines={1}
            >
              {detail}
            </Text>
          </View>
        ) : null}
      </View>
      {selected ? (
        <SymbolView
          name="checkmark.circle.fill"
          size={20}
          tintColor="#6b9cff"
        />
      ) : null}
    </Pressable>
  );
}

export { PickerOption };
