import { cn } from "@/lib/utils";
import type { PropsWithChildren } from "react";
import { View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { APP_LAYOUT } from "@/components/app/app-layout";

type AppBottomActionBarProps = PropsWithChildren<{
  className?: string;
}>;

function AppBottomActionBar({ children, className }: AppBottomActionBarProps) {
  const insets = useSafeAreaInsets();

  return (
    <View
      className={cn("border-border bg-background border-t", className)}
      style={{
        paddingBottom: insets.bottom + APP_LAYOUT.bottomActionExtraInset,
        paddingHorizontal: APP_LAYOUT.screenGutter,
        paddingTop: APP_LAYOUT.bottomActionTopInset,
      }}
    >
      {children}
    </View>
  );
}

export { AppBottomActionBar };
export type { AppBottomActionBarProps };
