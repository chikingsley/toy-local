import {
  type SuperwhisperTranscriptionResult,
  voiceModelSpec,
} from "@chikingsley/superwhisper-provider";

import type { Env } from "../../bindings";
import { speakerTurnsFromWords } from "../transcription/speaker-turns";
import type {
  BatchTranscriptionProvider,
  BatchTranscriptionResult,
} from "../transcription/types";
import { createSuperwhisperProvider } from "./config";

const MAX_BUFFERED_MEDIA_BYTES = 25 * 1024 * 1024;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const stringOption = (
  options: Record<string, unknown>,
  ...names: string[]
): string | undefined => {
  for (const name of names) {
    const value = options[name];
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }
};

const stringArrayOption = (
  options: Record<string, unknown>,
  ...names: string[]
): string[] | undefined => {
  for (const name of names) {
    const value = options[name];
    if (
      Array.isArray(value) &&
      value.length > 0 &&
      value.every((item) => typeof item === "string")
    ) {
      return value;
    }
  }
};

const fetchMedia = async (
  media: Parameters<BatchTranscriptionProvider["transcribe"]>[0]["media"],
  fetcher: typeof fetch
): Promise<Uint8Array> => {
  if (media.sizeBytes > MAX_BUFFERED_MEDIA_BYTES) {
    throw new Error(
      `Superwhisper media exceeds the ${MAX_BUFFERED_MEDIA_BYTES}-byte buffered limit`
    );
  }
  const response = await fetcher(media.url);
  if (!response.ok) {
    throw new Error(
      `could not fetch transcription media: ${response.status} ${response.statusText}`
    );
  }
  const declaredSize = Number(response.headers.get("content-length"));
  if (
    Number.isFinite(declaredSize) &&
    declaredSize > MAX_BUFFERED_MEDIA_BYTES
  ) {
    throw new Error(
      `Superwhisper media exceeds the ${MAX_BUFFERED_MEDIA_BYTES}-byte buffered limit`
    );
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (bytes.byteLength > MAX_BUFFERED_MEDIA_BYTES) {
    throw new Error(
      `Superwhisper media exceeds the ${MAX_BUFFERED_MEDIA_BYTES}-byte buffered limit`
    );
  }
  return bytes;
};

const normalizedResult = (
  result: SuperwhisperTranscriptionResult
): BatchTranscriptionResult => {
  const words = result.words.map((word) => ({
    endSeconds: word.endSecond,
    scores:
      word.confidence === undefined
        ? undefined
        : { confidence: word.confidence },
    speaker: word.speaker,
    startSeconds: word.startSecond,
    text: word.text,
  }));
  const segments = result.segments.map((segment) => ({
    endSeconds: segment.endSecond,
    speaker: segment.speaker,
    startSeconds: segment.startSecond,
    text: segment.text,
  }));
  const providerSpeakerTurns = segments
    .filter((segment) => segment.speaker !== undefined)
    .map(({ endSeconds, speaker, startSeconds, text }) => ({
      endSeconds,
      speaker,
      startSeconds,
      text,
    }));
  const speakerTurns =
    providerSpeakerTurns.length > 0
      ? providerSpeakerTurns
      : speakerTurnsFromWords(words);
  const providerResponse = isRecord(result.raw)
    ? result.raw
    : { value: result.raw };
  const collection = (available: boolean, source: "derived" | "provider") =>
    available
      ? ({ availability: "available", source } as const)
      : ({ availability: "provider_omitted", source } as const);

  return {
    audioEvents: [],
    collections: {
      audioEvents: { availability: "unsupported" },
      segments: collection(segments.length > 0, "provider"),
      speakerTurns: collection(speakerTurns.length > 0, "derived"),
      tokens: { availability: "unsupported" },
      words: collection(words.length > 0, "provider"),
    },
    durationSeconds: result.durationInSeconds,
    language: result.language,
    providerMetadata: result.recordingId
      ? { requestId: result.recordingId }
      : {},
    providerResponse,
    segments,
    speakerTurns,
    text: result.text,
    tokens: [],
    usage: {},
    warnings: [],
    words,
  };
};

export const createSuperwhisperTranscriptionProvider = (config: {
  env: Env;
  fetch?: typeof fetch;
}): BatchTranscriptionProvider => ({
  transcribe: async (request) => {
    const model = voiceModelSpec(request.model);
    if (!model) {
      throw new Error(
        `unsupported Superwhisper transcription model: ${request.model}`
      );
    }
    const options = request.providerOptions ?? {};
    const optionDiarize = options.diarize;
    const audio = await fetchMedia(request.media, config.fetch ?? fetch);
    const result = await createSuperwhisperProvider(
      config.env
    ).client.transcribe(model.key, {
      audio,
      diarize:
        request.diarize ??
        (typeof optionDiarize === "boolean" ? optionDiarize : undefined),
      filename: request.media.filename,
      keyterms: stringArrayOption(options, "keyterm", "keywords", "keyterms"),
      language:
        request.language ?? stringOption(options, "language", "languageCode"),
      mediaType: request.media.contentType,
    });
    return normalizedResult(result);
  },
});
