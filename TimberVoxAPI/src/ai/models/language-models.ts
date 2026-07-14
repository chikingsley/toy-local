import type { LanguageModelEntry, LanguageModelProviderId } from "./types";

const mapLanguageModels = <TProvider extends LanguageModelProviderId>(
  provider: TProvider,
  models: readonly string[]
): Record<string, LanguageModelEntry> =>
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

const ANTHROPIC_LANGUAGE_MODEL_IDS = [
  "claude-fable-5",
  "claude-opus-4-8",
  "claude-sonnet-5",
  "claude-haiku-4-5",
] as const;

const CEREBRAS_LANGUAGE_MODEL_IDS = [
  "gpt-oss-120b",
  "gemma-4-31b",
  "zai-glm-4.7",
] as const;

const DEEPSEEK_LANGUAGE_MODEL_IDS = [
  "deepseek-v4-flash",
  "deepseek-v4-pro",
] as const;

const GOOGLE_LANGUAGE_MODEL_IDS = ["gemini-3.1-flash-lite"] as const;

const GROQ_LANGUAGE_MODEL_IDS = [
  "openai/gpt-oss-120b",
  "openai/gpt-oss-20b",
  "qwen/qwen3.6-27b",
] as const;

const MISTRAL_LANGUAGE_MODEL_IDS = [
  "mistral-medium-3.5",
  "mistral-medium-latest",
  "mistral-small-2603",
  "mistral-small-latest",
  "mistral-large-2512",
  "mistral-large-latest",
  "ministral-14b-2512",
  "ministral-14b-latest",
] as const;

const OPENAI_LANGUAGE_MODEL_IDS = [
  "gpt-5.5",
  "gpt-5.4",
  "gpt-5.4-pro",
  "gpt-5.4-mini",
  "gpt-5.4-nano",
] as const;

const ZAI_LANGUAGE_MODEL_IDS = ["glm-5.2"] as const;

export const LANGUAGE_MODEL_MAP = {
  ...mapLanguageModels("anthropic", ANTHROPIC_LANGUAGE_MODEL_IDS),
  ...mapLanguageModels("cerebras", CEREBRAS_LANGUAGE_MODEL_IDS),
  ...mapLanguageModels("deepseek", DEEPSEEK_LANGUAGE_MODEL_IDS),
  ...mapLanguageModels("google", GOOGLE_LANGUAGE_MODEL_IDS),
  ...mapLanguageModels("groq", GROQ_LANGUAGE_MODEL_IDS),
  ...mapLanguageModels("mistral", MISTRAL_LANGUAGE_MODEL_IDS),
  ...mapLanguageModels("openai", OPENAI_LANGUAGE_MODEL_IDS),
  ...mapLanguageModels("zai", ZAI_LANGUAGE_MODEL_IDS),
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
