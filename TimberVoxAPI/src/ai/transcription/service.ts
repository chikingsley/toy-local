import type { Env } from "../../bindings";
import { resolveBatchAsrModel } from "../models/transcription-routes";
import type {
  BatchAsrExecutionProviderId,
  BatchAsrProviderId,
} from "../models/types";
import { resolveBatchTranscriptionProvider } from "./registry";
import {
  BatchTranscriptionResultSchema,
  type RemoteMediaSource,
} from "./types";

export interface TranscribeRemoteMediaResult {
  executionModel: string;
  executionProvider: BatchAsrExecutionProviderId;
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
  const provider = resolveBatchTranscriptionProvider(
    env,
    route.executionProvider
  );
  const result = await provider.transcribe({
    diarize: input.diarize,
    language: input.language,
    media: input.media,
    model: route.executionModel,
    providerOptions: input.providerOptions?.[route.provider],
  });

  return {
    executionModel: route.executionModel,
    executionProvider: route.executionProvider,
    model: modelId,
    provider: route.provider,
    result: BatchTranscriptionResultSchema.parse(result),
    upstreamModel: route.upstreamModel,
  };
};
