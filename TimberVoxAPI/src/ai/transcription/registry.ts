import type { Env } from "../../bindings";
import { createDeepgramTranscriptionProvider } from "../deepgram/transcription/client";
import { createElevenLabsTranscriptionProvider } from "../elevenlabs/transcription/client";
import { createMistralTranscriptionProvider } from "../mistral/transcription/client";
import type { BatchAsrExecutionProviderId } from "../models/types";
import { createSuperwhisperTranscriptionProvider } from "../superwhisper/transcription";
import type { BatchTranscriptionProvider } from "./types";

export const resolveBatchTranscriptionProvider = (
  env: Env,
  provider: BatchAsrExecutionProviderId
): BatchTranscriptionProvider => {
  switch (provider) {
    case "deepgram":
      return createDeepgramTranscriptionProvider({
        apiKey: env.DEEPGRAM_API_KEY,
      });
    case "elevenlabs":
      return createElevenLabsTranscriptionProvider({
        apiKey: env.ELEVENLABS_API_KEY,
      });
    case "mistral":
      return createMistralTranscriptionProvider({
        apiKey: env.MISTRAL_API_KEY,
      });
    case "superwhisper":
      return createSuperwhisperTranscriptionProvider({ env });
    default:
      throw new Error(`unsupported batch transcription provider: ${provider}`);
  }
};
