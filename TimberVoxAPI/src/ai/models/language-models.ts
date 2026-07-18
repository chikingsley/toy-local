import type {
  LanguageModelCallPolicy,
  LanguageModelEntry,
  LanguageModelExecutionProviderId,
  LanguageModelIntelligence,
  LanguageModelProviderId,
} from "./types";

interface LanguageModelConfig {
  callPolicy: LanguageModelCallPolicy;
  executionModel?: string;
  executionProvider?: LanguageModelExecutionProviderId;
  intelligence?: LanguageModelIntelligence;
  model: string;
}

const artificialAnalysis = (
  index: number,
  profile: string
): LanguageModelIntelligence => ({
  index,
  measuredAt: "2026-07-14",
  profile,
  source: "artificial-analysis",
  sourceVersion: "4.1",
});

const mapLanguageModels = <TProvider extends LanguageModelProviderId>(
  provider: TProvider,
  models: readonly LanguageModelConfig[]
): Record<string, LanguageModelEntry> =>
  Object.fromEntries(
    models.map(
      ({
        callPolicy,
        executionModel,
        executionProvider,
        intelligence,
        model,
      }) => {
        const resolvedExecutionProvider =
          executionProvider ?? directExecutionProvider(provider);
        const resolvedExecutionModel = executionModel ?? model;
        return [
          `${provider}-${model}`,
          {
            callPolicy,
            executionModel: resolvedExecutionModel,
            executionProvider: resolvedExecutionProvider,
            intelligence,
            provider,
            providerModelId:
              `${resolvedExecutionProvider}:${resolvedExecutionModel}` as const,
            upstreamModel: model,
          },
        ];
      }
    )
  );

const directExecutionProvider = (
  provider: LanguageModelProviderId
): LanguageModelExecutionProviderId => {
  if (provider === "grok") {
    throw new Error("Grok routes require an explicit execution provider");
  }
  return provider;
};

const ANTHROPIC_LANGUAGE_MODELS = [
  {
    callPolicy: {
      providerOptions: { anthropic: { thinking: { type: "disabled" } } },
      reasoningProfile: "none",
    },
    executionProvider: "superwhisper",
    intelligence: artificialAnalysis(41.7, "claude-sonnet-5-non-reasoning"),
    model: "claude-sonnet-5",
  },
  {
    callPolicy: {
      providerOptions: { anthropic: { thinking: { type: "disabled" } } },
      reasoningProfile: "none",
    },
    executionProvider: "superwhisper",
    model: "claude-sonnet-4-6",
  },
  {
    callPolicy: {
      providerOptions: { anthropic: { thinking: { type: "disabled" } } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(23.7, "claude-4-5-haiku"),
    model: "claude-haiku-4-5",
  },
] as const satisfies readonly LanguageModelConfig[];

const CEREBRAS_LANGUAGE_MODELS = [
  {
    callPolicy: {
      providerOptions: { cerebras: { reasoningEffort: "low" } },
      reasoningProfile: "low",
    },
    intelligence: artificialAnalysis(14.9, "gpt-oss-120b-low"),
    model: "gpt-oss-120b",
  },
  {
    callPolicy: { reasoningProfile: "none" },
    intelligence: artificialAnalysis(21.8, "gemma-4-31b-non-reasoning"),
    model: "gemma-4-31b",
  },
  {
    callPolicy: {
      providerOptions: { cerebras: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(26.6, "glm-4-7-non-reasoning"),
    model: "zai-glm-4.7",
  },
] as const satisfies readonly LanguageModelConfig[];

const DEEPSEEK_LANGUAGE_MODELS = [
  {
    callPolicy: {
      providerOptions: { deepseek: { thinking: { type: "disabled" } } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(28.7, "deepseek-v4-flash-non-reasoning"),
    model: "deepseek-v4-flash",
  },
  {
    callPolicy: {
      providerOptions: { deepseek: { thinking: { type: "disabled" } } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(31.2, "deepseek-v4-pro-non-reasoning"),
    model: "deepseek-v4-pro",
  },
] as const satisfies readonly LanguageModelConfig[];

const GOOGLE_LANGUAGE_MODELS = [
  {
    callPolicy: {
      providerOptions: {
        google: { thinkingConfig: { thinkingLevel: "minimal" } },
      },
      reasoningProfile: "minimal",
    },
    intelligence: artificialAnalysis(25, "gemini-3.1-flash-lite-minimal"),
    model: "gemini-3.1-flash-lite",
  },
  {
    callPolicy: { reasoningProfile: "none" },
    executionProvider: "superwhisper",
    model: "gemini-3-flash-preview",
  },
  {
    callPolicy: { reasoningProfile: "none" },
    executionProvider: "superwhisper",
    model: "gemini-3.1-flash-lite-preview",
  },
] as const satisfies readonly LanguageModelConfig[];

const GROK_LANGUAGE_MODELS = [
  {
    callPolicy: { reasoningProfile: "none" },
    executionProvider: "superwhisper",
    model: "grok-4-1-fast-non-reasoning",
  },
] as const satisfies readonly LanguageModelConfig[];

const GROQ_LANGUAGE_MODELS = [
  {
    callPolicy: {
      providerOptions: { groq: { reasoningEffort: "low" } },
      reasoningProfile: "low",
    },
    intelligence: artificialAnalysis(14.9, "gpt-oss-120b-low"),
    model: "openai/gpt-oss-120b",
  },
  {
    callPolicy: {
      providerOptions: { groq: { reasoningEffort: "low" } },
      reasoningProfile: "low",
    },
    intelligence: artificialAnalysis(14.3, "gpt-oss-20b-low"),
    model: "openai/gpt-oss-20b",
  },
  {
    callPolicy: {
      providerOptions: { groq: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(30.5, "qwen3-6-27b-non-reasoning"),
    model: "qwen/qwen3.6-27b",
  },
] as const satisfies readonly LanguageModelConfig[];

const MISTRAL_LANGUAGE_MODELS = [
  {
    callPolicy: {
      providerOptions: { mistral: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(30, "mistral-medium-3-5-reasoning"),
    model: "mistral-medium-latest",
  },
  {
    callPolicy: {
      providerOptions: { mistral: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(11, "mistral-small-3-2-non-reasoning"),
    model: "mistral-small-latest",
  },
  {
    callPolicy: { reasoningProfile: "none" },
    intelligence: artificialAnalysis(16, "mistral-large-3-non-reasoning"),
    model: "mistral-large-latest",
  },
] as const satisfies readonly LanguageModelConfig[];

const OPENAI_LANGUAGE_MODELS = [
  {
    callPolicy: {
      providerOptions: { openai: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    executionProvider: "superwhisper",
    model: "gpt-5.2",
  },
  {
    callPolicy: {
      providerOptions: { openai: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    executionProvider: "superwhisper",
    model: "gpt-5.3-chat-latest",
  },
  {
    callPolicy: {
      providerOptions: { openai: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(35.4, "gpt-5-5-non-reasoning"),
    model: "gpt-5.5",
  },
  {
    callPolicy: {
      providerOptions: { openai: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(27.7, "gpt-5-4-non-reasoning"),
    model: "gpt-5.4",
  },
  {
    callPolicy: {
      providerOptions: { openai: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    executionProvider: "superwhisper",
    intelligence: artificialAnalysis(16.6, "gpt-5-4-mini-non-reasoning"),
    model: "gpt-5.4-mini",
  },
  {
    callPolicy: {
      providerOptions: { openai: { reasoningEffort: "none" } },
      reasoningProfile: "none",
    },
    executionProvider: "superwhisper",
    intelligence: artificialAnalysis(17.6, "gpt-5-4-nano-non-reasoning"),
    model: "gpt-5.4-nano",
  },
] as const satisfies readonly LanguageModelConfig[];

const ZAI_LANGUAGE_MODELS = [
  {
    callPolicy: {
      providerOptions: { zhipu: { thinking: { type: "disabled" } } },
      reasoningProfile: "none",
    },
    intelligence: artificialAnalysis(34.1, "glm-5-2-non-reasoning"),
    model: "glm-5.2",
  },
] as const satisfies readonly LanguageModelConfig[];

export const LANGUAGE_MODEL_MAP = {
  ...mapLanguageModels("anthropic", ANTHROPIC_LANGUAGE_MODELS),
  ...mapLanguageModels("cerebras", CEREBRAS_LANGUAGE_MODELS),
  ...mapLanguageModels("deepseek", DEEPSEEK_LANGUAGE_MODELS),
  ...mapLanguageModels("google", GOOGLE_LANGUAGE_MODELS),
  ...mapLanguageModels("grok", GROK_LANGUAGE_MODELS),
  ...mapLanguageModels("groq", GROQ_LANGUAGE_MODELS),
  ...mapLanguageModels("mistral", MISTRAL_LANGUAGE_MODELS),
  ...mapLanguageModels("openai", OPENAI_LANGUAGE_MODELS),
  ...mapLanguageModels("zai", ZAI_LANGUAGE_MODELS),
} as const satisfies Record<string, LanguageModelEntry>;

export const resolveLanguageModelRoute = (
  modelId: string
): LanguageModelEntry => {
  const model = LANGUAGE_MODEL_MAP[modelId as keyof typeof LANGUAGE_MODEL_MAP];
  if (!model) {
    throw new Error(`unsupported language model: ${modelId}`);
  }
  return model;
};
