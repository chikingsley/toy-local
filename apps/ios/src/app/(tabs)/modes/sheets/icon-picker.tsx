import { useRouter } from "expo-router";
import { SymbolView } from "expo-symbols";
import { FlatList, Pressable, View } from "react-native";

import {
  APP_FORM_SHEET_INSET_PROPS,
} from "@/components/app/app-form-sheet";
import {
  MODE_ICON_COLUMNS,
  MODE_ICONS,
} from "@/features/modes/mode-editor-contract";
import { useModeEditor } from "@/features/modes/mode-editor-state";

export default function IconPickerScreen() {
  const router = useRouter();
  const editor = useModeEditor();
  return (
    <FlatList
      {...APP_FORM_SHEET_INSET_PROPS}
      className="bg-background flex-1"
      columnWrapperClassName="justify-between"
      contentContainerClassName="gap-2 px-[18px] pt-6 pb-10"
      data={MODE_ICONS}
      keyExtractor={(iconKey) => iconKey}
      numColumns={MODE_ICON_COLUMNS}
      renderItem={({ item: iconKey }) => {
        const selected = editor.draft?.iconKey === iconKey;
        return (
          <View className="w-10 items-center">
            <Pressable
              accessibilityLabel={`Use ${iconKey} icon`}
              className={
                selected
                  ? "bg-primary size-10 items-center justify-center rounded-full"
                  : "active:bg-accent size-10 items-center justify-center rounded-full"
              }
              onPress={() => {
                editor.chooseIcon(iconKey);
                router.back();
              }}
            >
              <SymbolView
                name={iconKey}
                size={20}
                tintColor={selected ? "#ffffff" : "#8bb2ff"}
              />
            </Pressable>
          </View>
        );
      }}
    />
  );
}
