import { readFile } from "node:fs/promises";
import { basename, extname, resolve } from "node:path";
import { describe, expect, it } from "vitest";

import { transcribeAudio } from "../../src/ai/batch-transcribe";
import { liveEnv, liveTestsEnabled } from "./env";

interface AsrCase {
  envKey: string;
  model: string;
}

const audioFixturePath =
  process.env.TIMBERVOX_LIVE_ASR_AUDIO_FILE ??
  process.env.LIVE_ASR_AUDIO_FILE ??
  resolve("tests/fixtures/audio/asr-smoke.wav");

const contentTypeByExtension: Record<string, string> = {
  ".flac": "audio/flac",
  ".m4a": "audio/mp4",
  ".mp3": "audio/mpeg",
  ".ogg": "audio/ogg",
  ".opus": "audio/ogg",
  ".wav": "audio/wav",
  ".webm": "audio/webm",
};

const contentType = (path: string): string =>
  contentTypeByExtension[extname(path).toLowerCase()] ??
  "application/octet-stream";

const audioBuffer = async (path: string): Promise<ArrayBuffer> => {
  const bytes = await readFile(path);
  return new Uint8Array(bytes).buffer;
};

const cases: AsrCase[] = [
  { envKey: "MISTRAL_API_KEY", model: "mistral-voxtral-mini-latest" },
  { envKey: "DEEPGRAM_API_KEY", model: "deepgram-nova-3" },
  { envKey: "ELEVENLABS_API_KEY", model: "elevenlabs-scribe_v2" },
  { envKey: "GROQ_API_KEY", model: "groq-whisper-large-v3-turbo" },
  { envKey: "ASSEMBLYAI_API_KEY", model: "assemblyai-best" },
];

describe("live ASR providers", () => {
  for (const testCase of cases) {
    it.skipIf(
      !(liveTestsEnabled && audioFixturePath && process.env[testCase.envKey])
    )(`transcribes with ${testCase.model}`, async () => {
      if (!audioFixturePath) {
        throw new Error("missing TIMBERVOX_LIVE_ASR_AUDIO_FILE");
      }
      const result = await transcribeAudio(liveEnv(), testCase.model, {
        contentType: contentType(audioFixturePath),
        data: await audioBuffer(audioFixturePath),
        filename: basename(audioFixturePath),
      });

      expect(result.result.text.trim().length).toBeGreaterThan(0);
    });
  }

  it.skipIf(
    !(liveTestsEnabled && audioFixturePath && process.env.DEEPGRAM_API_KEY)
  )("transcribes with explicit Deepgram diarization", async () => {
    if (!audioFixturePath) {
      throw new Error("missing TIMBERVOX_LIVE_ASR_AUDIO_FILE");
    }
    const result = await transcribeAudio(liveEnv(), "deepgram-nova-3", {
      contentType: contentType(audioFixturePath),
      data: await audioBuffer(audioFixturePath),
      filename: basename(audioFixturePath),
      providerOptions: {
        deepgram: {
          diarize: true,
          smartFormat: true,
        },
      },
    });

    expect(result.result.text.trim().length).toBeGreaterThan(0);
    expect(result.result.segments?.length ?? 0).toBeGreaterThan(0);
  });
});
