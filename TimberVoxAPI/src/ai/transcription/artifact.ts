import { z } from "@hono/zod-openapi";

import type { RealtimeAsrProviderId } from "../models/types";
import {
  finalRealtimeTranscript,
  type RealtimeTranscriptEvent,
} from "../realtime/normalize";
import type { BatchTranscriptionResult } from "./types";

const TranscriptSpeakerSchema = z.union([z.string(), z.number()]);

const TranscriptScoresSchema = z
  .object({
    confidence: z.number().min(0).max(1).nullable(),
    log_probability: z.number().nullable(),
    probability: z.number().min(0).max(1).nullable(),
    score: z.number().nullable(),
    speaker_confidence: z.number().min(0).max(1).nullable(),
  })
  .strict();

const TimedTextSchema = z
  .object({
    end_seconds: z.number().nonnegative(),
    scores: TranscriptScoresSchema.nullable(),
    speaker: TranscriptSpeakerSchema.nullable(),
    start_seconds: z.number().nonnegative(),
    text: z.string(),
  })
  .strict();

const TranscriptTokenSchema = z
  .object({
    end_seconds: z.number().nonnegative().nullable(),
    kind: z.string().nullable(),
    scores: TranscriptScoresSchema.nullable(),
    speaker: TranscriptSpeakerSchema.nullable(),
    start_seconds: z.number().nonnegative().nullable(),
    text: z.string(),
    token_id: z.number().int().nullable(),
  })
  .strict();

const TranscriptAudioEventSchema = z
  .object({
    end_seconds: z.number().nonnegative().nullable(),
    start_seconds: z.number().nonnegative().nullable(),
    text: z.string(),
  })
  .strict();

const CollectionAvailabilitySchema = z.enum([
  "available",
  "not_requested",
  "provider_omitted",
  "unsupported",
]);

const CollectionSourceSchema = z.enum(["derived", "provider"]);

const CollectionBaseSchema = z.object({
  availability: CollectionAvailabilitySchema,
  source: CollectionSourceSchema.nullable(),
});

const TokenCollectionSchema = CollectionBaseSchema.extend({
  items: z.array(TranscriptTokenSchema),
}).strict();

const WordCollectionSchema = CollectionBaseSchema.extend({
  items: z.array(TimedTextSchema),
}).strict();

const SegmentCollectionSchema = CollectionBaseSchema.extend({
  items: z.array(TimedTextSchema),
}).strict();

const SpeakerTurnCollectionSchema = CollectionBaseSchema.extend({
  items: z.array(
    TimedTextSchema.omit({ scores: true }).extend({ scores: z.null() })
  ),
}).strict();

const AudioEventCollectionSchema = CollectionBaseSchema.extend({
  items: z.array(TranscriptAudioEventSchema),
}).strict();

const UsageSchema = z
  .object({
    input_tokens: z.number().int().nonnegative().nullable(),
    output_tokens: z.number().int().nonnegative().nullable(),
    total_tokens: z.number().int().nonnegative().nullable(),
  })
  .strict();

export const TranscriptionArtifactSchema = z
  .object({
    content: z
      .object({
        audio_events: AudioEventCollectionSchema,
        segments: SegmentCollectionSchema,
        speaker_turns: SpeakerTurnCollectionSchema,
        tokens: TokenCollectionSchema,
        words: WordCollectionSchema,
      })
      .strict(),
    language: z
      .object({
        confidence: z.number().min(0).max(1).nullable(),
        detected: z.string().nullable(),
        requested: z.string().nullable(),
      })
      .strict(),
    metrics: z
      .object({
        audio_duration_seconds: z.number().nonnegative().nullable(),
        decoder_seconds: z.number().nonnegative().nullable(),
        encoder_seconds: z.number().nonnegative().nullable(),
        first_result_latency_ms: z.number().nonnegative().nullable(),
        gpu_utilization: z.number().nullable(),
        normalization_latency_ms: z.number().nonnegative().nullable(),
        peak_memory_mb: z.number().nonnegative().nullable(),
        preprocessor_seconds: z.number().nonnegative().nullable(),
        processing_seconds: z.number().nonnegative().nullable(),
        provider_latency_ms: z.number().nonnegative().nullable(),
        queue_delay_ms: z.number().nonnegative().nullable(),
        realtime_speed_factor: z.number().nonnegative().nullable(),
        tokens_per_second: z.number().nonnegative().nullable(),
        usage: UsageSchema,
        wall_latency_ms: z.number().nonnegative().nullable(),
      })
      .strict(),
    provenance: z
      .object({
        completed_at: z.string(),
        executor: z.enum(["cloud", "local"]),
        library_name: z.string().nullable(),
        library_version: z.string().nullable(),
        model: z.string(),
        provider: z.string(),
        provider_request_id: z.string().nullable(),
        run_id: z.string(),
        started_at: z.string(),
        transport: z.enum(["batch", "realtime"]),
        upstream_model: z.string(),
      })
      .strict(),
    provider_capture: z
      .object({
        metadata: z.record(z.string(), z.unknown()),
        response: z
          .object({
            media_type: z.literal("application/json"),
            payload: z.record(z.string(), z.unknown()),
          })
          .strict(),
      })
      .strict(),
    schema_version: z.literal(2),
    text: z.string(),
    warnings: z.array(
      z
        .object({
          code: z.string(),
          message: z.string(),
        })
        .strict()
    ),
  })
  .strict()
  .openapi("TranscriptionArtifact");

export type TranscriptionArtifact = z.infer<typeof TranscriptionArtifactSchema>;

interface BatchArtifactInput {
  completedAt: string;
  model: string;
  provider: string;
  providerLatencyMs: number;
  queueDelayMs: number | null;
  requestedLanguage?: string;
  result: BatchTranscriptionResult;
  runId: string;
  startedAt: string;
  upstreamModel: string;
}

export const batchTranscriptionArtifact = (
  input: BatchArtifactInput
): TranscriptionArtifact => {
  const { result } = input;
  const providerSeconds = input.providerLatencyMs / 1000;
  const { outputTokens } = result.usage;
  const providerRequestId = result.providerMetadata?.requestId;

  return TranscriptionArtifactSchema.parse({
    content: {
      audio_events: collection(
        result.collections.audioEvents,
        result.audioEvents.map((event) => ({
          end_seconds: event.endSeconds ?? null,
          start_seconds: event.startSeconds ?? null,
          text: event.text,
        }))
      ),
      segments: collection(
        result.collections.segments,
        result.segments.map(timedText)
      ),
      speaker_turns: collection(
        result.collections.speakerTurns,
        result.speakerTurns.map((turn) => ({
          end_seconds: turn.endSeconds,
          scores: null,
          speaker: turn.speaker ?? null,
          start_seconds: turn.startSeconds,
          text: turn.text,
        }))
      ),
      tokens: collection(
        result.collections.tokens,
        result.tokens.map((token) => ({
          end_seconds: token.endSeconds ?? null,
          kind: token.kind ?? null,
          scores: scores(token.scores),
          speaker: token.speaker ?? null,
          start_seconds: token.startSeconds ?? null,
          text: token.text,
          token_id: token.tokenId ?? null,
        }))
      ),
      words: collection(result.collections.words, result.words.map(timedText)),
    },
    language: {
      confidence: result.languageConfidence ?? null,
      detected: result.language ?? null,
      requested: input.requestedLanguage ?? null,
    },
    metrics: {
      audio_duration_seconds: result.durationSeconds ?? null,
      decoder_seconds: null,
      encoder_seconds: null,
      first_result_latency_ms: null,
      gpu_utilization: null,
      normalization_latency_ms: null,
      peak_memory_mb: null,
      preprocessor_seconds: null,
      processing_seconds: null,
      provider_latency_ms: input.providerLatencyMs,
      queue_delay_ms: input.queueDelayMs,
      realtime_speed_factor:
        result.durationSeconds === undefined || providerSeconds <= 0
          ? null
          : result.durationSeconds / providerSeconds,
      tokens_per_second:
        outputTokens === undefined || providerSeconds <= 0
          ? null
          : outputTokens / providerSeconds,
      usage: {
        input_tokens: result.usage.inputTokens ?? null,
        output_tokens: outputTokens ?? null,
        total_tokens: result.usage.totalTokens ?? null,
      },
      wall_latency_ms: Math.max(
        0,
        Date.parse(input.completedAt) - Date.parse(input.startedAt)
      ),
    },
    provenance: {
      completed_at: input.completedAt,
      executor: "cloud",
      library_name: null,
      library_version: null,
      model: input.model,
      provider: input.provider,
      provider_request_id:
        typeof providerRequestId === "string" ? providerRequestId : null,
      run_id: input.runId,
      started_at: input.startedAt,
      transport: "batch",
      upstream_model: input.upstreamModel,
    },
    provider_capture: {
      metadata: jsonObject(result.providerMetadata ?? {}),
      response: {
        media_type: "application/json",
        payload: jsonObject(result.providerResponse),
      },
    },
    schema_version: 2,
    text: result.text,
    warnings: result.warnings,
  });
};

interface RealtimeArtifactInput {
  audioBytes: number;
  completedAt: string;
  detectedLanguage?: string;
  durationSeconds?: number;
  error?: string | null;
  events: RealtimeTranscriptEvent[];
  firstResultAt?: string | null;
  messageCount: number;
  model: string;
  provider: RealtimeAsrProviderId;
  providerEvents: unknown[];
  providerMetadata: Record<string, unknown>;
  requestedLanguage?: string | null;
  responses: unknown[];
  resultSegments: Array<{
    endSecond: number;
    startSecond: number;
    text: string;
  }>;
  runId: string;
  sampleRate?: number | null;
  startedAt: string;
  upstreamModel: string;
  warnings: unknown[];
}

export const realtimeTranscriptionArtifact = (
  input: RealtimeArtifactInput
): TranscriptionArtifact => {
  const wallLatencyMs = Math.max(
    0,
    Date.parse(input.completedAt) - Date.parse(input.startedAt)
  );
  const audioDurationSeconds =
    input.durationSeconds ?? audioSeconds(input.audioBytes, input.sampleRate);
  const segments = uniqueTimedText([
    ...input.events.flatMap((event) => event.segments),
    ...input.resultSegments.map((segment) => ({
      endSeconds: segment.endSecond,
      startSeconds: segment.startSecond,
      text: segment.text,
    })),
  ]);
  const words = uniqueTimedText(input.events.flatMap((event) => event.words));
  const speakerTurns = uniqueTimedText(
    input.events.flatMap((event) => event.speakerTurns)
  );
  const normalizedWarnings = input.warnings.map((warning) => ({
    code: "ai_sdk_warning",
    message: warningMessage(warning),
  }));
  if (input.error) {
    normalizedWarnings.push({
      code: "realtime_failed",
      message: input.error,
    });
  }

  return TranscriptionArtifactSchema.parse({
    content: {
      audio_events: unavailableCollection("provider_omitted"),
      segments: artifactCollection(segments.map(timedText), "provider"),
      speaker_turns: artifactCollection(
        speakerTurns.map((turn) => ({ ...timedText(turn), scores: null })),
        "derived"
      ),
      tokens: unavailableCollection("unsupported"),
      words: artifactCollection(words.map(timedText), "provider"),
    },
    language: {
      confidence: null,
      detected: input.detectedLanguage ?? null,
      requested: input.requestedLanguage ?? null,
    },
    metrics: {
      audio_duration_seconds: audioDurationSeconds,
      decoder_seconds: null,
      encoder_seconds: null,
      first_result_latency_ms: input.firstResultAt
        ? Math.max(
            0,
            Date.parse(input.firstResultAt) - Date.parse(input.startedAt)
          )
        : null,
      gpu_utilization: null,
      normalization_latency_ms: null,
      peak_memory_mb: null,
      preprocessor_seconds: null,
      processing_seconds: null,
      provider_latency_ms: null,
      queue_delay_ms: null,
      realtime_speed_factor:
        audioDurationSeconds && wallLatencyMs > 0
          ? audioDurationSeconds / (wallLatencyMs / 1000)
          : null,
      tokens_per_second: null,
      usage: {
        input_tokens: null,
        output_tokens: null,
        total_tokens: null,
      },
      wall_latency_ms: wallLatencyMs,
    },
    provenance: {
      completed_at: input.completedAt,
      executor: "cloud",
      library_name: "AI SDK",
      library_version: "7.0.26",
      model: input.model,
      provider: input.provider,
      provider_request_id: null,
      run_id: input.runId,
      started_at: input.startedAt,
      transport: "realtime",
      upstream_model: input.upstreamModel,
    },
    provider_capture: {
      metadata: jsonObject({
        ai_sdk_provider_metadata: input.providerMetadata,
        audio_bytes: input.audioBytes,
        message_count: input.messageCount,
        responses: input.responses,
      }),
      response: {
        media_type: "application/json",
        payload: jsonObject({
          protocol_events: input.events,
          provider_events: input.providerEvents,
        }),
      },
    },
    schema_version: 2,
    text: finalRealtimeTranscript(input.provider, input.events),
    warnings: normalizedWarnings,
  });
};

const collection = <Item>(
  info: BatchTranscriptionResult["collections"][keyof BatchTranscriptionResult["collections"]],
  items: Item[]
): {
  availability: typeof info.availability;
  items: Item[];
  source: typeof info.source | null;
} => ({
  availability: info.availability,
  items,
  source: info.source ?? null,
});

const scores = (
  value:
    | BatchTranscriptionResult["tokens"][number]["scores"]
    | BatchTranscriptionResult["words"][number]["scores"]
): z.infer<typeof TranscriptScoresSchema> | null =>
  value
    ? {
        confidence: value.confidence ?? null,
        log_probability: value.logProbability ?? null,
        probability: value.probability ?? null,
        score: value.score ?? null,
        speaker_confidence: value.speakerConfidence ?? null,
      }
    : null;

const timedText = (
  value:
    | BatchTranscriptionResult["segments"][number]
    | BatchTranscriptionResult["words"][number]
    | RealtimeTranscriptEvent["segments"][number]
    | RealtimeTranscriptEvent["words"][number]
): z.infer<typeof TimedTextSchema> => ({
  end_seconds: value.endSeconds,
  scores: scores(value.scores),
  speaker: value.speaker ?? null,
  start_seconds: value.startSeconds,
  text: value.text,
});

const artifactCollection = <Item>(
  items: Item[],
  source: "derived" | "provider"
) => ({
  availability:
    items.length > 0 ? ("available" as const) : ("provider_omitted" as const),
  items,
  source: items.length > 0 ? source : null,
});

const unavailableCollection = (
  availability: "provider_omitted" | "unsupported"
) => ({ availability, items: [], source: null });

const audioSeconds = (
  audioBytes: number,
  sampleRate?: number | null
): number | null => {
  if (audioBytes <= 0 || !sampleRate) {
    return null;
  }
  return audioBytes / 2 / sampleRate;
};

const uniqueTimedText = <
  Item extends { endSeconds: number; startSeconds: number; text: string },
>(
  items: Item[]
): Item[] => {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = `${item.startSeconds}:${item.endSeconds}:${item.text}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
};

const warningMessage = (warning: unknown): string => {
  if (
    typeof warning === "object" &&
    warning !== null &&
    "message" in warning &&
    typeof warning.message === "string"
  ) {
    return warning.message;
  }
  return JSON.stringify(warning) ?? String(warning);
};

const jsonObject = (value: Record<string, unknown>): Record<string, unknown> =>
  JSON.parse(JSON.stringify(value)) as Record<string, unknown>;
