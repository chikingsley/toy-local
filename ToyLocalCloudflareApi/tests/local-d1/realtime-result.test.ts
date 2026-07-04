import { randomUUID } from "node:crypto";
import { beforeAll, describe, expect, it } from "vitest";

import {
  finalRealtimeTranscript,
  normalizeDeepgramTranscriptEvent,
  normalizeMistralTranscriptEvent,
  persistRealtimeResult,
} from "../../src/realtime/result";
import { executeD1, localD1Env, migrateLocalD1 } from "./helpers";

describe("local D1 realtime result persistence", () => {
  beforeAll(async () => {
    await migrateLocalD1();
  });

  it("normalizes provider events and persists transcript artifacts, session metadata, and usage", async () => {
    const env = localD1Env();
    const sessionId = `rt_${randomUUID()}`;
    const clientId = `client_${randomUUID()}`;
    const deepgramEvent = normalizeDeepgramTranscriptEvent({
      channel: {
        alternatives: [
          {
            transcript: "hello from deepgram",
            words: [
              {
                confidence: 0.99,
                end: 0.5,
                punctuated_word: "hello",
                speaker: 0,
                start: 0,
              },
            ],
          },
        ],
      },
      is_final: true,
      speech_final: true,
      type: "Results",
    });
    const mistralEvent = normalizeMistralTranscriptEvent({
      language: "en",
      model: "voxtral-mini-2507",
      text: "hello from mistral",
      type: "transcription.done",
    });

    expect(deepgramEvent).toMatchObject({
      is_final: true,
      text: "hello from deepgram",
    });
    expect(mistralEvent).toMatchObject({
      is_final: true,
      text: "hello from mistral",
    });
    if (!(deepgramEvent && mistralEvent)) {
      throw new Error("expected realtime transcript events");
    }
    expect(finalRealtimeTranscript("deepgram", [deepgramEvent])).toBe(
      "hello from deepgram"
    );
    expect(finalRealtimeTranscript("mistral", [mistralEvent])).toBe(
      "hello from mistral"
    );

    const result = await persistRealtimeResult(
      env,
      {
        clientId,
        language: "en",
        model: "deepgram-nova-3",
        provider: "deepgram",
        sampleRate: 16_000,
        sessionId,
        upstreamModel: "nova-3",
      },
      {
        audioBytes: 32_000,
        endedAt: "2026-07-02T00:00:01.000Z",
        events: [deepgramEvent],
        messageCount: 3,
        startedAt: "2026-07-02T00:00:00.000Z",
        status: "succeeded",
      }
    );

    expect(result).toMatchObject({
      transcript: "hello from deepgram",
      transcriptJsonKey: `realtime/${clientId}/${sessionId}/transcript.json`,
      transcriptTextKey: `realtime/${clientId}/${sessionId}/transcript.txt`,
    });
    const transcriptObject = await env.ARTIFACTS.get(result.transcriptTextKey);
    await expect(transcriptObject?.text()).resolves.toBe("hello from deepgram");

    const sessionRows = await executeD1<{
      audio_seconds: number;
      transcript: string;
      transcript_json_key: string;
    }>(`
      SELECT transcript, transcript_json_key, audio_seconds
      FROM realtime_sessions
      WHERE id = '${sessionId}'
    `);
    expect(sessionRows.results[0]).toEqual({
      audio_seconds: 1,
      transcript: "hello from deepgram",
      transcript_json_key: result.transcriptJsonKey,
    });

    const usageRows = await executeD1<{
      asr_seconds: number;
      kind: string;
      request_count: number;
    }>(`
      SELECT kind, request_count, asr_seconds
      FROM usage_daily
      WHERE account_key = '${clientId}'
        AND kind = 'realtime_asr'
    `);
    expect(usageRows.results[0]).toEqual({
      asr_seconds: 1,
      kind: "realtime_asr",
      request_count: 1,
    });
  });
});
