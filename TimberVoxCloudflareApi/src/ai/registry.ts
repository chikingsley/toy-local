import { createAnthropic } from "@ai-sdk/anthropic";
import { createAssemblyAI } from "@ai-sdk/assemblyai";
import { createCerebras } from "@ai-sdk/cerebras";
import { createDeepgram } from "@ai-sdk/deepgram";
import { createDeepSeek } from "@ai-sdk/deepseek";
import { createElevenLabs } from "@ai-sdk/elevenlabs";
import { createGoogle } from "@ai-sdk/google";
import { createGroq } from "@ai-sdk/groq";
import { createMistral } from "@ai-sdk/mistral";
import { createOpenAI } from "@ai-sdk/openai";
import {
  createProviderRegistry,
  type LanguageModel,
  type TranscriptionModel,
} from "ai";
import { createZhipu } from "zhipu-ai-provider";

import type { Env } from "../bindings";
import { createMistralProvider } from "./mistral/provider";
import {
  languageModelRoute,
  type TranscriptionProviderId,
  transcriptionModelRoute,
} from "./model-routes";

type LanguageModelProviderId =
  | "anthropic"
  | "cerebras"
  | "deepseek"
  | "google"
  | "groq"
  | "mistral"
  | "openai"
  | "zai";

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

const transcriptionProviderApiKey = (
  env: Env,
  provider: TranscriptionProviderId
): string | undefined => {
  switch (provider) {
    case "assemblyai":
      return env.ASSEMBLYAI_API_KEY;
    case "deepgram":
      return env.DEEPGRAM_API_KEY;
    case "elevenlabs":
      return env.ELEVENLABS_API_KEY;
    case "groq":
      return env.GROQ_API_KEY;
    case "mistral":
      return env.MISTRAL_API_KEY;
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

const createTranscriptionProviders = (env: Env) => ({
  assemblyai: createAssemblyAI({ apiKey: env.ASSEMBLYAI_API_KEY }),
  deepgram: createDeepgram({ apiKey: env.DEEPGRAM_API_KEY }),
  elevenlabs: createElevenLabs({ apiKey: env.ELEVENLABS_API_KEY }),
  groq: createGroq({ apiKey: env.GROQ_API_KEY }),
  mistral: createMistralProvider({ apiKey: env.MISTRAL_API_KEY }),
});

const createAiRegistry = (env: Env) =>
  createProviderRegistry(createLanguageModelProviders(env));

const createTranscriptionRegistry = (env: Env) =>
  createProviderRegistry(createTranscriptionProviders(env));

export const resolveLanguageModel = (
  env: Env,
  modelId: string
): LanguageModel => {
  const route = languageModelRoute(modelId);
  if (!languageProviderApiKey(env, route.provider)) {
    throw new Error(
      `missing API key for language model provider: ${route.provider}`
    );
  }
  return createAiRegistry(env).languageModel(route.providerModelId);
};

export const resolveTranscriptionModel = (
  env: Env,
  modelId: string
): TranscriptionModel => {
  const route = transcriptionModelRoute(modelId);
  if (!transcriptionProviderApiKey(env, route.provider)) {
    throw new Error(
      `missing API key for transcription model provider: ${route.provider}`
    );
  }
  return createTranscriptionRegistry(env).transcriptionModel(
    route.providerModelId
  );
};
