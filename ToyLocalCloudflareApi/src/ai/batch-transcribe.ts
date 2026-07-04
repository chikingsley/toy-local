import { transcribe } from "ai";

import type { Env } from "../bindings";
import {
  type TranscriptionProviderId,
  transcriptionModelRoute,
} from "./model-routes";
import { resolveTranscriptionModel } from "./registry";

export interface TranscribeAudioResult {
  model: string;
  provider: TranscriptionProviderId;
  result: {
    durationSeconds?: number;
    language?: string;
    providerMetadata?: unknown;
    segments?: readonly {
      endSeconds?: number;
      speaker?: number | string;
      startSeconds?: number;
      text: string;
    }[];
    text: string;
    warnings?: unknown[];
  };
  upstreamModel: string;
}

export const transcribeAudio = async (
  env: Env,
  modelId: string,
  input: {
    contentType: string;
    data: ArrayBuffer;
    filename: string;
    language?: string;
    providerOptions?: Parameters<typeof transcribe>[0]["providerOptions"];
  }
): Promise<TranscribeAudioResult> => {
  const route = transcriptionModelRoute(modelId);
  const result = await transcribe({
    audio: input.data,
    model: resolveTranscriptionModel(env, modelId),
    providerOptions: input.providerOptions,
  });
  const segments =
    deepgramWordSegments(result.responses.at(0)) ?? result.segments;

  return {
    model: modelId,
    provider: route.provider,
    result: {
      durationSeconds: result.durationInSeconds,
      language: result.language,
      providerMetadata: result.providerMetadata,
      segments: segments.map((segment) => ({
        endSeconds: segment.endSecond,
        speaker: "speaker" in segment ? segment.speaker : undefined,
        startSeconds: segment.startSecond,
        text: segment.text,
      })),
      text: result.text,
      warnings: result.warnings,
    },
    upstreamModel: route.upstreamModel,
  };
};

const deepgramWordSegments = (
  response: unknown
):
  | readonly {
      endSecond?: number;
      speaker?: number | string;
      startSecond?: number;
      text: string;
    }[]
  | undefined => {
  const body = (response as { body?: unknown } | undefined)?.body;
  const words =
    (body as DeepgramRawResponse | undefined)?.results?.channels
      ?.at(0)
      ?.alternatives?.at(0)?.words ?? [];
  const segments = words.flatMap((word) => {
    const text = word.punctuated_word ?? word.word;
    return text
      ? [
          {
            endSecond: word.end,
            speaker: word.speaker,
            startSecond: word.start,
            text,
          },
        ]
      : [];
  });
  return segments.length > 0 ? segments : undefined;
};

interface DeepgramRawResponse {
  results?: {
    channels?: {
      alternatives?: {
        words?: {
          end?: number;
          punctuated_word?: string;
          speaker?: number | string;
          start?: number;
          word?: string;
        }[];
      }[];
    }[];
  };
}
