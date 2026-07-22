import { LegendList } from "@legendapp/list/react-native";
import { SymbolView } from "expo-symbols";
import { useRouter } from "expo-router";
import { useMemo, useState } from "react";
import { Pressable, View } from "react-native";

import { AppScreen } from "@/components/app/app-screen";
import { APP_VIRTUALIZED_LIST_CONTENT_STYLE } from "@/components/app/app-layout";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Text } from "@/components/ui/text";
import {
  type DictationHistoryItem,
  useHistory,
} from "@/features/history/history-store";
import {
  dictationDisplayText,
  formatDictationMetadata,
} from "@/features/history/history-format";

export default function HistoryScreen() {
  const history = useHistory();
  const router = useRouter();
  const [query, setQuery] = useState("");
  const filtered = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    return normalized
      ? history.items.filter((item) =>
          dictationDisplayText(item).toLocaleLowerCase().includes(normalized),
        )
      : history.items;
  }, [history.items, query]);

  return (
    <AppScreen keyboardShouldPersistTaps="handled">
      <LegendList
        ListEmptyComponent={
          <HistoryEmptyState searching={Boolean(query.trim())} />
        }
        ListHeaderComponent={
          <View className="pb-3">
            <Input
              accessibilityLabel="Search history"
              className="h-12 rounded-2xl border-0 px-4 shadow-none"
              onChangeText={setQuery}
              placeholder="Search history"
              testID="history-search"
              value={query}
            />
          </View>
        }
        contentContainerStyle={APP_VIRTUALIZED_LIST_CONTENT_STYLE}
        data={filtered}
        estimatedItemSize={132}
        keyboardDismissMode="interactive"
        keyboardShouldPersistTaps="handled"
        keyExtractor={(item) => item.id}
        recycleItems
        renderItem={({ item }) => (
          <HistoryRow
            item={item}
            onPress={() =>
              router.push({
                pathname: "/history/[id]",
                params: { id: item.id },
              })
            }
          />
        )}
      />
    </AppScreen>
  );
}

function HistoryRow({
  item,
  onPress,
}: {
  item: DictationHistoryItem;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityLabel={`Open dictation from ${new Date(item.createdAt).toLocaleDateString()}`}
      onPress={onPress}
      testID={`history-row-${item.id}`}
    >
      <Card className="gap-0 rounded-[20px] border-0 py-0 shadow-none">
        <CardContent className="gap-3 px-[17px] py-4">
          <View className="flex-row items-start gap-3">
            <Text className="flex-1 text-[17px] leading-6" numberOfLines={4}>
              {dictationDisplayText(item)}
            </Text>
            <SymbolView name="chevron.right" size={14} tintColor="#707785" />
          </View>
          <Text className="text-muted-foreground text-xs">
            {formatDictationMetadata(item)}
          </Text>
        </CardContent>
      </Card>
    </Pressable>
  );
}

function HistoryEmptyState({ searching }: { searching: boolean }) {
  return (
    <View className="items-center gap-3 px-8 py-24">
      <SymbolView
        name={searching ? "magnifyingglass" : "waveform"}
        size={38}
        tintColor="#59606d"
      />
      <Text className="text-xl font-bold">
        {searching ? "No matches" : "No dictations yet"}
      </Text>
      <Text className="text-muted-foreground text-center text-sm leading-5">
        {searching
          ? "Try another word or phrase."
          : "Completed app, keyboard, and shortcut dictations appear here."}
      </Text>
    </View>
  );
}
