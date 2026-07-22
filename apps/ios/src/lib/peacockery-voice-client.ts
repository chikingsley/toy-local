import {
  createPeacockeryVoiceClient,
  type PeacockeryVoiceClient,
} from "@chikingsley/peacockery-voice-client";

import { configuredApiOrigin } from "@/lib/api-credential";

type FetchImplementation = typeof fetch;

function configuredVoiceClient(
  credential: string,
  fetchImplementation: FetchImplementation = fetch,
): PeacockeryVoiceClient {
  return createPeacockeryVoiceClient({
    apiKey: credential,
    baseUrl: configuredApiOrigin(),
    fetch: fetchImplementation,
  });
}

function voiceApiError(operation: string, response: Response, error: unknown) {
  const detail =
    isRecord(error) && typeof error.error === "string"
      ? `: ${error.error}`
      : ".";
  return new Error(`${operation} failed (${response.status})${detail}`);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export { configuredVoiceClient, voiceApiError };
export type { FetchImplementation };
