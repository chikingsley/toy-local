import { z } from "zod";

import {
  connectDeepgramRealtime,
  type DeepgramRealtimeOptions,
  sendDeepgramAudio,
  sendDeepgramCloseStream,
  sendDeepgramFinalize,
  sendDeepgramKeepAlive,
} from "../ai/deepgram/realtime/client";
import { parseDeepgramRealtimeEvent } from "../ai/deepgram/realtime/events";
import {
  connectMistralRealtime,
  normalizeMistralRealtimeAudioEncoding,
  sendMistralInputAudioAppend,
  sendMistralInputAudioEnd,
  sendMistralInputAudioFlush,
} from "../ai/mistral/realtime/client";
import { parseMistralRealtimeEvent } from "../ai/mistral/realtime/events";
import type { RealtimeProviderId } from "../ai/model-routes";
import type { Env } from "../bindings";
import {
  normalizeDeepgramTranscriptEvent,
  normalizeMistralTranscriptEvent,
  persistRealtimeResult,
  type RealtimeTranscriptEvent,
} from "../realtime/result";

interface RealtimeSessionConfig {
  clientId: string | null;
  deepgram: DeepgramRealtimeOptions;
  encoding: string | null;
  language: string | null;
  model: string;
  provider: RealtimeProviderId;
  sampleRate: number | null;
  sessionId: string;
  targetStreamingDelayMs: number | null;
  upstreamModel: string;
}

const json = (value: unknown): string => JSON.stringify(value);

const RealtimeSessionConfigSchema = z
  .object({
    channels: z.number().int().positive().optional(),
    clientId: z.string().nullable().optional(),
    deepgram: z
      .object({
        detectEntities: z.boolean().optional(),
        diarize: z.boolean().optional(),
        diarizeModel: z.enum(["latest", "v1"]).optional(),
        dictation: z.boolean().optional(),
        endpointing: z.string().optional(),
        fillerWords: z.boolean().optional(),
        interimResults: z.boolean().optional(),
        keyterm: z.array(z.string()).optional(),
        keywords: z.array(z.string()).optional(),
        mipOptOut: z.boolean().optional(),
        multichannel: z.boolean().optional(),
        numerals: z.boolean().optional(),
        profanityFilter: z.boolean().optional(),
        punctuate: z.boolean().optional(),
        redact: z.array(z.string()).optional(),
        replace: z.array(z.string()).optional(),
        search: z.array(z.string()).optional(),
        smartFormat: z.boolean().optional(),
        tag: z.array(z.string()).optional(),
        utteranceEndMs: z.number().int().positive().optional(),
        vadEvents: z.boolean().optional(),
        version: z.string().optional(),
      })
      .optional(),
    encoding: z.string().nullable().optional(),
    language: z.string().nullable().optional(),
    model: z.string(),
    provider: z.enum(["deepgram", "mistral"]),
    sampleRate: z.number().int().positive().nullable().optional(),
    sessionId: z.string(),
    targetStreamingDelayMs: z.number().int().positive().nullable().optional(),
    upstreamModel: z.string(),
  })
  .strict();

const configFromHeaders = (headers: Headers): RealtimeSessionConfig => {
  const rawConfig = headers.get("x-realtime-config");
  if (!rawConfig) {
    throw new Error("missing realtime config");
  }
  const config = RealtimeSessionConfigSchema.parse(JSON.parse(rawConfig));
  return {
    deepgram: {
      ...config.deepgram,
      channels: config.channels,
      encoding: config.encoding ?? undefined,
      language: config.language ?? undefined,
      sampleRate: config.sampleRate ?? undefined,
    },
    clientId: config.clientId ?? null,
    encoding: config.encoding ?? null,
    language: config.language ?? null,
    model: config.model,
    provider: config.provider,
    sampleRate: config.sampleRate ?? null,
    sessionId: config.sessionId,
    targetStreamingDelayMs: config.targetStreamingDelayMs ?? null,
    upstreamModel: config.upstreamModel,
  };
};

const closeSocket = (socket: WebSocket, code: number, reason: string): void => {
  try {
    socket.close(code, reason);
  } catch {
    // Socket was already closed.
  }
};

const PROVIDER_FLUSH_TIMEOUT_MS = 3000;

export class RealtimeSession {
  private audioBytes = 0;
  private readonly env: Env;
  private messageCount = 0;
  private provider: RealtimeProviderId | null = null;
  private providerSocket: WebSocket | null = null;
  private providerSocketPromise: Promise<WebSocket> | null = null;
  private providerClosed = false;
  private providerClosedWaiters: Array<() => void> = [];
  private persisted = false;
  private readonly state: DurableObjectState;
  private startedAt: string | null = null;
  private readonly transcriptEvents: RealtimeTranscriptEvent[] = [];

  constructor(state: DurableObjectState, env: Env) {
    this.env = env;
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    if (request.headers.get("upgrade")?.toLowerCase() !== "websocket") {
      return new Response("expected websocket upgrade", { status: 426 });
    }

    const config = configFromHeaders(request.headers);
    this.startedAt = new Date().toISOString();
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    server.accept();

    await this.state.storage.put("session", {
      audioBytes: this.audioBytes,
      config,
      messageCount: this.messageCount,
      startedAt: this.startedAt,
    });

    server.send(
      json({
        config,
        session_id: config.sessionId,
        type: "session.started",
      })
    );

    this.providerSocketPromise = this.connectProvider(server, config);

    server.addEventListener("message", (event) => {
      this.state.waitUntil(this.handleMessage(server, event, config));
    });

    server.addEventListener("close", () => {
      this.closeProvider();
      this.state.waitUntil(
        Promise.all([
          this.state.storage.put("session", {
            audioBytes: this.audioBytes,
            config,
            endedAt: new Date().toISOString(),
            messageCount: this.messageCount,
          }),
          this.persistResult(config, "succeeded"),
        ])
      );
    });

    return new Response(null, { status: 101, webSocket: client });
  }

  private handleMessage(
    socket: WebSocket,
    event: MessageEvent,
    config: RealtimeSessionConfig
  ): Promise<void> {
    this.messageCount += 1;

    if (typeof event.data === "string") {
      return this.handleTextMessage(socket, event.data, config);
    }

    return this.handleAudioMessage(socket, event.data, config);
  }

  private async handleAudioMessage(
    socket: WebSocket,
    data: unknown,
    config: RealtimeSessionConfig
  ): Promise<void> {
    const audio = await audioBytes(data);
    const size = audio.byteLength;
    this.audioBytes += size;
    await this.withProviderSocket((providerSocket) => {
      if (config.provider === "deepgram") {
        sendDeepgramAudio(providerSocket, audio);
        return;
      }
      sendMistralInputAudioAppend(providerSocket, audio);
    });
    socket.send(
      json({
        audio_bytes: this.audioBytes,
        chunk_bytes: size,
        message_count: this.messageCount,
        session_id: config.sessionId,
        type: "audio.received",
      })
    );
  }

  private async handleTextMessage(
    socket: WebSocket,
    data: string,
    config: RealtimeSessionConfig
  ): Promise<void> {
    let message: unknown;
    try {
      message = JSON.parse(data);
    } catch {
      socket.send(
        json({
          message_count: this.messageCount,
          session_id: config.sessionId,
          text: data,
          type: "text.received",
        })
      );
      return;
    }

    if (
      typeof message === "object" &&
      message !== null &&
      "type" in message &&
      message.type === "close"
    ) {
      try {
        await this.withProviderSocket((providerSocket) => {
          this.closeProviderStream(providerSocket, config.provider);
        });
        await this.waitForProviderClose(PROVIDER_FLUSH_TIMEOUT_MS);
      } catch {
        // No provider socket to flush; end the session directly.
      }
      socket.send(
        json({
          audio_bytes: this.audioBytes,
          message_count: this.messageCount,
          session_id: config.sessionId,
          type: "session.ended",
        })
      );
      closeSocket(socket, 1000, "client requested close");
      return;
    }

    if (
      typeof message === "object" &&
      message !== null &&
      "type" in message &&
      message.type === "ping"
    ) {
      socket.send(
        json({
          message_count: this.messageCount,
          session_id: config.sessionId,
          type: "pong",
        })
      );
      return;
    }

    if (config.provider === "deepgram" && isDeepgramClientMessage(message)) {
      await this.withProviderSocket((providerSocket) => {
        this.forwardDeepgramClientMessage(providerSocket, message.type);
      });
      socket.send(
        json({
          message_count: this.messageCount,
          provider: "deepgram",
          session_id: config.sessionId,
          type: "event.forwarded",
        })
      );
      return;
    }

    if (config.provider === "mistral" && isMistralClientMessage(message)) {
      await this.withProviderSocket((providerSocket) => {
        providerSocket.send(JSON.stringify(message));
      });
      socket.send(
        json({
          message_count: this.messageCount,
          session_id: config.sessionId,
          type: "event.forwarded",
        })
      );
      return;
    }

    socket.send(
      json({
        message,
        message_count: this.messageCount,
        session_id: config.sessionId,
        type: "event.received",
      })
    );
  }

  private async connectProvider(
    socket: WebSocket,
    config: RealtimeSessionConfig
  ): Promise<WebSocket> {
    try {
      const providerSocket =
        config.provider === "deepgram"
          ? await connectDeepgramRealtime({
              apiKey: this.env.DEEPGRAM_API_KEY,
              model: config.upstreamModel,
              options: config.deepgram,
            })
          : await connectMistralRealtime({
              apiKey: this.env.MISTRAL_API_KEY,
              model: config.upstreamModel,
              session: {
                audioFormat: {
                  encoding: normalizeMistralRealtimeAudioEncoding(
                    config.encoding ?? "pcm_s16le"
                  ),
                  sampleRate: config.sampleRate ?? 16_000,
                },
                targetStreamingDelayMs:
                  config.targetStreamingDelayMs ?? undefined,
              },
            });
      this.provider = config.provider;
      this.providerSocket = providerSocket;
      this.attachProviderSocket(socket, providerSocket, config);
      safeSend(
        socket,
        json({
          provider: config.provider,
          session_id: config.sessionId,
          type: "provider.connected",
        })
      );
      return providerSocket;
    } catch (error) {
      safeSend(
        socket,
        json({
          error: error instanceof Error ? error.message : String(error),
          provider: config.provider,
          session_id: config.sessionId,
          type: "provider.error",
        })
      );
      throw error;
    }
  }

  private attachProviderSocket(
    clientSocket: WebSocket,
    providerSocket: WebSocket,
    config: RealtimeSessionConfig
  ): void {
    providerSocket.addEventListener("message", (event) => {
      this.state.waitUntil(
        this.forwardProviderMessage(clientSocket, event, config.provider)
      );
    });
    providerSocket.addEventListener("close", () => {
      this.resolveProviderClosed();
      safeSend(
        clientSocket,
        json({
          provider: config.provider,
          session_id: config.sessionId,
          type: "provider.closed",
        })
      );
      this.state.waitUntil(this.persistResult(config, "succeeded"));
    });
    providerSocket.addEventListener("error", () => {
      this.resolveProviderClosed();
      safeSend(
        clientSocket,
        json({
          provider: config.provider,
          session_id: config.sessionId,
          type: "provider.error",
        })
      );
      this.state.waitUntil(
        this.persistResult(config, "failed", "provider error")
      );
    });
  }

  private resolveProviderClosed(): void {
    this.providerClosed = true;
    const waiters = this.providerClosedWaiters;
    this.providerClosedWaiters = [];
    for (const waiter of waiters) {
      waiter();
    }
  }

  private waitForProviderClose(timeoutMs: number): Promise<void> {
    if (this.providerClosed) {
      return Promise.resolve();
    }
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        resolve();
      }, timeoutMs);
      this.providerClosedWaiters.push(() => {
        clearTimeout(timer);
        resolve();
      });
    });
  }

  private async forwardProviderMessage(
    clientSocket: WebSocket,
    event: MessageEvent,
    provider: RealtimeProviderId
  ): Promise<void> {
    const data = await messageDataToString(event.data);
    if (provider === "deepgram") {
      const parsed = parseDeepgramRealtimeEvent(data);
      if (parsed?.type === "Results") {
        await this.state.storage.put("transcription", parsed);
        const event = normalizeDeepgramTranscriptEvent(parsed);
        if (event) {
          this.transcriptEvents.push(event);
        }
      }
    } else {
      const parsed = parseMistralRealtimeEvent(data);
      if (parsed?.type === "transcription.done") {
        await this.state.storage.put("transcription", parsed);
      }
      if (parsed) {
        const event = normalizeMistralTranscriptEvent(parsed);
        if (event) {
          this.transcriptEvents.push(event);
        }
      }
    }
    safeSend(clientSocket, data);
  }

  private async withProviderSocket(
    action: (providerSocket: WebSocket) => void
  ): Promise<void> {
    const providerSocket = await this.providerSocketPromise;
    if (!providerSocket) {
      throw new Error("provider socket is not connected");
    }
    action(providerSocket);
  }

  private closeProviderStream(
    providerSocket: WebSocket,
    provider: RealtimeProviderId
  ): void {
    if (provider === "deepgram") {
      sendDeepgramFinalize(providerSocket);
      sendDeepgramCloseStream(providerSocket);
      return;
    }
    sendMistralInputAudioFlush(providerSocket);
    sendMistralInputAudioEnd(providerSocket);
  }

  private forwardDeepgramClientMessage(
    providerSocket: WebSocket,
    type: DeepgramClientMessageType
  ): void {
    switch (type) {
      case "CloseStream":
      case "close_stream":
        sendDeepgramCloseStream(providerSocket);
        return;
      case "Finalize":
      case "finalize":
        sendDeepgramFinalize(providerSocket);
        return;
      case "KeepAlive":
      case "keep_alive":
        sendDeepgramKeepAlive(providerSocket);
        return;
      default:
        return;
    }
  }

  private closeProvider(): void {
    const providerSocket = this.providerSocket;
    const provider = this.provider;
    this.providerSocket = null;
    this.provider = null;
    if (providerSocket) {
      if (provider === "deepgram") {
        sendDeepgramCloseStream(providerSocket);
      } else {
        sendMistralInputAudioEnd(providerSocket);
      }
      closeSocket(providerSocket, 1000, "client disconnected");
    }
  }

  private async persistResult(
    config: RealtimeSessionConfig,
    status: "failed" | "succeeded",
    error?: string
  ): Promise<void> {
    if (this.persisted) {
      return;
    }
    this.persisted = true;
    const endedAt = new Date().toISOString();
    try {
      await persistRealtimeResult(this.env, config, {
        audioBytes: this.audioBytes,
        endedAt,
        error,
        events: this.transcriptEvents,
        messageCount: this.messageCount,
        startedAt: this.startedAt ?? endedAt,
        status,
      });
    } catch (persistError) {
      console.error(
        JSON.stringify({
          error:
            persistError instanceof Error
              ? persistError.message
              : String(persistError),
          event: "realtime.persist_failed",
          session_id: config.sessionId,
        })
      );
    }
  }
}

const audioBytes = async (data: unknown): Promise<Uint8Array> => {
  if (data instanceof ArrayBuffer) {
    return new Uint8Array(data);
  }
  if (data instanceof Blob) {
    return new Uint8Array(await data.arrayBuffer());
  }
  if (ArrayBuffer.isView(data)) {
    return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
  }
  throw new Error("unsupported audio message payload");
};

const safeSend = (socket: WebSocket, data: string): boolean => {
  try {
    socket.send(data);
    return true;
  } catch {
    return false;
  }
};

const messageDataToString = async (data: unknown): Promise<string> => {
  if (typeof data === "string") {
    return data;
  }
  if (data instanceof ArrayBuffer) {
    return new TextDecoder().decode(data);
  }
  if (data instanceof Blob) {
    return await data.text();
  }
  if (ArrayBuffer.isView(data)) {
    return new TextDecoder().decode(
      new Uint8Array(data.buffer, data.byteOffset, data.byteLength)
    );
  }
  return JSON.stringify(data);
};

const isMistralClientMessage = (value: unknown): value is { type: string } => {
  if (typeof value !== "object" || value === null || !("type" in value)) {
    return false;
  }
  const type = value.type;
  return (
    type === "input_audio.append" ||
    type === "input_audio.flush" ||
    type === "input_audio.end" ||
    type === "session.update"
  );
};

type DeepgramClientMessageType =
  | "CloseStream"
  | "Finalize"
  | "KeepAlive"
  | "close_stream"
  | "finalize"
  | "keep_alive";

const isDeepgramClientMessage = (
  value: unknown
): value is { type: DeepgramClientMessageType } => {
  if (typeof value !== "object" || value === null || !("type" in value)) {
    return false;
  }
  const type = value.type;
  return (
    type === "CloseStream" ||
    type === "Finalize" ||
    type === "KeepAlive" ||
    type === "close_stream" ||
    type === "finalize" ||
    type === "keep_alive"
  );
};
