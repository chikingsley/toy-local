import { generateText, Output } from "ai";
import { z } from "zod";

import { recordUsageEvent } from "../../accounting/usage";
import type { Env } from "../../bindings";
import { resolveLanguageModelRoute } from "../models/language-models";
import type { LanguageModelProviderId } from "../models/types";
import { resolveLanguageModel } from "./provider-registry";

const TextMessage = z
  .object({
    content: z.string().min(1),
    role: z.enum(["assistant", "system", "user"]),
  })
  .strict();

type CallerJsonSchema = Parameters<typeof z.fromJSONSchema>[0];
type CallerObjectJsonSchema = Exclude<CallerJsonSchema, boolean>;

const isObjectRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const CallerObjectSchema = z
  .custom<CallerObjectJsonSchema>(
    isObjectRecord,
    "schema must be a JSON Schema object"
  )
  .superRefine((schema, context) => {
    if (!("type" in schema) || schema.type !== "object") {
      context.addIssue({
        code: "custom",
        message: "output schema root type must be object",
      });
      return;
    }
    try {
      z.fromJSONSchema(schema);
    } catch (error) {
      context.addIssue({
        code: "custom",
        message: `invalid output JSON Schema: ${
          error instanceof Error ? error.message : String(error)
        }`,
      });
    }
  });

const ObjectOutputRequest = z
  .object({
    description: z.string().min(1).max(500).optional(),
    name: z
      .string()
      .min(1)
      .max(64)
      .regex(/^[A-Za-z_][A-Za-z0-9_-]*$/)
      .optional(),
    schema: CallerObjectSchema,
    type: z.literal("object"),
  })
  .strict();

// Dictation delivery is interactive. Let the caller surface an upstream
// failure within the product's ten-second ceiling instead of allowing the AI
// SDK's default retries to turn one slow provider response into a 30-second
// stall.
const providerTimeoutMs = 10_000;

export const TextRequest = z
  .object({
    messages: z.array(TextMessage).min(1),
    model: z.string().min(1),
    output: ObjectOutputRequest.optional(),
    providerOptions: z
      .custom<Parameters<typeof generateText>[0]["providerOptions"]>()
      .optional(),
    temperature: z.number().optional(),
  })
  .strict();

export type TextRequest = z.infer<typeof TextRequest>;

interface TextResultBase {
  finishReason: string;
  model: string;
  provider: LanguageModelProviderId;
  upstreamModel: string;
  usage: {
    inputTokens: number | undefined;
    outputTokens: number | undefined;
    totalTokens: number | undefined;
  };
  warnings: unknown[] | undefined;
}

export type TextResult = TextResultBase &
  (
    | { outputType: "object"; output: Record<string, unknown> }
    | { outputType: "text"; text: string }
  );

export const runText = async (
  env: Env,
  request: TextRequest,
  actor?: { credentialId: string; userId: string }
): Promise<TextResult> => {
  const route = resolveLanguageModelRoute(request.model);
  const model = resolveLanguageModel(env, request.model);
  // AI SDK v7 rejects system-role entries in `messages`; system text must go
  // through `instructions`.
  const systemParts: string[] = [];
  const chatMessages: { content: string; role: "assistant" | "user" }[] = [];
  for (const message of request.messages) {
    if (message.role === "system") {
      systemParts.push(message.content);
    } else {
      chatMessages.push({ content: message.content, role: message.role });
    }
  }
  const instructions =
    systemParts.length > 0 ? systemParts.join("\n\n") : undefined;
  const baseOptions = {
    ...(chatMessages.length > 0
      ? { instructions, messages: chatMessages }
      : { messages: [{ content: instructions ?? "", role: "user" as const }] }),
    maxRetries: 0,
    model,
    providerOptions: request.providerOptions,
    temperature: request.temperature,
    timeout: providerTimeoutMs,
  };
  const providerStart = performance.now();
  const result = request.output
    ? await generateText({
        ...baseOptions,
        output: Output.object({
          description: request.output.description,
          name: request.output.name,
          schema: z.fromJSONSchema(request.output.schema),
        }),
      })
    : await generateText(baseOptions);
  const providerLatencyMs = Math.round(performance.now() - providerStart);

  if (actor) {
    await recordUsageEvent(env, {
      clientId: actor.credentialId,
      inputTokens: result.usage.inputTokens,
      kind: "llm",
      model: request.model,
      outputTokens: result.usage.outputTokens,
      provider: route.provider,
      providerLatencyMs,
      route: "/v1/text",
      status: 200,
      totalTokens: result.usage.totalTokens,
      upstreamModel: route.upstreamModel,
      userId: actor.userId,
    });
  }

  const common = {
    finishReason: result.finishReason,
    model: request.model,
    provider: route.provider,
    upstreamModel: route.upstreamModel,
    usage: {
      inputTokens: result.usage.inputTokens,
      outputTokens: result.usage.outputTokens,
      totalTokens: result.usage.totalTokens,
    },
    warnings: result.warnings,
  };
  if (request.output) {
    const parsed = z.fromJSONSchema(request.output.schema).parse(result.output);
    if (!isObjectRecord(parsed)) {
      throw new Error("text object output was not an object");
    }
    return { ...common, output: parsed, outputType: "object" };
  }
  return {
    ...common,
    outputType: "text",
    text: result.text.trim(),
  };
};
