import { generateText, Output, streamText } from "ai";
import { z } from "zod";

import { recordUsageEvent } from "../../accounting/usage";
import type { Env } from "../../bindings";
import { resolveLanguageModelRoute } from "../models/language-models";
import type { LanguageModelProviderId } from "../models/types";
import { normalizeProviderFailure } from "../provider-failure";
import { enforceLanguageModelCallPolicy } from "./call-policy";
import { resolveLanguageModel } from "./provider-registry";
import {
  type TextStreamEvent,
  textStreamCompletedEvent,
  textStreamDeltaEvent,
  textStreamFailedEvent,
  textStreamStartedEvent,
} from "./stream-protocol";

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
    maxOutputTokens: z.number().int().positive().optional(),
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

export const TextStreamRequest = TextRequest.omit({ output: true }).strict();

export type TextStreamRequest = z.infer<typeof TextStreamRequest>;

interface TextResultBase {
  finishReason: string;
  model: string;
  provider: LanguageModelProviderId;
  providerLatencyMs: number;
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

const prepareTextCall = (env: Env, request: TextRequest) => {
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
  const callPolicy = enforceLanguageModelCallPolicy({
    callerProviderOptions: request.providerOptions,
    callerTemperature: request.temperature,
    route,
  });
  const baseOptions = {
    ...(chatMessages.length > 0
      ? { instructions, messages: chatMessages }
      : { messages: [{ content: instructions ?? "", role: "user" as const }] }),
    maxOutputTokens: request.maxOutputTokens,
    maxRetries: 0,
    model,
    providerOptions: callPolicy.providerOptions,
    temperature: callPolicy.temperature,
    timeout: providerTimeoutMs,
  };
  return { baseOptions, route };
};

export const runText = async (
  env: Env,
  request: TextRequest,
  actor?: { credentialId: string; userId: string }
): Promise<TextResult> => {
  const { baseOptions, route } = prepareTextCall(env, request);
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
      provider: route.executionProvider,
      providerLatencyMs,
      route: "/v1/text",
      status: 200,
      totalTokens: result.usage.totalTokens,
      upstreamModel: route.executionModel,
      userId: actor.userId,
    });
  }

  const common = {
    finishReason: result.finishReason,
    model: request.model,
    provider: route.provider,
    providerLatencyMs,
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

type TextStreamEmitter = (event: TextStreamEvent) => Promise<void>;

export const runTextStream = async (
  env: Env,
  request: TextStreamRequest,
  actor: { credentialId: string; userId: string },
  emit: TextStreamEmitter
): Promise<void> => {
  const { baseOptions, route } = prepareTextCall(env, request);
  let sequence = 0;
  await emit(
    textStreamStartedEvent({
      model: request.model,
      provider: route.provider,
      sequence,
      upstreamModel: route.upstreamModel,
    })
  );
  sequence += 1;

  const providerStart = performance.now();
  let providerError: unknown;
  let hasVisibleText = false;
  try {
    const result = streamText({
      ...baseOptions,
      onError: ({ error }) => {
        providerError = error;
      },
    });
    for await (const delta of result.textStream) {
      hasVisibleText ||= delta.trim().length > 0;
      await emit(textStreamDeltaEvent(delta, sequence));
      sequence += 1;
    }
    const step = await result.finalStep;
    const providerLatencyMs = Math.round(performance.now() - providerStart);
    if (!hasVisibleText) {
      const message =
        "Provider completed without emitting user-visible text after the route reasoning policy was applied";
      await recordUsageEvent(env, {
        clientId: actor.credentialId,
        error: message,
        inputTokens: step.usage.inputTokens,
        kind: "llm",
        model: request.model,
        outputTokens: step.usage.outputTokens,
        provider: route.executionProvider,
        providerLatencyMs,
        route: "/v1/text/stream",
        status: 502,
        totalTokens: step.usage.totalTokens,
        upstreamModel: route.executionModel,
        userId: actor.userId,
      });
      await emit(
        textStreamFailedEvent({
          category: "empty_output",
          code: "empty_output",
          message,
          model: request.model,
          provider: route.provider,
          providerLatencyMs,
          retryable: false,
          sequence,
          upstreamModel: route.upstreamModel,
        })
      );
      return;
    }
    await recordUsageEvent(env, {
      clientId: actor.credentialId,
      inputTokens: step.usage.inputTokens,
      kind: "llm",
      model: request.model,
      outputTokens: step.usage.outputTokens,
      provider: route.executionProvider,
      providerLatencyMs,
      route: "/v1/text/stream",
      status: 200,
      totalTokens: step.usage.totalTokens,
      upstreamModel: route.executionModel,
      userId: actor.userId,
    });
    await emit(
      textStreamCompletedEvent({
        finishReason: step.finishReason,
        model: request.model,
        performance: {
          effective_output_tokens_per_second:
            step.performance.effectiveOutputTokensPerSecond,
          output_tokens_per_second: step.performance.outputTokensPerSecond,
          response_time_ms: step.performance.responseTimeMs,
          step_time_ms: step.performance.stepTimeMs,
          time_to_first_output_ms: step.performance.timeToFirstOutputMs,
        },
        provider: route.provider,
        providerLatencyMs,
        responseModelId: step.response.modelId,
        sequence,
        upstreamModel: route.upstreamModel,
        usage: {
          input_tokens: step.usage.inputTokens,
          output_tokens: step.usage.outputTokens,
          reasoning_tokens: step.usage.outputTokenDetails.reasoningTokens,
          text_tokens: step.usage.outputTokenDetails.textTokens,
          total_tokens: step.usage.totalTokens,
        },
        warnings: step.warnings,
      })
    );
  } catch (error) {
    const resolvedError = providerError ?? error;
    const failure = normalizeProviderFailure(resolvedError);
    const providerLatencyMs = Math.round(performance.now() - providerStart);
    await recordUsageEvent(env, {
      clientId: actor.credentialId,
      error: failure.message,
      kind: "llm",
      model: request.model,
      provider: route.executionProvider,
      providerLatencyMs,
      route: "/v1/text/stream",
      status: failure.statusCode ?? 502,
      upstreamModel: route.executionModel,
      userId: actor.userId,
    });
    await emit(
      textStreamFailedEvent({
        category: failure.category,
        code: "provider_error",
        message: failure.message,
        model: request.model,
        provider: route.provider,
        providerCode: failure.providerCode,
        providerLatencyMs,
        retryAfterMs: failure.retryAfterMs,
        retryable: failure.retryable,
        sequence,
        statusCode: failure.statusCode,
        upstreamModel: route.upstreamModel,
      })
    );
  }
};
