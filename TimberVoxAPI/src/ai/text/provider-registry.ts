import { createAnthropic } from "@ai-sdk/anthropic";
import { createCerebras } from "@ai-sdk/cerebras";
import { createDeepSeek } from "@ai-sdk/deepseek";
import { createGoogle } from "@ai-sdk/google";
import { createGroq } from "@ai-sdk/groq";
import { createMistral } from "@ai-sdk/mistral";
import { createOpenAI } from "@ai-sdk/openai";
import { createProviderRegistry, type LanguageModel } from "ai";
import { createZhipu } from "zhipu-ai-provider";

import type { Env } from "../../bindings";
import { resolveLanguageModelRoute } from "../models/language-models";
import type { LanguageModelProviderId } from "../models/types";

const languageProviderApiKey = (
  env: Env,
  provider: LanguageModelProviderId
): string | undefined => {
  switch (provider) {
    case "anthropic":
      return env.ANTHROPIC_API_KEY;
    case "cerebras":
      return env.CEREBRAS_API_KEY;
    case "deepseek":
      return env.DEEPSEEK_API_KEY;
    case "google":
      return env.GOOGLE_GENERATIVE_AI_API_KEY;
    case "groq":
      return env.GROQ_API_KEY;
    case "mistral":
      return env.MISTRAL_API_KEY;
    case "openai":
      return env.OPENAI_API_KEY;
    case "zai":
      return env.ZAI_API_KEY;
    default:
      return;
  }
};

const createLanguageModelProviders = (env: Env) => ({
  anthropic: createAnthropic({ apiKey: env.ANTHROPIC_API_KEY }),
  cerebras: createCerebras({ apiKey: env.CEREBRAS_API_KEY }),
  deepseek: createDeepSeek({ apiKey: env.DEEPSEEK_API_KEY }),
  google: createGoogle({ apiKey: env.GOOGLE_GENERATIVE_AI_API_KEY }),
  groq: createGroq({ apiKey: env.GROQ_API_KEY }),
  mistral: createMistral({ apiKey: env.MISTRAL_API_KEY }),
  openai: createOpenAI({ apiKey: env.OPENAI_API_KEY }),
  zai: createZhipu({
    apiKey: env.ZAI_API_KEY,
    baseURL: "https://api.z.ai/api/paas/v4",
  }),
});

const createAiRegistry = (env: Env) =>
  createProviderRegistry(createLanguageModelProviders(env));

export const resolveLanguageModel = (
  env: Env,
  modelId: string
): LanguageModel => {
  const route = resolveLanguageModelRoute(modelId);
  if (!languageProviderApiKey(env, route.provider)) {
    throw new Error(
      `missing API key for language model provider: ${route.provider}`
    );
  }
  return createAiRegistry(env).languageModel(route.providerModelId);
};
