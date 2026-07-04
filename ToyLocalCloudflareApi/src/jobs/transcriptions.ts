import { z } from "zod";

import { recordUsageEvent } from "../accounting/usage";
import { transcribeAudio } from "../ai/batch-transcribe";
import { transcriptionModelRoute } from "../ai/model-routes";
import { runTextTransform, TextTransformRequest } from "../ai/text-transform";
import type { Env, JobRow } from "../bindings";
import { jobView, setJobStatus } from "./db";
import { createAndEnqueue } from "./enqueue";
import {
  isTransientProviderError,
  providerErrorMessage,
  retryDelaySeconds,
  TransientProviderError,
} from "./provider-errors";

export const TranscriptionRequest = z
  .object({
    asr_model: z.string().min(1),
    diarize: z.boolean().optional(),
    input_key: z.string().min(1),
    language: z.string().min(1).optional(),
    provider_options: z
      .record(z.string(), z.record(z.string(), z.unknown()))
      .optional(),
    transform: TextTransformRequest.optional(),
  })
  .strict();

export type TranscriptionRequest = z.infer<typeof TranscriptionRequest>;

const nowIso = (): string => new Date().toISOString();

interface TransformJobResult {
  finish_reason: string;
  model: string;
  provider: string;
  provider_latency_ms: number;
  upstream_model: string;
  usage: {
    input_tokens: number | undefined;
    output_tokens: number | undefined;
    total_tokens: number | undefined;
  };
}

const runOptionalTransform = async (
  env: Env,
  request: TextTransformRequest | undefined
): Promise<{ text: string | null; transform: TransformJobResult | null }> => {
  if (!request) {
    return { text: null, transform: null };
  }

  const transformStart = performance.now();
  const transformed = await runTextTransform(env, request);
  return {
    text: transformed.text,
    transform: {
      finish_reason: transformed.finishReason,
      model: transformed.model,
      provider: transformed.provider,
      provider_latency_ms: Math.round(performance.now() - transformStart),
      upstream_model: transformed.upstreamModel,
      usage: {
        input_tokens: transformed.usage.inputTokens,
        output_tokens: transformed.usage.outputTokens,
        total_tokens: transformed.usage.totalTokens,
      },
    },
  };
};

const handleJobError = async (
  env: Env,
  job: JobRow,
  error: unknown,
  attempts: number
): Promise<void> => {
  if (isTransientProviderError(error)) {
    const message = providerErrorMessage(error);
    await setJobStatus(env, job.id, "queued", {
      error: `transient provider error: ${message}`,
      progress: 0.2,
    });
    throw new TransientProviderError(message, retryDelaySeconds(attempts));
  }

  await setJobStatus(env, job.id, "failed", {
    error: providerErrorMessage(error),
    progress: 1,
  });
};

export const runTranscriptionJob = async (
  env: Env,
  job: JobRow,
  input: { attempts?: number } = {}
): Promise<void> => {
  const startedAt = nowIso();
  await setJobStatus(env, job.id, "running", {
    progress: 0.2,
    startedAt,
  });

  try {
    const params = TranscriptionRequest.parse(
      JSON.parse(job.params_json ?? "{}")
    );
    const object = await env.ARTIFACTS.get(params.input_key);
    if (!object) {
      throw new Error(`input object not found: ${params.input_key}`);
    }
    const contentType =
      object.httpMetadata?.contentType ?? "application/octet-stream";
    const providerStart = performance.now();
    const transcription = await transcribeAudio(env, params.asr_model, {
      contentType,
      data: await object.arrayBuffer(),
      filename: params.input_key.split("/").at(-1) ?? "source",
      language: params.language,
      providerOptions: transcriptionProviderOptions(params),
    });
    const providerLatencyMs = performance.now() - providerStart;
    const rawTranscript = transcription.result.text;
    const { text: transformedText, transform } = await runOptionalTransform(
      env,
      params.transform
    );
    const finalTranscript = transformedText ?? rawTranscript;

    await recordUsageEvent(env, {
      asrSeconds: transcription.result.durationSeconds ?? null,
      clientId: job.client_id,
      jobId: job.id,
      kind: "asr",
      model: transcription.model,
      provider: transcription.provider,
      providerLatencyMs: Math.round(providerLatencyMs),
      route: "/v1/transcriptions",
      status: 200,
      upstreamModel: transcription.upstreamModel,
    });
    if (transform) {
      await recordUsageEvent(env, {
        clientId: job.client_id,
        inputTokens: transform.usage.input_tokens ?? null,
        jobId: job.id,
        kind: "llm",
        model: transform.model,
        outputTokens: transform.usage.output_tokens ?? null,
        provider: transform.provider,
        providerLatencyMs: transform.provider_latency_ms,
        route: "/v1/transcriptions",
        status: 200,
        totalTokens: transform.usage.total_tokens ?? null,
        upstreamModel: transform.upstream_model,
      });
    }

    await setJobStatus(env, job.id, "succeeded", {
      progress: 1,
      result: {
        asr: {
          duration_seconds: transcription.result.durationSeconds ?? null,
          language: transcription.result.language ?? null,
          model: transcription.model,
          provider: transcription.provider,
          provider_latency_ms: Math.round(providerLatencyMs),
          provider_metadata: transcription.result.providerMetadata ?? null,
          segments: transcription.result.segments ?? [],
          upstream_model: transcription.upstreamModel,
          warnings: transcription.result.warnings ?? [],
        },
        queued_delay_ms:
          job.queued_at === null
            ? null
            : Date.parse(startedAt) - Date.parse(job.queued_at),
        raw_transcript: rawTranscript,
        steps: [
          {
            kind: "asr",
            model: transcription.model,
            provider: transcription.provider,
            provider_latency_ms: Math.round(providerLatencyMs),
            upstream_model: transcription.upstreamModel,
          },
          ...(transform
            ? [
                {
                  kind: "text_transform",
                  model: transform.model,
                  provider: transform.provider,
                  provider_latency_ms: transform.provider_latency_ms,
                  upstream_model: transform.upstream_model,
                },
              ]
            : []),
        ],
        transcript: finalTranscript,
        transform,
      },
    });
  } catch (error) {
    await handleJobError(env, job, error, input.attempts ?? 1);
  }
};

const transcriptionProviderOptions = (
  params: TranscriptionRequest
): Parameters<typeof transcribeAudio>[2]["providerOptions"] => {
  const providerOptions = { ...(params.provider_options ?? {}) };
  const routeProvider = transcriptionModelRoute(params.asr_model).provider;
  if (routeProvider && (params.diarize !== undefined || params.language)) {
    providerOptions[routeProvider] = {
      ...(providerOptions[routeProvider] ?? {}),
      ...(params.diarize === undefined ? {} : { diarize: params.diarize }),
      ...(params.language ? { language: params.language } : {}),
    };
  }
  return Object.keys(providerOptions).length > 0
    ? (providerOptions as Parameters<
        typeof transcribeAudio
      >[2]["providerOptions"])
    : undefined;
};

export const createTranscription = async (
  env: Env,
  body: TranscriptionRequest,
  input: { idempotencyKey?: string; scope?: string } = {}
) => {
  const result = await createAndEnqueue(env, {
    clientId: input.scope ?? "local-dev",
    idempotencyKey: input.idempotencyKey,
    inputKey: body.input_key,
    kind: "transcription",
    params: body,
    scope: input.scope ?? "local-dev",
  });
  return {
    idempotentHit: result.idempotentHit,
    status: (result.idempotentHit ? 200 : 202) as 200 | 202,
    view: jobView(result.job),
  };
};
