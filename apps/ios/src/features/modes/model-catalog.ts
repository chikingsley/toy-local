import { configuredApiCredential } from "@/lib/api-credential";

const CATALOG_URL = "https://timbervox.peacockery.studio/v1/models";

// Hermes does not ship Intl.DisplayNames. Keep the presentation mapping local
// while the Worker remains authoritative for which codes each route supports.
const LANGUAGE_NAMES: Readonly<Record<string, string>> = {
  ar: "Arabic",
  ast: "Asturian",
  ba: "Bashkir",
  be: "Belarusian",
  bg: "Bulgarian",
  bn: "Bengali",
  bs: "Bosnian",
  ca: "Catalan",
  ceb: "Cebuano",
  cs: "Czech",
  da: "Danish",
  de: "German",
  el: "Greek",
  en: "English",
  es: "Spanish",
  et: "Estonian",
  fa: "Persian",
  fil: "Filipino",
  fi: "Finnish",
  fr: "French",
  gu: "Gujarati",
  haw: "Hawaiian",
  he: "Hebrew",
  hi: "Hindi",
  ht: "Haitian Creole",
  hr: "Croatian",
  hu: "Hungarian",
  id: "Indonesian",
  it: "Italian",
  ja: "Japanese",
  jw: "Javanese",
  kea: "Kabuverdianu",
  kn: "Kannada",
  ko: "Korean",
  lt: "Lithuanian",
  lv: "Latvian",
  mk: "Macedonian",
  mr: "Marathi",
  ms: "Malay",
  nl: "Dutch",
  no: "Norwegian",
  nso: "Northern Sotho",
  pl: "Polish",
  pt: "Portuguese",
  ro: "Romanian",
  ru: "Russian",
  sk: "Slovak",
  sl: "Slovenian",
  sr: "Serbian",
  su: "Sundanese",
  sv: "Swedish",
  ta: "Tamil",
  te: "Telugu",
  th: "Thai",
  tl: "Filipino",
  tr: "Turkish",
  uk: "Ukrainian",
  ur: "Urdu",
  vi: "Vietnamese",
  yue: "Cantonese",
  zh: "Chinese",
};

export type CatalogRoute = {
  model: string;
  provider: string;
  supportedLanguages: string[];
  supportsAutomaticLanguage: boolean;
  supportsDiarization: boolean;
};

export type TranscriptionModel = {
  batch?: CatalogRoute;
  id: string;
  performance?: {
    accuracy?: string;
    speed?: string;
  };
  provider: string;
  realtime?: CatalogRoute;
  runtime: "cloud" | "local";
};

export type LanguageModel = {
  id: string;
  intelligence?: {
    displayScore: number;
    index: number;
    measuredAt: string;
    profile: string;
    source: "artificial-analysis";
    sourceVersion: string;
  };
  performance?: {
    outputThroughput: string;
  };
  provider: string;
};

export type ModelCatalog = {
  languageModels: LanguageModel[];
  transcriptionModels: TranscriptionModel[];
};

type JsonRecord = Record<string, unknown>;

const LOCAL_TRANSCRIPTION_MODELS: TranscriptionModel[] = [
  {
    batch: {
      model: "parakeet-tdt-ctc-110m-coreml",
      provider: "fluid-audio",
      supportedLanguages: ["en"],
      supportsAutomaticLanguage: false,
      supportsDiarization: false,
    },
    id: "local-parakeet-110m",
    performance: { accuracy: "3.0% WER", speed: "Local · ~452 MB" },
    provider: "nvidia",
    realtime: {
      model: "parakeet-realtime-eou-120m-coreml/320ms",
      provider: "fluid-audio",
      supportedLanguages: ["en"],
      supportsAutomaticLanguage: false,
      supportsDiarization: false,
    },
    runtime: "local",
  },
];

function isRecord(value: unknown): value is JsonRecord {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function parseRoute(value: unknown): CatalogRoute | undefined {
  if (!isRecord(value)) return undefined;
  const supportedLanguages = Array.isArray(value.supported_languages)
    ? value.supported_languages.filter(
        (language): language is string => typeof language === "string",
      )
    : [];
  if (
    typeof value.model !== "string" ||
    typeof value.provider !== "string" ||
    typeof value.supports_automatic_language !== "boolean" ||
    typeof value.supports_diarization !== "boolean" ||
    supportedLanguages.length === 0
  ) {
    return undefined;
  }
  return {
    model: value.model,
    provider: value.provider,
    supportedLanguages,
    supportsAutomaticLanguage: value.supports_automatic_language,
    supportsDiarization: value.supports_diarization,
  };
}

function parseLanguageModelIntelligence(
  value: unknown,
): LanguageModel["intelligence"] {
  if (
    !isRecord(value) ||
    typeof value.display_score !== "number" ||
    !Number.isFinite(value.display_score) ||
    value.display_score < 0 ||
    value.display_score > 10 ||
    typeof value.index !== "number" ||
    !Number.isFinite(value.index) ||
    value.index <= 0 ||
    typeof value.measured_at !== "string" ||
    typeof value.profile !== "string" ||
    value.source !== "artificial-analysis" ||
    typeof value.source_version !== "string"
  ) {
    return undefined;
  }
  return {
    displayScore: value.display_score,
    index: value.index,
    measuredAt: value.measured_at,
    profile: value.profile,
    source: value.source,
    sourceVersion: value.source_version,
  };
}

function metricNumber(value: number) {
  return value.toFixed(2).replace(/\.?0+$/, "");
}

function parseModelAccuracy(value: unknown): string | undefined {
  if (
    !isRecord(value) ||
    value.metric !== "wer" ||
    typeof value.value !== "number" ||
    !Number.isFinite(value.value)
  ) {
    return undefined;
  }
  return `${metricNumber(value.value)}% WER`;
}

function parseModelSpeed(value: unknown): string | undefined {
  if (!isRecord(value) || typeof value.kind !== "string") return undefined;
  if (value.kind === "realtime") return "Realtime";
  if (
    typeof value.value !== "number" ||
    !Number.isFinite(value.value) ||
    value.value < 0
  ) {
    return undefined;
  }
  if (value.kind === "effective-tps") {
    return `~${metricNumber(value.value)} effective tok/s`;
  }
  if (value.kind === "rtfx") {
    return `${metricNumber(value.value)}× realtime`;
  }
  return undefined;
}

function parseModelCatalog(value: unknown): ModelCatalog {
  if (!isRecord(value) || !Array.isArray(value.models)) {
    throw new Error("The model catalog response is invalid.");
  }
  if (value.presentation_schema_version !== 1) {
    throw new Error("The model presentation schema is unsupported.");
  }

  const languageModels: LanguageModel[] = [];
  const transcriptionModels: TranscriptionModel[] = [];
  for (const candidate of value.models) {
    if (
      !isRecord(candidate) ||
      typeof candidate.id !== "string" ||
      typeof candidate.provider !== "string"
    ) {
      continue;
    }
    if (candidate.kind === "language") {
      const outputThroughput = parseModelSpeed(candidate.speed);
      languageModels.push({
        id: candidate.id,
        intelligence: parseLanguageModelIntelligence(candidate.intelligence),
        performance: outputThroughput ? { outputThroughput } : undefined,
        provider: candidate.provider,
      });
      continue;
    }
    if (candidate.kind !== "transcription" || !isRecord(candidate.routes)) {
      continue;
    }
    const batch = parseRoute(candidate.routes.batch);
    const realtime = parseRoute(candidate.routes.realtime);
    if (!batch && !realtime) continue;
    const accuracy = parseModelAccuracy(candidate.accuracy);
    const speed = parseModelSpeed(candidate.speed);
    transcriptionModels.push({
      batch,
      id: candidate.id,
      performance: accuracy || speed ? { accuracy, speed } : undefined,
      provider: candidate.provider,
      realtime,
      runtime: "cloud",
    });
  }

  if (transcriptionModels.length === 0) {
    throw new Error("No supported transcription models are available.");
  }
  return {
    languageModels,
    transcriptionModels: [
      ...transcriptionModels,
      ...LOCAL_TRANSCRIPTION_MODELS,
    ],
  };
}

async function fetchModelCatalog(
  signal?: AbortSignal,
  credential = configuredApiCredential(),
  fetchImplementation: typeof fetch = fetch,
) {
  if (!credential) {
    throw new Error("This build does not have an active TimberVox session.");
  }
  const response = await fetchImplementation(CATALOG_URL, {
    headers: { Authorization: `Bearer ${credential}` },
    signal,
  });
  if (!response.ok) {
    throw new Error(`The model catalog request failed (${response.status}).`);
  }
  return parseModelCatalog(await response.json());
}

function defaultTranscriptionModel(catalog: ModelCatalog) {
  return (
    catalog.transcriptionModels.find(
      (model) => model.provider === "mistral" && model.realtime,
    ) ??
    catalog.transcriptionModels.find((model) => model.realtime) ??
    catalog.transcriptionModels[0]
  );
}

function selectedTranscriptionModel(catalog: ModelCatalog, modelId: string) {
  return catalog.transcriptionModels.find((model) => model.id === modelId);
}

function selectedRoute(
  model: TranscriptionModel | undefined,
  realtimeEnabled = Boolean(model?.realtime),
) {
  if (!model) return undefined;
  if (realtimeEnabled && model.realtime) return model.realtime;
  return model.batch ?? model.realtime;
}

function modelDisplayName(model: TranscriptionModel) {
  if (model.id === "local-parakeet-110m") return "Parakeet Local";
  if (model.id.includes("voxtral")) return "Voxtral Mini";
  if (model.id.includes("nova-3")) return "Nova 3";
  if (model.id.includes("nova-2")) return "Nova 2";
  return model.id;
}

function languageModelDisplayName(model: LanguageModel) {
  const providerPrefix = `${model.provider}-`;
  const providerless = model.id.startsWith(providerPrefix)
    ? model.id.slice(providerPrefix.length)
    : model.id;
  const rawLeaf = providerless.split("/").at(-1) ?? providerless;
  const leaf =
    model.provider === "mistral"
      ? rawLeaf.replace(/-(?:latest|\d{4}|\d+\.\d+)$/i, "")
      : rawLeaf;
  const tokens = leaf.split("-");

  return tokens
    .map((token) => {
      if (/^\d+b$/i.test(token)) return token.toUpperCase();
      if (/^gpt$/i.test(token)) return "GPT";
      if (/^oss$/i.test(token)) return "OSS";
      if (/^qwen\d/i.test(token)) return token.replace(/^qwen/i, "Qwen ");
      if (/^gemini$/i.test(token)) return "Gemini";
      if (/^mistral$/i.test(token)) return "Mistral";
      if (/^ministral$/i.test(token)) return "Ministral";
      if (/^glm$/i.test(token)) return "GLM";
      if (/^zai$/i.test(token)) return "Z.ai";
      return token.charAt(0).toUpperCase() + token.slice(1);
    })
    .join(" ");
}

function languageModelFamilyKey(model: LanguageModel) {
  if (model.provider !== "mistral") return model.id;
  return model.id.replace(/-(?:latest|\d{4}|\d+\.\d+)$/i, "");
}

function languageModelsForPicker(models: LanguageModel[]) {
  const visibleModels = new Map<string, LanguageModel>();

  for (const model of models) {
    const key = languageModelFamilyKey(model);
    const existing = visibleModels.get(key);
    const modelIsPinned = !model.id.endsWith("-latest");
    const existingIsLatest = existing?.id.endsWith("-latest") ?? false;

    if (!existing || (modelIsPinned && existingIsLatest)) {
      visibleModels.set(key, model);
    }
  }

  return [...visibleModels.values()];
}

function providerDisplayName(provider: string) {
  if (provider === "nvidia") return "NVIDIA";
  return provider.charAt(0).toUpperCase() + provider.slice(1);
}

function languageModelIntelligenceScore(
  model: LanguageModel,
  _availableModels: LanguageModel[],
) {
  return model.intelligence?.displayScore;
}

function languageModelDetail(
  model: LanguageModel,
  availableModels: LanguageModel[],
) {
  const intelligenceScore = languageModelIntelligenceScore(
    model,
    availableModels,
  );
  const details = [
    model.performance?.outputThroughput,
    intelligenceScore === undefined
      ? undefined
      : `${intelligenceScore.toFixed(1)}/10 intelligence`,
  ].filter(Boolean);
  return details.join(" · ") || "Intelligence not rated";
}

function languageDisplayName(code: string) {
  if (code === "multi") return "Multilingual";
  const normalizedCode = code.toLocaleLowerCase();
  const baseCode = normalizedCode.split(/[-_]/, 1)[0];
  return (
    LANGUAGE_NAMES[normalizedCode] ??
    LANGUAGE_NAMES[baseCode] ??
    code.toLocaleUpperCase()
  );
}

function transcriptionModelDetail(model: TranscriptionModel) {
  return [
    model.performance?.speed ??
      (model.realtime ? "Realtime" : "After recording"),
    model.performance?.accuracy,
  ]
    .filter(Boolean)
    .join(" · ");
}

export {
  defaultTranscriptionModel,
  fetchModelCatalog,
  languageDisplayName,
  languageModelFamilyKey,
  languageModelDetail,
  languageModelDisplayName,
  languageModelIntelligenceScore,
  languageModelsForPicker,
  modelDisplayName,
  parseModelCatalog,
  selectedRoute,
  selectedTranscriptionModel,
  providerDisplayName,
  transcriptionModelDetail,
};
