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

export const TextTransformRequestSchema = z
  .object({
    messages: z.array(TextMessage).min(1),
    model: z.string().min(1),
    providerOptions: z.record(z.string(), z.unknown()).optional(),
    temperature: z.number().optional(),
  })
  .openapi("TextTransformRequest");

export const TextTransformResponse = z
  .object({
    finishReason: z.string(),
    model: z.string(),
    provider: z.string(),
    text: z.string(),
    upstreamModel: z.string(),
    usage: z.object({
      inputTokens: z.number().optional(),
      outputTokens: z.number().optional(),
      totalTokens: z.number().optional(),
    }),
  })
  .openapi("TextTransformResponse");

export const UploadReservationRequest = z
  .object({
    content_type: z.string().min(1).optional(),
    filename: z.string().min(1).optional(),
  })
  .strict()
  .openapi("UploadReservationRequest");

export const UploadReservationResponse = z
  .object({
    input_key: z.string(),
    upload_id: z.string(),
    upload_url: z.string(),
  })
  .openapi("UploadReservationResponse");

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
    transform: TextTransformRequestSchema.optional(),
  })
  .strict()
  .openapi("TranscriptionRequest");

export const LicenseCreateRequest = z
  .object({
    display_name: z.string().min(1).optional(),
    email: z.email(),
    expires_at: z.iso.datetime().optional(),
    max_activations: z.number().int().positive().max(25).optional(),
    notes: z.string().min(1).optional(),
  })
  .strict()
  .openapi("LicenseCreateRequest");

export const LicenseCreateResponse = z
  .object({
    email: z.string(),
    license_id: z.string(),
    license_key: z.string(),
    max_activations: z.number(),
    status: z.string(),
    user_id: z.string(),
  })
  .openapi("LicenseCreateResponse");

export const LicenseActivationRequest = z
  .object({
    app_version: z.string().min(1).optional(),
    device_id: z.string().min(1),
    device_name: z.string().min(1).optional(),
    email: z.email(),
    license_key: z.string().min(1),
  })
  .strict()
  .openapi("LicenseActivationRequest");

export const LicenseActivationResponse = z
  .object({
    activation_id: z.string(),
    credential: z.string(),
    credential_id: z.string(),
    email: z.string(),
    license_id: z.string(),
    user_id: z.string(),
  })
  .openapi("LicenseActivationResponse");

export const LicenseValidationResponse = z
  .object({
    activation_id: z.string().nullable(),
    credential_id: z.string(),
    email: z.string(),
    user_id: z.string(),
    valid: z.literal(true),
  })
  .openapi("LicenseValidationResponse");

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
