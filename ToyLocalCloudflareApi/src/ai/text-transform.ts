import { generateText } from "ai";
import { z } from "zod";

import type { Env } from "../bindings";
import {
  type LanguageModelProviderId,
  languageModelRoute,
} from "./model-routes";
import { resolveLanguageModel } from "./registry";

const TextMessage = z
  .object({
    content: z.string().min(1),
    role: z.enum(["assistant", "system", "user"]),
  })
  .strict();

export const TextTransformRequest = z
  .object({
    messages: z.array(TextMessage).min(1),
    model: z.string().min(1),
    providerOptions: z
      .custom<Parameters<typeof generateText>[0]["providerOptions"]>()
      .optional(),
    temperature: z.number().optional(),
  })
  .strict();

export type TextTransformRequest = z.infer<typeof TextTransformRequest>;

export interface TextTransformResult {
  finishReason: string;
  model: string;
  provider: LanguageModelProviderId;
  text: string;
  upstreamModel: string;
  usage: {
    inputTokens: number | undefined;
    outputTokens: number | undefined;
    totalTokens: number | undefined;
  };
  warnings: unknown[] | undefined;
}

export const runTextTransform = async (
  env: Env,
  request: TextTransformRequest
): Promise<TextTransformResult> => {
  const route = languageModelRoute(request.model);
  const model = resolveLanguageModel(env, request.model);
  const result = await generateText({
    messages: request.messages,
    model,
    providerOptions: request.providerOptions,
    temperature: request.temperature,
  });

  return {
    finishReason: result.finishReason,
    model: request.model,
    provider: route.provider,
    text: result.text,
    upstreamModel: route.upstreamModel,
    usage: {
      inputTokens: result.usage.inputTokens,
      outputTokens: result.usage.outputTokens,
      totalTokens: result.usage.totalTokens,
    },
    warnings: result.warnings,
  };
};
