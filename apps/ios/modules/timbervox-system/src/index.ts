import { requireNativeView } from "expo";
import type { ComponentType } from "react";
import type { ViewProps } from "react-native";

const NativeShortcutsButton: ComponentType<ViewProps> =
  requireNativeView("TimberVoxSystem");

export { NativeShortcutsButton };
