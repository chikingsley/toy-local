import type { Env } from "../../bindings";
import { resolveBatchAsrModel } from "../models/transcription-routes";
import type { BatchAsrProviderId } from "../models/types";
import { resolveBatchTranscriptionProvider } from "./registry";
import {
  BatchTranscriptionResultSchema,
  type RemoteMediaSource,
} from "./types";

export interface TranscribeRemoteMediaResult {
  model: string;
  provider: BatchAsrProviderId;
  result: ReturnType<typeof BatchTranscriptionResultSchema.parse>;
  upstreamModel: string;
}

export const transcribeRemoteMedia = async (
  env: Env,
  modelId: string,
  input: {
    diarize?: boolean;
    language?: string;
    media: RemoteMediaSource;
    providerOptions?: Record<string, Record<string, unknown>>;
  }
): Promise<TranscribeRemoteMediaResult> => {
  const route = resolveBatchAsrModel(modelId);
  const provider = resolveBatchTranscriptionProvider(env, route.provider);
  const result = await provider.transcribe({
    diarize: input.diarize,
    language: input.language,
    media: input.media,
    model: route.upstreamModel,
    providerOptions: input.providerOptions?.[route.provider],
  });

  return {
    model: modelId,
    provider: route.provider,
    result: BatchTranscriptionResultSchema.parse(result),
    upstreamModel: route.upstreamModel,
  };
};
