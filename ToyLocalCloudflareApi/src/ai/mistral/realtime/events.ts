import { z } from "zod";

const RealtimeSessionSchema = z
  .object({
    audio_format: z
      .object({
        encoding: z.string(),
        sample_rate: z.number().int(),
      })
      .optional(),
    model: z.string(),
    request_id: z.string(),
    target_streaming_delay_ms: z.number().int().nullable().optional(),
  })
  .catchall(z.unknown());

const MistralRealtimeEventSchema = z.discriminatedUnion("type", [
  z
    .object({
      session: RealtimeSessionSchema,
      type: z.literal("session.created"),
    })
    .catchall(z.unknown()),
  z
    .object({
      session: RealtimeSessionSchema,
      type: z.literal("session.updated"),
    })
    .catchall(z.unknown()),
  z
    .object({
      audio_language: z.string(),
      type: z.literal("transcription.language"),
    })
    .catchall(z.unknown()),
  z
    .object({
      end: z.number(),
      speaker_id: z.string().nullable().optional(),
      start: z.number(),
      text: z.string(),
      type: z.literal("transcription.segment"),
    })
    .catchall(z.unknown()),
  z
    .object({
      text: z.string(),
      type: z.literal("transcription.text.delta"),
    })
    .catchall(z.unknown()),
  z
    .object({
      language: z.string().nullable(),
      model: z.string(),
      text: z.string(),
      type: z.literal("transcription.done"),
    })
    .catchall(z.unknown()),
  z
    .object({
      error: z
        .object({
          code: z.number().int(),
          message: z.union([z.string(), z.record(z.string(), z.unknown())]),
        })
        .catchall(z.unknown()),
      type: z.literal("error"),
    })
    .catchall(z.unknown()),
]);

export type MistralRealtimeEvent = z.infer<typeof MistralRealtimeEventSchema>;

export const parseMistralRealtimeEvent = (
  data: string
): MistralRealtimeEvent | undefined => {
  try {
    return MistralRealtimeEventSchema.parse(JSON.parse(data));
  } catch {
    return;
  }
};
