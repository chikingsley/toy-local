import type { ModeDraft, ModePresetKind } from "@/features/modes/mode-types";
import { DEFAULT_TRANSCRIPTION_MODEL_ID } from "@/features/modes/mode-defaults";

type PresetDefinition = {
  defaultDescription: string;
  defaultName: string;
  outputContract: string;
  processingInstructions: string | null;
  suggestedIcon: string;
  usesProcessing: boolean;
};

type TextTransformMessage = {
  content: string;
  role: "system" | "user";
};

type PresetProcessingRequest = {
  messages: TextTransformMessage[];
  model: string;
  temperature: 0;
};

const PRESET_DEFINITIONS: Record<ModePresetKind, PresetDefinition> = {
  voice: {
    defaultDescription:
      "Turn your voice into punctuated text with no AI post-processing.",
    defaultName: "Voice to Text",
    outputContract:
      "Return the canonical speech-to-text result with punctuation and no AI text transformation.",
    processingInstructions: null,
    suggestedIcon: "person.wave.2.fill",
    usesProcessing: false,
  },
  message: {
    defaultDescription: "Turn speech into a concise conversational message.",
    defaultName: "Message",
    outputContract:
      "Return a concise conversational message that preserves the speaker's meaning.",
    processingInstructions:
      "Rewrite the transcript as a concise conversational message. Preserve intent and do not invent facts.",
    suggestedIcon: "message.fill",
    usesProcessing: true,
  },
  mail: {
    defaultDescription:
      "Turn speech into a structured email while preserving your intent.",
    defaultName: "Mail",
    outputContract:
      "Return an email with an appropriate greeting, readable body, and closing without inventing details.",
    processingInstructions:
      "Rewrite the transcript as a clear email. Preserve intent, add only structural email conventions, and do not invent facts.",
    suggestedIcon: "envelope.fill",
    usesProcessing: true,
  },
  note: {
    defaultDescription: "Organize dictated ideas into a readable note.",
    defaultName: "Note",
    outputContract:
      "Return a readable note that organizes the dictated ideas without adding new claims.",
    processingInstructions:
      "Organize the transcript into a readable note. Preserve every material idea and do not invent facts.",
    suggestedIcon: "note.text",
    usesProcessing: true,
  },
  custom: {
    defaultDescription: "Apply your own instructions to the transcript.",
    defaultName: "Custom",
    outputContract:
      "Return text produced by the user's saved processing instructions, grounded only in the transcript.",
    processingInstructions: "",
    suggestedIcon: "slider.horizontal.3",
    usesProcessing: true,
  },
};

const AVAILABLE_PRESETS = Object.keys(PRESET_DEFINITIONS) as ModePresetKind[];

function createModeId() {
  return `mode_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

function createModeDraft(
  presetKind: ModePresetKind = "voice",
  asrModelId = DEFAULT_TRANSCRIPTION_MODEL_ID,
): ModeDraft {
  const preset = PRESET_DEFINITIONS[presetKind];
  return {
    asrModelId,
    description: preset.defaultDescription,
    iconCustomized: false,
    iconKey: preset.suggestedIcon,
    id: createModeId(),
    identifySpeakers: false,
    language: null,
    name: preset.defaultName,
    presetKind,
    processingInstructions: preset.processingInstructions,
    processingModelId: null,
    realtimeEnabled: true,
  };
}

function applyPreset(draft: ModeDraft, presetKind: ModePresetKind): ModeDraft {
  const priorPreset = PRESET_DEFINITIONS[draft.presetKind];
  const nextPreset = PRESET_DEFINITIONS[presetKind];
  return {
    ...draft,
    description:
      draft.description === priorPreset.defaultDescription
        ? nextPreset.defaultDescription
        : draft.description,
    iconKey: draft.iconCustomized ? draft.iconKey : nextPreset.suggestedIcon,
    name:
      draft.name === priorPreset.defaultName
        ? nextPreset.defaultName
        : draft.name,
    presetKind,
    processingInstructions: nextPreset.usesProcessing
      ? nextPreset.processingInstructions
      : null,
    processingModelId: nextPreset.usesProcessing
      ? draft.processingModelId
      : null,
  };
}

function buildPresetProcessingRequest({
  presetKind,
  processingInstructions,
  processingModelId,
  transcript,
}: {
  presetKind: ModePresetKind;
  processingInstructions: string | null;
  processingModelId: string | null;
  transcript: string;
}): PresetProcessingRequest | null {
  const preset = PRESET_DEFINITIONS[presetKind];
  if (!preset.usesProcessing) return null;
  if (!processingModelId) {
    throw new Error("A processing model is required for this preset.");
  }
  const instructions = processingInstructions?.trim();
  if (!instructions) {
    throw new Error("Processing instructions are required for this preset.");
  }
  return {
    messages: [
      { content: instructions, role: "system" },
      { content: transcript, role: "user" },
    ],
    model: processingModelId,
    temperature: 0,
  };
}

function displayedArtifactForPreset({
  presetKind,
  transcript,
  transformedText,
}: {
  presetKind: ModePresetKind;
  transcript: string;
  transformedText?: string | null;
}) {
  const preset = PRESET_DEFINITIONS[presetKind];
  if (!preset.usesProcessing) return transcript;
  const processed = transformedText?.trim();
  if (!processed) {
    throw new Error("A processed artifact is required for this preset.");
  }
  return processed;
}

export {
  applyPreset,
  AVAILABLE_PRESETS,
  buildPresetProcessingRequest,
  createModeDraft,
  displayedArtifactForPreset,
  PRESET_DEFINITIONS,
};
export type { PresetProcessingRequest };
