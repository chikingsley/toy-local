import type { LanguageModelProviderId } from "../models/types";
import type { ProviderFailureCategory } from "../provider-failure";

const TEXT_STREAM_PROTOCOL_VERSION = 1 as const;

interface TextStreamEventBase {
  protocol_version: typeof TEXT_STREAM_PROTOCOL_VERSION;
  sequence: number;
}

export interface TextStreamStartedEvent extends TextStreamEventBase {
  model: string;
  provider: LanguageModelProviderId;
  type: "stream.started";
  upstream_model: string;
}

export interface TextStreamDeltaEvent extends TextStreamEventBase {
  delta: string;
  type: "text.delta";
}

export interface TextStreamCompletedEvent extends TextStreamEventBase {
  finish_reason: string;
  model: string;
  performance: {
    effective_output_tokens_per_second: number;
    output_tokens_per_second: number | undefined;
    response_time_ms: number;
    step_time_ms: number;
    time_to_first_output_ms: number | undefined;
  };
  provider: LanguageModelProviderId;
  provider_latency_ms: number;
  response_model_id: string;
  type: "stream.completed";
  upstream_model: string;
  usage: {
    input_tokens: number | undefined;
    output_tokens: number | undefined;
    reasoning_tokens: number | undefined;
    text_tokens: number | undefined;
    total_tokens: number | undefined;
  };
  warnings: unknown[] | undefined;
}

export interface TextStreamFailedEvent extends TextStreamEventBase {
  error: {
    category: ProviderFailureCategory;
    code: "empty_output" | "provider_error" | "stream_error";
    message: string;
    provider_code?: string;
    retry_after_ms?: number;
    retryable: boolean;
    status_code?: number;
  };
  model: string;
  provider: LanguageModelProviderId;
  provider_latency_ms: number;
  type: "stream.failed";
  upstream_model: string;
}

export type TextStreamEvent =
  | TextStreamCompletedEvent
  | TextStreamDeltaEvent
  | TextStreamFailedEvent
  | TextStreamStartedEvent;

const eventBase = (sequence: number) => ({
  protocol_version: TEXT_STREAM_PROTOCOL_VERSION,
  sequence,
});

export const textStreamStartedEvent = (input: {
  model: string;
  provider: LanguageModelProviderId;
  sequence: number;
  upstreamModel: string;
}): TextStreamStartedEvent => ({
  ...eventBase(input.sequence),
  model: input.model,
  provider: input.provider,
  type: "stream.started",
  upstream_model: input.upstreamModel,
});

export const textStreamDeltaEvent = (
  delta: string,
  sequence: number
): TextStreamDeltaEvent => ({
  ...eventBase(sequence),
  delta,
  type: "text.delta",
});

export const textStreamCompletedEvent = (input: {
  finishReason: string;
  model: string;
  performance: TextStreamCompletedEvent["performance"];
  provider: LanguageModelProviderId;
  providerLatencyMs: number;
  responseModelId: string;
  sequence: number;
  upstreamModel: string;
  usage: TextStreamCompletedEvent["usage"];
  warnings: unknown[] | undefined;
}): TextStreamCompletedEvent => ({
  ...eventBase(input.sequence),
  finish_reason: input.finishReason,
  model: input.model,
  performance: input.performance,
  provider: input.provider,
  provider_latency_ms: input.providerLatencyMs,
  response_model_id: input.responseModelId,
  type: "stream.completed",
  upstream_model: input.upstreamModel,
  usage: input.usage,
  warnings: input.warnings,
});

export const textStreamFailedEvent = (input: {
  category: ProviderFailureCategory;
  code: TextStreamFailedEvent["error"]["code"];
  message: string;
  model: string;
  provider: LanguageModelProviderId;
  providerCode?: string;
  providerLatencyMs: number;
  retryAfterMs?: number;
  retryable: boolean;
  sequence: number;
  statusCode?: number;
  upstreamModel: string;
}): TextStreamFailedEvent => ({
  ...eventBase(input.sequence),
  error: {
    category: input.category,
    code: input.code,
    message: input.message,
    provider_code: input.providerCode,
    retry_after_ms: input.retryAfterMs,
    retryable: input.retryable,
    status_code: input.statusCode,
  },
  model: input.model,
  provider: input.provider,
  provider_latency_ms: input.providerLatencyMs,
  type: "stream.failed",
  upstream_model: input.upstreamModel,
});
