import { createAnthropic } from "@ai-sdk/anthropic";
import { createCerebras } from "@ai-sdk/cerebras";
import { createDeepSeek } from "@ai-sdk/deepseek";
import { createGoogle } from "@ai-sdk/google";
import { createGroq } from "@ai-sdk/groq";
import { createMistral } from "@ai-sdk/mistral";
import { createOpenAI } from "@ai-sdk/openai";
import { createSuperwhisper } from "@chikingsley/superwhisper-provider";
import { createProviderRegistry, type LanguageModel } from "ai";
import { createZhipu } from "zhipu-ai-provider";

import type { Env } from "../../bindings";
import { resolveLanguageModelRoute } from "../models/language-models";
import type { LanguageModelExecutionProviderId } from "../models/types";
import {
  superwhisperCredentials,
  superwhisperIsConfigured,
} from "../superwhisper/config";

const languageProviderIsConfigured = (
  env: Env,
  provider: LanguageModelExecutionProviderId
): boolean => {
  switch (provider) {
    case "anthropic":
      return Boolean(env.ANTHROPIC_API_KEY);
    case "cerebras":
      return Boolean(env.CEREBRAS_API_KEY);
    case "deepseek":
      return Boolean(env.DEEPSEEK_API_KEY);
    case "google":
      return Boolean(env.GOOGLE_GENERATIVE_AI_API_KEY);
    case "groq":
      return Boolean(env.GROQ_API_KEY);
    case "mistral":
      return Boolean(env.MISTRAL_API_KEY);
    case "openai":
      return Boolean(env.OPENAI_API_KEY);
    case "superwhisper":
      return superwhisperIsConfigured(env);
    case "zai":
      return Boolean(env.ZAI_API_KEY);
    default:
      return false;
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
  superwhisper: createSuperwhisper({
    credentials: superwhisperCredentials(env),
  }),
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
  if (!languageProviderIsConfigured(env, route.executionProvider)) {
    throw new Error(
      `missing credentials for language model execution provider: ${route.executionProvider}`
    );
  }
  return createAiRegistry(env).languageModel(route.providerModelId);
};
