import {
  defaultTranscriptionModel,
  selectedRoute,
  selectedTranscriptionModel,
  type ModelCatalog,
} from "@/features/modes/model-catalog";
import type { Mode, ModeDraft } from "@/features/modes/mode-types";
import { PRESET_DEFINITIONS } from "@/features/modes/preset-contracts";

function modeToDraft(mode: Mode): ModeDraft {
  const {
    createdAt: _createdAt,
    isActive: _isActive,
    updatedAt: _updatedAt,
    ...draft
  } = mode;
  return draft;
}

function normalizeModeDraft(
  draft: ModeDraft,
  catalog: ModelCatalog,
): ModeDraft {
  const selected = selectedTranscriptionModel(catalog, draft.asrModelId);
  const model = selected ?? defaultTranscriptionModel(catalog);
  const realtimeEnabled = Boolean(
    model.realtime && (draft.realtimeEnabled || !model.batch),
  );
  const route = selectedRoute(model, realtimeEnabled);
  if (!route) throw new Error("No supported transcription route is available.");

  const language =
    draft.language && route.supportedLanguages.includes(draft.language)
      ? draft.language
      : route.supportsAutomaticLanguage
        ? null
        : route.supportedLanguages[0];
  const preset = PRESET_DEFINITIONS[draft.presetKind];
  const processingModelId = preset.usesProcessing
    ? catalog.languageModels.some(
        (candidate) => candidate.id === draft.processingModelId,
      )
      ? draft.processingModelId
      : (catalog.languageModels[0]?.id ?? null)
    : null;

  return {
    ...draft,
    asrModelId: model.id,
    identifySpeakers: route.supportsDiarization
      ? draft.identifySpeakers
      : false,
    language,
    processingInstructions: preset.usesProcessing
      ? draft.processingInstructions
      : null,
    processingModelId,
    realtimeEnabled,
  };
}

function draftsEqual(left: ModeDraft, right: ModeDraft) {
  return JSON.stringify(left) === JSON.stringify(right);
}

export { draftsEqual, modeToDraft, normalizeModeDraft };
