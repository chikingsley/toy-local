import { z } from "zod";

import { MistralTimestampGranularitySchema } from "./api-types";

export const MistralTranscriptionModelOptionsSchema = z
  .object({
    contextBias: z.array(z.string().min(1)).max(100).optional(),
    diarize: z.boolean().optional(),
    language: z
      .string()
      .regex(/^\w{2}$/)
      .optional(),
    temperature: z.number().optional(),
    timestampGranularities: z
      .array(MistralTimestampGranularitySchema)
      .min(1)
      .optional(),
  })
  .strict();

export type MistralTranscriptionModelOptions = z.infer<
  typeof MistralTranscriptionModelOptionsSchema
>;

export const appendMistralTranscriptionOptions = (
  form: FormData,
  options: MistralTranscriptionModelOptions
): void => {
  appendRepeated(form, "context_bias", options.contextBias);
  appendOptional(form, "diarize", options.diarize);
  appendOptional(form, "language", options.language);
  appendOptional(form, "temperature", options.temperature);
  appendRepeated(
    form,
    "timestamp_granularities",
    options.timestampGranularities
  );
};

const appendOptional = (
  form: FormData,
  key: string,
  value: boolean | number | string | undefined
): void => {
  if (value !== undefined) {
    form.append(key, String(value));
  }
};

const appendRepeated = (
  form: FormData,
  key: string,
  values: readonly string[] | undefined
): void => {
  for (const value of values ?? []) {
    form.append(key, value);
  }
};
