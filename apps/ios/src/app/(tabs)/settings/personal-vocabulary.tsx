import { AnimatedLegendList } from "@legendapp/list/reanimated";
import type { LegendListRef } from "@legendapp/list/react-native";
import { useFocusEffect, useRouter } from "expo-router";
import { SymbolView } from "expo-symbols";
import { useCallback, useMemo, useRef, useState } from "react";
import { ActionSheetIOS, Alert, View } from "react-native";
import { LinearTransition, useSharedValue } from "react-native-reanimated";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { APP_LIST_WITH_BOTTOM_ACTION_CONTENT_STYLE } from "@/components/app/app-layout";
import { AppScreen } from "@/components/app/app-screen";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Text } from "@/components/ui/text";
import {
  personalValueKey,
  type PersonalVocabularyEntry,
} from "@/features/keyboard/personal-vocabulary-contract";
import {
  movePersonalEntry,
  readPersonalVocabulary,
  removePersonalEntry,
  resumeAutomaticPersonalEntry,
} from "@/features/keyboard/personal-vocabulary";
import {
  PersonalVocabularyRow,
  VOCABULARY_ROW_HEIGHT,
} from "@/features/keyboard/personal-vocabulary-row";

export default function PersonalVocabularyScreen() {
  const router = useRouter();
  const [entries, setEntries] = useState<PersonalVocabularyEntry[]>([]);
  const [filter, setFilter] = useState("");
  const listRef = useRef<LegendListRef>(null);
  const scrollOffset = useSharedValue(0);
  const scrollOffsetRef = useRef(0);
  const lastAutoScrollAt = useRef(0);

  const refresh = useCallback(() => {
    setEntries(readPersonalVocabulary());
  }, []);

  useFocusEffect(refresh);

  const filteredEntries = useMemo(() => {
    const query = personalValueKey(filter);
    if (!query) return entries;
    return entries.filter((entry) =>
      personalValueKey(entry.value).includes(query),
    );
  }, [entries, filter]);

  const moveEntry = useCallback(
    (entry: PersonalVocabularyEntry, index: number) => {
      setEntries(movePersonalEntry(entry.value, index));
    },
    [],
  );

  const resumeAutomatic = useCallback((entry: PersonalVocabularyEntry) => {
    setEntries(resumeAutomaticPersonalEntry(entry.value));
  }, []);

  const confirmForget = useCallback((entry: PersonalVocabularyEntry) => {
    Alert.alert(
      `Forget ${entry.value}?`,
      "Its usage count and preferred spelling will be removed. TimberVox can learn it again later.",
      [
        { style: "cancel", text: "Cancel" },
        {
          onPress: () => setEntries(removePersonalEntry(entry.value)),
          style: "destructive",
          text: "Forget",
        },
      ],
    );
  }, []);

  const showMenu = useCallback(
    (entry: PersonalVocabularyEntry) => {
      const options = ["Move to Top"];
      if (entry.pinnedSlot !== null) options.push("Resume Automatic Ranking");
      options.push("Forget", "Cancel");
      const forgetIndex = options.indexOf("Forget");
      const cancelIndex = options.indexOf("Cancel");
      ActionSheetIOS.showActionSheetWithOptions(
        {
          cancelButtonIndex: cancelIndex,
          destructiveButtonIndex: forgetIndex,
          options,
          title: entry.value,
        },
        (selectedIndex) => {
          const action = options[selectedIndex];
          if (action === "Move to Top") moveEntry(entry, 0);
          if (action === "Resume Automatic Ranking") resumeAutomatic(entry);
          if (action === "Forget") confirmForget(entry);
        },
      );
    },
    [confirmForget, moveEntry, resumeAutomatic],
  );

  const autoScroll = useCallback(
    (direction: -1 | 1) => {
      const now = Date.now();
      if (now - lastAutoScrollAt.current < 60) return;
      lastAutoScrollAt.current = now;
      const nextOffset = Math.max(0, scrollOffsetRef.current + direction * 36);
      listRef.current?.scrollToOffset({ animated: false, offset: nextOffset });
      scrollOffsetRef.current = nextOffset;
      scrollOffset.set(nextOffset);
    },
    [scrollOffset],
  );

  const header = (
    <View className="gap-3 pb-3">
      <View className="flex-row items-center justify-between px-1">
        <Text className="text-muted-foreground text-sm">
          {entries.length} {entries.length === 1 ? "entry" : "entries"}
        </Text>
        {filter ? (
          <Text className="text-muted-foreground text-xs">
            {filteredEntries.length} shown
          </Text>
        ) : null}
      </View>
      <Input
        accessibilityLabel="Search personal vocabulary"
        autoCapitalize="none"
        autoCorrect={false}
        className="h-12 rounded-2xl border-0 px-4 shadow-none"
        onChangeText={setFilter}
        placeholder="Search personal vocabulary"
        testID="personal-vocabulary-filter"
        value={filter}
      />
      {filter ? (
        <Text className="text-muted-foreground px-1 text-xs leading-4">
          Clear search to drag. Row actions remain available from the menu.
        </Text>
      ) : null}
    </View>
  );

  return (
    <View className="bg-background flex-1">
      <AppScreen keyboardShouldPersistTaps="handled">
        <AnimatedLegendList
          ListEmptyComponent={
            <VocabularyEmptyState searching={Boolean(filter)} />
          }
          ListHeaderComponent={header}
          contentContainerStyle={APP_LIST_WITH_BOTTOM_ACTION_CONTENT_STYLE}
          data={filteredEntries}
          estimatedItemSize={VOCABULARY_ROW_HEIGHT}
          itemLayoutAnimation={LinearTransition.duration(180)}
          keyboardDismissMode="interactive"
          keyboardShouldPersistTaps="handled"
          keyExtractor={(entry) => personalValueKey(entry.value)}
          onScroll={(event) => {
            const offset = event.nativeEvent.contentOffset.y;
            scrollOffsetRef.current = offset;
            scrollOffset.set(offset);
          }}
          recycleItems
          ref={listRef}
          renderItem={({ item, index }) => (
            <PersonalVocabularyRow
              canDrag={!filter}
              entry={item}
              index={index}
              itemCount={entries.length}
              onAutoScroll={autoScroll}
              onMove={(destination) => moveEntry(item, destination)}
              onShowMenu={() => showMenu(item)}
              scrollOffset={scrollOffset}
            />
          )}
          scrollEventThrottle={16}
        />
      </AppScreen>

      <AppBottomActionBar>
        <Button
          accessibilityLabel="Add personal vocabulary"
          className="h-14 rounded-2xl"
          onPress={() => router.push("./personal-vocabulary-add")}
          testID="personal-vocabulary-open-add"
        >
          <SymbolView name="plus" size={17} tintColor="#ffffff" />
          <Text className="text-base font-bold">Add Vocabulary</Text>
        </Button>
      </AppBottomActionBar>
    </View>
  );
}

function VocabularyEmptyState({ searching }: { searching: boolean }) {
  return (
    <View className="items-center gap-3 px-8 py-24">
      <SymbolView
        name={searching ? "magnifyingglass" : "text.badge.plus"}
        size={38}
        tintColor="#59606d"
      />
      <Text className="text-xl font-bold">
        {searching ? "No matches" : "No personal vocabulary yet"}
      </Text>
      <Text className="text-muted-foreground text-center text-sm leading-5">
        {searching
          ? "Try another word or completion."
          : "TimberVox learns unusual words as you type. You can also add one directly."}
      </Text>
    </View>
  );
}
