import { type ViewProps, View } from "react-native";
import { NativeShortcutsButton } from "timbervox-system";

type ShortcutsButtonProps = ViewProps & { className?: string };

function ShortcutsButton(props: ShortcutsButtonProps) {
  return (
    <View {...props}>
      <NativeShortcutsButton style={{ flex: 1 }} />
    </View>
  );
}

export { ShortcutsButton };
