import { customProvider } from "ai";

import type { MistralConfig } from "./config";
import { MistralTranscriptionModel } from "./transcription/model";

export interface MistralProviderSettings {
  apiKey: string;
  baseUrl?: string;
  fetch?: typeof fetch;
  headers?: Record<string, string | undefined>;
}

export const createMistralProvider = (
  settings: MistralProviderSettings
): ReturnType<typeof customProvider> =>
  customProvider({
    transcriptionModels: {
      "voxtral-mini-2602": new MistralTranscriptionModel(
        "voxtral-mini-2602",
        mistralConfig(settings, "mistral.transcription")
      ),
      "voxtral-mini-latest": new MistralTranscriptionModel(
        "voxtral-mini-latest",
        mistralConfig(settings, "mistral.transcription")
      ),
      "voxtral-mini-2507": new MistralTranscriptionModel(
        "voxtral-mini-2507",
        mistralConfig(settings, "mistral.transcription")
      ),
    },
  });

const mistralConfig = (
  settings: MistralProviderSettings,
  provider: string
): MistralConfig => ({
  apiKey: settings.apiKey,
  baseUrl: settings.baseUrl,
  fetch: settings.fetch,
  headers: settings.headers,
  provider,
});
