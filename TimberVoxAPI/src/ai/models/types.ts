export type LanguageModelProviderId =
  | "anthropic"
  | "cerebras"
  | "deepseek"
  | "google"
  | "groq"
  | "mistral"
  | "openai"
  | "zai";

export type BatchAsrProviderId = "deepgram" | "elevenlabs" | "mistral";

export type RealtimeAsrProviderId = "deepgram" | "mistral";

export interface LanguageModelEntry {
  provider: LanguageModelProviderId;
  providerModelId: `${LanguageModelProviderId}:${string}`;
  upstreamModel: string;
}

export interface BatchAsrModelEntry {
  acceptedOptions: readonly AcceptedAsrOptionName[];
  provider: BatchAsrProviderId;
  supportedLanguages: readonly string[];
  supportsAutomaticLanguage: boolean;
  upstreamModel: string;
}

export interface RealtimeAsrModelEntry {
  acceptedOptions: readonly AcceptedAsrOptionName[];
  provider: RealtimeAsrProviderId;
  supportedLanguages: readonly string[];
  supportsAutomaticLanguage: boolean;
  upstreamModel: string;
}

export type PublicModelKind = "language" | "transcription";
export type AsrTransport = "batch" | "realtime";
export type AcceptedAsrOptionName = string;

export interface PublicAsrRouteSpec {
  acceptedOptions: readonly AcceptedAsrOptionName[];
  model: string;
  provider: BatchAsrProviderId | RealtimeAsrProviderId;
  supportedLanguages: readonly string[];
  supportsAutomaticLanguage: boolean;
  supportsDiarization: boolean;
  upstreamModel: string;
}

interface PublicLanguageModelSpec {
  acceptedOptions?: never;
  id: string;
  kind: "language";
  provider: LanguageModelProviderId;
  routes?: never;
  supportedLanguages?: never;
  transports?: never;
  upstreamModel: string;
}

export interface PublicTranscriptionModelSpec {
  acceptedOptions: Partial<
    Record<AsrTransport, readonly AcceptedAsrOptionName[]>
  >;
  id: string;
  kind: "transcription";
  provider: BatchAsrProviderId | RealtimeAsrProviderId;
  routes: Partial<Record<AsrTransport, PublicAsrRouteSpec>>;
  supportedLanguages: readonly string[];
  transports: readonly AsrTransport[];
  upstreamModel: string;
}

export type PublicModelSpec =
  | PublicLanguageModelSpec
  | PublicTranscriptionModelSpec;
