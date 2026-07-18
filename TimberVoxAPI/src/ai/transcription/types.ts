import { z } from "zod";

const TranscriptSpeakerSchema = z.union([z.string(), z.number()]);

const TranscriptCollectionAvailabilitySchema = z.enum([
  "available",
  "not_requested",
  "provider_omitted",
  "unsupported",
]);

const TranscriptCollectionSourceSchema = z.enum(["derived", "provider"]);

const TranscriptCollectionInfoSchema = z
  .object({
    availability: TranscriptCollectionAvailabilitySchema,
    source: TranscriptCollectionSourceSchema.optional(),
  })
  .strict();

const TranscriptScoresSchema = z
  .object({
    confidence: z.number().min(0).max(1).optional(),
    logProbability: z.number().optional(),
    probability: z.number().min(0).max(1).optional(),
    score: z.number().optional(),
    speakerConfidence: z.number().min(0).max(1).optional(),
  })
  .strict();

const TimedTextSchema = z
  .object({
    endSeconds: z.number().nonnegative(),
    speaker: TranscriptSpeakerSchema.optional(),
    startSeconds: z.number().nonnegative(),
    text: z.string(),
  })
  .strict();

const TranscriptWordSchema = TimedTextSchema.extend({
  scores: TranscriptScoresSchema.optional(),
}).strict();

const TranscriptSegmentSchema = TimedTextSchema.extend({
  scores: TranscriptScoresSchema.optional(),
}).strict();

const TranscriptSpeakerTurnSchema = TimedTextSchema.strict();

const TranscriptTokenSchema = z
  .object({
    endSeconds: z.number().nonnegative().optional(),
    kind: z.string().optional(),
    scores: TranscriptScoresSchema.optional(),
    speaker: TranscriptSpeakerSchema.optional(),
    startSeconds: z.number().nonnegative().optional(),
    text: z.string(),
    tokenId: z.number().int().optional(),
  })
  .strict();

const TranscriptAudioEventSchema = z
  .object({
    endSeconds: z.number().nonnegative().optional(),
    startSeconds: z.number().nonnegative().optional(),
    text: z.string(),
  })
  .strict();

const TranscriptionUsageSchema = z
  .object({
    inputTokens: z.number().int().nonnegative().optional(),
    outputTokens: z.number().int().nonnegative().optional(),
    totalTokens: z.number().int().nonnegative().optional(),
  })
  .strict();

export const BatchTranscriptionResultSchema = z
  .object({
    audioEvents: z.array(TranscriptAudioEventSchema),
    collections: z
      .object({
        audioEvents: TranscriptCollectionInfoSchema,
        segments: TranscriptCollectionInfoSchema,
        speakerTurns: TranscriptCollectionInfoSchema,
        tokens: TranscriptCollectionInfoSchema,
        words: TranscriptCollectionInfoSchema,
      })
      .strict(),
    durationSeconds: z.number().nonnegative().optional(),
    language: z.string().optional(),
    languageConfidence: z.number().min(0).max(1).optional(),
    providerMetadata: z.record(z.string(), z.unknown()).optional(),
    providerResponse: z.record(z.string(), z.unknown()),
    segments: z.array(TranscriptSegmentSchema),
    speakerTurns: z.array(TranscriptSpeakerTurnSchema),
    text: z.string(),
    tokens: z.array(TranscriptTokenSchema),
    usage: TranscriptionUsageSchema,
    warnings: z.array(
      z
        .object({
          code: z.string(),
          message: z.string(),
        })
        .strict()
    ),
    words: z.array(TranscriptWordSchema),
  })
  .strict();

export type BatchTranscriptionResult = z.infer<
  typeof BatchTranscriptionResultSchema
>;
export type TranscriptSpeakerTurn = z.infer<typeof TranscriptSpeakerTurnSchema>;
export type TranscriptSegment = z.infer<typeof TranscriptSegmentSchema>;
export type TranscriptWord = z.infer<typeof TranscriptWordSchema>;

export interface RemoteMediaSource {
  contentType: string;
  filename: string;
  sizeBytes: number;
  url: URL;
}

interface BatchTranscriptionProviderRequest {
  diarize?: boolean;
  language?: string;
  media: RemoteMediaSource;
  model: string;
  providerOptions?: Record<string, unknown>;
}

export interface BatchTranscriptionProvider {
  transcribe: (
    request: BatchTranscriptionProviderRequest
  ) => Promise<BatchTranscriptionResult>;
}
