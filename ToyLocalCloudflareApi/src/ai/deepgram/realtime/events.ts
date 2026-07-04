import { z } from "zod";

const DeepgramRealtimeEventSchema = z
  .object({
    type: z.enum(["Results", "Metadata", "UtteranceEnd", "SpeechStarted"]),
  })
  .catchall(z.unknown());

export type DeepgramRealtimeEvent = z.infer<typeof DeepgramRealtimeEventSchema>;

export const parseDeepgramRealtimeEvent = (
  data: string
): DeepgramRealtimeEvent | undefined => {
  try {
    return DeepgramRealtimeEventSchema.parse(JSON.parse(data));
  } catch {
    return;
  }
};
