import {
  createPeacockeryVoiceClient,
  type PeacockeryVoiceClient,
} from "@simonpeacocks/peacockery-voice-client";

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

// Every Worker request must carry a deadline; a hung connection otherwise
// strands the dictation workflow in a stage the user cannot leave.
async function withRequestTimeout<T>(
  milliseconds: number,
  label: string,
  run: (signal: AbortSignal) => Promise<T>,
): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), milliseconds);
  try {
    return await run(controller.signal);
  } catch (error) {
    if (controller.signal.aborted) {
      throw new Error(`${label} timed out. Check your connection and retry.`);
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

export { configuredVoiceClient, voiceApiError, withRequestTimeout };
export type { FetchImplementation };
