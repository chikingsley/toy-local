import { describe, expect, it } from "vitest";

import { parseDeepgramRealtimeEvent } from "../../src/ai/deepgram/realtime/events";
import { parseMistralRealtimeEvent } from "../../src/ai/mistral/realtime/events";
import {
  finalRealtimeTranscript,
  normalizeDeepgramTranscriptEvent,
  normalizeMistralTranscriptEvent,
  realtimeTranscriptEventFromStreamPart,
} from "../../src/ai/realtime/normalize";
import {
  terminalSessionEvent,
  transcriptProtocolEvent,
} from "../../src/ai/realtime/protocol";
import { realtimeTranscriptionArtifact } from "../../src/ai/transcription/artifact";

const requiredTranscriptKeys = [
  "protocol_version",
  "segments",
  "sequence",
  "session_id",
  "speaker_turns",
  "text",
  "type",
  "words",
];

const required = <T>(value: T | null | undefined): T => {
  if (value === null || value === undefined) {
    throw new Error("expected contract fixture to parse");
  }
  return value;
};

describe("provider-neutral realtime protocol", () => {
  it("maps Deepgram and Mistral committed speech to the same wire shape", () => {
    const deepgram = parseDeepgramRealtimeEvent(
      JSON.stringify({
        channel: {
          alternatives: [
            {
              transcript: "Safety meeting complete.",
              words: [
                {
                  confidence: 0.99,
                  end: 1.2,
                  punctuated_word: "Safety",
                  speaker: 0,
                  start: 0.8,
                },
              ],
            },
          ],
        },
        duration: 0.4,
        is_final: true,
        speech_final: true,
        start: 0.8,
        type: "Results",
      })
    );
    const mistral = parseMistralRealtimeEvent(
      JSON.stringify({
        end: 1.2,
        speaker_id: "0",
        start: 0.8,
        text: "Safety meeting complete.",
        type: "transcription.segment",
      })
    );

    const deepgramTranscript = required(
      normalizeDeepgramTranscriptEvent(required(deepgram))
    );
    const mistralTranscript = required(
      normalizeMistralTranscriptEvent(required(mistral))
    );
    const deepgramEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      deepgramTranscript
    );
    const mistralEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      mistralTranscript
    );

    expect(required(deepgramEvent).type).toBe("transcript.committed");
    expect(required(mistralEvent).type).toBe("transcript.committed");
    expect(Object.keys(required(deepgramEvent)).sort()).toEqual(
      [...requiredTranscriptKeys, "speech_final"].sort()
    );
    expect(Object.keys(required(mistralEvent)).sort()).toEqual(
      requiredTranscriptKeys.sort()
    );
    expect(deepgramEvent).not.toHaveProperty("channel");
    expect(mistralEvent).not.toHaveProperty("speaker_id");
  });

  it("expresses provider streaming differences without provider-specific events", () => {
    const deepgram = parseDeepgramRealtimeEvent(
      JSON.stringify({
        channel: { alternatives: [{ transcript: "Safety meet" }] },
        is_final: false,
        type: "Results",
      })
    );
    const mistral = parseMistralRealtimeEvent(
      JSON.stringify({
        text: "Safety meet",
        type: "transcription.text.delta",
      })
    );
    const deepgramEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      required(normalizeDeepgramTranscriptEvent(required(deepgram)))
    );
    const mistralEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      required(normalizeMistralTranscriptEvent(required(mistral)))
    );

    expect(required(deepgramEvent).type).toBe("transcript.interim");
    expect(required(mistralEvent).type).toBe("transcript.delta");
    expect(Object.keys(required(deepgramEvent)).sort()).toEqual(
      requiredTranscriptKeys.sort()
    );
    expect(Object.keys(required(mistralEvent)).sort()).toEqual(
      requiredTranscriptKeys.sort()
    );
  });

  it("assembles Mistral deltas instead of replacing them with a trailing done packet", () => {
    const events = [
      normalizeMistralTranscriptEvent(
        required(
          parseMistralRealtimeEvent(
            JSON.stringify({
              text: "TimberVox realtime dictation test",
              type: "transcription.text.delta",
            })
          )
        )
      ),
      normalizeMistralTranscriptEvent(
        required(
          parseMistralRealtimeEvent(
            JSON.stringify({
              text: ".",
              type: "transcription.text.delta",
            })
          )
        )
      ),
      normalizeMistralTranscriptEvent(
        required(
          parseMistralRealtimeEvent(
            JSON.stringify({
              language: "en",
              model: "voxtral-mini-transcribe-realtime-2602",
              text: ".",
              type: "transcription.done",
            })
          )
        )
      ),
    ].map(required);

    expect(finalRealtimeTranscript("mistral", events)).toBe(
      "TimberVox realtime dictation test."
    );

    const artifact = realtimeTranscriptionArtifact({
      audioBytes: 32_000,
      completedAt: "2026-07-11T12:00:01.000Z",
      events,
      messageCount: 3,
      model: "mistral-voxtral-realtime",
      provider: "mistral",
      providerEvents: [],
      providerMetadata: {},
      requestedLanguage: "en",
      responses: [],
      resultSegments: [],
      runId: "rt_mistral_deltas",
      sampleRate: 16_000,
      startedAt: "2026-07-11T12:00:00.000Z",
      upstreamModel: "voxtral-mini-transcribe-realtime-2602",
      warnings: [],
    });
    expect(artifact.text).toBe("TimberVox realtime dictation test.");
  });

  it("normalizes Deepgram timed segments into the persisted artifact schema", () => {
    const deepgram = required(
      normalizeDeepgramTranscriptEvent(
        required(
          parseDeepgramRealtimeEvent(
            JSON.stringify({
              channel: {
                alternatives: [
                  {
                    transcript: "TimberVox realtime dictation test.",
                    words: [
                      {
                        confidence: 0.99,
                        end: 0.5,
                        start: 0,
                        word: "TimberVox",
                      },
                    ],
                  },
                ],
              },
              duration: 1.25,
              is_final: true,
              speech_final: true,
              start: 0,
              type: "Results",
            })
          )
        )
      )
    );
    const artifact = realtimeTranscriptionArtifact({
      audioBytes: 40_000,
      completedAt: "2026-07-11T12:00:01.250Z",
      events: [deepgram],
      messageCount: 1,
      model: "deepgram-nova-3",
      provider: "deepgram",
      providerEvents: [],
      providerMetadata: {},
      requestedLanguage: "en",
      responses: [],
      resultSegments: [],
      runId: "rt_deepgram_segments",
      sampleRate: 16_000,
      startedAt: "2026-07-11T12:00:00.000Z",
      upstreamModel: "nova-3",
      warnings: [],
    });

    expect(artifact.text).toBe("TimberVox realtime dictation test.");
    expect(artifact.content.segments.items).toEqual([
      {
        end_seconds: 1.25,
        scores: null,
        speaker: null,
        start_seconds: 0,
        text: "TimberVox realtime dictation test.",
      },
    ]);
  });

  it("uses one terminal result contract for either provider", () => {
    const artifact = (provider: "deepgram" | "mistral") =>
      realtimeTranscriptionArtifact({
        audioBytes: 32_000,
        completedAt: "2026-07-11T12:00:01.000Z",
        events: [
          {
            delivery: "committed",
            isFinal: true,
            providerEvent: null,
            segments: [],
            speakerTurns: [],
            text: "Safety meeting complete.",
            type: "transcript",
            words: [],
          },
        ],
        messageCount: 10,
        model: "test-model",
        provider,
        providerEvents: [],
        providerMetadata: {},
        requestedLanguage: "en",
        responses: [],
        resultSegments: [],
        runId: "rt_contract",
        sampleRate: 16_000,
        startedAt: "2026-07-11T12:00:00.000Z",
        upstreamModel: "test-upstream-model",
        warnings: [],
      });
    const base = (provider: "deepgram" | "mistral") => ({
      result: artifact(provider),
      sessionId: "rt_contract",
      status: "succeeded" as const,
    });
    const deepgram = terminalSessionEvent(base("deepgram"), 4);
    const mistral = terminalSessionEvent(base("mistral"), 4);

    expect(deepgram.type).toBe("session.completed");
    expect(mistral.type).toBe("session.completed");
    expect(Object.keys(deepgram).sort()).toEqual(Object.keys(mistral).sort());
    expect(deepgram.result.provenance.provider).toBe("deepgram");
    expect(deepgram).not.toHaveProperty("transcript");
  });

  it("maps the AI SDK transcription stream into the TimberVox protocol", () => {
    const streamEvent = realtimeTranscriptEventFromStreamPart({
      endSecond: 1.2,
      providerMetadata: {
        timbervox: {
          segments: [
            {
              endSeconds: 1.2,
              startSeconds: 0.8,
              text: "Safety meeting complete.",
            },
          ],
          speakerTurns: [],
          words: [
            {
              endSeconds: 1.2,
              scores: { confidence: 0.99 },
              speaker: 0,
              startSeconds: 0.8,
              text: "Safety",
            },
          ],
        },
      },
      startSecond: 0.8,
      text: "Safety meeting complete.",
      type: "transcript-final",
    });
    const protocolEvent = transcriptProtocolEvent(
      "rt_contract",
      2,
      required(streamEvent)
    );

    expect(required(protocolEvent).type).toBe("transcript.committed");
    expect(required(protocolEvent).words).toEqual([
      {
        endSeconds: 1.2,
        scores: { confidence: 0.99 },
        speaker: 0,
        startSeconds: 0.8,
        text: "Safety",
      },
    ]);
  });
});
