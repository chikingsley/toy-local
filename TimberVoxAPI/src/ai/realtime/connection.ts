import type { Env } from "../../bindings";
import {
  connectDeepgramRealtime,
  type DeepgramRealtimeOptions,
  sendDeepgramAudio,
  sendDeepgramCloseStream,
  sendDeepgramFinalize,
} from "../deepgram/realtime/client";
import { parseDeepgramRealtimeEvent } from "../deepgram/realtime/events";
import {
  connectMistralRealtime,
  normalizeMistralRealtimeAudioEncoding,
  sendMistralInputAudioAppend,
  sendMistralInputAudioEnd,
  sendMistralInputAudioFlush,
} from "../mistral/realtime/client";
import { parseMistralRealtimeEvent } from "../mistral/realtime/events";
import type { DirectRealtimeAsrExecutionProviderId } from "../models/types";
import {
  normalizeDeepgramTranscriptEvent,
  normalizeMistralTranscriptEvent,
  type RealtimeTranscriptEvent,
} from "./normalize";

export interface RealtimeProviderConnectionConfig {
  deepgram: DeepgramRealtimeOptions;
  encoding: string | null;
  provider: DirectRealtimeAsrExecutionProviderId;
  sampleRate: number | null;
  targetStreamingDelayMs: number | null;
  upstreamModel: string;
}

export interface ParsedRealtimeProviderMessage {
  providerError?: string;
  providerEvent?: unknown;
  transcriptEvent?: RealtimeTranscriptEvent;
}

export interface RealtimeProviderConnection {
  close: (socket: WebSocket) => void;
  connect: () => Promise<WebSocket>;
  finish: (socket: WebSocket) => void;
  parseMessage: (data: string) => ParsedRealtimeProviderMessage;
  provider: DirectRealtimeAsrExecutionProviderId;
  sendAudio: (socket: WebSocket, audio: Uint8Array) => void;
}

export const createRealtimeProviderConnection = (
  env: Env,
  config: RealtimeProviderConnectionConfig
): RealtimeProviderConnection =>
  config.provider === "deepgram"
    ? deepgramConnection(env, config)
    : mistralConnection(env, config);

const deepgramConnection = (
  env: Env,
  config: RealtimeProviderConnectionConfig
): RealtimeProviderConnection => ({
  close: sendDeepgramCloseStream,
  connect: () =>
    connectDeepgramRealtime({
      apiKey: env.DEEPGRAM_API_KEY,
      model: config.upstreamModel,
      options: config.deepgram,
    }),
  finish: (socket) => {
    sendDeepgramFinalize(socket);
    sendDeepgramCloseStream(socket);
  },
  parseMessage: (data) => {
    const providerEvent = parseDeepgramRealtimeEvent(data);
    const transcriptEvent = providerEvent
      ? (normalizeDeepgramTranscriptEvent(providerEvent) ?? undefined)
      : undefined;
    return {
      providerError:
        providerEvent?.type === "Error"
          ? describeProviderError(providerEvent)
          : undefined,
      providerEvent,
      transcriptEvent,
    };
  },
  provider: "deepgram",
  sendAudio: sendDeepgramAudio,
});

const mistralConnection = (
  env: Env,
  config: RealtimeProviderConnectionConfig
): RealtimeProviderConnection => ({
  close: sendMistralInputAudioEnd,
  connect: () =>
    connectMistralRealtime({
      apiKey: env.MISTRAL_API_KEY,
      model: config.upstreamModel,
      session: {
        audioFormat: {
          encoding: normalizeMistralRealtimeAudioEncoding(
            config.encoding ?? "pcm_s16le"
          ),
          sampleRate: config.sampleRate ?? 16_000,
        },
        targetStreamingDelayMs: config.targetStreamingDelayMs ?? undefined,
      },
    }),
  finish: (socket) => {
    sendMistralInputAudioFlush(socket);
    sendMistralInputAudioEnd(socket);
  },
  parseMessage: (data) => {
    const providerEvent = parseMistralRealtimeEvent(data);
    const transcriptEvent = providerEvent
      ? (normalizeMistralTranscriptEvent(providerEvent) ?? undefined)
      : undefined;
    return {
      providerError:
        providerEvent?.type === "error"
          ? describeProviderError(providerEvent.error)
          : undefined,
      providerEvent,
      transcriptEvent,
    };
  },
  provider: "mistral",
  sendAudio: sendMistralInputAudioAppend,
});

const describeProviderError = (value: unknown): string => {
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "object" && value !== null) {
    const record = value as Record<string, unknown>;
    if (typeof record.message === "string") {
      return record.message;
    }
    if (record.message !== undefined) {
      return JSON.stringify(record.message);
    }
  }
  return JSON.stringify(value);
};
