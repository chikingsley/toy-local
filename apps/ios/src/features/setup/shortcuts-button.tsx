import { SymbolView } from "expo-symbols";
import { Linking } from "react-native";

import { Button, type ButtonProps } from "@/components/ui/button";
import { Text } from "@/components/ui/text";

const TIMBERVOX_SHORTCUT_URL =
  "https://www.icloud.com/shortcuts/e42e0c3a7b214062b102571429275e7a";

function ShortcutsButton(props: ButtonProps) {
  return (
    <Button
      accessibilityLabel="Add Toggle TimberVox Dictation shortcut"
      {...props}
      onPress={() => {
        void Linking.openURL(TIMBERVOX_SHORTCUT_URL);
      }}
    >
      <SymbolView name="plus.circle.fill" size={20} tintColor="#ffffff" />
      <Text className="text-base font-bold">Add Shortcut</Text>
    </Button>
  );
}

export { ShortcutsButton, TIMBERVOX_SHORTCUT_URL };
