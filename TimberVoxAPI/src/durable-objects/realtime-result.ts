import { recordUsageEvent } from "../accounting/usage";
import type {
  RealtimeAsrExecutionProviderId,
  RealtimeAsrProviderId,
} from "../ai/models/types";
import type { RealtimeTranscriptEvent } from "../ai/realtime/normalize";
import {
  realtimeTranscriptionArtifact,
  type TranscriptionArtifact,
} from "../ai/transcription/artifact";
import type { Env } from "../bindings";

export interface RealtimeResultConfig {
  clientId: string;
  credentialId: string;
  executionModel: string;
  executionProvider: RealtimeAsrExecutionProviderId;
  language: string | null;
  model: string;
  provider: RealtimeAsrProviderId;
  sampleRate: number | null;
  sessionId: string;
  upstreamModel: string;
  userId: string;
}

export interface RealtimeResultInput {
  audioBytes: number;
  detectedLanguage?: string;
  durationSeconds?: number;
  endedAt: string;
  error?: string | null;
  events: RealtimeTranscriptEvent[];
  firstResultAt?: string | null;
  messageCount: number;
  providerEvents: unknown[];
  providerMetadata: Record<string, unknown>;
  responses: unknown[];
  resultSegments: Array<{
    endSecond: number;
    startSecond: number;
    text: string;
  }>;
  startedAt: string;
  status: "failed" | "succeeded";
  warnings: unknown[];
}

export interface RealtimePersistResult {
  artifact: TranscriptionArtifact;
}

const contentTypeJson = "application/json";
const contentTypeText = "text/plain; charset=utf-8";

const audioSeconds = (
  audioBytes: number,
  sampleRate: number | null
): number | null => {
  if (audioBytes <= 0 || !sampleRate) {
    return null;
  }
  return audioBytes / 2 / sampleRate;
};

export const persistRealtimeResult = async (
  env: Env,
  config: RealtimeResultConfig,
  input: RealtimeResultInput
): Promise<RealtimePersistResult> => {
  const artifact = buildRealtimeArtifact(config, input);
  const transcript = artifact.text;
  const prefix = `realtime/${config.userId}/${config.sessionId}`;
  const transcriptJsonKey = `${prefix}/artifact.json`;
  const transcriptTextKey = `${prefix}/transcript.txt`;

  await env.ARTIFACTS.put(transcriptJsonKey, JSON.stringify(artifact), {
    httpMetadata: { contentType: contentTypeJson },
  });
  await env.ARTIFACTS.put(transcriptTextKey, transcript, {
    httpMetadata: { contentType: contentTypeText },
  });
  await env.DB.prepare(
    `INSERT INTO realtime_sessions
      (id, client_id, credential_id, owner_user_id, provider, model,
       upstream_model, language, status,
       transcript, transcript_json_key, transcript_text_key, audio_bytes,
       audio_seconds, message_count, error, started_at, ended_at, created_at,
       updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       client_id = excluded.client_id,
       credential_id = excluded.credential_id,
       owner_user_id = excluded.owner_user_id,
       provider = excluded.provider,
       model = excluded.model,
       upstream_model = excluded.upstream_model,
       language = excluded.language,
       status = excluded.status,
       transcript = excluded.transcript,
       transcript_json_key = excluded.transcript_json_key,
       transcript_text_key = excluded.transcript_text_key,
       audio_bytes = excluded.audio_bytes,
       audio_seconds = excluded.audio_seconds,
       message_count = excluded.message_count,
       error = excluded.error,
       ended_at = excluded.ended_at,
       updated_at = excluded.updated_at`
  )
    .bind(
      config.sessionId,
      config.clientId,
      config.credentialId,
      config.userId,
      config.provider,
      config.model,
      config.upstreamModel,
      config.language,
      input.status,
      transcript,
      transcriptJsonKey,
      transcriptTextKey,
      input.audioBytes,
      audioSeconds(input.audioBytes, config.sampleRate),
      input.messageCount,
      input.error ?? null,
      input.startedAt,
      input.endedAt,
      input.startedAt,
      input.endedAt
    )
    .run();

  await recordUsageEvent(env, {
    asrSeconds: audioSeconds(input.audioBytes, config.sampleRate),
    clientId: config.clientId,
    error: input.error ?? null,
    kind: "realtime_asr",
    metadata: { session_id: config.sessionId },
    model: config.model,
    provider: config.executionProvider,
    route: "/v1/realtime",
    status: input.status === "succeeded" ? 200 : 500,
    upstreamModel: config.executionModel,
    userId: config.userId,
  });

  return { artifact };
};

export const buildRealtimeArtifact = (
  config: RealtimeResultConfig,
  input: RealtimeResultInput
): TranscriptionArtifact =>
  realtimeTranscriptionArtifact({
    audioBytes: input.audioBytes,
    completedAt: input.endedAt,
    detectedLanguage: input.detectedLanguage,
    durationSeconds: input.durationSeconds,
    error: input.error,
    events: input.events,
    firstResultAt: input.firstResultAt,
    messageCount: input.messageCount,
    model: config.model,
    provider: config.provider,
    providerEvents: input.providerEvents,
    providerMetadata: input.providerMetadata,
    requestedLanguage: config.language,
    responses: input.responses,
    resultSegments: input.resultSegments,
    runId: config.sessionId,
    sampleRate: config.sampleRate,
    startedAt: input.startedAt,
    upstreamModel: config.upstreamModel,
    warnings: input.warnings,
  });
