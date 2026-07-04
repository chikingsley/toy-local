export type LanguageModelProviderId =
  | "anthropic"
  | "cerebras"
  | "deepseek"
  | "google"
  | "groq"
  | "mistral"
  | "openai"
  | "zai";

export type TranscriptionProviderId =
  | "assemblyai"
  | "deepgram"
  | "elevenlabs"
  | "groq"
  | "mistral";

export type RealtimeProviderId = "deepgram" | "mistral";

interface LanguageModelRoute {
  provider: LanguageModelProviderId;
  providerModelId: `${LanguageModelProviderId}:${string}`;
  upstreamModel: string;
}

interface TranscriptionModelRoute {
  provider: TranscriptionProviderId;
  providerModelId: `${TranscriptionProviderId}:${string}`;
  upstreamModel: string;
}

export interface RealtimeModelRoute {
  provider: RealtimeProviderId;
  upstreamModel: string;
}

const languageRoutes = <TProvider extends LanguageModelProviderId>(
  provider: TProvider,
  models: readonly string[]
): Record<string, LanguageModelRoute> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        provider,
        providerModelId: `${provider}:${model}`,
        upstreamModel: model,
      },
    ])
  );

const transcriptionRoutes = <TProvider extends TranscriptionProviderId>(
  provider: TProvider,
  models: readonly string[]
): Record<string, TranscriptionModelRoute> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        provider,
        providerModelId: `${provider}:${model}`,
        upstreamModel: model,
      },
    ])
  );

const realtimeRoutes = <TProvider extends RealtimeProviderId>(
  provider: TProvider,
  models: readonly string[]
): Record<string, RealtimeModelRoute> =>
  Object.fromEntries(
    models.map((model) => [
      `${provider}-${model}`,
      {
        provider,
        upstreamModel: model,
      },
    ])
  );

const ANTHROPIC_LANGUAGE_MODELS = [
  "claude-haiku-4-5",
  "claude-haiku-4-5-20251001",
  "claude-opus-4-0",
  "claude-opus-4-20250514",
  "claude-opus-4-1",
  "claude-opus-4-1-20250805",
  "claude-opus-4-5",
  "claude-opus-4-5-20251101",
  "claude-opus-4-6",
  "claude-opus-4-7",
  "claude-opus-4-8",
  "claude-fable-5",
  "claude-sonnet-4-0",
  "claude-sonnet-4-20250514",
  "claude-sonnet-4-5",
  "claude-sonnet-4-5-20250929",
  "claude-sonnet-4-6",
  "claude-sonnet-5",
] as const;

const CEREBRAS_LANGUAGE_MODELS = [
  "gpt-oss-120b",
  "llama3.1-8b",
  "qwen-3-235b-a22b-instruct-2507",
  "qwen-3-235b-a22b-thinking-2507",
  "zai-glm-4.6",
  "zai-glm-4.7",
] as const;

const DEEPSEEK_LANGUAGE_MODELS = [
  "deepseek-chat",
  "deepseek-reasoner",
] as const;

const GOOGLE_LANGUAGE_MODELS = [
  "gemini-pro-latest",
  "gemini-flash-latest",
  "gemini-flash-lite-latest",
  "gemini-3.5-flash",
  "gemini-3.1-pro-preview",
  "gemini-3.1-pro-preview-customtools",
  "gemini-3.1-flash-image-preview",
  "gemini-3.1-flash-lite-preview",
  "gemini-3.1-flash-tts-preview",
  "gemini-3-pro-preview",
  "gemini-3-pro-image-preview",
  "gemini-3-flash-preview",
  "gemini-2.5-pro",
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash-image",
  "gemini-2.5-flash-native-audio-latest",
  "gemini-2.5-flash-native-audio-preview-09-2025",
  "gemini-2.5-flash-native-audio-preview-12-2025",
  "gemini-2.5-computer-use-preview-10-2025",
  "deep-research-pro-preview-12-2025",
  "deep-research-max-preview-04-2026",
  "deep-research-preview-04-2026",
  "nano-banana-pro-preview",
] as const;

const GROQ_LANGUAGE_MODELS = [
  "gemma2-9b-it",
  "llama-3.1-8b-instant",
  "llama-3.3-70b-versatile",
  "meta-llama/llama-guard-4-12b",
  "openai/gpt-oss-120b",
  "openai/gpt-oss-20b",
  "deepseek-r1-distill-llama-70b",
  "meta-llama/llama-4-maverick-17b-128e-instruct",
  "meta-llama/llama-4-scout-17b-16e-instruct",
  "meta-llama/llama-prompt-guard-2-22m",
  "meta-llama/llama-prompt-guard-2-86m",
  "moonshotai/kimi-k2-instruct-0905",
  "qwen/qwen3-32b",
  "llama-guard-3-8b",
  "llama3-70b-8192",
  "llama3-8b-8192",
  "mixtral-8x7b-32768",
  "qwen-qwq-32b",
  "qwen-2.5-32b",
  "deepseek-r1-distill-qwen-32b",
] as const;

const MISTRAL_LANGUAGE_MODELS = [
  "ministral-3b-latest",
  "ministral-8b-latest",
  "ministral-14b-latest",
  "mistral-large-latest",
  "mistral-medium-latest",
  "mistral-medium-3",
  "mistral-large-2512",
  "mistral-medium-2508",
  "mistral-medium-2505",
  "mistral-small-2506",
  "pixtral-large-latest",
  "mistral-medium-3.5",
  "mistral-small-latest",
  "mistral-small-2603",
  "magistral-medium-latest",
  "magistral-small-latest",
  "magistral-medium-2509",
  "magistral-small-2509",
] as const;

const OPENAI_LANGUAGE_MODELS = [
  "gpt-5.5",
  "gpt-5.4",
  "gpt-5.4-mini",
  "gpt-5.4-nano",
  "gpt-5.4-pro",
  "gpt-5.3-chat-latest",
  "gpt-5.3-codex",
  "gpt-5.2",
  "gpt-5.2-chat-latest",
  "gpt-5.2-pro",
  "gpt-5.2-codex",
  "gpt-5.1",
  "gpt-5.1-chat-latest",
  "gpt-5.1-codex-mini",
  "gpt-5.1-codex",
  "gpt-5.1-codex-max",
  "gpt-5",
  "gpt-5-chat-latest",
  "gpt-5-codex",
  "gpt-5-mini",
  "gpt-5-nano",
  "gpt-5-pro",
  "o4-mini",
  "o3",
  "o3-mini",
  "o1",
] as const;

const ZAI_LANGUAGE_MODELS = [
  "glm-4.7",
  "glm-4.7-flash",
  "glm-4.7-flashx",
  "glm-4.6",
  "glm-4.6-flash",
  "glm-4.6-flashx",
  "glm-4.6v",
  "glm-4.6v-flash",
  "glm-4.6v-flashx",
  "glm-4.5",
  "glm-4.5-flash",
  "glm-4.5-flashx",
  "glm-4.5-air",
  "glm-4.5-airx",
  "glm-4.1v-thinking-flash",
  "glm-4.1v-thinking-flashx",
  "glm-z1-air",
  "glm-z1-airx",
  "glm-z1-flash",
] as const;

const ASSEMBLYAI_TRANSCRIPTION_MODELS = ["best", "nano"] as const;

const DEEPGRAM_TRANSCRIPTION_MODELS = [
  "base",
  "base-general",
  "base-meeting",
  "base-phonecall",
  "base-finance",
  "base-conversationalai",
  "base-voicemail",
  "base-video",
  "enhanced",
  "enhanced-general",
  "enhanced-meeting",
  "enhanced-phonecall",
  "enhanced-finance",
  "nova",
  "nova-general",
  "nova-phonecall",
  "nova-medical",
  "nova-2",
  "nova-2-general",
  "nova-2-meeting",
  "nova-2-phonecall",
  "nova-2-finance",
  "nova-2-conversationalai",
  "nova-2-voicemail",
  "nova-2-video",
  "nova-2-medical",
  "nova-2-drivethru",
  "nova-2-automotive",
  "nova-2-atc",
  "nova-3",
  "nova-3-general",
  "nova-3-medical",
] as const;

const ELEVENLABS_TRANSCRIPTION_MODELS = [
  "scribe_v1",
  "scribe_v1_experimental",
  "scribe_v2",
] as const;

const GROQ_TRANSCRIPTION_MODELS = [
  "whisper-large-v3-turbo",
  "whisper-large-v3",
] as const;

const MISTRAL_TRANSCRIPTION_MODELS = [
  "voxtral-mini-latest",
  "voxtral-mini-2507",
  "voxtral-mini-2602",
] as const;

const MISTRAL_REALTIME_MODELS = [
  "voxtral-mini-transcribe-realtime-2602",
] as const;

const LANGUAGE_MODEL_ROUTES = {
  ...languageRoutes("anthropic", ANTHROPIC_LANGUAGE_MODELS),
  ...languageRoutes("cerebras", CEREBRAS_LANGUAGE_MODELS),
  ...languageRoutes("deepseek", DEEPSEEK_LANGUAGE_MODELS),
  ...languageRoutes("google", GOOGLE_LANGUAGE_MODELS),
  ...languageRoutes("groq", GROQ_LANGUAGE_MODELS),
  ...languageRoutes("mistral", MISTRAL_LANGUAGE_MODELS),
  ...languageRoutes("openai", OPENAI_LANGUAGE_MODELS),
  ...languageRoutes("zai", ZAI_LANGUAGE_MODELS),
} as const satisfies Record<string, LanguageModelRoute>;

const TRANSCRIPTION_MODEL_ROUTES = {
  ...transcriptionRoutes("assemblyai", ASSEMBLYAI_TRANSCRIPTION_MODELS),
  ...transcriptionRoutes("deepgram", DEEPGRAM_TRANSCRIPTION_MODELS),
  ...transcriptionRoutes("elevenlabs", ELEVENLABS_TRANSCRIPTION_MODELS),
  ...transcriptionRoutes("groq", GROQ_TRANSCRIPTION_MODELS),
  ...transcriptionRoutes("mistral", MISTRAL_TRANSCRIPTION_MODELS),
} as const satisfies Record<string, TranscriptionModelRoute>;

const REALTIME_MODEL_ROUTES = {
  ...realtimeRoutes("deepgram", DEEPGRAM_TRANSCRIPTION_MODELS),
  ...realtimeRoutes("mistral", MISTRAL_REALTIME_MODELS),
} as const satisfies Record<string, RealtimeModelRoute>;

export const languageModelRoute = (modelId: string): LanguageModelRoute => {
  const route =
    LANGUAGE_MODEL_ROUTES[modelId as keyof typeof LANGUAGE_MODEL_ROUTES];
  if (!route) {
    throw new Error(`unsupported language model: ${modelId}`);
  }
  return route;
};

export const transcriptionModelRoute = (
  modelId: string
): TranscriptionModelRoute => {
  const route =
    TRANSCRIPTION_MODEL_ROUTES[
      modelId as keyof typeof TRANSCRIPTION_MODEL_ROUTES
    ];
  if (!route) {
    throw new Error(`unsupported transcription model: ${modelId}`);
  }
  return route;
};

export const realtimeModelRoute = (modelId: string): RealtimeModelRoute => {
  const route =
    REALTIME_MODEL_ROUTES[modelId as keyof typeof REALTIME_MODEL_ROUTES];
  if (!route) {
    throw new Error(`unsupported realtime model: ${modelId}`);
  }
  return route;
};
