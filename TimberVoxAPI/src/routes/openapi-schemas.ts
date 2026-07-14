import { z } from "@hono/zod-openapi";

const ErrorResponse = z
  .object({
    error: z.string(),
    issues: z.array(z.unknown()).optional(),
  })
  .openapi("ErrorResponse");

export const JsonErrorContent = {
  "application/json": { schema: ErrorResponse },
};

export const HealthResponse = z
  .object({
    ok: z.boolean(),
    service: z.string(),
  })
  .openapi("HealthResponse");

export const JobView = z
  .object({
    completed_at: z.string().nullable(),
    created_at: z.string(),
    error: z.string().nullable(),
    job_id: z.string(),
    kind: z.literal("transcription"),
    progress: z.number(),
    queued_at: z.string().nullable(),
    result: z.record(z.string(), z.unknown()).nullable(),
    started_at: z.string().nullable(),
    status: z.enum(["pending", "queued", "running", "succeeded", "failed"]),
    updated_at: z.string(),
  })
  .openapi("JobView");

const TextMessage = z
  .object({
    content: z.string().min(1),
    role: z.enum(["assistant", "system", "user"]),
  })
  .openapi("TextMessage");

export const TextRequestSchema = z
  .object({
    messages: z.array(TextMessage).min(1),
    model: z.string().min(1),
    output: z
      .object({
        description: z.string().min(1).max(500).optional(),
        name: z.string().min(1).max(64).optional(),
        schema: z.record(z.string(), z.unknown()),
        type: z.literal("object"),
      })
      .strict()
      .optional(),
    providerOptions: z.record(z.string(), z.unknown()).optional(),
    temperature: z.number().optional(),
  })
  .openapi("TextRequest");

const TextResponseBase = z.object({
  finishReason: z.string(),
  model: z.string(),
  provider: z.string(),
  upstreamModel: z.string(),
  usage: z.object({
    inputTokens: z.number().optional(),
    outputTokens: z.number().optional(),
    totalTokens: z.number().optional(),
  }),
});

export const TextResponse = z
  .discriminatedUnion("outputType", [
    TextResponseBase.extend({
      output: z.record(z.string(), z.unknown()),
      outputType: z.literal("object"),
    }),
    TextResponseBase.extend({
      outputType: z.literal("text"),
      text: z.string(),
    }),
  ])
  .openapi("TextResponse");

const RealtimeTerminalBase = z.object({
  audio_bytes: z.number().int().nonnegative(),
  ended_at: z.string(),
  language: z.string().nullable(),
  message_count: z.number().int().nonnegative(),
  model: z.string(),
  protocol_version: z.literal(1),
  provider: z.enum(["deepgram", "mistral"]),
  sequence: z.number().int().nonnegative(),
  session_id: z.string(),
  started_at: z.string(),
  transcript: z.string(),
});

export const RealtimeSessionResultResponse = z
  .discriminatedUnion("type", [
    RealtimeTerminalBase.extend({
      audio_seconds: z.number().nonnegative().nullable(),
      status: z.literal("succeeded"),
      type: z.literal("session.completed"),
    }),
    RealtimeTerminalBase.extend({
      error: z.object({
        code: z.enum(["provider_error", "session_error"]),
        message: z.string(),
        retryable: z.boolean(),
      }),
      status: z.literal("failed"),
      type: z.literal("session.failed"),
    }),
  ])
  .openapi("RealtimeSessionResult");

export const UploadReservationRequest = z
  .object({
    content_type: z.string().min(1),
    filename: z.string().min(1).optional(),
    size_bytes: z.number().int().positive(),
  })
  .strict()
  .openapi("UploadReservationRequest");

export const UploadReservationResponse = z
  .object({
    input_key: z.string(),
    transfer: z.discriminatedUnion("kind", [
      z
        .object({
          headers: z.record(z.string(), z.string()),
          kind: z.literal("single"),
          url: z.url(),
        })
        .strict(),
      z
        .object({
          kind: z.literal("multipart"),
          part_size_bytes: z.number().int().positive(),
          parts: z.array(
            z
              .object({
                headers: z.record(z.string(), z.string()),
                part_number: z.number().int().positive(),
                url: z.url(),
              })
              .strict()
          ),
        })
        .strict(),
    ]),
    upload_id: z.string(),
  })
  .openapi("UploadReservationResponse");

export const UploadCompletionRequest = z
  .object({
    parts: z
      .array(
        z
          .object({
            etag: z.string().min(1),
            part_number: z.number().int().positive(),
          })
          .strict()
      )
      .default([]),
  })
  .strict()
  .openapi("UploadCompletionRequest");

export const UploadCompletionResponse = z
  .object({
    input_key: z.string(),
    size_bytes: z.number(),
  })
  .openapi("UploadCompletionResponse");

export const TranscriptionRequestSchema = z
  .object({
    asr_model: z.string().min(1),
    diarize: z.boolean().optional(),
    input_key: z.string().min(1),
    language: z.string().min(1).optional(),
    provider_options: z
      .record(z.string(), z.record(z.string(), z.unknown()))
      .optional(),
    sync: z.boolean().optional(),
  })
  .strict()
  .openapi("TranscriptionRequest");

const UsageTotals = z
  .object({
    asr_seconds: z.number(),
    estimated_cost_micro_usd: z.number(),
    input_tokens: z.number(),
    output_tokens: z.number(),
    provider_latency_ms: z.number(),
    request_count: z.number(),
    total_tokens: z.number(),
  })
  .openapi("UsageTotals");

const UsageDailyRow = z
  .object({
    account_key: z.string(),
    asr_seconds: z.number(),
    day: z.string(),
    estimated_cost_micro_usd: z.number(),
    input_tokens: z.number(),
    kind: z.string(),
    model: z.string(),
    output_tokens: z.number(),
    provider: z.string(),
    provider_latency_ms: z.number(),
    request_count: z.number(),
    total_tokens: z.number(),
    upstream_model: z.string().nullable(),
  })
  .openapi("UsageDailyRow");

export const UsageDailyResponse = z
  .object({
    rows: z.array(UsageDailyRow),
    totals: UsageTotals,
  })
  .openapi("UsageDailyResponse");

export const UsageSummaryResponse = UsageDailyResponse.extend({
  analytics_engine: z.object({
    queryable_from_worker: z.boolean(),
    writes_enabled: z.boolean(),
  }),
  recent_request_logs: z.array(z.record(z.string(), z.unknown())),
}).openapi("UsageSummaryResponse");

export const AnalyticsUsageResponse = z
  .object({
    data: z.unknown(),
    dataset: z.string(),
    query: z.string(),
  })
  .openapi("AnalyticsUsageResponse");

export const ResourceValidationResponse = z
  .object({
    checks: z.record(
      z.string(),
      z.object({
        detail: z.string().optional(),
        ok: z.boolean(),
      })
    ),
    ok: z.boolean(),
    validation_id: z.string(),
  })
  .openapi("ResourceValidationResponse");
