import { parseNativeResultEnvelope } from "@/features/dictation/native-result-bridge";

jest.mock("timbervox-system", () => ({
  acknowledgeNativeResult: jest.fn(),
  getNativeResultOutbox: jest.fn(() => []),
}));

jest.mock("@/features/dictation/dictation-repository", () => ({
  persistDictationOutcome: jest.fn(),
}));

jest.mock("@/features/keyboard/app-group-bridge", () => ({
  readBridgeNumber: jest.fn(),
  readBridgeString: jest.fn(),
  writeBridgeNumber: jest.fn(),
}));

const envelope = {
  artifactJSON: JSON.stringify({ schema_version: 2, text: "hello" }),
  createdAt: "2026-07-15T08:00:00Z",
  durationMs: 1_500,
  endedAt: "2026-07-15T08:00:01Z",
  entryPoint: "shortcut",
  errorCode: null,
  errorMessage: null,
  finalText: "Hello.",
  mode: {
    asrModelId: "mistral/voxtral-mini-latest",
    batchModelId: "mistral/voxtral-mini-latest",
    description: "Voice to Text",
    iconKey: "waveform",
    id: "mode_voice",
    identifySpeakers: false,
    language: null,
    name: "Voice to Text",
    presetKind: "voice",
    processingInstructions: null,
    processingModelId: null,
    realtimeModel: "voxtral-realtime",
  },
  rawText: "hello",
  recordingURI: "file:///shortcut.wav",
  requestId: "shortcut_request",
  resultId: "shortcut_result",
  schemaVersion: 1,
  startedAt: "2026-07-15T08:00:00Z",
  status: "succeeded",
};

describe("native Shortcut result envelope", () => {
  it("accepts the complete versioned result contract", () => {
    expect(parseNativeResultEnvelope(JSON.stringify(envelope))).toEqual(
      envelope,
    );
  });

  it("rejects an unsupported schema before persistence", () => {
    expect(() =>
      parseNativeResultEnvelope(
        JSON.stringify({ ...envelope, schemaVersion: 2 }),
      ),
    ).toThrow("unsupported schema");
  });

  it("rejects a mode without the batch route used by the native intent", () => {
    const { batchModelId: _batchModelId, ...mode } = envelope.mode;
    expect(() =>
      parseNativeResultEnvelope(JSON.stringify({ ...envelope, mode })),
    ).toThrow("invalid");
  });
});
