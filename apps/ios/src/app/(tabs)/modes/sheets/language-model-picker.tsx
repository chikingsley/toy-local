import { useRouter } from "expo-router";
import { useMemo } from "react";
import { FlatList } from "react-native";

import {
  APP_FORM_SHEET_CONTENT_STYLE,
  APP_FORM_SHEET_INSET_PROPS,
} from "@/components/app/app-form-sheet";
import { Text } from "@/components/ui/text";
import {
  languageModelDetail,
  languageModelDisplayName,
  languageModelFamilyKey,
  languageModelsForPicker,
} from "@/features/modes/model-catalog";
import { useModeEditor } from "@/features/modes/mode-editor-state";
import { useModes } from "@/features/modes/mode-provider";
import { PickerOption } from "@/features/modes/picker-option";
import { ProviderIcon } from "@/features/modes/provider-icon";

export default function LanguageModelPickerScreen() {
  const router = useRouter();
  const editor = useModeEditor();
  const { catalog } = useModes();
  const languageModels = useMemo(
    () => languageModelsForPicker(catalog?.languageModels ?? []),
    [catalog?.languageModels],
  );
  const defaultModelId = languageModels[0]?.id ?? null;
  const selectedModelId = editor.draft?.processingModelId ?? defaultModelId;
  const selectedModel = catalog?.languageModels.find(
    (model) => model.id === selectedModelId,
  );
  const selectedFamily = selectedModel
    ? languageModelFamilyKey(selectedModel)
    : null;

  return (
    <FlatList
      {...APP_FORM_SHEET_INSET_PROPS}
      className="bg-background flex-1"
      contentContainerStyle={APP_FORM_SHEET_CONTENT_STYLE}
      data={languageModels}
      keyExtractor={(model) => model.id}
      ListFooterComponent={
        <Text className="text-muted-foreground px-1 pt-2 text-xs leading-4">
          Effective speed is visible output divided by the complete TimberVox
          request time. Intelligence uses Artificial Analysis v4.1 model scores
          on a 10-point display scale.
        </Text>
      }
      renderItem={({ item: model }) => (
        <PickerOption
          detail={languageModelDetail(model, languageModels)}
          label={languageModelDisplayName(model)}
          leading={<ProviderIcon provider={model.provider} />}
          onPress={() => {
            editor.patch({ processingModelId: model.id });
            router.back();
          }}
          selected={selectedFamily === languageModelFamilyKey(model)}
          testID={`language-model-option-${model.id}`}
        />
      )}
    />
  );
}
