import { z } from "zod";

import { recordUsageEvent } from "../accounting/usage";
import { resolveBatchAsrModel } from "../ai/models/transcription-routes";
import { transcribeRemoteMedia } from "../ai/transcription/service";
import type { AuthSession } from "../auth/service";
import type { Env, JobRow } from "../bindings";
import { completedUpload } from "../uploads/service";
import { signR2GetUrl } from "../uploads/signing";
import { createJob, getJob, jobView, setJobStatus } from "./db";
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
    sync: z.boolean().optional(),
  })
  .strict();

export type TranscriptionRequest = z.infer<typeof TranscriptionRequest>;

const nowIso = (): string => new Date().toISOString();

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
    if (!job.owner_user_id) {
      throw new Error("transcription job has no owner");
    }
    const upload = await completedUpload(
      env,
      params.input_key,
      job.owner_user_id
    );
    if (!upload) {
      throw new Error(`completed upload not found: ${params.input_key}`);
    }
    const route = resolveBatchAsrModel(params.asr_model);
    assertSupportedLanguage(route, params.language);
    const providerStart = performance.now();
    const transcription = await transcribeRemoteMedia(env, params.asr_model, {
      diarize: params.diarize,
      language: params.language,
      media: {
        contentType: upload.contentType,
        filename: upload.filename,
        sizeBytes: upload.sizeBytes,
        url: new URL(await signR2GetUrl(env, upload.inputKey)),
      },
      providerOptions: params.provider_options,
    });
    const providerLatencyMs = performance.now() - providerStart;
    const rawTranscript = transcription.result.text;

    await recordUsageEvent(env, {
      asrSeconds: transcription.result.durationSeconds ?? null,
      clientId: job.credential_id ?? job.client_id,
      jobId: job.id,
      kind: "asr",
      model: transcription.model,
      provider: transcription.provider,
      providerLatencyMs: Math.round(providerLatencyMs),
      route: "/v1/transcriptions",
      status: 200,
      upstreamModel: transcription.upstreamModel,
      userId: job.owner_user_id,
    });

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
          segments: transcription.result.segments,
          speaker_turns: transcription.result.speakerTurns,
          upstream_model: transcription.upstreamModel,
          warnings: transcription.result.warnings,
          words: transcription.result.words,
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
        ],
        transcript: rawTranscript,
      },
    });
  } catch (error) {
    await handleJobError(env, job, error, input.attempts ?? 1);
  }
};

const assertSupportedLanguage = (
  route: ReturnType<typeof resolveBatchAsrModel>,
  language: string | undefined
): void => {
  if (!language) {
    return;
  }
  if (!route.supportedLanguages.includes(language)) {
    throw new Error(
      `language '${language}' is not supported by ${route.provider}:${route.upstreamModel}`
    );
  }
};

export const createTranscription = async (
  env: Env,
  body: TranscriptionRequest,
  input: { auth: AuthSession; idempotencyKey?: string }
) => {
  if (!(await completedUpload(env, body.input_key, input.auth.userId))) {
    throw new Error("upload not found");
  }
  const scope = `${input.auth.userId}:${input.auth.credentialId}`;
  if (body.sync) {
    const { sync: _sync, ...params } = body;
    const job = await createJob(env, {
      clientId: input.auth.credentialId,
      credentialId: input.auth.credentialId,
      inputKey: body.input_key,
      kind: "transcription",
      ownerUserId: input.auth.userId,
      params,
      status: "queued",
    });
    try {
      await runTranscriptionJob(env, job);
    } catch {
      // Transient provider error: the job is back in "queued" — hand it to
      // the queue so the client's polling still completes it.
      await env.JOBS_QUEUE.send({ job_id: job.id, kind: "transcription" });
    }
    const fresh = await getJob(env, job.id);
    return {
      idempotentHit: false,
      status: 200 as const,
      view: jobView(fresh ?? job),
    };
  }

  const result = await createAndEnqueue(env, {
    clientId: input.auth.credentialId,
    credentialId: input.auth.credentialId,
    idempotencyKey: input.idempotencyKey,
    inputKey: body.input_key,
    kind: "transcription",
    ownerUserId: input.auth.userId,
    params: body,
    scope,
  });
  return {
    idempotentHit: result.idempotentHit,
    status: (result.idempotentHit ? 200 : 202) as 200 | 202,
    view: jobView(result.job),
  };
};
