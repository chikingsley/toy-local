import { useRouter } from "expo-router";
import { FlatList, View } from "react-native";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { APP_LIST_WITH_BOTTOM_ACTION_CONTENT_STYLE } from "@/components/app/app-layout";
import { AppScreen } from "@/components/app/app-screen";
import { Button } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import { useModeEditor } from "@/features/modes/mode-editor-state";
import { ModeRow } from "@/features/modes/mode-row";
import { useModes } from "@/features/modes/mode-provider";
import { modeToDraft } from "@/features/modes/mode-validation";

export default function ModesScreen() {
  const router = useRouter();
  const { begin } = useModeEditor();
  const { catalogError, loading, modes, retryCatalog } = useModes();

  return (
    <View className="bg-background flex-1">
      <AppScreen>
        <FlatList
          className="flex-1"
          contentContainerStyle={APP_LIST_WITH_BOTTOM_ACTION_CONTENT_STYLE}
          data={modes}
          keyExtractor={(mode) => mode.id}
          ListEmptyComponent={
            <View className="items-center gap-2 py-24">
              <Text className="text-lg font-bold">
                {loading ? "Loading modes…" : "No modes yet"}
              </Text>
              <Text className="text-muted-foreground text-center text-sm">
                Create a mode to define how your dictation should be handled.
              </Text>
            </View>
          }
          renderItem={({ item }) => (
            <ModeRow
              mode={item}
              onPress={() => {
                begin(modeToDraft(item));
                router.push({
                  pathname: "/modes/[modeId]",
                  params: { modeId: item.id },
                });
              }}
            />
          )}
        />
        {catalogError ? (
          <View className="absolute right-[18px] bottom-[18px] left-[18px] items-center gap-2">
            <Text className="text-destructive text-center text-xs">
              {catalogError}
            </Text>
            <Button
              onPress={() => void retryCatalog()}
              size="sm"
              testID="retry-model-catalog"
              variant="outline"
            >
              <Text>Retry Models</Text>
            </Button>
          </View>
        ) : null}
      </AppScreen>

      <AppBottomActionBar>
        <Button
          accessibilityLabel="Create mode"
          className="h-14 rounded-2xl"
          disabled={!modes.length && loading}
          onPress={() => router.push("/modes/new")}
          testID="create-mode"
        >
          <Text className="text-base font-bold">Create Mode</Text>
        </Button>
      </AppBottomActionBar>
    </View>
  );
}
