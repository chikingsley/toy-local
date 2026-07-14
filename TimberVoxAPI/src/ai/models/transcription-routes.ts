import {
  deepgramNova2Languages,
  deepgramNova3Languages,
  elevenLabsScribeV2Languages,
  mistralVoxtralLanguages,
} from "./asr-languages";
import type {
  AcceptedAsrOptionName,
  BatchAsrModelEntry,
  BatchAsrProviderId,
  RealtimeAsrModelEntry,
  RealtimeAsrProviderId,
} from "./types";

const deepgramBatchOptions = [
  "language",
  "detectLanguage",
  "smartFormat",
  "punctuate",
  "paragraphs",
  "summarize",
  "topics",
  "intents",
  "sentiment",
  "detectEntities",
  "redact",
  "replace",
  "search",
  "keyterm",
  "diarize",
  "utterances",
  "uttSplit",
  "fillerWords",
] as const;

const elevenLabsBatchOptions = [
  "languageCode",
  "tagAudioEvents",
  "numSpeakers",
  "timestampsGranularity",
  "diarize",
  "fileFormat",
] as const;

const mistralBatchOptions = [
  "contextBias",
  "diarize",
  "language",
  "temperature",
  "timestampGranularities",
] as const;

const deepgramRealtimeOptions = [
  "channels",
  "detect_entities",
  "diarize",
  "diarize_model",
  "dictation",
  "encoding",
  "endpointing",
  "filler_words",
  "interim_results",
  "keyterm",
  "keywords",
  "language",
  "mip_opt_out",
  "multichannel",
  "numerals",
  "profanity_filter",
  "punctuate",
  "redact",
  "replace",
  "sample_rate",
  "search",
  "smart_format",
  "tag",
  "utterance_end_ms",
  "vad_events",
  "version",
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
  models: TModels,
  supportedLanguagesByModel: Record<TModels[number], readonly string[]>,
  acceptedOptions: readonly AcceptedAsrOptionName[]
): Record<string, BatchAsrModelEntry> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        acceptedOptions,
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
  models: TModels,
  supportedLanguagesByModel: Record<TModels[number], readonly string[]>,
  acceptedOptions: readonly AcceptedAsrOptionName[]
): Record<string, RealtimeAsrModelEntry> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        acceptedOptions,
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
    ["nova-3", "nova-2"],
    {
      "nova-2": deepgramNova2Languages,
      "nova-3": deepgramNova3Languages,
    },
    deepgramBatchOptions
  ),
  ...mapBatchRoutes(
    "elevenlabs",
    ["scribe_v2"],
    { scribe_v2: elevenLabsScribeV2Languages },
    elevenLabsBatchOptions
  ),
  ...mapBatchRoutes(
    "mistral",
    ["voxtral-mini-latest"],
    { "voxtral-mini-latest": mistralVoxtralLanguages },
    mistralBatchOptions
  ),
} as const satisfies Record<string, BatchAsrModelEntry>;

export const REALTIME_ASR_MODEL_MAP = {
  ...mapRealtimeRoutes(
    "deepgram",
    ["nova-3", "nova-2"],
    {
      "nova-2": deepgramNova2Languages,
      "nova-3": deepgramNova3Languages,
    },
    deepgramRealtimeOptions
  ),
  ...mapRealtimeRoutes(
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
