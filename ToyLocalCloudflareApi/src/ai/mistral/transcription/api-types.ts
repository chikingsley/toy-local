import { z } from "zod";

export const MistralTimestampGranularitySchema = z.enum(["segment", "word"]);

const MistralTranscriptionSegmentSchema = z
  .object({
    end: z.number(),
    score: z.number().nullable().optional(),
    speaker_id: z.string().nullable().optional(),
    start: z.number(),
    text: z.string(),
    type: z.literal("transcription_segment").optional(),
  })
  .catchall(z.unknown());

const MistralUsageInfoSchema = z
  .object({
    completion_tokens: z.number().int().optional(),
    prompt_audio_seconds: z.number().nullable().optional(),
    prompt_tokens: z.number().int().optional(),
    total_tokens: z.number().int().optional(),
  })
  .catchall(z.unknown());

export const MistralTranscriptionResponseSchema = z
  .object({
    language: z.string().nullable(),
    model: z.string(),
    segments: z.array(MistralTranscriptionSegmentSchema).optional(),
    text: z.string(),
    usage: MistralUsageInfoSchema,
  })
  .catchall(z.unknown());
