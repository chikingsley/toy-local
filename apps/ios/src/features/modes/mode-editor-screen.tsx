import { Stack, useRouter } from "expo-router";
import { SymbolView } from "expo-symbols";
import { Fragment, useMemo, useState } from "react";
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  View,
} from "react-native";

import { AppBottomActionBar } from "@/components/app/app-bottom-action-bar";
import { AppScreen } from "@/components/app/app-screen";
import { AppSection } from "@/components/app/app-section";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Switch } from "@/components/ui/switch";
import { Text } from "@/components/ui/text";
import { Textarea } from "@/components/ui/textarea";
import {
  optionalModeFields,
  type OptionalModeField,
} from "@/features/modes/mode-editor-contract";
import { useModeEditor } from "@/features/modes/mode-editor-state";
import {
  languageDisplayName,
  languageModelDisplayName,
  modelDisplayName,
  selectedRoute,
  selectedTranscriptionModel,
} from "@/features/modes/model-catalog";
import { useModes } from "@/features/modes/mode-provider";
import { PRESET_DEFINITIONS } from "@/features/modes/preset-contracts";

function ModeEditorScreen({ isNew }: { isNew: boolean }) {
  const router = useRouter();
  const editor = useModeEditor();
  const modes = useModes();
  const [saving, setSaving] = useState(false);
  const draft = editor.draft;
  const model = useMemo(
    () =>
      draft && modes.catalog
        ? selectedTranscriptionModel(modes.catalog, draft.asrModelId)
        : undefined,
    [draft, modes.catalog],
  );
  const route = selectedRoute(model, draft?.realtimeEnabled);
  const processingModel = useMemo(
    () =>
      modes.catalog?.languageModels.find(
        (candidate) => candidate.id === draft?.processingModelId,
      ) ?? modes.catalog?.languageModels[0],
    [draft?.processingModelId, modes.catalog],
  );

  if (!draft) {
    return (
      <AppScreen contentClassName="items-center justify-center px-6">
        <Text className="text-muted-foreground">Loading mode…</Text>
      </AppScreen>
    );
  }

  const preset = PRESET_DEFINITIONS[draft.presetKind];
  const optionalFields = optionalModeFields({
    presetKind: draft.presetKind,
    supportsDiarization: Boolean(route?.supportsDiarization),
  });
  const settingFields = optionalFields.filter(
    (field) => field !== "instructions",
  );

  const requestRename = () => {
    Alert.prompt(
      "Rename mode",
      undefined,
      [
        { style: "cancel", text: "Cancel" },
        {
          onPress: (value?: string) => {
            const name = value?.trim();
            if (!name) {
              Alert.alert("Name this mode", "A mode name cannot be empty.");
              return;
            }
            editor.patch({ name });
          },
          text: "Save",
        },
      ],
      "plain-text",
      draft.name,
    );
  };

  const activateCurrentMode = async () => {
    if (!draft.name.trim()) {
      Alert.alert("Name this mode", "Enter a name before using the mode.");
      return;
    }
    setSaving(true);
    try {
      const saved = await modes.saveMode({
        ...draft,
        description: draft.description.trim(),
        name: draft.name.trim(),
      });
      await modes.activateMode(saved.id);
      router.dismissAll();
      router.replace("/record");
    } catch (error) {
      Alert.alert(
        "Mode not saved",
        error instanceof Error ? error.message : "Try again.",
      );
    } finally {
      setSaving(false);
    }
  };

  const deleteCurrentMode = () => {
    const stored = modes.modes.find((candidate) => candidate.id === draft.id);
    if (!stored || isNew) return;
    if (stored.isActive) {
      Alert.alert(
        "Choose another mode first",
        "Use a different mode before deleting the active one.",
      );
      return;
    }
    Alert.alert("Delete mode?", `Delete ${stored.name}?`, [
      { style: "cancel", text: "Cancel" },
      {
        onPress: () =>
          void modes.deleteMode(stored.id).then(() => router.back()),
        style: "destructive",
        text: "Delete",
      },
    ]);
  };

  const renderSetting = (field: OptionalModeField) => {
    switch (field) {
      case "identifySpeakers":
        return (
          <SwitchRow
            checked={draft.identifySpeakers}
            label="Identify speakers"
            onCheckedChange={(identifySpeakers) =>
              editor.patch({ identifySpeakers })
            }
            testID="mode-identify-speakers-toggle"
          />
        );
      case "languageModel":
        return (
          <PickerRow
            disabled={!processingModel}
            label="Language model"
            onPress={() => router.push("/modes/sheets/language-model-picker")}
            testID="mode-language-model-picker"
            value={
              processingModel
                ? languageModelDisplayName(processingModel)
                : "Loading…"
            }
          />
        );
      case "instructions":
        return null;
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === "ios" ? "padding" : undefined}
      className="bg-background flex-1"
    >
      <Stack.Screen
        options={{
          headerTitle: () => (
            <ModeEditorHeader
              iconKey={draft.iconKey}
              name={draft.name}
              onChangeIcon={() => router.push("/modes/sheets/icon-picker")}
              onRename={requestRename}
            />
          ),
          title: draft.name,
        }}
      />

      <View className="flex-1">
        <AppScreen
          contentClassName="gap-3 pb-[18px]"
          keyboardShouldPersistTaps="handled"
          scroll
        >
          <AppSection>
            <PickerRow
              detail={preset.defaultDescription}
              label="Preset"
              onPress={() => router.push("/modes/sheets/preset-picker")}
              testID="mode-preset-picker"
              value={preset.defaultName}
            />
            <Separator />
            <PickerRow
              label="Language"
              onPress={() => router.push("/modes/sheets/language-picker")}
              testID="mode-language-picker"
              value={
                draft.language
                  ? languageDisplayName(draft.language)
                  : "Automatic"
              }
            />
          </AppSection>

          <AppSection>
            <PickerRow
              disabled={!modes.catalog}
              label="Voice model"
              onPress={() => router.push("/modes/sheets/model-picker")}
              testID="mode-transcription-model-picker"
              value={
                model
                  ? modelDisplayName(model)
                  : modes.catalogError
                    ? "Unavailable"
                    : "Loading…"
              }
            />
            {model?.batch && model.realtime ? (
              <>
                <Separator />
                <SwitchRow
                  checked={draft.realtimeEnabled}
                  label="Realtime"
                  onCheckedChange={(realtimeEnabled) =>
                    editor.patch({ realtimeEnabled })
                  }
                  testID="mode-realtime-toggle"
                />
              </>
            ) : null}
          </AppSection>

          {modes.catalogError ? (
            <AppSection contentClassName="items-center gap-3 py-4">
              <Text className="text-destructive text-center text-sm">
                {modes.catalogError}
              </Text>
              <Button
                onPress={() => void modes.retryCatalog()}
                size="sm"
                testID="retry-model-catalog"
                variant="outline"
              >
                <Text>Retry Models</Text>
              </Button>
            </AppSection>
          ) : null}

          {settingFields.length > 0 ? (
            <AppSection>
              {settingFields.map((field, index) => (
                <Fragment key={field}>
                  {index > 0 ? <Separator /> : null}
                  {renderSetting(field)}
                </Fragment>
              ))}
            </AppSection>
          ) : null}

          {optionalFields.includes("instructions") ? (
            <AppSection>
              <View className="gap-2 py-3">
                <Text className="font-semibold">Instructions</Text>
                <Textarea
                  accessibilityLabel="Processing instructions"
                  className="bg-muted/35 min-h-[120px] rounded-2xl border-0 shadow-none"
                  onChangeText={(processingInstructions) =>
                    editor.patch({ processingInstructions })
                  }
                  placeholder="How should TimberVox shape the transcript?"
                  value={draft.processingInstructions ?? ""}
                  testID="mode-processing-instructions"
                />
              </View>
            </AppSection>
          ) : null}

          {!isNew ? (
            <AppSection contentClassName="px-0">
              <Pressable
                accessibilityLabel="Delete mode"
                className="active:bg-accent min-h-[58px] flex-row items-center justify-between px-[17px]"
                onPress={deleteCurrentMode}
                testID="delete-mode"
              >
                <Text className="text-destructive font-semibold">
                  Delete this mode
                </Text>
                <SymbolView name="trash" size={18} tintColor="#ff6971" />
              </Pressable>
            </AppSection>
          ) : null}
        </AppScreen>

        <AppBottomActionBar>
          <Button
            accessibilityLabel="Use mode"
            className="h-14 rounded-2xl"
            disabled={saving || !modes.catalog}
            onPress={() => void activateCurrentMode()}
            testID="use-mode"
          >
            <Text className="text-base font-bold">
              {saving ? "Saving…" : "Use Mode"}
            </Text>
          </Button>
        </AppBottomActionBar>
      </View>
    </KeyboardAvoidingView>
  );
}

function ModeEditorHeader({
  iconKey,
  name,
  onChangeIcon,
  onRename,
}: {
  iconKey: string;
  name: string;
  onChangeIcon: () => void;
  onRename: () => void;
}) {
  return (
    <View className="max-w-[248px] flex-row items-center justify-center gap-1">
      <Pressable
        accessibilityLabel="Change mode icon"
        className="active:bg-accent size-8 items-center justify-center rounded-full"
        onPress={onChangeIcon}
        testID="change-mode-icon"
      >
        <SymbolView name={iconKey as never} size={19} tintColor="#f4f6fb" />
      </Pressable>
      <Pressable
        accessibilityLabel={`Rename ${name} mode`}
        className="active:bg-accent min-w-0 flex-row items-center gap-1 rounded-lg px-1.5 py-1"
        onPress={onRename}
        testID="rename-mode"
      >
        <Text
          className="max-w-[164px] text-[17px] font-semibold"
          numberOfLines={1}
        >
          {name}
        </Text>
        <SymbolView name="pencil" size={12} tintColor="#8b929f" />
      </Pressable>
    </View>
  );
}

function PickerRow({
  detail,
  disabled = false,
  label,
  onPress,
  value,
  testID,
}: {
  detail?: string;
  disabled?: boolean;
  label: string;
  onPress: () => void;
  value: string;
  testID?: string;
}) {
  return (
    <Pressable
      className="active:opacity-70 gap-1.5 py-3"
      disabled={disabled}
      onPress={onPress}
      style={{ opacity: disabled ? 0.5 : 1 }}
      testID={testID}
    >
      <View className="min-h-8 flex-row items-center justify-between gap-4">
        <Text className="font-semibold">{label}</Text>
        <View className="min-w-0 flex-1 flex-row items-center justify-end gap-2">
          <Text
            className="text-muted-foreground shrink text-sm"
            numberOfLines={1}
          >
            {value}
          </Text>
          <SymbolView name="chevron.right" size={13} tintColor="#737b89" />
        </View>
      </View>
      {detail ? (
        <Text className="text-muted-foreground pr-6 text-[13px] leading-[18px]">
          {detail}
        </Text>
      ) : null}
    </Pressable>
  );
}

function SwitchRow({
  checked,
  label,
  onCheckedChange,
  testID,
}: {
  checked: boolean;
  label: string;
  onCheckedChange: (checked: boolean) => void;
  testID?: string;
}) {
  return (
    <View className="min-h-[58px] flex-row items-center justify-between gap-4">
      <Text className="font-semibold">{label}</Text>
      <Switch
        checked={checked}
        onCheckedChange={onCheckedChange}
        testID={testID}
      />
    </View>
  );
}

export { ModeEditorHeader, ModeEditorScreen };
