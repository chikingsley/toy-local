import { recordUsageEvent } from "../accounting/usage";
import type { DeepgramRealtimeEvent } from "../ai/deepgram/realtime/events";
import type { MistralRealtimeEvent } from "../ai/mistral/realtime/events";
import type { RealtimeProviderId } from "../ai/model-routes";
import type { Env } from "../bindings";

interface RealtimeWord {
  confidence?: number;
  end: number;
  speaker?: string;
  start: number;
  text: string;
}

export interface RealtimeTranscriptEvent {
  end?: number;
  is_final: boolean;
  raw: unknown;
  speech_final?: boolean;
  start?: number;
  text: string;
  type: "transcript";
  words?: RealtimeWord[];
}

export interface RealtimeResultConfig {
  clientId: string | null;
  language: string | null;
  model: string;
  provider: RealtimeProviderId;
  sampleRate: number | null;
  sessionId: string;
  upstreamModel: string;
}

export interface RealtimeResultInput {
  audioBytes: number;
  endedAt: string;
  error?: string | null;
  events: RealtimeTranscriptEvent[];
  messageCount: number;
  startedAt: string;
  status: "failed" | "succeeded";
}

export interface RealtimePersistResult {
  transcript: string;
  transcriptJsonKey: string;
  transcriptTextKey: string;
}

const contentTypeJson = "application/json";
const contentTypeText = "text/plain; charset=utf-8";

const wordText = (value: Record<string, unknown>): string | null => {
  const candidate = value.punctuated_word ?? value.text ?? value.word;
  return typeof candidate === "string" && candidate.trim()
    ? candidate.trim()
    : null;
};

const normalizeSpeaker = (value: unknown): string | undefined => {
  if (value === null || value === undefined || value === "") {
    return;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return `speaker_${value}`;
  }
  if (typeof value === "string") {
    return value.startsWith("speaker_") ? value : `speaker_${value}`;
  }
  return;
};

const normalizeWords = (value: unknown): RealtimeWord[] | undefined => {
  if (!Array.isArray(value)) {
    return;
  }
  const words: RealtimeWord[] = [];
  for (const item of value) {
    if (typeof item !== "object" || item === null) {
      continue;
    }
    const raw = item as Record<string, unknown>;
    const text = wordText(raw);
    if (!text || typeof raw.start !== "number" || typeof raw.end !== "number") {
      continue;
    }
    const word: RealtimeWord = {
      end: raw.end,
      start: raw.start,
      text,
    };
    if (typeof raw.confidence === "number") {
      word.confidence = raw.confidence;
    }
    const speaker = normalizeSpeaker(raw.speaker ?? raw.speaker_id);
    if (speaker) {
      word.speaker = speaker;
    }
    words.push(word);
  }
  return words.length > 0 ? words : undefined;
};

export const normalizeDeepgramTranscriptEvent = (
  event: DeepgramRealtimeEvent
): RealtimeTranscriptEvent | null => {
  if (event.type !== "Results") {
    return null;
  }
  const raw = event as Record<string, unknown>;
  const channel = raw.channel as
    | { alternatives?: { transcript?: string; words?: unknown }[] }
    | undefined;
  const [alternative] = channel?.alternatives ?? [];
  const text = alternative?.transcript?.trim();
  if (!text) {
    return null;
  }
  return {
    is_final: Boolean(raw.is_final),
    raw: event,
    speech_final: Boolean(raw.speech_final),
    text,
    type: "transcript",
    words: normalizeWords(alternative?.words),
  };
};

export const normalizeMistralTranscriptEvent = (
  event: MistralRealtimeEvent
): RealtimeTranscriptEvent | null => {
  if (event.type === "transcription.segment") {
    return {
      end: event.end,
      is_final: true,
      raw: event,
      start: event.start,
      text: event.text,
      type: "transcript",
      words: [
        {
          end: event.end,
          speaker: normalizeSpeaker(event.speaker_id),
          start: event.start,
          text: event.text,
        },
      ],
    };
  }
  if (event.type === "transcription.done") {
    return {
      is_final: true,
      raw: event,
      text: event.text,
      type: "transcript",
    };
  }
  if (event.type === "transcription.text.delta") {
    return {
      is_final: false,
      raw: event,
      text: event.text,
      type: "transcript",
    };
  }
  return null;
};

export const finalRealtimeTranscript = (
  provider: RealtimeProviderId,
  events: RealtimeTranscriptEvent[]
): string => {
  const finalEvents = events.filter((event) => event.is_final && event.text);
  if (provider === "deepgram") {
    return finalEvents
      .map((event) => event.text)
      .join(" ")
      .trim();
  }
  return (
    finalEvents.at(-1)?.text ??
    events
      .filter((event) => event.text)
      .map((event) => event.text)
      .join("")
  ).trim();
};

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
  const transcript = finalRealtimeTranscript(config.provider, input.events);
  const prefix = `realtime/${config.clientId ?? "anonymous"}/${config.sessionId}`;
  const transcriptJsonKey = `${prefix}/transcript.json`;
  const transcriptTextKey = `${prefix}/transcript.txt`;
  const resultJson = {
    audio_bytes: input.audioBytes,
    audio_seconds: audioSeconds(input.audioBytes, config.sampleRate),
    client_id: config.clientId,
    ended_at: input.endedAt,
    error: input.error ?? null,
    events: input.events,
    language: config.language,
    message_count: input.messageCount,
    model: config.model,
    provider: config.provider,
    session_id: config.sessionId,
    started_at: input.startedAt,
    status: input.status,
    transcript,
    upstream_model: config.upstreamModel,
  };

  await env.ARTIFACTS.put(transcriptJsonKey, JSON.stringify(resultJson), {
    httpMetadata: { contentType: contentTypeJson },
  });
  await env.ARTIFACTS.put(transcriptTextKey, transcript, {
    httpMetadata: { contentType: contentTypeText },
  });
  await env.DB.prepare(
    `INSERT INTO realtime_sessions
      (id, client_id, provider, model, upstream_model, language, status,
       transcript, transcript_json_key, transcript_text_key, audio_bytes,
       audio_seconds, message_count, error, started_at, ended_at, created_at,
       updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       client_id = excluded.client_id,
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
    provider: config.provider,
    route: "/v1/realtime",
    status: input.status === "succeeded" ? 200 : 500,
    upstreamModel: config.upstreamModel,
  });

  return { transcript, transcriptJsonKey, transcriptTextKey };
};
