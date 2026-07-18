import {
  deepgramNova2Languages,
  deepgramNova3Languages,
  elevenLabsScribeV2Languages,
  mistralVoxtralLanguages,
} from "./asr-languages";
import type {
  AcceptedAsrOptionName,
  BatchAsrExecutionProviderId,
  BatchAsrModelEntry,
  BatchAsrProviderId,
  RealtimeAsrExecutionProviderId,
  RealtimeAsrModelEntry,
  RealtimeAsrProviderId,
} from "./types";

const mistralBatchOptions = [
  "contextBias",
  "diarize",
  "language",
  "temperature",
  "timestampGranularities",
] as const;

const superwhisperDeepgramBatchOptions = [
  "diarize",
  "keyterm",
  "language",
] as const;

const superwhisperScribeBatchOptions = [
  "diarize",
  "keyterms",
  "languageCode",
] as const;

const superwhisperBatchOptions = ["keyterms", "language"] as const;

const superwhisperDeepgramRealtimeOptions = [
  "diarize",
  "encoding",
  "keyterm",
  "keywords",
  "language",
  "sample_rate",
] as const;

const superwhisperScribeRealtimeOptions = [
  "encoding",
  "keyterm",
  "keywords",
  "language",
  "sample_rate",
] as const;

const mistralRealtimeOptions = [
  "audio_format.encoding",
  "audio_format.sample_rate",
  "target_streaming_delay_ms",
] as const;

const mapBatchRoutes = <
  TProvider extends BatchAsrProviderId,
  const TModels extends readonly string[],
>(
  provider: TProvider,
  executionProvider: BatchAsrExecutionProviderId,
  models: TModels,
  supportedLanguagesByModel: Record<TModels[number], readonly string[]>,
  acceptedOptions: readonly AcceptedAsrOptionName[],
  executionModelsByModel: Partial<Record<TModels[number], string>> = {}
): Record<string, BatchAsrModelEntry> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        acceptedOptions,
        executionModel:
          executionModelsByModel[model as TModels[number]] ?? model,
        executionProvider,
        provider,
        supportedLanguages: supportedLanguagesByModel[model as TModels[number]],
        supportsAutomaticLanguage: true,
        upstreamModel: model,
      },
    ])
  );

const mapRealtimeRoutes = <
  TProvider extends RealtimeAsrProviderId,
  const TModels extends readonly string[],
>(
  provider: TProvider,
  executionProvider: RealtimeAsrExecutionProviderId,
  models: TModels,
  supportedLanguagesByModel: Record<TModels[number], readonly string[]>,
  acceptedOptions: readonly AcceptedAsrOptionName[],
  executionModelsByModel: Partial<Record<TModels[number], string>> = {}
): Record<string, RealtimeAsrModelEntry> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        acceptedOptions,
        executionModel:
          executionModelsByModel[model as TModels[number]] ?? model,
        executionProvider,
        provider,
        supportedLanguages: supportedLanguagesByModel[model as TModels[number]],
        supportsAutomaticLanguage: true,
        upstreamModel: model,
      },
    ])
  );

export const BATCH_ASR_MODEL_MAP = {
  ...mapBatchRoutes(
    "deepgram",
    "superwhisper",
    ["nova-3", "nova-2", "nova-2-medical"],
    {
      "nova-2": deepgramNova2Languages,
      "nova-2-medical": ["en"],
      "nova-3": deepgramNova3Languages,
    },
    superwhisperDeepgramBatchOptions,
    {
      "nova-2": "sw-deepgram-nova-2",
      "nova-2-medical": "sw-deepgram-nova-2-medical",
      "nova-3": "sw-deepgram-nova-3",
    }
  ),
  ...mapBatchRoutes(
    "elevenlabs",
    "superwhisper",
    ["scribe_v2"],
    { scribe_v2: elevenLabsScribeV2Languages },
    superwhisperScribeBatchOptions,
    { scribe_v2: "sw-elevenlabs-scribe" }
  ),
  ...mapBatchRoutes(
    "mistral",
    "mistral",
    ["voxtral-mini-latest"],
    { "voxtral-mini-latest": mistralVoxtralLanguages },
    mistralBatchOptions
  ),
  ...mapBatchRoutes(
    "superwhisper",
    "superwhisper",
    ["ultra-cloud-v1-east", "sv-1"],
    { "sv-1": [], "ultra-cloud-v1-east": [] },
    superwhisperBatchOptions,
    {
      "sv-1": "sv-1",
      "ultra-cloud-v1-east": "sw-ultra-cloud-v1-east",
    }
  ),
} as const satisfies Record<string, BatchAsrModelEntry>;

export const REALTIME_ASR_MODEL_MAP = {
  ...mapRealtimeRoutes(
    "deepgram",
    "superwhisper",
    ["nova-3", "nova-2", "nova-2-medical"],
    {
      "nova-2": deepgramNova2Languages,
      "nova-2-medical": ["en"],
      "nova-3": deepgramNova3Languages,
    },
    superwhisperDeepgramRealtimeOptions,
    {
      "nova-2": "sw-deepgram-nova-2",
      "nova-2-medical": "sw-deepgram-nova-2-medical",
      "nova-3": "sw-deepgram-nova-3",
    }
  ),
  ...mapRealtimeRoutes(
    "elevenlabs",
    "superwhisper",
    ["scribe_v2"],
    { scribe_v2: elevenLabsScribeV2Languages },
    superwhisperScribeRealtimeOptions,
    { scribe_v2: "sw-elevenlabs-scribe" }
  ),
  ...mapRealtimeRoutes(
    "mistral",
    "mistral",
    ["voxtral-mini-transcribe-realtime-2602"],
    {
      "voxtral-mini-transcribe-realtime-2602": mistralVoxtralLanguages,
    },
    mistralRealtimeOptions
  ),
} as const satisfies Record<string, RealtimeAsrModelEntry>;

export const resolveBatchAsrModel = (modelId: string): BatchAsrModelEntry => {
  const model =
    BATCH_ASR_MODEL_MAP[modelId as keyof typeof BATCH_ASR_MODEL_MAP];
  if (!model) {
    throw new Error(`unsupported transcription model: ${modelId}`);
  }
  return model;
};

export const resolveRealtimeAsrModel = (
  modelId: string
): RealtimeAsrModelEntry => {
  const model =
    REALTIME_ASR_MODEL_MAP[modelId as keyof typeof REALTIME_ASR_MODEL_MAP];
  if (!model) {
    throw new Error(`unsupported realtime model: ${modelId}`);
  }
  return model;
};

export const resolveRealtimeLanguage = (
  route: RealtimeAsrModelEntry,
  requestedLanguage: string | undefined
): string | undefined =>
  requestedLanguage ?? (route.provider === "deepgram" ? "multi" : undefined);
