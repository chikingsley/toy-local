const DEEPGRAM_REALTIME_URL = "https://api.deepgram.com/v1/listen";

export interface DeepgramRealtimeOptions {
  channels?: number;
  detectEntities?: boolean;
  diarize?: boolean;
  diarizeModel?: "latest" | "v1";
  dictation?: boolean;
  encoding?: string;
  endpointing?: string;
  fillerWords?: boolean;
  interimResults?: boolean;
  keyterm?: readonly string[];
  keywords?: readonly string[];
  language?: string;
  mipOptOut?: boolean;
  multichannel?: boolean;
  numerals?: boolean;
  profanityFilter?: boolean;
  punctuate?: boolean;
  redact?: readonly string[];
  replace?: readonly string[];
  sampleRate?: number;
  search?: readonly string[];
  smartFormat?: boolean;
  tag?: readonly string[];
  utteranceEndMs?: number;
  vadEvents?: boolean;
  version?: string;
}

export interface DeepgramRealtimeBridgeConfig {
  apiKey?: string;
  baseUrl?: string;
  fetch?: typeof fetch;
  headers?: Record<string, string | undefined>;
  model: string;
  options?: DeepgramRealtimeOptions;
}

type DeepgramRealtimeClientMessage =
  | { type: "CloseStream" }
  | { type: "Finalize" }
  | { type: "KeepAlive" };

export const connectDeepgramRealtime = async (
  config: DeepgramRealtimeBridgeConfig
): Promise<WebSocket> => {
  if (!config.apiKey) {
    throw new Error("missing DEEPGRAM_API_KEY");
  }

  const url = new URL(config.baseUrl ?? DEEPGRAM_REALTIME_URL);
  url.searchParams.set("model", config.model);
  appendDeepgramOptions(url, config.options);

  const response = await (config.fetch ?? fetch)(url, {
    headers: {
      ...definedHeaders(config.headers),
      authorization: `Token ${config.apiKey}`,
      upgrade: "websocket",
    },
  });
  const socket = response.webSocket;
  if (!socket) {
    throw new Error(`Deepgram realtime upgrade failed: ${response.status}`);
  }
  socket.accept();
  return socket;
};

export const sendDeepgramAudio = (
  socket: WebSocket,
  audio: ArrayBuffer | Uint8Array
): void => {
  socket.send(audio instanceof Uint8Array ? audio : new Uint8Array(audio));
};

export const sendDeepgramFinalize = (socket: WebSocket): void => {
  sendDeepgramControl(socket, { type: "Finalize" });
};

export const sendDeepgramCloseStream = (socket: WebSocket): void => {
  sendDeepgramControl(socket, { type: "CloseStream" });
};

export const sendDeepgramKeepAlive = (socket: WebSocket): void => {
  sendDeepgramControl(socket, { type: "KeepAlive" });
};

const sendDeepgramControl = (
  socket: WebSocket,
  message: DeepgramRealtimeClientMessage
): void => {
  socket.send(JSON.stringify(message));
};

const appendDeepgramOptions = (
  url: URL,
  options: DeepgramRealtimeOptions | undefined
): void => {
  if (!options) {
    return;
  }

  appendNumber(url, "channels", options.channels);
  appendBoolean(url, "detect_entities", options.detectEntities);
  appendBoolean(url, "diarize", options.diarize);
  appendString(url, "diarize_model", options.diarizeModel);
  appendBoolean(url, "dictation", options.dictation);
  appendString(url, "encoding", options.encoding);
  appendString(url, "endpointing", options.endpointing);
  appendBoolean(url, "filler_words", options.fillerWords);
  appendBoolean(url, "interim_results", options.interimResults);
  appendStrings(url, "keyterm", options.keyterm);
  appendStrings(url, "keywords", options.keywords);
  appendString(url, "language", options.language);
  appendBoolean(url, "mip_opt_out", options.mipOptOut);
  appendBoolean(url, "multichannel", options.multichannel);
  appendBoolean(url, "numerals", options.numerals);
  appendBoolean(url, "profanity_filter", options.profanityFilter);
  appendBoolean(url, "punctuate", options.punctuate);
  appendStrings(url, "redact", options.redact);
  appendStrings(url, "replace", options.replace);
  appendNumber(url, "sample_rate", options.sampleRate);
  appendStrings(url, "search", options.search);
  appendBoolean(url, "smart_format", options.smartFormat);
  appendStrings(url, "tag", options.tag);
  appendNumber(url, "utterance_end_ms", options.utteranceEndMs);
  appendBoolean(url, "vad_events", options.vadEvents);
  appendString(url, "version", options.version);
};

const appendBoolean = (
  url: URL,
  key: string,
  value: boolean | undefined
): void => {
  if (value !== undefined) {
    url.searchParams.set(key, String(value));
  }
};

const appendNumber = (
  url: URL,
  key: string,
  value: number | undefined
): void => {
  if (value !== undefined) {
    url.searchParams.set(key, String(value));
  }
};

const appendString = (
  url: URL,
  key: string,
  value: string | undefined
): void => {
  if (value) {
    url.searchParams.set(key, value);
  }
};

const appendStrings = (
  url: URL,
  key: string,
  values: readonly string[] | undefined
): void => {
  for (const value of values ?? []) {
    if (value) {
      url.searchParams.append(key, value);
    }
  }
};

const definedHeaders = (
  headers: Record<string, string | undefined> | undefined
): Record<string, string> => {
  const entries = Object.entries(headers ?? {}).filter(
    (entry): entry is [string, string] => entry[1] !== undefined
  );
  return Object.fromEntries(entries);
};
