import { z } from "zod";

import { type MistralConfig, mistralHeaders, mistralUrl } from "../config";

const REALTIME_PATH = "/v1/audio/transcriptions/realtime";
const MAX_APPEND_BYTES = 262_144;

const MistralRealtimeAudioEncodingSchema = z.enum([
  "pcm_s16le",
  "pcm_s32le",
  "pcm_f16le",
  "pcm_f32le",
  "pcm_mulaw",
  "pcm_alaw",
]);

type MistralRealtimeAudioEncoding = z.infer<
  typeof MistralRealtimeAudioEncodingSchema
>;

interface MistralRealtimeSessionConfig {
  audioFormat: {
    encoding: MistralRealtimeAudioEncoding;
    sampleRate: number;
  };
  targetStreamingDelayMs?: number;
}

export interface MistralRealtimeBridgeConfig
  extends Pick<MistralConfig, "apiKey" | "baseUrl" | "fetch" | "headers"> {
  model: string;
  session?: MistralRealtimeSessionConfig;
}

type MistralRealtimeClientMessage =
  | { audio: string; type: "input_audio.append" }
  | { type: "input_audio.flush" }
  | { type: "input_audio.end" }
  | {
      session: {
        audio_format?: {
          encoding: MistralRealtimeAudioEncoding;
          sample_rate: number;
        };
        target_streaming_delay_ms?: number;
      };
      type: "session.update";
    };

export const normalizeMistralRealtimeAudioEncoding = (
  encoding: string
): MistralRealtimeAudioEncoding => {
  if (encoding === "linear16" || encoding === "pcm_16000") {
    return "pcm_s16le";
  }
  return MistralRealtimeAudioEncodingSchema.parse(encoding);
};

export const connectMistralRealtime = async (
  config: MistralRealtimeBridgeConfig
): Promise<WebSocket> => {
  const url = mistralUrl({ baseUrl: config.baseUrl }, REALTIME_PATH);
  url.searchParams.set("model", config.model);

  const headers = mistralHeaders(
    {
      apiKey: config.apiKey,
      headers: config.headers,
    },
    { upgrade: "websocket" }
  );
  const response = await (config.fetch ?? fetch)(url, { headers });
  const socket = response.webSocket;
  if (!socket) {
    throw new Error(`Mistral realtime upgrade failed: ${response.status}`);
  }
  socket.accept();

  if (config.session) {
    sendMistralSessionUpdate(socket, config.session);
  }

  return socket;
};

const sendMistralSessionUpdate = (
  socket: WebSocket,
  session: MistralRealtimeSessionConfig
): void => {
  const payload: MistralRealtimeClientMessage = {
    session: {},
    type: "session.update",
  };

  payload.session.audio_format = {
    encoding: session.audioFormat.encoding,
    sample_rate: session.audioFormat.sampleRate,
  };
  if (session.targetStreamingDelayMs !== undefined) {
    payload.session.target_streaming_delay_ms = session.targetStreamingDelayMs;
  }

  socket.send(JSON.stringify(payload));
};

export const sendMistralInputAudioAppend = (
  socket: WebSocket,
  audio: ArrayBuffer | Uint8Array
): void => {
  const bytes = audio instanceof Uint8Array ? audio : new Uint8Array(audio);
  for (let offset = 0; offset < bytes.byteLength; offset += MAX_APPEND_BYTES) {
    const chunk = bytes.slice(offset, offset + MAX_APPEND_BYTES);
    socket.send(
      JSON.stringify({
        audio: bytesToBase64(chunk),
        type: "input_audio.append",
      } satisfies MistralRealtimeClientMessage)
    );
  }
};

export const sendMistralInputAudioFlush = (socket: WebSocket): void => {
  socket.send(
    JSON.stringify({
      type: "input_audio.flush",
    } satisfies MistralRealtimeClientMessage)
  );
};

export const sendMistralInputAudioEnd = (socket: WebSocket): void => {
  socket.send(
    JSON.stringify({
      type: "input_audio.end",
    } satisfies MistralRealtimeClientMessage)
  );
};

const bytesToBase64 = (bytes: Uint8Array): string => {
  let binary = "";
  const chunkSize = 0x80_00;
  for (let offset = 0; offset < bytes.byteLength; offset += chunkSize) {
    const chunk = bytes.slice(offset, offset + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
};
