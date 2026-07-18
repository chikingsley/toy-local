import type { SQLiteDatabase } from "expo-sqlite";

import { persistDictationOutcome } from "@/features/dictation/dictation-repository";
import type { DictationOutcome } from "@/features/dictation/dictation-types";
import {
  deleteRecording,
  persistRecording,
} from "@/features/dictation/recording-file";

jest.mock("@/features/dictation/recording-file", () => ({
  deleteRecording: jest.fn(),
  persistRecording: jest.fn(() => ({
    format: "audio/wav",
    sizeBytes: 48,
    uri: "file:///recordings/request_1_dictation_1.wav",
  })),
}));

const outcome: DictationOutcome = {
  artifacts: [
    {
      id: "dictation_1_raw",
      kind: "raw",
      modelId: "voxtral",
      payload: { schema_version: 2, text: "hello world" },
      text: "hello world",
      timing: null,
    },
  ],
  audioChunks: [new Uint8Array([1, 2, 3, 4]).buffer],
  createdAt: "2026-07-14T10:00:00.000Z",
  durationMs: 2_000,
  endedAt: "2026-07-14T10:00:02.000Z",
  entryPoint: "keyboard",
  error: null,
  language: "en",
  mode: {
    asrModelId: "voxtral",
    description: "Voice",
    iconKey: "waveform",
    id: "mode_voice",
    identifySpeakers: false,
    language: "en",
    name: "Voice to Text",
    presetKind: "voice",
    processingInstructions: null,
    processingModelId: null,
    realtimeModel: "voxtral-realtime",
  },
  requestId: "request_1",
  resultId: "dictation_1",
  startedAt: "2026-07-14T10:00:00.000Z",
  status: "succeeded",
};

function databaseThatRuns(
  runAsync = jest.fn(async (_query: string, ..._params: unknown[]) => ({
    changes: 1,
  })),
) {
  const database = {
    withExclusiveTransactionAsync: jest.fn(
      async (task: (transaction: SQLiteDatabase) => Promise<void>) => {
        await task({ runAsync } as unknown as SQLiteDatabase);
      },
    ),
  } as unknown as SQLiteDatabase;
  return { database, runAsync };
}

describe("durable dictation repository", () => {
  beforeEach(() => jest.clearAllMocks());

  it("writes the recording and commits Dictation plus Raw Artifact in one transaction", async () => {
    const { database, runAsync } = databaseThatRuns();

    await persistDictationOutcome(database, outcome);

    expect(persistRecording).toHaveBeenCalledWith(
      outcome.audioChunks,
      "request_1",
      "dictation_1",
    );
    expect(database.withExclusiveTransactionAsync).toHaveBeenCalledTimes(1);
    expect(runAsync).toHaveBeenCalledTimes(2);
    expect(runAsync.mock.calls[0][0]).toContain("INSERT INTO dictations");
    expect(runAsync.mock.calls[0]).toEqual(
      expect.arrayContaining([
        "dictation_1",
        "request_1",
        "keyboard",
        "succeeded",
        "file:///recordings/request_1_dictation_1.wav",
      ]),
    );
    expect(runAsync.mock.calls[1][0]).toContain("INSERT INTO artifacts");
    expect(runAsync.mock.calls[1]).toEqual(
      expect.arrayContaining(["dictation_1_raw", "raw", "hello world"]),
    );
  });

  it("removes the just-written WAV when the database transaction fails", async () => {
    const database = {
      withExclusiveTransactionAsync: jest.fn(async () => {
        throw new Error("disk full");
      }),
    } as unknown as SQLiteDatabase;

    await expect(persistDictationOutcome(database, outcome)).rejects.toThrow(
      "disk full",
    );
    expect(deleteRecording).toHaveBeenCalledWith(
      "file:///recordings/request_1_dictation_1.wav",
    );
  });
});
