import { useRouter } from "expo-router";
import { SymbolView } from "expo-symbols";
import { Pressable } from "react-native";

function AppHeaderBackButton({ label = "Back" }: { label?: string }) {
  const router = useRouter();

  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      className="active:bg-accent size-11 items-center justify-center rounded-full"
      hitSlop={8}
      onPress={() => router.back()}
      testID="app-header-back"
    >
      <SymbolView name="chevron.left" size={18} tintColor="#f4f6fb" />
    </Pressable>
  );
}

export { AppHeaderBackButton };
