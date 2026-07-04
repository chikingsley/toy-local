import type { MistralConfig } from "../config";
import { mistralHeaders, mistralUrl } from "../config";
import { MistralApiError } from "../error";
import { MistralTranscriptionResponseSchema } from "./api-types";
import {
  appendMistralTranscriptionOptions,
  MistralTranscriptionModelOptionsSchema,
} from "./model-options";

interface TranscriptionGenerateOptions {
  abortSignal?: AbortSignal;
  audio: ArrayBuffer | Uint8Array | string;
  headers?: Record<string, string | undefined>;
  mediaType: string;
  providerOptions?: Record<string, unknown>;
}

const TRANSCRIPTIONS_PATH = "/v1/audio/transcriptions";

export class MistralTranscriptionModel {
  private readonly config: MistralConfig;
  readonly modelId: string;
  readonly specificationVersion = "v4" as const;

  constructor(modelId: string, config: MistralConfig) {
    this.config = config;
    this.modelId = modelId;
  }

  get provider(): string {
    return this.config.provider;
  }

  async doGenerate(options: TranscriptionGenerateOptions) {
    const currentDate = new Date();
    const providerOptions = MistralTranscriptionModelOptionsSchema.parse(
      getMistralProviderOptions(options.providerOptions)
    );
    const audio =
      typeof options.audio === "string"
        ? base64ToBytes(options.audio)
        : options.audio;
    const response = await (this.config.fetch ?? fetch)(
      mistralUrl(this.config, TRANSCRIPTIONS_PATH),
      {
        body: createRequestBody({
          audio,
          mediaType: options.mediaType,
          modelId: this.modelId,
          options: providerOptions,
        }),
        headers: mistralHeaders(this.config, options.headers),
        method: "POST",
        signal: options.abortSignal,
      }
    );
    const rawBody = await readResponseBody(response);

    if (!response.ok) {
      throw new MistralApiError(
        `Mistral transcription failed ${response.status}`,
        {
          body: rawBody,
          status: response.status,
        }
      );
    }

    const body = MistralTranscriptionResponseSchema.parse(rawBody);

    return {
      durationInSeconds: body.usage.prompt_audio_seconds ?? undefined,
      language: body.language ?? undefined,
      providerMetadata: {
        mistral: {
          completion_tokens: body.usage.completion_tokens ?? null,
          prompt_audio_seconds: body.usage.prompt_audio_seconds ?? null,
          prompt_tokens: body.usage.prompt_tokens ?? null,
          total_tokens: body.usage.total_tokens ?? null,
        },
      },
      response: {
        body: rawBody,
        headers: Object.fromEntries(response.headers.entries()),
        modelId: body.model,
        timestamp: currentDate,
      },
      segments:
        body.segments?.map((segment) => ({
          endSecond: segment.end,
          startSecond: segment.start,
          text: segment.text,
        })) ?? [],
      text: body.text,
      warnings: [],
    };
  }
}

const getMistralProviderOptions = (
  providerOptions: Record<string, unknown> | undefined
): unknown => {
  const value = providerOptions?.mistral;
  return typeof value === "object" && value !== null ? value : {};
};

const createRequestBody = ({
  audio,
  mediaType,
  modelId,
  options,
}: {
  audio: ArrayBuffer | Uint8Array;
  mediaType: string;
  modelId: string;
  options: Parameters<typeof appendMistralTranscriptionOptions>[1];
}): FormData => {
  const form = new FormData();
  form.append("model", modelId);
  form.append(
    "file",
    new Blob([audio], { type: mediaType }),
    filenameForMediaType(mediaType)
  );
  appendMistralTranscriptionOptions(form, options);
  return form;
};

const readResponseBody = async (response: Response): Promise<unknown> => {
  const text = await response.text();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

const filenameForMediaType = (mediaType: string): string => {
  const subtype = mediaType.split("/").at(1)?.split(";").at(0);
  return subtype ? `audio.${subtype}` : "audio";
};

const base64ToBytes = (value: string): Uint8Array =>
  Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
